using DrWatson
@quickactivate "project"
using Agents
using CairoMakie
include(srcdir("daisyworld.jl"))

model = daisyworld()

function plot_daisyworld(model)
    fig = Figure(size=(600, 600))
    ax = Axis(fig[1, 1]; xlabel="X", ylabel="Y", title="Daisyworld")

    hm = heatmap!(ax, model.temperature; colorrange=(-20, 60), colormap=:thermal)
    Colorbar(fig[1, 2], hm; label="Temperature, °C")

    for agent in allagents(model)
        color = agent.breed == :black ? :black : :white
        scatter!(ax, [agent.pos[2]], [agent.pos[1]]; color=color, markersize=8)
    end

    return fig
end

for step in [0, 1, 5, 40]
    run!(model, step == 0 ? 0 : step)
    fig = plot_daisyworld(model)
    fname = "daisyworld_step$(lpad(step, 3, '0')).png"
    save(plotsdir(fname), fig)
    println("Сохранён график: $fname")
end

println("Визуализация завершена!")
