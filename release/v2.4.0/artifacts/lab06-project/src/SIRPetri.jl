module SIRPetri

using DataFrames
using OrdinaryDiffEq
using Plots
using Random

struct PetriNet
    place_names::Vector{Symbol}
    transition_names::Vector{Symbol}
    default_rates::Vector{Float64}
end

function build_sir_network(β = 0.3, γ = 0.1)
    place_names = [:S, :I, :R]
    transition_names = [:infection, :recovery]
    rates = [Float64(β), Float64(γ)]
    net = PetriNet(place_names, transition_names, rates)
    u0 = [990.0, 10.0, 0.0]
    return net, u0, copy(place_names)
end

function sir_ode(net::PetriNet, rates = net.default_rates)
    β, γ = Float64.(rates)

    function f!(du, u, p, t)
        S, I, R = u
        population = max(S + I + R, 1.0)
        infection_rate = β * S * I / population
        recovery_rate = γ * I
        du[1] = -infection_rate
        du[2] = infection_rate - recovery_rate
        du[3] = recovery_rate
        return nothing
    end

    return f!
end

function simulate_deterministic(
    net::PetriNet,
    u0::AbstractVector,
    tspan;
    saveat = 0.1,
    rates = net.default_rates,
)
    prob = ODEProblem(sir_ode(net, rates), collect(Float64, u0), tspan)
    sol = solve(prob, Tsit5(); saveat = saveat)

    df = DataFrame(time = sol.t)
    df.S = sol[1, :]
    df.I = sol[2, :]
    df.R = sol[3, :]
    return df
end

function simulate_stochastic(
    net::PetriNet,
    u0::AbstractVector,
    tspan;
    rates = net.default_rates,
    rng = Random.GLOBAL_RNG,
)
    β, γ = Float64.(rates)
    marking = round.(Int, u0)
    t = Float64(tspan[1])
    tmax = Float64(tspan[2])

    times = Float64[t]
    states = Vector{NTuple{3, Int}}([(marking[1], marking[2], marking[3])])

    while t < tmax
        S, I, R = marking
        population = max(S + I + R, 1)
        a_inf = β * S * I / population
        a_rec = γ * I
        a0 = a_inf + a_rec
        a0 <= 0 && break

        dt = randexp(rng) / a0
        t += dt
        t > tmax && break

        if rand(rng) * a0 < a_inf
            if S > 0 && I > 0
                marking[1] -= 1
                marking[2] += 1
            end
        else
            if I > 0
                marking[2] -= 1
                marking[3] += 1
            end
        end

        push!(times, t)
        push!(states, (marking[1], marking[2], marking[3]))
    end

    df = DataFrame(time = times)
    df.S = [state[1] for state in states]
    df.I = [state[2] for state in states]
    df.R = [state[3] for state in states]
    return df
end

function plot_sir(df::DataFrame; title = "Динамика модели SIR")
    p = plot(
        df.time,
        [df.S df.I df.R];
        label = ["S (Susceptible)" "I (Infected)" "R (Recovered)"],
        xlabel = "Time",
        ylabel = "Population",
        linewidth = 2,
        title,
        grid = true,
        size = (900, 520),
        color = [:royalblue :firebrick :seagreen],
    )
    return p
end

function sample_path(df::DataFrame, target_times::AbstractVector; column = :I)
    nrow(df) > 0 || return Float64[]

    sampled = Vector{Float64}(undef, length(target_times))
    idx = 1
    current_value = Float64(df[1, column])

    for (i, target_time) in enumerate(target_times)
        while idx < nrow(df) && Float64(df[idx + 1, :time]) <= Float64(target_time) + 1e-9
            idx += 1
            current_value = Float64(df[idx, column])
        end
        sampled[i] = current_value
    end

    return sampled
end

function plot_compare_infected(df_det::DataFrame, df_stoch::DataFrame)
    infected_stoch = sample_path(df_stoch, df_det.time; column = :I)
    p = plot(
        df_det.time,
        [df_det.I infected_stoch];
        label = ["Deterministic I" "Stochastic I"],
        xlabel = "Time",
        ylabel = "Infected",
        title = "Сравнение детерминированной и стохастической динамики",
        linewidth = 2,
        color = [:firebrick :darkorange],
        grid = true,
        size = (900, 520),
    )
    return p
end

function plot_scan(df_scan::DataFrame)
    p = plot(
        df_scan.β,
        [df_scan.peak_I df_scan.final_R];
        label = ["Peak I" "Final R"],
        marker = :circle,
        linewidth = 2,
        xlabel = "β (infection rate)",
        ylabel = "Population",
        title = "Чувствительность модели к коэффициенту заражения",
        color = [:firebrick :seagreen],
        grid = true,
        size = (900, 520),
    )
    return p
end

function animate_sir(df::DataFrame, output_path::AbstractString; fps = 12)
    ymax = maximum(vcat(df.S, df.I, df.R)) * 1.05
    labels = ["S", "I", "R"]
    colors = [:royalblue, :firebrick, :seagreen]

    anim = @animate for row in eachrow(df)
        bar(
            labels,
            [Float64(row.S), Float64(row.I), Float64(row.R)];
            color = colors,
            legend = false,
            xlabel = "State",
            ylabel = "Population",
            ylim = (0, ymax),
            title = "t = $(round(Float64(row.time), digits = 1))",
            size = (720, 480),
        )
    end

    gif(anim, output_path; fps = fps)
    return output_path
end

function to_graphviz_sir(net::PetriNet)
    return """
    digraph SIRPetri {
      rankdir=LR;
      node [fontname="Helvetica"];
      S [shape=circle];
      I [shape=circle];
      R [shape=circle];
      infection [shape=box, label="infection"];
      recovery [shape=box, label="recovery"];
      S -> infection;
      I -> infection;
      infection -> I;
      infection -> I;
      I -> recovery;
      recovery -> R;
    }
    """
end

export PetriNet
export animate_sir
export build_sir_network
export plot_compare_infected
export plot_scan
export plot_sir
export sample_path
export simulate_deterministic
export simulate_stochastic
export sir_ode
export to_graphviz_sir

end # module
