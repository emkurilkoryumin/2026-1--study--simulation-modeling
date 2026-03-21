using DrWatson
@quickactivate "project"
using Agents
using Plots
include(srcdir("daisyworld.jl"))

init_white_vals = [0.2, 0.8]
max_age_vals = [25, 40]

function plot_daisyworld(model, step, params)
    p = heatmap(model.temperature,
        title="init_white=$(params[:init_white]), max_age=$(params[:max_age]), шаг $step",
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

for init_white in init_white_vals
    for max_age in max_age_vals
        println("Исследование: init_white=$init_white, max_age=$max_age")
        
        params = Dict(:init_white => init_white, :max_age => max_age)
        
        for step in [0, 5, 40]
            if step == 0
                model = daisyworld(; init_white, max_age)
            elseif step == 5
                model = daisyworld(; init_white, max_age)
                run!(model, 5)
            else
                model = daisyworld(; init_white, max_age)
                run!(model, 40)
            end
            
            p = plot_daisyworld(model, step, params)
            fname = "daisyworld_iw$(init_white)_ma$(max_age)_step$(lpad(step, 2, '0')).png"
            savefig(plotsdir(fname))
        end
    end
end

println("✅ Параметрическое исследование (тепловые карты) завершено!")
