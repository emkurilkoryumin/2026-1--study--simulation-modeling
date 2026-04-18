# # Лабораторная работа 4: модель SIR в агентном подходе
#
# В этой части лабораторной работы реализуется агентная версия классической
# модели `SIR`. Каждый человек моделируется отдельным агентом с одним из трёх
# состояний: восприимчивый (`S`), инфицированный (`I`) или выздоровевший (`R`).

using DrWatson
@quickactivate "project"

using Agents
using DataFrames
using Plots
using Statistics

include(srcdir("sir_agents_model.jl"))

script_name = "01_sir_agents"
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

# ## Параметры базового сценария
#
# Для согласования с разделом про ODE-модель используются те же ключевые
# параметры: вероятность заражения `beta`, число контактов `contacts_per_day`
# и скорость выздоровления `gamma`.

population = 1000
initial_infected = 10
beta = 0.05
contacts_per_day = 10
gamma = 0.25
steps = 80

model = sir_model(;
    population,
    initial_infected,
    beta,
    contacts_per_day,
    gamma,
    seed = 42,
)

susceptible(agent) = is_susceptible(agent)
infected(agent) = is_infected(agent)
recovered(agent) = is_recovered(agent)
adata = [(susceptible, count), (infected, count), (recovered, count)]

# ## Выполнение моделирования

agent_df, _ = run!(model, steps; adata = adata)
rename!(agent_df, Dict(
    :count_susceptible => :susceptible,
    :count_infected => :infected,
    :count_recovered => :recovered,
))
agent_df[!, :population] = fill(population, nrow(agent_df))
agent_df[!, :infected_share] = 100 .* agent_df.infected ./ population
agent_df[!, :recovered_share] = 100 .* agent_df.recovered ./ population
agent_df[!, :susceptible_share] = 100 .* agent_df.susceptible ./ population
agent_df[!, :effective_reproduction] =
    (contacts_per_day * beta / gamma) .* agent_df.susceptible ./ population

# ## Анализ пика эпидемии

peak_idx = argmax(agent_df.infected)
peak_time = agent_df.time[peak_idx]
peak_value = agent_df.infected[peak_idx]
theoretical_r0 = contacts_per_day * beta / gamma

println("Параметры SIR-ABM:")
println("population = ", population)
println("initial_infected = ", initial_infected)
println("beta = ", beta)
println("contacts_per_day = ", contacts_per_day)
println("gamma = ", gamma)
println("R0 = ", round(theoretical_r0, digits = 2))
println("Пик заражения: ", peak_value, " человек на шаге ", peak_time)
println("Переболело к концу моделирования: ", agent_df.recovered[end], " человек")

# ## График динамики S, I, R

default(size = (850, 520), dpi = 150, legend = :right, linewidth = 2)

plt1 = plot(
    agent_df.time,
    [agent_df.susceptible agent_df.infected agent_df.recovered];
    label = ["S(t)" "I(t)" "R(t)"],
    xlabel = "Шаг моделирования",
    ylabel = "Число агентов",
    title = "Агентная модель SIR: динамика состояний",
    color = [:royalblue :firebrick :seagreen],
    grid = true,
)
vline!(plt1, [peak_time]; color = :black, linestyle = :dash, label = "пик I(t)")
annotate!(plt1, peak_time, peak_value, text("пик = $(peak_value)", 8, :left))

# ## График инфицированных

plt2 = plot(
    agent_df.time,
    agent_df.infected;
    label = "I(t)",
    xlabel = "Шаг моделирования",
    ylabel = "Число инфицированных",
    title = "Агентная модель SIR: динамика числа заражённых",
    color = :firebrick,
    fill = (0, 0.25, :firebrick),
    grid = true,
)
vline!(plt2, [peak_time]; color = :black, linestyle = :dash, label = "пик I(t)")
annotate!(plt2, peak_time, peak_value, text("пик = $(peak_value)", 8, :left))

# ## График инфицированных в логарифмическом масштабе

infected_for_log = max.(agent_df.infected, 1)
plt3 = plot(
    agent_df.time,
    infected_for_log;
    label = "I(t)",
    xlabel = "Шаг моделирования",
    ylabel = "Число инфицированных (log10)",
    title = "Агентная модель SIR: заражённые в логарифмическом масштабе",
    color = :firebrick,
    yscale = :log10,
    grid = true,
)

# ## График долей популяции

plt4 = plot(
    agent_df.time,
    [agent_df.susceptible_share agent_df.infected_share agent_df.recovered_share];
    label = ["S(t), %" "I(t), %" "R(t), %"],
    xlabel = "Шаг моделирования",
    ylabel = "Доля популяции, %",
    title = "Агентная модель SIR: доли популяции",
    color = [:royalblue :firebrick :seagreen],
    grid = true,
)

# ## Фазовый портрет

plt5 = plot(
    agent_df.susceptible,
    agent_df.infected;
    xlabel = "S(t)",
    ylabel = "I(t)",
    title = "Фазовый портрет агентной SIR-модели",
    color = :purple,
    legend = false,
    grid = true,
)

# ## Эффективное репродуктивное число

plt6 = plot(
    agent_df.time,
    agent_df.effective_reproduction;
    xlabel = "Шаг моделирования",
    ylabel = "R_e(t)",
    title = "Эффективное репродуктивное число",
    color = :darkgreen,
    legend = false,
    grid = true,
)
hline!(plt6, [1.0]; color = :red, linestyle = :dash)

# ## Компактная панель основных графиков

plt7 = plot(layout = (2, 3), size = (1200, 780))

plot!(
    plt7[1],
    agent_df.time,
    agent_df.susceptible;
    label = "S(t)",
    color = :royalblue,
    title = "Восприимчивые",
    xlabel = "Шаг",
    ylabel = "Число агентов",
    grid = true,
)
plot!(
    plt7[2],
    agent_df.time,
    agent_df.infected;
    label = "I(t)",
    color = :firebrick,
    title = "Инфицированные",
    xlabel = "Шаг",
    ylabel = "Число агентов",
    grid = true,
)
plot!(
    plt7[3],
    agent_df.time,
    agent_df.recovered;
    label = "R(t)",
    color = :seagreen,
    title = "Выздоровевшие",
    xlabel = "Шаг",
    ylabel = "Число агентов",
    grid = true,
)
plot!(
    plt7[4],
    agent_df.time,
    infected_for_log;
    label = "I(t)",
    color = :firebrick,
    title = "Логарифмический масштаб",
    xlabel = "Шаг",
    ylabel = "I(t)",
    yscale = :log10,
    grid = true,
)
plot!(
    plt7[5],
    agent_df.susceptible,
    agent_df.infected;
    label = "Фазовая траектория",
    color = :purple,
    title = "Фазовый портрет",
    xlabel = "S(t)",
    ylabel = "I(t)",
    grid = true,
)
plot!(
    plt7[6],
    agent_df.time,
    agent_df.effective_reproduction;
    label = "R_e(t)",
    color = :darkgreen,
    title = "Эффективное R_e",
    xlabel = "Шаг",
    ylabel = "R_e(t)",
    grid = true,
)
hline!(plt7[6], [1.0]; color = :red, linestyle = :dash, label = "R_e = 1")

savefig(plt1, plotsdir(script_name, "sir_main.png"))
savefig(plt2, plotsdir(script_name, "sir_infected.png"))
savefig(plt3, plotsdir(script_name, "sir_log_scale.png"))
savefig(plt4, plotsdir(script_name, "sir_percentages.png"))
savefig(plt5, plotsdir(script_name, "sir_phase_portrait.png"))
savefig(plt6, plotsdir(script_name, "sir_effective_R.png"))
savefig(plt7, plotsdir(script_name, "sir_panel.png"))

open(datadir(script_name, "sir_summary.txt"), "w") do io
    println(io, "R0 = $(round(theoretical_r0, digits = 3))")
    println(io, "peak_time = $(peak_time)")
    println(io, "peak_infected = $(peak_value)")
    println(io, "recovered_final = $(agent_df.recovered[end])")
end

println("Графики и сводка сохранены в plots/$(script_name) и data/$(script_name).")
