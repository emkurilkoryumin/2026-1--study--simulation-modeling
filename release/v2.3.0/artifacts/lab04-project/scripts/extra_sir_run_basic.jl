using DrWatson
@quickactivate "project"

using Plots

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

params = (
    Ns = [600, 600, 600],
    β_und = [0.5, 0.5, 0.5],
    β_det = [0.05, 0.05, 0.05],
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [0, 0, 1],
    seed = 42,
    n_steps = 100,
)

df = run_extra_sir(;
    Ns = params.Ns,
    β_und = params.β_und,
    β_det = params.β_det,
    infection_period = params.infection_period,
    detection_time = params.detection_time,
    death_rate = params.death_rate,
    reinfection_probability = params.reinfection_probability,
    Is = params.Is,
    seed = params.seed,
    n_steps = params.n_steps,
)

metrics = peak_metrics(df)

plt = plot(
    df.time,
    [df.susceptible df.infected df.recovered];
    label = ["S(t)" "I(t)" "R(t)"],
    xlabel = "Шаг моделирования",
    ylabel = "Число агентов",
    title = "Дополнительный запуск SIR: базовая динамика",
    linewidth = 2,
    color = [:royalblue :firebrick :seagreen],
    size = (900, 520),
    grid = true,
)
plot!(df.time, df.dead; label = "Умершие", color = :black, linestyle = :dash)

savefig(plt, plotsdir(script_name, "sir_basic_dynamics.png"))
write_tsv(datadir(script_name, "sir_basic_timeseries.tsv"), df)

open(datadir(script_name, "sir_basic_summary.txt"), "w") do io
    println(io, "peak_time = $(metrics.peak_time)")
    println(io, "peak_infected = $(metrics.peak_infected)")
    println(io, "peak_share = $(round(metrics.peak_share, digits = 4))")
    println(io, "final_infected_share = $(round(metrics.final_infected_share, digits = 4))")
    println(io, "final_recovered_share = $(round(metrics.final_recovered_share, digits = 4))")
    println(io, "death_share = $(round(metrics.death_share, digits = 4))")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
