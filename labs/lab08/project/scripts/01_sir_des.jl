# # Лабораторная работа 8: дискретно-событийная модель SIR
#
# В базовом сценарии моделируется эпидемия в полностью смешивающейся
# популяции. Каждый восприимчивый агент через экспоненциально распределённые
# интервалы времени выбирает случайный контакт. При встрече с инфицированным
# заражение происходит с вероятностью `beta`.

using DrWatson
@quickactivate "project"

# Графический backend работает без оконного интерфейса. Это важно при
# запуске из терминала и при автоматическом выполнении notebook.
ENV["GKSwstype"] = "100"

using CSV
using Plots

include(srcdir("SIRDESLab08.jl"))
using .SIRDESLab08

# Результаты эксперимента и графики сохраняются в стандартных каталогах
# проекта DrWatson: data/sims и plots.
mkpath(datadir("sims"))
mkpath(plotsdir())

# ## Параметры базового сценария
#
# Начальное состояние `u0 = [S0, I0, R0]`. Параметры модели:
# `beta` — вероятность передачи при контакте, `contacts` — частота контактов,
# `gamma` — интенсивность выздоровления.

tmax = 40.0
u0 = [990, 10, 0]
parameters = [0.05, 10.0, 0.25]

# Функция run_sir выполняет полный цикл моделирования:
# создаёт агентов, регистрирует процессы, запускает календарь событий
# и возвращает таблицу событий вместе со сводными показателями.
result = run_sir(
    u0,
    parameters;
    tmax = tmax,
    seed = 1234,
    scenario = "base",
)

# В CSV записываются полная траектория и короткая таблица метрик.
CSV.write(datadir("sims", "sir_990_10_0.05_10.0_0.25.csv"), result.data)
CSV.write(datadir("sims", "sir_base_summary.csv"), result.summary)

println("Базовый сценарий DES-SIR")
println(result.summary)

# ## График стохастической траектории
#
# Ступенчатые изменения S, I и R фиксируются в моменты заражения и
# выздоровления. Между событиями численность групп не меняется.

plot(
    result.data.t,
    result.data.S;
    label = "S",
    linewidth = 2,
    xlabel = "Время",
    ylabel = "Численность",
    title = "Дискретно-событийная SIR-модель",
)
plot!(result.data.t, result.data.I; label = "I", linewidth = 2)
plot!(result.data.t, result.data.R; label = "R", linewidth = 2)
savefig(plotsdir("sir_des.png"))

# ## Сравнение с детерминированной моделью
#
# Для контроля стохастическая траектория сопоставляется с численным решением
# системы ОДУ SIR. ОДУ интегрируются методом Рунге-Кутты четвёртого порядка.

ode = solve_deterministic_sir(u0, parameters; tmax = tmax)

plot(
    result.data.t,
    result.data.I;
    label = "DES: I(t)",
    linewidth = 2,
    xlabel = "Время",
    ylabel = "Инфицированные",
    title = "Стохастическая DES и детерминированная SIR-модель",
)
plot!(ode.t, ode.I; label = "ОДУ: I(t)", linewidth = 2, linestyle = :dash)
savefig(plotsdir("sir_des_vs_ode.png"))

CSV.write(datadir("sims", "sir_deterministic_ode.csv"), ode)
