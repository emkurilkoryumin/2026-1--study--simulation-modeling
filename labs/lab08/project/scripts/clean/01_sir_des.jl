using DrWatson
@quickactivate "project"

ENV["GKSwstype"] = "100"

using CSV
using Plots

include(srcdir("SIRDESLab08.jl"))
using .SIRDESLab08

mkpath(datadir("sims"))
mkpath(plotsdir())

tmax = 40.0
u0 = [990, 10, 0]
parameters = [0.05, 10.0, 0.25]

result = run_sir(
    u0,
    parameters;
    tmax = tmax,
    seed = 1234,
    scenario = "base",
)

CSV.write(datadir("sims", "sir_990_10_0.05_10.0_0.25.csv"), result.data)
CSV.write(datadir("sims", "sir_base_summary.csv"), result.summary)

println("Базовый сценарий DES-SIR")
println(result.summary)

plot(
    result.data.t,
    result.data.S;
    label = "S",
    linewidth = 2,
    xlabel = "Время",
    ylabel = "Численность",
    title = "Дискретно-событийная SIR-модель",
)
plot!(result.data.t, result.data.I; label = "I", linewidth = 2)
plot!(result.data.t, result.data.R; label = "R", linewidth = 2)
savefig(plotsdir("sir_des.png"))

ode = solve_deterministic_sir(u0, parameters; tmax = tmax)

plot(
    result.data.t,
    result.data.I;
    label = "DES: I(t)",
    linewidth = 2,
    xlabel = "Время",
    ylabel = "Инфицированные",
    title = "Стохастическая DES и детерминированная SIR-модель",
)
plot!(ode.t, ode.I; label = "ОДУ: I(t)", linewidth = 2, linestyle = :dash)
savefig(plotsdir("sir_des_vs_ode.png"))

CSV.write(datadir("sims", "sir_deterministic_ode.csv"), ode)
