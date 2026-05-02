using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots
using Random

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(datadir())
mkpath(plotsdir())

β = 0.3
γ = 0.1
tmax = 100.0

net, u0, states = build_sir_network(β, γ)

df_det = simulate_deterministic(net, u0, (0.0, tmax); saveat = 0.5, rates = [β, γ])
CSV.write(datadir("sir_det.csv"), df_det)

df_stoch = simulate_stochastic(
    net,
    u0,
    (0.0, tmax);
    rates = [β, γ],
    rng = MersenneTwister(123),
)
CSV.write(datadir("sir_stoch.csv"), df_stoch)

p_det = plot_sir(df_det; title = "Детерминированная динамика SIR")
p_stoch = plot_sir(df_stoch; title = "Стохастическая динамика SIR")

savefig(p_det, plotsdir("sir_det_dynamics.png"))
savefig(p_stoch, plotsdir("sir_stoch_dynamics.png"))

println("Базовый прогон завершён. Результаты в data/ и plots/")
println("Peak I (deterministic) = $(round(maximum(df_det.I), digits = 2))")
println("Peak I (stochastic)    = $(maximum(df_stoch.I))")
println("Final R (deterministic) = $(round(df_det.R[end], digits = 2))")
println("Final R (stochastic)    = $(df_stoch.R[end])")
