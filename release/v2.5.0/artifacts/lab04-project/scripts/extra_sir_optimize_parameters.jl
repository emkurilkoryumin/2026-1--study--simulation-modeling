using DrWatson
@quickactivate "project"

using DataFrames
using Plots
using Statistics

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

beta_values = [0.03, 0.05, 0.07, 0.09]
detection_values = [2, 4, 6]
death_values = [0.005, 0.01, 0.02]
seeds = [51, 52]

candidates = DataFrame(
    beta = Float64[],
    detection_time = Int[],
    death_rate = Float64[],
    mean_peak_share = Float64[],
    mean_death_share = Float64[],
    feasible = Bool[],
    objective = Float64[],
)

for beta in beta_values
    for detection_time in detection_values
        for death_rate in death_values
            peak_values = Float64[]
            death_shares = Float64[]

            for seed in seeds
                df = run_extra_sir(;
                    Ns = [300, 300, 300],
                    β_und = fill(beta, 3),
                    β_det = fill(beta / 10, 3),
                    infection_period = 14,
                    detection_time = detection_time,
                    death_rate = death_rate,
                    reinfection_probability = 0.1,
                    Is = [0, 0, 1],
                    seed = seed,
                    n_steps = 60,
                )

                metrics = peak_metrics(df)
                push!(peak_values, metrics.peak_share)
                push!(death_shares, metrics.death_share)
            end

            mean_peak_share = mean(peak_values)
            mean_death_share = mean(death_shares)
            feasible = mean_peak_share < 0.30
            objective = feasible ? mean_death_share : Inf

            push!(candidates, (beta, detection_time, death_rate, mean_peak_share, mean_death_share, feasible, objective))
        end
    end
end

sort!(candidates, [:objective, :mean_peak_share])
feasible_candidates = subset(candidates, :feasible => ByRow(identity))
isempty(feasible_candidates) && error("Не найдено допустимых кандидатов с mean_peak_share < 0.30")
best = feasible_candidates[1, :]

plt = scatter(
    candidates.mean_peak_share,
    candidates.mean_death_share;
    xlabel = "Средний пик заражения",
    ylabel = "Средняя доля умерших",
    title = "Подбор параметров SIR: пространство решений",
    label = "Все кандидаты",
    markerstrokewidth = 0,
    color = ifelse.(candidates.feasible, :steelblue, :lightgray),
    size = (900, 560),
    grid = true,
)
scatter!(
    feasible_candidates.mean_peak_share,
    feasible_candidates.mean_death_share;
    label = "Допустимые кандидаты",
    color = :steelblue,
    markerstrokewidth = 0,
)
scatter!(
    [best.mean_peak_share],
    [best.mean_death_share];
    label = "Лучший кандидат",
    color = :firebrick,
    markersize = 8,
)
annotate!(
    best.mean_peak_share,
    best.mean_death_share,
    text("beta=$(best.beta), det=$(best.detection_time), death=$(round(best.death_rate, digits = 2))", 8, :left),
)

savefig(plt, plotsdir(script_name, "optimization_tradeoff.png"))
write_tsv(datadir(script_name, "optimization_candidates.tsv"), candidates)

open(datadir(script_name, "optimization_best.txt"), "w") do io
    println(io, "constraint = mean_peak_share < 0.30")
    println(io, "beta = $(best.beta)")
    println(io, "detection_time = $(best.detection_time)")
    println(io, "death_rate = $(best.death_rate)")
    println(io, "mean_peak_share = $(round(best.mean_peak_share, digits = 4))")
    println(io, "mean_death_share = $(round(best.mean_death_share, digits = 4))")
    println(io, "objective = $(round(best.objective, digits = 4))")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
