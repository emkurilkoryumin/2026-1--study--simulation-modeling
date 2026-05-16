module DiscreteEventLab07

using DataFrames
using Distributions
using Random
using StableRNGs
using Statistics

factorial_float(n::Integer) = n <= 1 ? 1.0 : prod(Float64.(1:n))

function plotsmod()
    @eval import Plots
    return Plots
end

function mmc_theory(arrival_rate::Real, service_rate::Real, num_servers::Integer)
    λ = Float64(arrival_rate)
    μ = Float64(service_rate)
    c = Int(num_servers)

    offered_load = λ / μ
    ρ = λ / (c * μ)

    if !(λ < c * μ)
        return (
            rho = ρ,
            prob_wait = 1.0,
            mean_wait = Inf,
            mean_system = Inf,
            mean_queue = Inf,
            mean_system_size = Inf,
            utilization = min(ρ, 1.0),
        )
    end

    tail = (offered_load^c) / (factorial_float(c) * (1.0 - ρ))
    p0 = 1.0 / (sum((offered_load^n) / factorial_float(n) for n in 0:(c - 1)) + tail)
    prob_wait = tail * p0
    mean_wait = prob_wait / (c * μ - λ)
    mean_system = mean_wait + 1.0 / μ
    mean_queue = λ * mean_wait
    mean_system_size = λ * mean_system

    return (
        rho = ρ,
        prob_wait = prob_wait,
        mean_wait = mean_wait,
        mean_system = mean_system,
        mean_queue = mean_queue,
        mean_system_size = mean_system_size,
        utilization = ρ,
    )
end

function build_state_trace(events::Vector{NamedTuple})
    sort!(events, by = event -> (event.time, event.priority))

    queue_length = 0
    busy_servers = 0
    last_time = 0.0
    area_queue = 0.0
    area_service = 0.0

    times = Float64[0.0]
    queue_trace = Int[0]
    service_trace = Int[0]

    for event in events
        dt = event.time - last_time
        area_queue += queue_length * dt
        area_service += busy_servers * dt
        last_time = event.time

        queue_length += event.queue_delta
        busy_servers += event.service_delta

        push!(times, event.time)
        push!(queue_trace, queue_length)
        push!(service_trace, busy_servers)
    end

    return (
        state = DataFrame(
            time = times,
            queue_length = queue_trace,
            busy_servers = service_trace,
        ),
        area_queue = area_queue,
        area_service = area_service,
        end_time = last_time,
    )
end

function simulate_mmc(;
    num_customers::Integer = 1500,
    num_servers::Integer = 2,
    arrival_rate::Real = 0.85,
    service_rate::Real = 0.5,
    warmup_customers::Integer = 200,
    seed::Integer = 123,
)
    rng = StableRNG(seed)
    arrival_dist = Exponential(1.0 / Float64(arrival_rate))
    service_dist = Exponential(1.0 / Float64(service_rate))

    arrivals = Vector{Float64}(undef, num_customers)
    starts = Vector{Float64}(undef, num_customers)
    departures = Vector{Float64}(undef, num_customers)
    service_times = rand(rng, service_dist, num_customers)
    server_available = fill(0.0, num_servers)

    current_arrival = 0.0
    for i in 1:num_customers
        current_arrival += rand(rng, arrival_dist)
        arrivals[i] = current_arrival

        server_idx = argmin(server_available)
        starts[i] = max(arrivals[i], server_available[server_idx])
        departures[i] = starts[i] + service_times[i]
        server_available[server_idx] = departures[i]
    end

    events = NamedTuple[]
    for i in 1:num_customers
        push!(events, (time = arrivals[i], priority = 2, queue_delta = 1, service_delta = 0))
        push!(events, (time = starts[i], priority = 3, queue_delta = -1, service_delta = 1))
        push!(events, (time = departures[i], priority = 1, queue_delta = 0, service_delta = -1))
    end

    trace = build_state_trace(events)
    total_time = max(trace.end_time, eps(Float64))

    customers = DataFrame(
        id = collect(1:num_customers),
        arrival_time = arrivals,
        start_time = starts,
        departure_time = departures,
        service_time = service_times,
    )
    customers.wait_time = customers.start_time .- customers.arrival_time
    customers.system_time = customers.departure_time .- customers.arrival_time

    theory = mmc_theory(arrival_rate, service_rate, num_servers)
    start_idx = min(max(Int(warmup_customers) + 1, 1), num_customers)
    steady = customers[start_idx:end, :]

    summary = DataFrame(
        num_customers = [num_customers],
        warmup_customers = [warmup_customers],
        num_servers = [num_servers],
        arrival_rate = [Float64(arrival_rate)],
        service_rate = [Float64(service_rate)],
        mean_wait_sim = [mean(steady.wait_time)],
        mean_wait_theory = [theory.mean_wait],
        mean_system_sim = [mean(steady.system_time)],
        mean_system_theory = [theory.mean_system],
        avg_queue_sim = [trace.area_queue / total_time],
        avg_queue_theory = [theory.mean_queue],
        utilization_sim = [trace.area_service / (num_servers * total_time)],
        utilization_theory = [theory.utilization],
        prob_wait_sim = [mean(steady.wait_time .> 1e-9)],
        prob_wait_theory = [theory.prob_wait],
    )

    return (customers = customers, state = trace.state, summary = summary)
end

function ross_analytic_mttf(;
    N::Integer = 10,
    S::Integer = 3,
    num_repairers::Integer = 1,
    failure_mean::Real = 20.0,
    repair_mean::Real = 8.0,
)
    λ = N / Float64(failure_mean)
    μ = 1.0 / Float64(repair_mean)
    states = collect(N:(N + S))
    A = zeros(Float64, length(states), length(states))
    b = ones(Float64, length(states))

    for (idx, healthy) in enumerate(states)
        in_repair = N + S - healthy
        repair_rate = min(num_repairers, in_repair) * μ

        if healthy == N
            A[idx, idx] = λ + repair_rate
            if idx < length(states)
                A[idx, idx + 1] = -repair_rate
            end
        elseif healthy == N + S
            A[idx, idx] = λ
            if idx > 1
                A[idx, idx - 1] = -λ
            end
        else
            A[idx, idx] = λ + repair_rate
            A[idx, idx - 1] = -λ
            A[idx, idx + 1] = -repair_rate
        end
    end

    solution = A \ b
    return solution[end]
end

function simulate_ross(;
    N::Integer = 10,
    S::Integer = 3,
    num_repairers::Integer = 2,
    failure_mean::Real = 20.0,
    repair_mean::Real = 8.0,
    seed::Integer = 42,
)
    rng = StableRNG(seed)
    failure_rate = N / Float64(failure_mean)
    repair_rate = 1.0 / Float64(repair_mean)

    t = 0.0
    spares = Int(S)
    busy_repairers = 0
    repair_queue = 0
    healthy = N + S

    times = Float64[0.0]
    healthy_trace = Int[healthy]
    busy_trace = Int[0]
    queue_trace = Int[0]

    area_busy = 0.0
    area_queue = 0.0
    failures = 0
    repairs = 0

    while true
        dt_failure = randexp(rng) / failure_rate
        dt_repair = busy_repairers > 0 ? randexp(rng) / (busy_repairers * repair_rate) : Inf

        dt = min(dt_failure, dt_repair)
        t += dt
        area_busy += busy_repairers * dt
        area_queue += repair_queue * dt

        if dt_failure <= dt_repair
            failures += 1
            healthy -= 1

            if spares > 0
                spares -= 1
                if busy_repairers < num_repairers
                    busy_repairers += 1
                else
                    repair_queue += 1
                end

                push!(times, t)
                push!(healthy_trace, healthy)
                push!(busy_trace, busy_repairers)
                push!(queue_trace, repair_queue)
            else
                push!(times, t)
                push!(healthy_trace, healthy)
                push!(busy_trace, busy_repairers)
                push!(queue_trace, repair_queue)
                break
            end
        else
            repairs += 1
            spares += 1
            healthy += 1

            if repair_queue > 0
                repair_queue -= 1
            else
                busy_repairers -= 1
            end

            push!(times, t)
            push!(healthy_trace, healthy)
            push!(busy_trace, busy_repairers)
            push!(queue_trace, repair_queue)
        end
    end

    total_time = max(t, eps(Float64))
    state = DataFrame(
        time = times,
        healthy = healthy_trace,
        busy_repairers = busy_trace,
        repair_queue = queue_trace,
    )

    summary = DataFrame(
        N = [N],
        S = [S],
        num_repairers = [num_repairers],
        failure_mean = [Float64(failure_mean)],
        repair_mean = [Float64(repair_mean)],
        crash_time = [t],
        crash_time_theory = [ross_analytic_mttf(
            N = N,
            S = S,
            num_repairers = num_repairers,
            failure_mean = failure_mean,
            repair_mean = repair_mean,
        )],
        mean_utilization = [area_busy / (num_repairers * total_time)],
        avg_queue_length = [area_queue / total_time],
        failures = [failures],
        repairs = [repairs],
        status = ["system crashed"],
    )

    return (state = state, summary = summary)
end

function ross_parameter_grid(;
    machine_counts::AbstractVector{<:Integer} = [8, 10, 12, 14],
    repairer_counts::AbstractVector{<:Integer} = [1, 2, 3],
    num_runs::Integer = 30,
    S::Integer = 3,
    failure_mean::Real = 20.0,
    repair_mean::Real = 8.0,
    seed::Integer = 700,
)
    rows = NamedTuple[]

    for num_repairers in repairer_counts
        for N in machine_counts
            crash_times = Float64[]
            utilizations = Float64[]
            queue_lengths = Float64[]

            for run_id in 1:num_runs
                result = simulate_ross(
                    N = N,
                    S = S,
                    num_repairers = num_repairers,
                    failure_mean = failure_mean,
                    repair_mean = repair_mean,
                    seed = seed + 1000 * num_repairers + 100 * N + run_id,
                )

                push!(crash_times, result.summary.crash_time[1])
                push!(utilizations, result.summary.mean_utilization[1])
                push!(queue_lengths, result.summary.avg_queue_length[1])
            end

            push!(
                rows,
                (
                    N = N,
                    S = S,
                    num_repairers = num_repairers,
                    num_runs = num_runs,
                    crash_time_sim = mean(crash_times),
                    crash_time_std = length(crash_times) > 1 ? std(crash_times) : 0.0,
                    crash_time_theory = ross_analytic_mttf(
                        N = N,
                        S = S,
                        num_repairers = num_repairers,
                        failure_mean = failure_mean,
                        repair_mean = repair_mean,
                    ),
                    utilization = mean(utilizations),
                    avg_queue_length = mean(queue_lengths),
                ),
            )
        end
    end

    return DataFrame(rows)
end

function plot_mmc_timeline(state::DataFrame; title::AbstractString = "Динамика очереди M/M/c")
    P = plotsmod()
    p = P.plot(
        state.time,
        state.queue_length;
        label = "Длина очереди",
        seriestype = :steppost,
        linewidth = 2,
        xlabel = "Время",
        ylabel = "Число заявок",
        color = :firebrick,
        title = title,
        grid = true,
        size = (900, 520),
    )
    P.plot!(
        p,
        state.time,
        state.busy_servers;
        label = "Занятые каналы",
        seriestype = :steppost,
        linewidth = 2,
        color = :royalblue,
    )
    return p
end

function plot_mmc_wait_hist(
    customers::DataFrame;
    warmup_customers::Integer = 0,
    title::AbstractString = "Распределение времени ожидания",
)
    start_idx = min(max(Int(warmup_customers) + 1, 1), nrow(customers))
    P = plotsmod()
    return P.histogram(
        customers.wait_time[start_idx:end];
        bins = 30,
        normalize = true,
        xlabel = "Время ожидания",
        ylabel = "Плотность",
        title = title,
        color = :darkorange,
        alpha = 0.75,
        legend = false,
        grid = true,
        size = (900, 520),
    )
end

function plot_mmc_scan(scan::DataFrame)
    P = plotsmod()
    p1 = P.plot(
        scan.arrival_rate,
        scan.mean_wait_sim;
        label = "Имитация",
        marker = :circle,
        linewidth = 2,
        xlabel = "λ",
        ylabel = "Среднее ожидание",
        title = "M/M/c: среднее время ожидания",
        color = :firebrick,
        grid = true,
        size = (900, 900),
    )
    P.plot!(
        p1,
        scan.arrival_rate,
        scan.mean_wait_theory;
        label = "Теория Эрланга C",
        marker = :diamond,
        linestyle = :dash,
        linewidth = 2,
        color = :royalblue,
    )

    p2 = P.plot(
        scan.arrival_rate,
        scan.prob_wait_sim;
        label = "Имитация",
        marker = :circle,
        linewidth = 2,
        xlabel = "λ",
        ylabel = "Вероятность ожидания",
        title = "M/M/c: вероятность ожидания",
        color = :darkgreen,
        grid = true,
        size = (900, 900),
    )
    P.plot!(
        p2,
        scan.arrival_rate,
        scan.prob_wait_theory;
        label = "Теория Эрланга C",
        marker = :diamond,
        linestyle = :dash,
        linewidth = 2,
        color = :purple,
    )

    return P.plot(p1, p2; layout = (2, 1), size = (900, 900))
end

function plot_ross_state(state::DataFrame; title::AbstractString = "Число исправных машин")
    P = plotsmod()
    return P.plot(
        state.time,
        state.healthy;
        label = "Исправные машины",
        seriestype = :steppost,
        linewidth = 2,
        color = :royalblue,
        xlabel = "Время",
        ylabel = "Число машин",
        title = title,
        grid = true,
        size = (900, 520),
    )
end

function plot_ross_repair_monitor(
    state::DataFrame;
    title::AbstractString = "Мониторинг ремонтной подсистемы",
)
    P = plotsmod()
    p = P.plot(
        state.time,
        state.busy_repairers;
        label = "Занятые ремонтники",
        seriestype = :steppost,
        linewidth = 2,
        color = :darkgreen,
        xlabel = "Время",
        ylabel = "Число ресурсов",
        title = title,
        grid = true,
        size = (900, 520),
    )
    P.plot!(
        p,
        state.time,
        state.repair_queue;
        label = "Очередь на ремонт",
        seriestype = :steppost,
        linewidth = 2,
        color = :firebrick,
    )
    return p
end

function plot_ross_scan(scan::DataFrame)
    P = plotsmod()
    repairer_counts = sort(unique(scan.num_repairers))
    colors = [:firebrick, :royalblue, :darkgreen, :darkorange]

    p1 = P.plot(
        xlabel = "N",
        ylabel = "Среднее время до отказа",
        title = "Модель Росса: имитация и аналитика",
        grid = true,
        size = (900, 1200),
    )
    p2 = P.plot(
        xlabel = "N",
        ylabel = "Средняя загрузка",
        title = "Загрузка ремонтников",
        grid = true,
        size = (900, 1200),
    )
    p3 = P.plot(
        xlabel = "N",
        ylabel = "Средняя длина очереди",
        title = "Очередь на ремонт",
        grid = true,
        size = (900, 1200),
    )

    for (idx, num_repairers) in enumerate(repairer_counts)
        subset = sort(scan[scan.num_repairers .== num_repairers, :], :N)
        color = colors[mod1(idx, length(colors))]
        P.plot!(
            p1,
            subset.N,
            subset.crash_time_sim;
            label = "Имитация, r=$(num_repairers)",
            marker = :circle,
            linewidth = 2,
            color = color,
        )
        P.plot!(
            p1,
            subset.N,
            subset.crash_time_theory;
            label = "Аналитика, r=$(num_repairers)",
            marker = :diamond,
            linestyle = :dash,
            linewidth = 2,
            color = color,
        )
        P.plot!(
            p2,
            subset.N,
            subset.utilization;
            label = "r=$(num_repairers)",
            marker = :circle,
            linewidth = 2,
            color = color,
        )
        P.plot!(
            p3,
            subset.N,
            subset.avg_queue_length;
            label = "r=$(num_repairers)",
            marker = :circle,
            linewidth = 2,
            color = color,
        )
    end

    return P.plot(p1, p2, p3; layout = (3, 1), size = (900, 1200))
end

export mmc_theory
export plot_mmc_scan
export plot_mmc_timeline
export plot_mmc_wait_hist
export plot_ross_repair_monitor
export plot_ross_scan
export plot_ross_state
export ross_analytic_mttf
export ross_parameter_grid
export simulate_mmc
export simulate_ross

end # module
