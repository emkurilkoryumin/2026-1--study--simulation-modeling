using DrWatson
@quickactivate "project"

using CSV

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(datadir())
mkpath(plotsdir())

β = 0.3
γ = 0.1
tmax = 100.0

net, u0, _ = build_sir_network(β, γ)
df = simulate_deterministic(net, u0, (0.0, tmax); saveat = 0.2, rates = [β, γ])
CSV.write(datadir("sir_animation_source.csv"), df)

output_path = plotsdir("sir_animation.gif")
animate_sir(df, output_path; fps = 12)

println("Анимация сохранена: $(output_path)")
