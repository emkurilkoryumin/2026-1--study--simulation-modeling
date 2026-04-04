using DrWatson
@quickactivate "project"

using DataFrames
using Plots
using Statistics

include(srcdir("sir_extra_model.jl"))

script_name = splitext(basename(PROGRAM_FILE))[1]
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

population_by_city = [500, 500, 500]
heterogeneous_beta = [0.12, 0.08, 0.04]
homogeneous_beta = fill(mean(heterogeneous_beta), 3)
detection_ratio = 10
n_steps = 100

overall_hom, city_hom, _ = run_extra_sir_citywise(;
    Ns = population_by_city,
    β_und = homogeneous_beta,
    β_det = homogeneous_beta ./ detection_ratio,
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [0, 0, 1],
    seed = 42,
    n_steps = n_steps,
)

overall_het, city_het, _ = run_extra_sir_citywise(;
    Ns = population_by_city,
    β_und = heterogeneous_beta,
    β_det = heterogeneous_beta ./ detection_ratio,
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [0, 0, 1],
    seed = 42,
    n_steps = n_steps,
)

base_population = sum(population_by_city)
overall_hom[!, :infected_share] = overall_hom.infected ./ base_population
overall_het[!, :infected_share] = overall_het.infected ./ base_population

plt_overall = plot(
    overall_hom.time,
    overall_hom.infected_share;
    label = "Однородный beta",
    xlabel = "Шаг моделирования",
    ylabel = "Доля инфицированных",
    title = "Общая динамика: однородность против гетерогенности",
    linewidth = 2,
    color = :royalblue,
    size = (920, 520),
    grid = true,
)
plot!(overall_het.time, overall_het.infected_share; label = "Гетерогенный beta", color = :firebrick, linewidth = 2)

plt_cities = plot(layout = (3, 1), size = (920, 980))
for city in 1:3
    city_df = subset(city_het, :city => ByRow(==(city)))
    plot!(
        plt_cities[city],
        city_df.time,
        [city_df.susceptible city_df.infected city_df.recovered];
        label = ["S(t)" "I(t)" "R(t)"],
        xlabel = "Шаг моделирования",
        ylabel = "Число агентов",
        title = "Город $(city): beta = $(heterogeneous_beta[city])",
        linewidth = 2,
        color = [:royalblue :firebrick :seagreen],
        grid = true,
    )
end

savefig(plt_overall, plotsdir(script_name, "overall_heterogeneity_compare.png"))
savefig(plt_cities, plotsdir(script_name, "city_dynamics.png"))

summary = DataFrame(
    scenario = ["homogeneous", "heterogeneous"],
    peak_infected_share = [
        maximum(overall_hom.infected_share),
        maximum(overall_het.infected_share),
    ],
    peak_time = [
        overall_hom.time[argmax(overall_hom.infected_share)],
        overall_het.time[argmax(overall_het.infected_share)],
    ],
    final_death_share = [
        overall_hom.dead[end] / base_population,
        overall_het.dead[end] / base_population,
    ],
)

city_summary_rows = NamedTuple[]
for city in 1:3
    city_df = subset(city_het, :city => ByRow(==(city)))
    peak_index = argmax(city_df.infected)
    push!(city_summary_rows, (
        city = city,
        beta = heterogeneous_beta[city],
        peak_infected = Int(city_df.infected[peak_index]),
        peak_time = Int(city_df.time[peak_index]),
        final_dead = Int(city_df.dead[end]),
    ))
end
city_summary = DataFrame(city_summary_rows)

write_tsv(datadir(script_name, "overall_summary.tsv"), summary)
write_tsv(datadir(script_name, "city_summary.tsv"), city_summary)

open(datadir(script_name, "heterogeneity_comment.txt"), "w") do io
    println(io, "heterogeneous_beta = $(join(round.(heterogeneous_beta, digits = 3), ", "))")
    println(io, "homogeneous_beta = $(round(homogeneous_beta[1], digits = 3))")
    println(io, "overall_peak_homogeneous = $(round(summary.peak_infected_share[1], digits = 4))")
    println(io, "overall_peak_heterogeneous = $(round(summary.peak_infected_share[2], digits = 4))")
    println(io, "comment = higher beta in one city accelerates local outbreak and changes the global curve shape")
end

println("Результаты сохранены в plots/$(script_name) и data/$(script_name).")
