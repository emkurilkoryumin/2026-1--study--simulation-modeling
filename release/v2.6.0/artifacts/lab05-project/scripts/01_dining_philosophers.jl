# # Лабораторная работа 5: задача обедающих философов в сетях Петри
#
# В базовой части лабораторной работы сравниваются две сети Петри:
# классическая схема, в которой возможен deadlock, и модификация с арбитром,
# предотвращающая взаимную блокировку.

using DrWatson
@quickactivate "project"

using CSV
using DataFrames
using Plots
using Random
using Statistics

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

script_name = "01_dining_philosophers"
mkpath(plotsdir(script_name))
mkpath(datadir(script_name))

function total_tokens(df::DataFrame, columns::Vector{Symbol})
    return vec(sum(Matrix(df[:, columns]), dims = 2))
end

function summarize_network(label::String, df::DataFrame, net::PetriNet, N::Int)
    eaters = total_tokens(df, eat_columns(N))
    hungry_final = sum(Float64(df[end, column]) for column in state_columns("Hungry", N))
    deadlock = detect_deadlock(df, net)
    deadlock_time = deadlock ? df.time[end] : missing

    return (
        network = label,
        deadlock = deadlock,
        deadlock_time = deadlock_time,
        final_time = df.time[end],
        mean_eaters = mean(eaters),
        max_eaters = maximum(eaters),
        hungry_final = hungry_final,
    )
end

# ## Параметры базового сценария
#
# Для базового сравнения берутся пять философов. Скорость захвата первой вилки
# выбрана умеренной, а скорость захвата второй вилки выше: это позволяет в
# классической сети сначала наблюдать нормальную работу, а затем переход к
# тупику. Стохастическая динамика рассчитывается алгоритмом Гиллеспи, а
# непрерывная аппроксимация используется как дополнительная диагностическая
# кривая.

N = 5
tmax = 80.0
saveat = 0.2
left_rate = 0.5
right_rate = 1.8
put_rate = 0.8
rates = vcat(fill(left_rate, N), fill(right_rate, N), fill(put_rate, N))

net_classic, u0_classic, _ = build_classical_network(N)
net_arbiter, u0_arbiter, _ = build_arbiter_network(N)

df_classic = simulate_stochastic(
    net_classic,
    u0_classic,
    tmax;
    rates,
    rng = MersenneTwister(1),
)
df_arbiter = simulate_stochastic(
    net_arbiter,
    u0_arbiter,
    tmax;
    rates,
    rng = MersenneTwister(1),
)

ode_classic = simulate_ode(net_classic, u0_classic, tmax; saveat, rates)
ode_arbiter = simulate_ode(net_arbiter, u0_arbiter, tmax; saveat, rates)

CSV.write(datadir(script_name, "dining_classic.csv"), df_classic)
CSV.write(datadir(script_name, "dining_arbiter.csv"), df_arbiter)
CSV.write(datadir(script_name, "dining_classic_ode.csv"), ode_classic)
CSV.write(datadir(script_name, "dining_arbiter_ode.csv"), ode_arbiter)

summary = DataFrame([
    summarize_network("classic", df_classic, net_classic, N),
    summarize_network("arbiter", df_arbiter, net_arbiter, N),
])

CSV.write(datadir(script_name, "dining_summary.tsv"), summary; delim = '\t')

classic_plot = plot_marking_evolution(
    df_classic,
    N;
    title_prefix = "Классическая сеть",
)
arbiter_plot = plot_marking_evolution(
    df_arbiter,
    N;
    title_prefix = "Сеть с арбитром",
)

classic_eaters = total_tokens(df_classic, eat_columns(N))
arbiter_eaters = total_tokens(df_arbiter, eat_columns(N))
ode_classic_eaters = total_tokens(ode_classic, eat_columns(N))
ode_arbiter_eaters = total_tokens(ode_arbiter, eat_columns(N))

eating_compare = plot(
    df_classic.time,
    classic_eaters;
    label = "Классическая сеть",
    xlabel = "Время",
    ylabel = "Число философов в состоянии Eat",
    title = "Стохастическая динамика числа едящих философов",
    linewidth = 2,
    color = :firebrick,
    grid = true,
    size = (900, 520),
)
plot!(
    eating_compare,
    df_arbiter.time,
    arbiter_eaters;
    label = "Сеть с арбитром",
    color = :royalblue,
)

ode_compare = plot(
    ode_classic.time,
    ode_classic_eaters;
    label = "Классическая сеть",
    xlabel = "Время",
    ylabel = "Суммарная маркировка Eat",
    title = "ODE-аппроксимация числа едящих философов",
    linewidth = 2,
    color = :firebrick,
    grid = true,
    size = (900, 520),
)
plot!(
    ode_compare,
    ode_arbiter.time,
    ode_arbiter_eaters;
    label = "Сеть с арбитром",
    color = :royalblue,
)

savefig(classic_plot, plotsdir(script_name, "classic_simulation.png"))
savefig(arbiter_plot, plotsdir(script_name, "arbiter_simulation.png"))
savefig(eating_compare, plotsdir(script_name, "dining_eating_compare.png"))
savefig(ode_compare, plotsdir(script_name, "dining_ode_compare.png"))

println("Базовый сценарий задачи обедающих философов")
println("Параметры: left_rate = $(left_rate), right_rate = $(right_rate), put_rate = $(put_rate)")
println(summary)
println("Артефакты сохранены в plots/$(script_name) и data/$(script_name).")
