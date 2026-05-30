using Test
using DrWatson
@quickactivate "project"

using Random

include(srcdir("SIRPetri.jl"))
using .SIRPetri

@testset "lab06 sir petri" begin
    net, u0, states = build_sir_network(0.3, 0.1)

    @test states == [:S, :I, :R]
    @test net.place_names == [:S, :I, :R]
    @test net.transition_names == [:infection, :recovery]
    @test u0 == [990.0, 10.0, 0.0]

    df_det = simulate_deterministic(net, u0, (0.0, 5.0); saveat = 0.5, rates = [0.3, 0.1])
    det_population = df_det.S .+ df_det.I .+ df_det.R
    @test maximum(abs.(det_population .- sum(u0))) < 1e-6
    @test all(df_det.S .>= 0.0)
    @test all(df_det.I .>= 0.0)
    @test all(df_det.R .>= 0.0)

    df_stoch = simulate_stochastic(
        net,
        u0,
        (0.0, 5.0);
        rates = [0.3, 0.1],
        rng = MersenneTwister(7),
    )
    stoch_population = df_stoch.S .+ df_stoch.I .+ df_stoch.R
    @test all(stoch_population .== 1000)
    @test all(df_stoch.S .>= 0)
    @test all(df_stoch.I .>= 0)
    @test all(df_stoch.R .>= 0)

    sampled = sample_path(df_stoch, [0.0, 1.0, 2.0, 3.0]; column = :I)
    @test length(sampled) == 4
    @test all(sampled .>= 0)
end
