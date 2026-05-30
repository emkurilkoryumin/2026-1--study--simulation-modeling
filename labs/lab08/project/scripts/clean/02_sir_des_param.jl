using DrWatson
@quickactivate "project"

ENV["GKSwstype"] = "100"

using CSV
using DataFrames
using Plots

include(srcdir("SIRDESLab08.jl"))
using .SIRDESLab08

mkpath(datadir("sims"))
mkpath(plotsdir())

u0 = [990, 10, 0]
base_parameters = [0.05, 10.0, 0.25]
tmax = 40.0

scan_beta = sensitivity_scan(
    u0,
    base_parameters;
    parameter = :beta,
    values = [0.03, 0.05, 0.07],
    tmax = tmax,
    seed = 2100,
)
scan_contacts = sensitivity_scan(
    u0,
    base_parameters;
    parameter = :contacts,
    values = [6.0, 10.0, 14.0],
    tmax = tmax,
    seed = 2200,
)
scan_gamma = sensitivity_scan(
    u0,
    base_parameters;
    parameter = :gamma,
    values = [0.15, 0.25, 0.40],
    tmax = tmax,
    seed = 2300,
)

sensitivity_summary = vcat(scan_beta.summary, scan_contacts.summary, scan_gamma.summary)

CSV.write(datadir("sims", "sir_sensitivity_summary.csv"), sensitivity_summary)

println("Анализ чувствительности DES-SIR")
println(sensitivity_summary)

function plot_infected_scan(scan, parameter_label, filename)

    chart = plot(
        xlabel = "Время",
        ylabel = "Инфицированные",
        title = "Чувствительность к параметру $parameter_label",
    )
    for trajectory in scan.trajectories
        plot!(
            chart,
            trajectory.data.t,
            trajectory.data.I;
            label = "$parameter_label = $(trajectory.value)",
            linewidth = 2,
        )
    end
    savefig(chart, plotsdir(filename))
end

plot_infected_scan(scan_beta, "beta", "sir_sensitivity_beta.png")
plot_infected_scan(scan_contacts, "c", "sir_sensitivity_contacts.png")
plot_infected_scan(scan_gamma, "gamma", "sir_sensitivity_gamma.png")

recovery_modes = compare_recovery_modes(u0, base_parameters; tmax = tmax, seed = 3100)
recovery_summary = vcat(recovery_modes.exponential.summary, recovery_modes.fixed.summary)
CSV.write(datadir("sims", "sir_recovery_modes_summary.csv"), recovery_summary)

println("Сравнение длительности болезни")
println(recovery_summary)

plot(
    recovery_modes.exponential.data.t,
    recovery_modes.exponential.data.I;
    label = "Экспоненциальная длительность",
    linewidth = 2,
    xlabel = "Время",
    ylabel = "Инфицированные",
    title = "Влияние длительности болезни",
)
plot!(
    recovery_modes.fixed.data.t,
    recovery_modes.fixed.data.I;
    label = "Фиксированная длительность",
    linewidth = 2,
    linestyle = :dash,
)
savefig(plotsdir("sir_recovery_modes.png"))

metric_plots = plot(layout = (1, 2), size = (1000, 420))
levels = 1:3
level_ticks = (levels, ["низкий", "базовый", "высокий"])
for (parameter_name, marker_shape) in zip(["beta", "contacts", "gamma"], [:circle, :diamond, :utriangle])
    rows = sensitivity_summary[sensitivity_summary.parameter .== parameter_name, :]
    plot!(
        metric_plots[1],
        levels,
        rows.peak_infected;
        marker = marker_shape,
        label = parameter_name,
        xticks = level_ticks,
        xlabel = "Уровень параметра",
        ylabel = "Пик I",
        title = "Максимум числа инфицированных",
    )
    plot!(
        metric_plots[2],
        levels,
        rows.affected_share;
        marker = marker_shape,
        label = parameter_name,
        xticks = level_ticks,
        xlabel = "Уровень параметра",
        ylabel = "Итоговая доля заболевших",
        title = "Размер эпидемии",
    )
end
savefig(metric_plots, plotsdir("sir_sensitivity_metrics.png"))
