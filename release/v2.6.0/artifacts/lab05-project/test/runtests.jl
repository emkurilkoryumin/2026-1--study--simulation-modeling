using Test
using DrWatson
@quickactivate "project"

using Random

include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers

@testset "lab05 petri nets" begin
    N = 5

    net_classic, u0_classic, _ = build_classical_network(N)
    @test net_classic.n_places == 4N
    @test net_classic.n_transitions == 3N
    @test sum(u0_classic[1:N]) == N
    @test sum(u0_classic[3N + 1:4N]) == N
    @test !is_deadlock_marking(net_classic, u0_classic)

    net_arbiter, u0_arbiter, _ = build_arbiter_network(N)
    @test net_arbiter.n_places == 4N + 1
    @test net_arbiter.n_transitions == 3N
    @test u0_arbiter[end] == N - 1
    @test !is_deadlock_marking(net_arbiter, u0_arbiter)

    deadlocked = zeros(Float64, 4N)
    deadlocked[N + 1:2N] .= 1.0
    @test is_deadlock_marking(net_classic, deadlocked)

    df = simulate_stochastic(net_classic, u0_classic, 5.0; rng = MersenneTwister(7))
    for row in eachrow(df)
        philosopher_total = sum(
            Float64(row[Symbol("Think_$i")]) +
            Float64(row[Symbol("Hungry_$i")]) +
            Float64(row[Symbol("Eat_$i")]) for i in 1:N
        )
        @test philosopher_total ≈ N
    end
end
