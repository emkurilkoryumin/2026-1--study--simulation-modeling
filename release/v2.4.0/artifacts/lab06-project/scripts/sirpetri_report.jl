using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(plotsdir())

df_det = CSV.read(datadir("sir_det.csv"), DataFrame)
df_stoch = CSV.read(datadir("sir_stoch.csv"), DataFrame)
df_scan = CSV.read(datadir("sir_scan.csv"), DataFrame)

p1 = plot_compare_infected(df_det, df_stoch)
savefig(p1, plotsdir("comparison.png"))

p2 = plot(
    df_scan.β,
    df_scan.peak_I;
    marker = :circle,
    linewidth = 2,
    xlabel = "β",
    ylabel = "Peak I",
    title = "Зависимость пика инфицированных от β",
    color = :firebrick,
    grid = true,
    size = (900, 520),
)
savefig(p2, plotsdir("sensitivity.png"))

println("Отчётные графики сохранены в plots/")
