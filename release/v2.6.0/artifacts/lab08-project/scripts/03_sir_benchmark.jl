# # Лабораторная работа 8: оценка производительности
#
# Дополнительный сценарий измеряет время выполнения DES-SIR для популяции
# из 10000 индивидов. Результат сохраняется в CSV для включения в отчёт.

using DrWatson
@quickactivate "project"

using BenchmarkTools
using CSV
using DataFrames
using Statistics

include(srcdir("SIRDESLab08.jl"))
using .SIRDESLab08

# Каталог создаётся автоматически, если сценарий запускается первым.
mkpath(datadir("sims"))

# В популяции остаются 10 начальных инфицированных, а общее число агентов
# увеличивается до 10000 согласно дополнительному заданию.
u0 = [9990, 10, 0]
parameters = [0.05, 10.0, 0.25]
tmax = 40.0

# Прогрев исключает время компиляции Julia из итоговых измерений.
run_sir(u0, parameters; tmax = 1.0, seed = 4100)

# Выполняются три независимых измерения. Для агентной DES-модели этого
# достаточно, поскольку один полный запуск уже занимает десятки секунд.
trial = @benchmark run_sir($u0, $parameters; tmax = $tmax, seed = 4200) samples = 3 evals = 1 seconds = 60
best = minimum(trial)
typical = median(trial)

summary = DataFrame(
    population = [sum(u0)],
    tmax = [tmax],
    samples = [length(trial)],
    minimum_seconds = [best.time / 1.0e9],
    median_seconds = [typical.time / 1.0e9],
    memory_bytes = [typical.memory],
    allocations = [typical.allocs],
)

# Таблица содержит время, выделенную память и число аллокаций.
CSV.write(datadir("sims", "sir_benchmark_10000.csv"), summary)
println("Оценка производительности DES-SIR")
println(summary)
