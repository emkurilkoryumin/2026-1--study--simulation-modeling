using DrWatson
@quickactivate "project"

using CSV
using DataFrames

include(srcdir("DiscreteEventLab07Core.jl"))
using .DiscreteEventLab07

mkpath(datadir())
mkpath(plotsdir())

mmc = simulate_mmc(
    num_customers = 1500,
    num_servers = 2,
    arrival_rate = 0.85,
    service_rate = 0.5,
    warmup_customers = 200,
    seed = 123,
)

CSV.write(datadir("mmc_customers.csv"), mmc.customers)
CSV.write(datadir("mmc_state.csv"), mmc.state)
CSV.write(datadir("mmc_summary.tsv"), mmc.summary; delim = '\t')

println("Базовый сценарий M/M/c")
println(mmc.summary)

ross = simulate_ross(
    N = 10,
    S = 3,
    num_repairers = 2,
    failure_mean = 20.0,
    repair_mean = 8.0,
    seed = 42,
)

CSV.write(datadir("ross_state.csv"), ross.state)
CSV.write(datadir("ross_summary.tsv"), ross.summary; delim = '\t')

println("Базовый сценарий модели Росса")
println(ross.summary)
