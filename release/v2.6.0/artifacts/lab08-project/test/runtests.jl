using Test
using DrWatson
@quickactivate "project"

include(srcdir("SIRDESLab08.jl"))
using .SIRDESLab08

@testset "lab08 DES-SIR" begin
    result = run_sir([90, 10, 0], [0.05, 10.0, 0.25]; tmax = 20.0, seed = 7)
    @test all(result.data.S .+ result.data.I .+ result.data.R .== 100)
    @test all(diff(result.data.S) .<= 0)
    @test all(diff(result.data.R) .>= 0)
    @test all(diff(result.data.t) .>= 0)
    @test result.summary.events[1] == size(result.data, 1) - 1

    fixed = run_sir(
        [90, 10, 0],
        [0.05, 10.0, 0.25];
        tmax = 20.0,
        seed = 7,
        deterministic_recovery = true,
    )
    @test fixed.summary.recovery_mode[1] == "fixed"
    @test all(fixed.data.S .+ fixed.data.I .+ fixed.data.R .== 100)

    scan = sensitivity_scan(
        [90, 10, 0],
        [0.05, 10.0, 0.25];
        parameter = :beta,
        values = [0.03, 0.05],
        tmax = 10.0,
        seed = 9,
    )
    @test size(scan.summary, 1) == 2
    @test length(scan.trajectories) == 2

    ode = solve_deterministic_sir([90, 10, 0], [0.05, 10.0, 0.25]; tmax = 20.0)
    @test size(ode, 1) > 100
    @test maximum(abs.(ode.S .+ ode.I .+ ode.R .- 100.0)) < 1e-8

    @test_throws ArgumentError MakeSIRModel([100, 0, 0], [1.2, 10.0, 0.25])
    @test_throws ArgumentError sensitivity_scan(
        [90, 10, 0],
        [0.05, 10.0, 0.25];
        parameter = :unknown,
        values = [1.0],
    )
end
