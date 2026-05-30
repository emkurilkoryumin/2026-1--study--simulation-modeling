# # Лабораторная работа 6: базовый прогон модели SIR в сетях Петри
#
# В этом сценарии выполняется один базовый эксперимент с фиксированными
# коэффициентами заражения и выздоровления. Сравниваются две версии динамики:
# детерминированная `ODE`-аппроксимация и стохастическая траектория,
# рассчитанная алгоритмом Гиллеспи.

using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots
using Random

include(srcdir("SIRPetri.jl"))
using .SIRPetri

mkpath(datadir())
mkpath(plotsdir())

# ## Параметры базового сценария
#
# В методичке предлагается использовать следующие значения:
# `β = 0.3`, `γ = 0.1`, `tmax = 100.0`.

β = 0.3
γ = 0.1
tmax = 100.0

net, u0, states = build_sir_network(β, γ)

# ## Детерминированная симуляция
#
# Для гладкой кривой используется шаг сохранения `saveat = 0.5`.

df_det = simulate_deterministic(net, u0, (0.0, tmax); saveat = 0.5, rates = [β, γ])
CSV.write(datadir("sir_det.csv"), df_det)

# ## Стохастическая симуляция
#
# Фиксированное зерно случайных чисел делает траекторию воспроизводимой.

df_stoch = simulate_stochastic(
    net,
    u0,
    (0.0, tmax);
    rates = [β, γ],
    rng = MersenneTwister(123),
)
CSV.write(datadir("sir_stoch.csv"), df_stoch)

# ## Визуализация
#
# Сохраняются два отдельных графика для отчёта и итогового сравнения.

p_det = plot_sir(df_det; title = "Детерминированная динамика SIR")
p_stoch = plot_sir(df_stoch; title = "Стохастическая динамика SIR")

savefig(p_det, plotsdir("sir_det_dynamics.png"))
savefig(p_stoch, plotsdir("sir_stoch_dynamics.png"))

println("Базовый прогон завершён. Результаты в data/ и plots/")
println("Peak I (deterministic) = $(round(maximum(df_det.I), digits = 2))")
println("Peak I (stochastic)    = $(maximum(df_stoch.I))")
println("Final R (deterministic) = $(round(df_det.R[end], digits = 2))")
println("Final R (stochastic)    = $(df_stoch.R[end])")
