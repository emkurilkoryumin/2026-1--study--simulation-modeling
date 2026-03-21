using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
include(srcdir("daisyworld.jl"))

black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]

init_white_vals = [0.2, 0.8]
max_age_vals = [25, 40]

for init_white in init_white_vals
    for max_age in max_age_vals
        println("Исследование: init_white=$init_white, max_age=$max_age")
        
        model = daisyworld(; init_white, max_age)
        agent_df, _ = run!(model, 100; adata)
        
        p = plot(agent_df.time, [agent_df.count_black agent_df.count_white],
            label=["Чёрные" "Белые"],
            xlabel="Время (шаги)", ylabel="Численность",
            title="init_white=$init_white, max_age=$max_age",
            color=[:black :orange], linewidth=2)
        
        fname = "daisy_count_iw$(init_white)_ma$(max_age).png"
        savefig(plotsdir(fname))
    end
end

println("✅ Параметрическое исследование (численность) завершено!")
