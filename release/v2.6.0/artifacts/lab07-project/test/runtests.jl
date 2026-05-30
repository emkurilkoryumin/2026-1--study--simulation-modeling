using Test
using DrWatson
@quickactivate "project"

include(srcdir("DiscreteEventLab07Core.jl"))
using .DiscreteEventLab07

@testset "lab07 discrete-event models" begin
    theory = mmc_theory(0.8, 0.5, 2)
    @test theory.mean_wait > 0
    @test theory.prob_wait > 0

    mmc = simulate_mmc(
        num_customers = 80,
        num_servers = 2,
        arrival_rate = 0.75,
        service_rate = 0.5,
        warmup_customers = 10,
        seed = 7,
    )
    @test size(mmc.customers, 1) == 80
    @test mmc.summary.mean_wait_sim[1] >= 0

    ross = simulate_ross(
        N = 6,
        S = 2,
        num_repairers = 1,
        failure_mean = 8.0,
        repair_mean = 4.0,
        seed = 9,
    )
    @test ross.summary.crash_time[1] > 0
    @test ross.summary.crash_time_theory[1] > 0
    @test all(ross.state.healthy .>= 5)
end
