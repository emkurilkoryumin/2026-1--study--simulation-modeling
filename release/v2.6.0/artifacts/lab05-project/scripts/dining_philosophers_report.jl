using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

script_name = "dining_philosophers_report"
mkpath(plotsdir(script_name))

df_classic = CSV.read(datadir("01_dining_philosophers", "dining_classic.csv"), DataFrame)
df_arbiter = CSV.read(datadir("01_dining_philosophers", "dining_arbiter.csv"), DataFrame)
N = 5
eat_cols = eat_columns(N)

p1 = plot(
    df_classic.time,
    Matrix(df_classic[:, eat_cols]);
    label = ["Ф $i" for i in 1:N],
    xlabel = "Время",
    ylabel = "Eat (1/0)",
    title = "Классическая сеть",
    linewidth = 2,
    grid = true,
)
p2 = plot(
    df_arbiter.time,
    Matrix(df_arbiter[:, eat_cols]);
    label = ["Ф $i" for i in 1:N],
    xlabel = "Время",
    ylabel = "Eat (1/0)",
    title = "Сеть с арбитром",
    linewidth = 2,
    grid = true,
)

p_final = plot(p1, p2; layout = (2, 1), size = (900, 700))
savefig(p_final, plotsdir(script_name, "final_report.png"))

println("Итоговый отчёт сохранён в plots/$(script_name)/final_report.png")
