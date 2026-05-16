using DrWatson
@quickactivate "project"

using DataFrames
using Plots

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

population_by_city = [500, 500, 500]
base_rates = migration_matrix(3, 0.25)
quarantine_threshold = 0.08
n_steps = 110

overall_base, city_base, _ = run_extra_sir_citywise(;
    Ns = population_by_city,
    migration_rates = base_rates,
    β_und = [0.08, 0.08, 0.08],
    β_det = [0.008, 0.008, 0.008],
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [1, 0, 0],
    seed = 42,
    n_steps = n_steps,
)

closure_rows = NamedTuple[]
closed_cities = falses(3)

function quarantine_step!(model, step)
    snapshot = extra_sir_city_counts(model)
    for row in eachrow(snapshot)
        city = Int(row.city)
        if !closed_cities[city] && row.infected_share > quarantine_threshold
            model.migration_rates[city, :] .= 0.0
            model.migration_rates[city, city] = 1.0
            closed_cities[city] = true
            push!(closure_rows, (
                time = step,
                city = city,
                infected_share = Float64(row.infected_share),
            ))
        end
    end
end

overall_quarantine, city_quarantine, _ = run_extra_sir_citywise(;
    Ns = population_by_city,
    migration_rates = copy(base_rates),
    β_und = [0.08, 0.08, 0.08],
    β_det = [0.008, 0.008, 0.008],
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [1, 0, 0],
    seed = 42,
    n_steps = n_steps,
    after_step! = quarantine_step!,
)

base_population = sum(population_by_city)
overall_base[!, :infected_share] = overall_base.infected ./ base_population
overall_quarantine[!, :infected_share] = overall_quarantine.infected ./ base_population
overall_base[!, :death_share] = overall_base.dead ./ base_population
overall_quarantine[!, :death_share] = overall_quarantine.dead ./ base_population

plt = plot(layout = (2, 1), size = (920, 840))
plot!(
    plt[1],
    overall_base.time,
    overall_base.infected_share;
    label = "Без карантина",
    xlabel = "Шаг моделирования",
    ylabel = "Доля инфицированных",
    title = "Сравнение заражённости: базовый случай и карантин",
    linewidth = 2,
    color = :royalblue,
    grid = true,
)
plot!(plt[1], overall_quarantine.time, overall_quarantine.infected_share; label = "С карантином", color = :firebrick, linewidth = 2)

plot!(
    plt[2],
    overall_base.time,
    overall_base.death_share;
    label = "Без карантина",
    xlabel = "Шаг моделирования",
    ylabel = "Доля умерших",
    title = "Сравнение смертности",
    linewidth = 2,
    color = :royalblue,
    grid = true,
)
plot!(plt[2], overall_quarantine.time, overall_quarantine.death_share; label = "С карантином", color = :firebrick, linewidth = 2)

savefig(plt, plotsdir(script_name, "quarantine_comparison.png"))

closure_df = isempty(closure_rows) ? DataFrame(time = Int[], city = Int[], infected_share = Float64[]) : DataFrame(closure_rows)
summary = DataFrame(
    scenario = ["baseline", "quarantine"],
    peak_infected_share = [
        maximum(overall_base.infected_share),
        maximum(overall_quarantine.infected_share),
    ],
    peak_time = [
        overall_base.time[argmax(overall_base.infected_share)],
        overall_quarantine.time[argmax(overall_quarantine.infected_share)],
    ],
    final_death_share = [
        overall_base.death_share[end],
        overall_quarantine.death_share[end],
    ],
)

write_tsv(datadir(script_name, "quarantine_summary.tsv"), summary)
write_tsv(datadir(script_name, "quarantine_closures.tsv"), closure_df)

open(datadir(script_name, "quarantine_comment.txt"), "w") do io
    println(io, "quarantine_threshold = $(quarantine_threshold)")
    println(io, "baseline_peak = $(round(summary.peak_infected_share[1], digits = 4))")
    println(io, "quarantine_peak = $(round(summary.peak_infected_share[2], digits = 4))")
    println(io, "baseline_death_share = $(round(summary.final_death_share[1], digits = 4))")
    println(io, "quarantine_death_share = $(round(summary.final_death_share[2], digits = 4))")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
