using DrWatson
@quickactivate "project"

using DataFrames
using DelimitedFiles
using Plots

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

input_path = datadir("extra_sir_scan_beta", "beta_scan_summary.tsv")

if !isfile(input_path)
    error("Не найден $(input_path). Сначала запусти scripts/extra_sir_scan_beta.jl")
end

table, header = readdlm(input_path, '\t', header = true)
column_names = Symbol.(vec(header))
df = DataFrame(table, column_names)

for column in names(df)
    df[!, column] = parse.(Float64, string.(df[!, column]))
end

p1 = plot(
    df.beta,
    df.mean_peak_share;
    label = "Средний пик",
    xlabel = "Параметр beta",
    ylabel = "Доля популяции",
    linewidth = 2,
    marker = :circle,
    color = :firebrick,
    title = "Пик заражения при разных beta",
    grid = true,
)

p2 = plot(
    df.beta,
    df.mean_final_infected_share;
    label = "Конечная доля инфицированных",
    xlabel = "Параметр beta",
    ylabel = "Доля популяции",
    linewidth = 2,
    marker = :square,
    color = :royalblue,
    title = "Итоговая доля инфицированных",
    grid = true,
)

p3 = plot(
    df.beta,
    df.mean_death_share;
    label = "Доля умерших",
    xlabel = "Параметр beta",
    ylabel = "Доля популяции",
    linewidth = 2,
    marker = :diamond,
    color = :black,
    title = "Смертность при разных beta",
    grid = true,
)

plt = plot(p1, p2, p3; layout = (3, 1), size = (900, 980))
savefig(plt, plotsdir(script_name, "comprehensive_analysis.png"))

open(datadir(script_name, "visualization_source.txt"), "w") do io
    println(io, "input = $(input_path)")
    println(io, "rows = $(nrow(df))")
    println(io, "columns = $(join(String.(names(df)), ", "))")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
