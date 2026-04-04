using DrWatson
@quickactivate "project"

using DataFrames
using Plots
using Statistics

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

infection_period = 14
gamma = 1 / infection_period
beta_values = 0.02:0.01:0.18
seeds = [41, 42, 43, 44]
epidemic_threshold = 0.05

runs = DataFrame(
    beta = Float64[],
    seed = Int[],
    peak_share = Float64[],
    r0 = Float64[],
)

for beta in beta_values
    for seed in seeds
        df = run_extra_sir(;
            Ns = [500, 500, 500],
            β_und = fill(beta, 3),
            β_det = fill(beta / 10, 3),
            infection_period = infection_period,
            detection_time = 7,
            death_rate = 0.02,
            reinfection_probability = 0.1,
            Is = [0, 0, 1],
            seed = seed,
            n_steps = 100,
        )

        metrics = peak_metrics(df)
        push!(runs, (beta, seed, metrics.peak_share, beta / gamma))
    end
end

summary = combine(
    groupby(runs, :beta),
    :peak_share => mean => :mean_peak_share,
    :peak_share => maximum => :max_peak_share,
    :r0 => first => :r0,
)

threshold_index = findfirst(summary.mean_peak_share .> epidemic_threshold)
threshold_beta = isnothing(threshold_index) ? missing : summary.beta[threshold_index]
threshold_r0 = isnothing(threshold_index) ? missing : summary.r0[threshold_index]
theoretical_beta = gamma

plt = plot(
    summary.beta,
    summary.mean_peak_share;
    label = "Средний пик заражения",
    xlabel = "Параметр beta",
    ylabel = "Доля популяции",
    title = "Поиск эпидемического порога",
    linewidth = 2,
    marker = :circle,
    color = :firebrick,
    size = (920, 540),
    grid = true,
)
hline!(plt, [epidemic_threshold]; color = :black, linestyle = :dash, label = "Порог I > 5%")
vline!(plt, [theoretical_beta]; color = :royalblue, linestyle = :dash, label = "Теоретический beta при R0 = 1")

if !ismissing(threshold_beta)
    vline!(plt, [threshold_beta]; color = :seagreen, linestyle = :dashdot, label = "Наблюдаемый порог")
    annotate!(plt, threshold_beta, epidemic_threshold + 0.02, text("beta ≈ $(round(threshold_beta, digits = 3))", 8, :left))
end

savefig(plt, plotsdir(script_name, "threshold_beta_scan.png"))
write_tsv(datadir(script_name, "threshold_beta_runs.tsv"), runs)
write_tsv(datadir(script_name, "threshold_beta_summary.tsv"), summary)

open(datadir(script_name, "threshold_beta_result.txt"), "w") do io
    println(io, "infection_period = $(infection_period)")
    println(io, "gamma = $(round(gamma, digits = 4))")
    println(io, "theoretical_beta_threshold = $(round(theoretical_beta, digits = 4))")
    if !ismissing(threshold_beta)
        println(io, "observed_beta_threshold = $(round(threshold_beta, digits = 4))")
        println(io, "observed_r0_at_threshold = $(round(threshold_r0, digits = 4))")
    else
        println(io, "observed_beta_threshold = not_found")
    end
    println(io, "epidemic_condition = peak_share > $(epidemic_threshold)")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
