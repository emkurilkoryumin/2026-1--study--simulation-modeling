using Agents
using Agents.Graphs
using DataFrames
using Distributions: Poisson
using Random
using StatsBase: Weights, sample

@agent struct CityPerson(GraphAgent)
    days_infected::Int
    status::Symbol
end

is_susceptible(agent::CityPerson) = agent.status == :S
is_infected(agent::CityPerson) = agent.status == :I
is_recovered(agent::CityPerson) = agent.status == :R

function default_migration_rates(Ns::AbstractVector{<:Integer})
    city_count = length(Ns)
    matrix = zeros(Float64, city_count, city_count)

    for from_city in 1:city_count
        for to_city in 1:city_count
            matrix[from_city, to_city] = from_city == to_city ? Ns[from_city] : Ns[to_city]
        end
        matrix[from_city, :] ./= sum(matrix[from_city, :])
    end

    return matrix
end

function migration_matrix(city_count::Integer, intensity::Real)
    matrix = zeros(Float64, city_count, city_count)

    if city_count == 1
        matrix[1, 1] = 1.0
        return matrix
    end

    stay_probability = clamp(1.0 - Float64(intensity), 0.0, 1.0)
    move_probability = (1.0 - stay_probability) / (city_count - 1)

    for city in 1:city_count
        matrix[city, :] .= move_probability
        matrix[city, city] = stay_probability
    end

    return matrix
end

function initialize_extra_sir(;
    Ns = [600, 600, 600],
    migration_rates = nothing,
    β_und = [0.5, 0.5, 0.5],
    β_det = [0.05, 0.05, 0.05],
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    Is = [0, 0, 1],
    seed = 42,
)
    city_count = length(Ns)
    @assert length(β_und) == city_count
    @assert length(β_det) == city_count
    @assert length(Is) == city_count

    rates = migration_rates === nothing ? default_migration_rates(Ns) : Float64.(migration_rates)
    rng = Xoshiro(seed)

    properties = Dict(
        :Ns => Int.(Ns),
        :β_und => Float64.(β_und),
        :β_det => Float64.(β_det),
        :migration_rates => rates,
        :infection_period => infection_period,
        :detection_time => detection_time,
        :death_rate => Float64(death_rate),
        :reinfection_probability => Float64(reinfection_probability),
        :city_count => city_count,
        :initial_population => sum(Ns),
    )

    model = StandardABM(
        CityPerson,
        GraphSpace(complete_graph(city_count));
        properties,
        rng,
        agent_step! = extra_sir_agent_step!,
    )

    for city in 1:city_count
        for _ in 1:Ns[city]
            add_agent!(city, model, 0, :S)
        end
    end

    for city in 1:city_count
        initial_infected = min(Is[city], Ns[city])
        initial_infected == 0 && continue

        city_ids = collect(ids_in_position(city, model))
        infected_ids = sample(rng, city_ids, initial_infected; replace = false)

        for agent_id in infected_ids
            agent = model[agent_id]
            agent.status = :I
            agent.days_infected = 1
        end
    end

    return model
end

function extra_sir_agent_step!(agent::CityPerson, model)
    migrate!(agent, model)

    if is_infected(agent)
        transmit!(agent, model)
        agent.days_infected += 1
        recover_or_die!(agent, model)
    end

    return nothing
end

function migrate!(agent::CityPerson, model)
    probabilities = model.migration_rates[agent.pos, :]
    destination = sample(abmrng(model), 1:model.city_count, Weights(probabilities))

    if destination != agent.pos
        move_agent!(agent, destination, model)
    end

    return nothing
end

function transmit!(agent::CityPerson, model)
    rate = agent.days_infected < model.detection_time ? model.β_und[agent.pos] : model.β_det[agent.pos]
    rate <= 0 && return nothing

    targets = [other for other in agents_in_position(agent.pos, model) if other.id != agent.id]
    isempty(targets) && return nothing

    exposure_count = rand(abmrng(model), Poisson(rate * 3))
    exposure_count == 0 && return nothing

    for _ in 1:exposure_count
        target = rand(abmrng(model), targets)
        if is_susceptible(target)
            target.status = :I
            target.days_infected = 1
        elseif is_recovered(target) && rand(abmrng(model)) <= model.reinfection_probability
            target.status = :I
            target.days_infected = 1
        end
    end

    return nothing
end

function recover_or_die!(agent::CityPerson, model)
    if agent.days_infected < model.infection_period
        return nothing
    end

    if rand(abmrng(model)) <= model.death_rate
        remove_agent!(agent, model)
    else
        agent.status = :R
        agent.days_infected = 0
    end

    return nothing
end

function extra_sir_counts(model)
    susceptible = count(is_susceptible, allagents(model))
    infected = count(is_infected, allagents(model))
    recovered = count(is_recovered, allagents(model))
    alive = nagents(model)
    dead = model.initial_population - alive

    return (
        susceptible = susceptible,
        infected = infected,
        recovered = recovered,
        alive = alive,
        dead = dead,
    )
end

function extra_sir_city_counts(model)
    rows = NamedTuple[]

    for city in 1:model.city_count
        city_agents = collect(agents_in_position(city, model))
        susceptible = count(is_susceptible, city_agents)
        infected = count(is_infected, city_agents)
        recovered = count(is_recovered, city_agents)
        alive = length(city_agents)
        dead = model.Ns[city] - alive
        infected_share = infected / max(model.Ns[city], 1)

        push!(rows, (
            city = city,
            susceptible = susceptible,
            infected = infected,
            recovered = recovered,
            alive = alive,
            dead = dead,
            infected_share = infected_share,
        ))
    end

    return DataFrame(rows)
end

function append_city_rows!(rows, model, time)
    snapshot = extra_sir_city_counts(model)

    for row in eachrow(snapshot)
        push!(rows, (
            time = time,
            city = Int(row.city),
            susceptible = Int(row.susceptible),
            infected = Int(row.infected),
            recovered = Int(row.recovered),
            alive = Int(row.alive),
            dead = Int(row.dead),
            infected_share = Float64(row.infected_share),
        ))
    end

    return rows
end

function run_extra_sir(;
    n_steps = 100,
    kwargs...,
)
    model = initialize_extra_sir(; kwargs...)
    rows = NamedTuple[]
    push!(rows, merge((time = 0,), extra_sir_counts(model)))

    for step in 1:n_steps
        step!(model, 1)
        push!(rows, merge((time = step,), extra_sir_counts(model)))
    end

    return DataFrame(rows)
end

function run_extra_sir_citywise(;
    n_steps = 100,
    after_step! = nothing,
    kwargs...,
)
    model = initialize_extra_sir(; kwargs...)
    overall_rows = NamedTuple[]
    city_rows = NamedTuple[]

    push!(overall_rows, merge((time = 0,), extra_sir_counts(model)))
    append_city_rows!(city_rows, model, 0)

    for step in 1:n_steps
        step!(model, 1)

        if after_step! !== nothing
            after_step!(model, step)
        end

        push!(overall_rows, merge((time = step,), extra_sir_counts(model)))
        append_city_rows!(city_rows, model, step)
    end

    return DataFrame(overall_rows), DataFrame(city_rows), model
end

function peak_metrics(df::DataFrame)
    peak_index = argmax(df.infected)
    base_population = max(df.alive[1] + df.dead[1], 1)

    return (
        peak_time = Int(df.time[peak_index]),
        peak_infected = Int(df.infected[peak_index]),
        peak_share = df.infected[peak_index] / base_population,
        final_infected_share = df.infected[end] / base_population,
        final_recovered_share = df.recovered[end] / base_population,
        death_share = df.dead[end] / base_population,
    )
end

function write_tsv(path::AbstractString, df::DataFrame)
    open(path, "w") do io
        println(io, join(String.(names(df)), '\t'))
        for row in eachrow(df)
            println(io, join([row[column] for column in names(df)], '\t'))
        end
    end
end

export CityPerson
export default_migration_rates, migration_matrix
export append_city_rows!, extra_sir_city_counts, extra_sir_counts
export initialize_extra_sir, peak_metrics, run_extra_sir, run_extra_sir_citywise, write_tsv
export is_infected, is_recovered, is_susceptible
