using DrWatson
@quickactivate "project"
using Agents
using Plots
include(srcdir("daisyworld.jl"))

println("Создаём модель...")
model = daisyworld()
println("✓ Модель создана")

function plot_frame(model, step)
    temp = model.temperature
    p = heatmap(temp,
        title="Daisyworld - шаг $step",
        xlabel="X", ylabel="Y",
        color=:thermal, clim=(-20, 60),
        size=(600, 500))
    
    for agent in allagents(model)
        x, y = agent.pos
        color = agent.breed == :black ? :black : :white
        scatter!([y], [x], color=color, markersize=4, marker=:circle, label="")
    end
    return p
end

println("\nСоздаём анимацию...")
anim = @animate for step in 1:100
    run!(model, 1)
    plot_frame(model, step)
end

gif(anim, plotsdir("daisyworld_animation.gif"), fps = 15)
println("\n✅ Анимация сохранена: plots/daisyworld_animation.gif")
