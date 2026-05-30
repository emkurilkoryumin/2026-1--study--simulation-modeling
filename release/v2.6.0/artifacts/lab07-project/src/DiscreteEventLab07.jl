module DiscreteEventLab07

using ConcurrentSim
using DataFrames
using Distributions
using Random
using ResumableFunctions
using StableRNGs
using Statistics

mutable struct MMcStats
    arrival::Vector{Float64}
    start::Vector{Float64}
    departure::Vector{Float64}
    service::Vector{Float64}
end

mutable struct MMcMonitor
    queue_length::Int
    in_service::Int
    last_time::Float64
    area_queue::Float64
    area_service::Float64
    times::Vector{Float64}
    queue_trace::Vector{Int}
    service_trace::Vector{Int}
end

mutable struct RossMonitor
    healthy::Int
    busy_repairers::Int
    repair_queue::Int
    last_time::Float64
    area_busy::Float64
    area_queue::Float64
    times::Vector{Float64}
    healthy_trace::Vector{Int}
    busy_trace::Vector{Int}
    queue_trace::Vector{Int}
    failures::Int
    repairs::Int
end

MMcStats(num_customers::Integer) = MMcStats(
    fill(NaN, num_customers),
    fill(NaN, num_customers),
    fill(NaN, num_customers),
    fill(NaN, num_customers),
)

MMcMonitor() = MMcMonitor(0, 0, 0.0, 0.0, 0.0, [0.0], [0], [0])

RossMonitor(total_healthy::Integer) = RossMonitor(
    total_healthy,
    0,
    0,
    0.0,
    0.0,
    0.0,
    [0.0],
    [total_healthy],
    [0],
    [0],
    0,
    0,
)

factorial_float(n::Integer) = n <= 1 ? 1.0 : prod(Float64.(1:n))

function plotsmod()
    @eval import Plots
    return Plots
end

function update_mmc!(monitor::MMcMonitor, t::Real; queue_delta::Integer = 0, service_delta::Integer = 0)
    time = Float64(t)
    dt = time - monitor.last_time
    monitor.area_queue += monitor.queue_length * dt
    monitor.area_service += monitor.in_service * dt
    monitor.last_time = time
    monitor.queue_length += queue_delta
    monitor.in_service += service_delta
    push!(monitor.times, time)
    push!(monitor.queue_trace, monitor.queue_length)
    push!(monitor.service_trace, monitor.in_service)
    return nothing
end

function finalize_mmc!(monitor::MMcMonitor, t::Real)
    time = Float64(t)
    dt = time - monitor.last_time
    monitor.area_queue += monitor.queue_length * dt
    monitor.area_service += monitor.in_service * dt
    monitor.last_time = time
    if monitor.times[end] != time
        push!(monitor.times, time)
        push!(monitor.queue_trace, monitor.queue_length)
        push!(monitor.service_trace, monitor.in_service)
    end
    return nothing
end

function update_ross!(
    monitor::RossMonitor,
    t::Real;
    healthy_delta::Integer = 0,
    busy_delta::Integer = 0,
    queue_delta::Integer = 0,
)
    time = Float64(t)
    dt = time - monitor.last_time
    monitor.area_busy += monitor.busy_repairers * dt
    monitor.area_queue += monitor.repair_queue * dt
    monitor.last_time = time
    monitor.healthy += healthy_delta
    monitor.busy_repairers += busy_delta
    monitor.repair_queue += queue_delta
    push!(monitor.times, time)
    push!(monitor.healthy_trace, monitor.healthy)
    push!(monitor.busy_trace, monitor.busy_repairers)
    push!(monitor.queue_trace, monitor.repair_queue)
    return nothing
end

function finalize_ross!(monitor::RossMonitor, t::Real)
    time = Float64(t)
    dt = time - monitor.last_time
    monitor.area_busy += monitor.busy_repairers * dt
    monitor.area_queue += monitor.repair_queue * dt
    monitor.last_time = time
    if monitor.times[end] != time
        push!(monitor.times, time)
        push!(monitor.healthy_trace, monitor.healthy)
        push!(monitor.busy_trace, monitor.busy_repairers)
        push!(monitor.queue_trace, monitor.repair_queue)
    end
    return nothing
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

@resumable function mmc_customer(
    env::Environment,
    server::Resource,
    stats::MMcStats,
    monitor::MMcMonitor,
    id::Integer,
    service_dist::Distribution,
    rng::AbstractRNG,
)
    arrival_time = now(env)
    stats.arrival[id] = arrival_time
    update_mmc!(monitor, arrival_time; queue_delta = 1)

    req = request(server)
    @yield req

    start_time = now(env)
    service_time = rand(rng, service_dist)
    stats.start[id] = start_time
    stats.service[id] = service_time
    update_mmc!(monitor, start_time; queue_delta = -1, service_delta = 1)

    @yield timeout(env, service_time)

    departure_time = now(env)
    stats.departure[id] = departure_time
    update_mmc!(monitor, departure_time; service_delta = -1)
    @yield unlock(server)
end

@resumable function mmc_source(
    env::Environment,
    server::Resource,
    num_customers::Integer,
    arrival_dist::Distribution,
    service_dist::Distribution,
    stats::MMcStats,
    monitor::MMcMonitor,
    rng::AbstractRNG,
)
    for id in 1:num_customers
        @yield timeout(env, rand(rng, arrival_dist))
        @process mmc_customer(env, server, stats, monitor, id, service_dist, rng)
    end
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

    sim = Simulation()
    server = Resource(sim, num_servers)
    stats = MMcStats(num_customers)
    monitor = MMcMonitor()
    @process mmc_source(sim, server, num_customers, arrival_dist, service_dist, stats, monitor, rng)
    run(sim)

    end_time = maximum(stats.departure)
    finalize_mmc!(monitor, end_time)

    customers = DataFrame(
        id = collect(1:num_customers),
        arrival_time = stats.arrival,
        start_time = stats.start,
        departure_time = stats.departure,
        service_time = stats.service,
    )
    customers.wait_time = customers.start_time .- customers.arrival_time
    customers.system_time = customers.departure_time .- customers.arrival_time

    state = DataFrame(
        time = monitor.times,
        queue_length = monitor.queue_trace,
        busy_servers = monitor.service_trace,
    )

    theory = mmc_theory(arrival_rate, service_rate, num_servers)
    start_idx = min(max(Int(warmup_customers) + 1, 1), num_customers)
    steady = customers[start_idx:end, :]
    total_time = max(end_time, eps(Float64))

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
        avg_queue_sim = [monitor.area_queue / total_time],
        avg_queue_theory = [theory.mean_queue],
        utilization_sim = [monitor.area_service / (num_servers * total_time)],
        utilization_theory = [theory.utilization],
        prob_wait_sim = [mean(steady.wait_time .> 1e-9)],
        prob_wait_theory = [theory.prob_wait],
    )

    return (customers = customers, state = state, summary = summary)
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
    data = customers.wait_time[start_idx:end]
    P = plotsmod()
    return P.histogram(
        data;
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

@resumable function ross_machine(
    env::Environment,
    repair_facility::Resource,
    spares::Store{Process},
    monitor::RossMonitor,
    failure_dist::Distribution,
    repair_dist::Distribution,
    rng::AbstractRNG,
)
    while true
        try
            @yield timeout(env, Inf)
        catch
        end

        @yield timeout(env, rand(rng, failure_dist))
        failure_time = now(env)
        monitor.failures += 1
        update_ross!(monitor, failure_time; healthy_delta = -1)

        get_spare = take!(spares)
        @yield get_spare | timeout(env)
        if state(get_spare) != ConcurrentSim.idle
            @yield interrupt(value(get_spare))
        else
            throw(StopSimulation("No spare available"))
        end

        update_ross!(monitor, now(env); queue_delta = 1)
        @yield request(repair_facility)

        repair_start = now(env)
        update_ross!(monitor, repair_start; queue_delta = -1, busy_delta = 1)

        @yield timeout(env, rand(rng, repair_dist))

        repair_finish = now(env)
        monitor.repairs += 1
        update_ross!(monitor, repair_finish; busy_delta = -1, healthy_delta = 1)

        @yield unlock(repair_facility)
        @yield put!(spares, active_process(env))
    end
end

@resumable function ross_start(
    env::Environment,
    repair_facility::Resource,
    spares::Store{Process},
    monitor::RossMonitor,
    num_working::Integer,
    num_spares::Integer,
    failure_dist::Distribution,
    repair_dist::Distribution,
    rng::AbstractRNG,
)
    for _ in 1:num_working
        proc = @process ross_machine(env, repair_facility, spares, monitor, failure_dist, repair_dist, rng)
        @yield interrupt(proc)
    end

    for _ in 1:num_spares
        proc = @process ross_machine(env, repair_facility, spares, monitor, failure_dist, repair_dist, rng)
        @yield put!(spares, proc)
    end
end

function ross_analytic_mttf(;
    N::Integer = 10,
    S::Integer = 3,
    num_repairers::Integer = 1,
    failure_mean::Real = 100.0,
    repair_mean::Real = 1.0,
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
    failure_mean::Real = 100.0,
    repair_mean::Real = 1.0,
    seed::Integer = 42,
)
    rng = StableRNG(seed)
    failure_dist = Exponential(Float64(failure_mean))
    repair_dist = Exponential(Float64(repair_mean))

    sim = Simulation()
    repair_facility = Resource(sim, num_repairers)
    spares = Store{Process}(sim)
    monitor = RossMonitor(N + S)
    @process ross_start(sim, repair_facility, spares, monitor, N, S, failure_dist, repair_dist, rng)
    message = run(sim)

    crash_time = now(sim)
    finalize_ross!(monitor, crash_time)

    state = DataFrame(
        time = monitor.times,
        healthy = monitor.healthy_trace,
        busy_repairers = monitor.busy_trace,
        repair_queue = monitor.queue_trace,
    )

    crash_time_theory = ross_analytic_mttf(
        N = N,
        S = S,
        num_repairers = num_repairers,
        failure_mean = failure_mean,
        repair_mean = repair_mean,
    )
    total_time = max(crash_time, eps(Float64))
    summary = DataFrame(
        N = [N],
        S = [S],
        num_repairers = [num_repairers],
        failure_mean = [Float64(failure_mean)],
        repair_mean = [Float64(repair_mean)],
        crash_time = [crash_time],
        crash_time_theory = [crash_time_theory],
        mean_utilization = [monitor.area_busy / (num_repairers * total_time)],
        avg_queue_length = [monitor.area_queue / total_time],
        failures = [monitor.failures],
        repairs = [monitor.repairs],
        status = [string(message)],
    )

    return (state = state, summary = summary)
end

function ross_parameter_grid(;
    machine_counts::AbstractVector{<:Integer} = [8, 10, 12, 14],
    repairer_counts::AbstractVector{<:Integer} = [1, 2, 3],
    num_runs::Integer = 30,
    S::Integer = 3,
    failure_mean::Real = 100.0,
    repair_mean::Real = 1.0,
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
