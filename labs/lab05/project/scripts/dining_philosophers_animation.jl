using DrWatson
@quickactivate "project"

using Plots
using Random

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

script_name = "dining_philosophers_animation"
mkpath(plotsdir(script_name))

N = 3
tmax = 30.0
net, u0, names = build_classical_network(N)
rates = vcat(fill(0.5, N), fill(1.8, N), fill(0.8, N))
df = simulate_stochastic(net, u0, tmax; rates, rng = MersenneTwister(123))

anim = @animate for row in eachrow(df)
    marking = [Float64(row[Symbol(string(name))]) for name in names]
    bar(
        1:length(marking),
        marking;
        legend = false,
        ylims = (0, maximum(u0) + 1),
        xlabel = "Позиция",
        ylabel = "Фишки",
        title = "Время = $(round(row.time, digits = 2))",
        color = :steelblue,
    )
    xticks!(1:length(marking), string.(names), rotation = 45)
end

gif(anim, plotsdir(script_name, "philosophers_simulation.gif"); fps = 2)
println("Анимация сохранена в plots/$(script_name)/philosophers_simulation.gif")
