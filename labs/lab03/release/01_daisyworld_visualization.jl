using DrWatson
@quickactivate "project"
using Agents
using Plots
include(srcdir("daisyworld.jl"))

# Настройка стиля для лучшего вида
default(
    size=(600, 500),
    dpi=150,
    fontfamily="DejaVu Sans",
    titlefontsize=12,
    guidefontsize=10,
    legendfontsize=8
)

println("Создаём модель...")
model = daisyworld()
println("✓ Модель создана. Маргариток: ", length(allagents(model)))

function plot_daisyworld(model, step)
    temp = model.temperature
    
    # Тепловая карта
    p = heatmap(1:30, 1:30, temp,
        title="Daisyworld - шаг $step",
        xlabel="X", ylabel="Y",
        color=:thermal,
        clim=(-20, 60),
        aspect_ratio=:equal,
        framestyle=:box,
        grid=false,
        cbar=true,
        cbar_title="Температура, °C")
    
    # Маргаритки (крупнее и контрастнее)
    for agent in allagents(model)
        x, y = agent.pos
        if agent.breed == :black
            scatter!([y], [x], 
                color=:black, 
                markersize=6, 
                marker=:square,
                markerstrokecolor=:white,
                markerstrokewidth=0.5,
                label="")
        else
            scatter!([y], [x], 
                color=:white, 
                markersize=6, 
                marker=:circle,
                markerstrokecolor=:black,
                markerstrokewidth=0.5,
                label="")
        end
    end
    
    return p
end

steps = [0, 5, 40]

for step in steps
    if step == 0
        model = daisyworld()
    elseif step == 5
        model = daisyworld()
        run!(model, 5)
    elseif step == 40
        model = daisyworld()
        run!(model, 40)
    end
    
    println("  Шаг $step... Маргариток: ", length(allagents(model)))
    p = plot_daisyworld(model, step)
    savefig(plotsdir("daisyworld_step$(lpad(step, 3, '0')).png"))
end

println("\n✅ Визуализация завершена! Графики в папке plots/")
