using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
include(srcdir("daisyworld.jl"))

black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]

println("Запускаем симуляцию...")
model = daisyworld()
agent_df, _ = run!(model, 100; adata)

p = plot(agent_df.time, [agent_df.count_black agent_df.count_white],
    label=["Чёрные" "Белые"],
    xlabel="Время (шаги)", ylabel="Численность",
    title="Динамика численности маргариток",
    color=[:black :orange], linewidth=2)

savefig(plotsdir("daisyworld_count.png"))
println("✅ График сохранён: plots/daisyworld_count.png")
