using DrWatson
@quickactivate "project"

using DataFrames
using Plots
using Statistics

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

beta_values = 0.1:0.1:0.8
seeds = [42, 43, 44]

runs = DataFrame(
    beta = Float64[],
    seed = Int[],
    peak_share = Float64[],
    final_infected_share = Float64[],
    death_share = Float64[],
)

for beta in beta_values
    for seed in seeds
        df = run_extra_sir(;
            Ns = [500, 500, 500],
            β_und = fill(beta, 3),
            β_det = fill(beta / 10, 3),
            infection_period = 14,
            detection_time = 7,
            death_rate = 0.02,
            reinfection_probability = 0.1,
            Is = [0, 0, 1],
            seed = seed,
            n_steps = 90,
        )

        metrics = peak_metrics(df)
        push!(runs, (beta, seed, metrics.peak_share, metrics.final_infected_share, metrics.death_share))
    end
end

summary = combine(
    groupby(runs, :beta),
    :peak_share => mean => :mean_peak_share,
    :final_infected_share => mean => :mean_final_infected_share,
    :death_share => mean => :mean_death_share,
)

plt = plot(
    summary.beta,
    summary.mean_peak_share;
    label = "Средний пик заражения",
    xlabel = "Параметр beta",
    ylabel = "Доля популяции",
    marker = :circle,
    linewidth = 2,
    title = "Дополнительный запуск SIR: сканирование beta",
    size = (900, 520),
    grid = true,
)
plot!(summary.beta, summary.mean_final_infected_share; label = "Конечная доля инфицированных", marker = :square)
plot!(summary.beta, summary.mean_death_share; label = "Доля умерших", marker = :diamond)

savefig(plt, plotsdir(script_name, "beta_scan.png"))
write_tsv(datadir(script_name, "beta_scan_runs.tsv"), runs)
write_tsv(datadir(script_name, "beta_scan_summary.tsv"), summary)

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
