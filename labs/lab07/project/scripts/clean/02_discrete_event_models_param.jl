using DrWatson
@quickactivate "project"

using CSV
using DataFrames

include(srcdir("DiscreteEventLab07Core.jl"))
using .DiscreteEventLab07

mkpath(datadir())
mkpath(plotsdir())

arrival_rates = [0.50, 0.65, 0.80, 0.90]
mmc_rows = DataFrame()

for (idx, arrival_rate) in enumerate(arrival_rates)
    result = simulate_mmc(
        num_customers = 2000,
        num_servers = 2,
        arrival_rate = arrival_rate,
        service_rate = 0.5,
        warmup_customers = 300,
        seed = 200 + idx,
    )
    append!(mmc_rows, result.summary)
end

CSV.write(datadir("mmc_scan.tsv"), mmc_rows; delim = '\t')

println("Параметрический сценарий M/M/c")
println(mmc_rows)

machine_counts = [8, 10, 12, 14]
repairer_counts = [1, 2, 3]
num_runs = 30

ross_scan = ross_parameter_grid(
    machine_counts = machine_counts,
    repairer_counts = repairer_counts,
    num_runs = num_runs,
    S = 3,
    failure_mean = 20.0,
    repair_mean = 8.0,
    seed = 700,
)

CSV.write(datadir("ross_machine_scan.tsv"), ross_scan; delim = '\t')

println("Параметрический сценарий модели Росса")
println(ross_scan)
