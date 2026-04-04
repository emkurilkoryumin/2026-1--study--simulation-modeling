using Agents
using Random

@agent struct Person(NoSpaceAgent)
    status::Symbol
    days_infected::Int
end

is_susceptible(agent::Person) = agent.status == :S
is_infected(agent::Person) = agent.status == :I
is_recovered(agent::Person) = agent.status == :R

function infect_contacts!(agent::Person, model)
    for _ in 1:model.contacts_per_day
        target_id = rand(abmrng(model), 1:model.population)
        target_id == agent.id && continue
        target = model[target_id]
        if is_susceptible(target) && rand(abmrng(model)) <= model.beta
            push!(model.pending_infections, target_id)
        end
    end
end

function sir_agent_step!(agent::Person, model)
    is_infected(agent) || return
    infect_contacts!(agent, model)
    agent.days_infected += 1

    if rand(abmrng(model)) <= model.gamma
        push!(model.pending_recoveries, agent.id)
    end

    return nothing
end

function sir_model_step!(model)
    for agent_id in unique(model.pending_infections)
        agent = model[agent_id]
        if is_susceptible(agent)
            agent.status = :I
            agent.days_infected = 0
        end
    end

    for agent_id in unique(model.pending_recoveries)
        agent = model[agent_id]
        if is_infected(agent)
            agent.status = :R
            agent.days_infected = 0
        end
    end

    empty!(model.pending_infections)
    empty!(model.pending_recoveries)
    model.tick += 1
    return nothing
end

function sir_counts(model)
    susceptible = count(is_susceptible, allagents(model))
    infected = count(is_infected, allagents(model))
    recovered = count(is_recovered, allagents(model))
    return (susceptible = susceptible, infected = infected, recovered = recovered)
end

function sir_model(;
    population = 1000,
    initial_infected = 10,
    beta = 0.05,
    contacts_per_day = 10,
    gamma = 0.25,
    seed = 42,
)
    rng = MersenneTwister(seed)

    properties = Dict(
        :population => population,
        :beta => beta,
        :contacts_per_day => contacts_per_day,
        :gamma => gamma,
        :tick => 0,
        :pending_infections => Int[],
        :pending_recoveries => Int[],
    )

    model = StandardABM(
        Person;
        agent_step! = sir_agent_step!,
        model_step! = sir_model_step!,
        properties,
        rng,
        scheduler = Schedulers.Randomly(),
    )

    for _ in 1:(population - initial_infected)
        add_agent!(model, :S, 0)
    end

    for _ in 1:initial_infected
        add_agent!(model, :I, 0)
    end

    return model
end

export Person, sir_model, sir_counts, is_susceptible, is_infected, is_recovered
