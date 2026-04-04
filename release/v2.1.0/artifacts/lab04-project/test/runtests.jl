using Test
using Agents
using DrWatson
@quickactivate "project"

include(srcdir("sir_agents_model.jl"))

@testset "lab04 models" begin
    sir = sir_model(population = 200, initial_infected = 5, seed = 1)
    Agents.step!(sir, 10)
    counts = sir_counts(sir)
    @test counts.susceptible + counts.infected + counts.recovered == 200
end
