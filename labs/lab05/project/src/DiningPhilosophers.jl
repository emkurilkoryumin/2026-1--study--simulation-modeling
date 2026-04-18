module DiningPhilosophers

using DataFrames
using Plots
using Random

struct PetriNet
    n_places::Int
    n_transitions::Int
    incidence::Matrix{Int}
    place_names::Vector{Symbol}
    transition_names::Vector{Symbol}
end

function PetriNet(
    n_places::Integer,
    n_transitions::Integer;
    place_names = Symbol[],
    transition_names = Symbol[],
)
    n_places = Int(n_places)
    n_transitions = Int(n_transitions)
    incidence = zeros(Int, n_places, n_transitions)

    if isempty(place_names)
        place_names = [Symbol("p$i") for i in 1:n_places]
    end
    if isempty(transition_names)
        transition_names = [Symbol("t$i") for i in 1:n_transitions]
    end

    return PetriNet(n_places, n_transitions, incidence, place_names, transition_names)
end

function add_arc!(net::PetriNet, place::Integer, transition::Integer, sign::Integer)
    net.incidence[Int(place), Int(transition)] += Int(sign)
    return net
end

state_columns(group::AbstractString, N::Integer) = [Symbol("$(group)_$i") for i in 1:Int(N)]
eat_columns(N::Integer) = state_columns("Eat", N)

function build_classical_network(N::Integer)
    N = Int(N)
    N >= 2 || throw(ArgumentError("Число философов должно быть не меньше 2"))

    net = PetriNet(4N, 3N)

    for i in 1:N
        net.place_names[i] = Symbol("Think_$i")
        net.place_names[N + i] = Symbol("Hungry_$i")
        net.place_names[2N + i] = Symbol("Eat_$i")
        net.place_names[3N + i] = Symbol("Fork_$i")

        net.transition_names[i] = Symbol("GetLeft_$i")
        net.transition_names[N + i] = Symbol("GetRight_$i")
        net.transition_names[2N + i] = Symbol("PutForks_$i")
    end

    for i in 1:N
        think = i
        hungry = N + i
        eat = 2N + i
        left_fork = 3N + i
        right_fork = 3N + (i % N + 1)

        get_left = i
        get_right = N + i
        put_forks = 2N + i

        add_arc!(net, think, get_left, -1)
        add_arc!(net, left_fork, get_left, -1)
        add_arc!(net, hungry, get_left, +1)

        add_arc!(net, hungry, get_right, -1)
        add_arc!(net, right_fork, get_right, -1)
        add_arc!(net, eat, get_right, +1)

        add_arc!(net, eat, put_forks, -1)
        add_arc!(net, think, put_forks, +1)
        add_arc!(net, left_fork, put_forks, +1)
        add_arc!(net, right_fork, put_forks, +1)
    end

    u0 = zeros(Float64, net.n_places)
    for i in 1:N
        u0[i] = 1.0
        u0[3N + i] = 1.0
    end

    return net, u0, copy(net.place_names)
end

function build_arbiter_network(N::Integer)
    N = Int(N)
    N >= 2 || throw(ArgumentError("Число философов должно быть не меньше 2"))

    net = PetriNet(4N + 1, 3N)

    for i in 1:N
        net.place_names[i] = Symbol("Think_$i")
        net.place_names[N + i] = Symbol("Hungry_$i")
        net.place_names[2N + i] = Symbol("Eat_$i")
        net.place_names[3N + i] = Symbol("Fork_$i")

        net.transition_names[i] = Symbol("GetLeft_$i")
        net.transition_names[N + i] = Symbol("GetRight_$i")
        net.transition_names[2N + i] = Symbol("PutForks_$i")
    end
    arbiter_idx = 4N + 1
    net.place_names[arbiter_idx] = :Arbiter

    for i in 1:N
        think = i
        hungry = N + i
        eat = 2N + i
        left_fork = 3N + i
        right_fork = 3N + (i % N + 1)

        get_left = i
        get_right = N + i
        put_forks = 2N + i

        add_arc!(net, think, get_left, -1)
        add_arc!(net, left_fork, get_left, -1)
        add_arc!(net, arbiter_idx, get_left, -1)
        add_arc!(net, hungry, get_left, +1)

        add_arc!(net, hungry, get_right, -1)
        add_arc!(net, right_fork, get_right, -1)
        add_arc!(net, eat, get_right, +1)

        add_arc!(net, eat, put_forks, -1)
        add_arc!(net, think, put_forks, +1)
        add_arc!(net, left_fork, put_forks, +1)
        add_arc!(net, right_fork, put_forks, +1)
        add_arc!(net, arbiter_idx, put_forks, +1)
    end

    u0 = zeros(Float64, net.n_places)
    for i in 1:N
        u0[i] = 1.0
        u0[3N + i] = 1.0
    end
    u0[arbiter_idx] = N - 1

    return net, u0, copy(net.place_names)
end

function transition_propensities(
    net::PetriNet,
    marking::AbstractVector,
    rates::AbstractVector{<:Real},
)
    activities = zeros(Float64, net.n_transitions)

    for transition in 1:net.n_transitions
        activity = Float64(rates[transition])
        for place in 1:net.n_places
            requirement = -net.incidence[place, transition]
            if requirement <= 0
                continue
            end

            tokens = max(Float64(marking[place]), 0.0)
            if tokens + 1e-9 < requirement
                activity = 0.0
                break
            end
            activity *= tokens^requirement
        end
        activities[transition] = activity
    end

    return activities
end

function vectorfield(net::PetriNet; rates = ones(Float64, net.n_transitions))
    local_rates = collect(Float64, rates)

    function f!(du, u, params, t)
        activities = transition_propensities(net, u, local_rates)
        du .= net.incidence * activities
        return nothing
    end

    return f!
end

function simulate_ode(
    net::PetriNet,
    u0::AbstractVector,
    tmax::Real;
    saveat = 0.1,
    rates = ones(Float64, net.n_transitions),
)
    dt = Float64(saveat)
    tmax = Float64(tmax)
    times = collect(0.0:dt:tmax)
    f! = vectorfield(net; rates)

    state = collect(Float64, u0)
    derivative = zeros(Float64, length(state))
    states = Matrix{Float64}(undef, net.n_places, length(times))
    states[:, 1] = state

    for idx in 2:length(times)
        f!(derivative, state, nothing, times[idx - 1])
        state .= max.(state .+ dt .* derivative, 0.0)
        states[:, idx] = state
    end

    df = DataFrame(time = times)
    for place in 1:net.n_places
        df[!, String(net.place_names[place])] = states[place, :]
    end

    return df
end

function simulate_stochastic(
    net::PetriNet,
    u0::AbstractVector,
    tmax::Real;
    rates = ones(Float64, net.n_transitions),
    rng = Random.GLOBAL_RNG,
)
    local_rates = collect(Float64, rates)
    marking = collect(Float64, u0)
    time = 0.0

    times = Float64[time]
    states = Vector{Vector{Float64}}([copy(marking)])

    while time < tmax
        activities = transition_propensities(net, marking, local_rates)
        total_activity = sum(activities)
        total_activity <= 0 && break

        dt = -log(rand(rng)) / total_activity
        threshold = rand(rng) * total_activity
        cumulative = 0.0
        chosen = 1

        for transition in 1:net.n_transitions
            cumulative += activities[transition]
            if threshold <= cumulative
                chosen = transition
                break
            end
        end

        for place in 1:net.n_places
            marking[place] += net.incidence[place, chosen]
        end

        time += dt
        if time <= tmax + 1e-9
            push!(times, time)
            push!(states, copy(marking))
        end
    end

    df = DataFrame(time = times)
    for place in 1:net.n_places
        df[!, String(net.place_names[place])] = [state[place] for state in states]
    end

    return df
end

function latest_marking(df::DataFrame, net::PetriNet)
    return [Float64(df[end, String(place)]) for place in net.place_names]
end

function is_transition_enabled(
    net::PetriNet,
    marking::AbstractVector,
    transition::Integer;
    tol = 1e-9,
)
    transition = Int(transition)
    for place in 1:net.n_places
        requirement = -net.incidence[place, transition]
        if requirement > 0 && Float64(marking[place]) + tol < requirement
            return false
        end
    end
    return true
end

function is_deadlock_marking(net::PetriNet, marking::AbstractVector; tol = 1e-9)
    for transition in 1:net.n_transitions
        if is_transition_enabled(net, marking, transition; tol)
            return false
        end
    end
    return true
end

function detect_deadlock(df::DataFrame, net::PetriNet; tol = 1e-9)
    return is_deadlock_marking(net, latest_marking(df, net); tol)
end

function plot_marking_evolution(
    df::DataFrame,
    N::Integer;
    title_prefix = "",
    size = (850, 1000),
)
    N = Int(N)
    column_symbols = Set(Symbol.(names(df)))
    subplots = Any[]

    for group in ("Think", "Hungry", "Eat", "Fork")
        title_text = isempty(title_prefix) ? "$group states" : "$title_prefix: $group"
        subplot = plot(
            xlabel = "Время",
            ylabel = group,
            title = title_text,
            legend = :right,
            linewidth = 2,
            grid = true,
        )
        for i in 1:N
            column = Symbol("$(group)_$i")
            if column in column_symbols
                plot!(subplot, df.time, df[!, column]; label = string(column))
            end
        end
        push!(subplots, subplot)
    end

    return plot(subplots...; layout = (4, 1), size = size)
end

export PetriNet
export add_arc!, build_classical_network, build_arbiter_network
export state_columns, eat_columns
export vectorfield, simulate_ode, simulate_stochastic
export latest_marking, is_transition_enabled, is_deadlock_marking, detect_deadlock
export plot_marking_evolution

end
