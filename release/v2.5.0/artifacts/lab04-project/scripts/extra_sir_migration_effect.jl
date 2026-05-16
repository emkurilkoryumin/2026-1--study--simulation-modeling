using DrWatson
@quickactivate "project"

using DataFrames
using Plots
using Statistics

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

intensities = 0.0:0.1:0.5
seeds = [42, 43, 44]

runs = DataFrame(
    migration_intensity = Float64[],
    seed = Int[],
    peak_time = Int[],
    peak_share = Float64[],
)

for intensity in intensities
    rates = migration_matrix(3, intensity)
    for seed in seeds
        df = run_extra_sir(;
            Ns = [500, 500, 500],
            migration_rates = rates,
            β_und = [0.5, 0.5, 0.5],
            β_det = [0.05, 0.05, 0.05],
            infection_period = 14,
            detection_time = 7,
            death_rate = 0.02,
            reinfection_probability = 0.1,
            Is = [1, 0, 0],
            seed = seed,
            n_steps = 120,
        )

        metrics = peak_metrics(df)
        push!(runs, (float(intensity), seed, metrics.peak_time, metrics.peak_share))
    end
end

summary = combine(
    groupby(runs, :migration_intensity),
    :peak_time => mean => :mean_peak_time,
    :peak_share => mean => :mean_peak_share,
)

best_index = argmin(summary.mean_peak_time)
best_intensity = summary.migration_intensity[best_index]
best_peak_time = summary.mean_peak_time[best_index]
best_peak_share = summary.mean_peak_share[best_index]

plt = plot(layout = (2, 1), size = (900, 760))
plot!(
    plt[1],
    summary.migration_intensity,
    summary.mean_peak_time;
    label = "Среднее время до пика",
    marker = :circle,
    linewidth = 2,
    xlabel = "Интенсивность миграции",
    ylabel = "Шаг",
    title = "Влияние миграции на время до пика",
    grid = true,
)
plot!(
    plt[2],
    summary.migration_intensity,
    summary.mean_peak_share;
    label = "Средняя доля в пике",
    marker = :square,
    linewidth = 2,
    xlabel = "Интенсивность миграции",
    ylabel = "Доля популяции",
    title = "Влияние миграции на масштаб пика",
    grid = true,
)

savefig(plt, plotsdir(script_name, "migration_effect.png"))
write_tsv(datadir(script_name, "migration_runs.tsv"), runs)
write_tsv(datadir(script_name, "migration_summary.tsv"), summary)

open(datadir(script_name, "migration_best.txt"), "w") do io
    println(io, "best_migration_intensity = $(round(best_intensity, digits = 3))")
    println(io, "mean_peak_time = $(round(best_peak_time, digits = 3))")
    println(io, "mean_peak_share = $(round(best_peak_share, digits = 4))")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
