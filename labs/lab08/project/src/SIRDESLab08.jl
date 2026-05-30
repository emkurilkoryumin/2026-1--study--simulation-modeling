module SIRDESLab08

# Ядро лабораторной работы: агентная дискретно-событийная модель SIR.
# Сценарии запуска находятся в каталоге scripts.
using ConcurrentSim
using DataFrames
using Distributions
using Random
using ResumableFunctions
using StableRNGs
using Statistics

export SIRPerson
export SIRModel
export MakeSIRModel
export activate!
export compare_recovery_modes
export out
export run_sir
export sensitivity_scan
export sir_run!
export solve_deterministic_sir
export summary_metrics

# Один агент хранит только идентификатор и текущее состояние:
# :S — восприимчивый, :I — инфицированный, :R — выздоровевший.
mutable struct SIRPerson
    id::Int64
    status::Symbol
end

# Модель объединяет календарь событий, параметры эпидемии, агентов,
# генератор случайных чисел и временные ряды S(t), I(t), R(t).
mutable struct SIRModel{R<:AbstractRNG}
    sim::ConcurrentSim.Simulation
    beta::Float64
    contacts::Float64
    gamma::Float64
    deterministic_recovery::Bool
    ta::Vector{Float64}
    Sa::Vector{Int64}
    Ia::Vector{Int64}
    Ra::Vector{Int64}
    all_individuals::Vector{SIRPerson}
    rng::R
    processes::Vector{Any}
    activated::Bool
    horizon::Float64
end

# При каждом изменении состояния добавляется новая точка временного ряда.
increment!(values::Vector{Int64}) = push!(values, values[end] + 1)
decrement!(values::Vector{Int64}) = push!(values, values[end] - 1)
carryover!(values::Vector{Int64}) = push!(values, values[end])

# Ошибочные параметры лучше отклонить до регистрации процессов агентов.
function validate_inputs(u0, parameters)
    length(u0) == 3 || throw(ArgumentError("u0 must contain S0, I0 and R0"))
    length(parameters) == 3 || throw(ArgumentError("parameters must contain beta, contacts and gamma"))

    S, I, R = u0
    beta, contacts, gamma = parameters
    all(value -> value isa Integer && value >= 0, u0) ||
        throw(ArgumentError("initial population counts must be non-negative integers"))
    S + I + R >= 2 || throw(ArgumentError("population must contain at least two individuals"))
    0.0 <= beta <= 1.0 || throw(ArgumentError("beta must belong to [0, 1]"))
    contacts > 0.0 || throw(ArgumentError("contacts must be positive"))
    gamma > 0.0 || throw(ArgumentError("gamma must be positive"))
    return nothing
end

# Событие заражения уменьшает S и увеличивает I.
function infection_update!(sim::ConcurrentSim.Simulation, model::SIRModel)
    push!(model.ta, ConcurrentSim.now(sim))
    decrement!(model.Sa)
    increment!(model.Ia)
    carryover!(model.Ra)
    return nothing
end

# Событие выздоровления уменьшает I и увеличивает R.
function recovery_update!(sim::ConcurrentSim.Simulation, model::SIRModel)
    push!(model.ta, ConcurrentSim.now(sim))
    carryover!(model.Sa)
    decrement!(model.Ia)
    increment!(model.Ra)
    return nothing
end

# Возобновляемая функция описывает жизненный цикл одного агента.
# @yield timeout(...) планирует следующее событие в виртуальном времени.
@resumable function live(
    sim::ConcurrentSim.Simulation,
    individual::SIRPerson,
    model::SIRModel,
)
    while individual.status == :S
        # Интервал между контактами имеет среднее значение 1 / contacts.
        @yield timeout(sim, rand(model.rng, Exponential(1.0 / model.contacts)))

        # Агент выбирает случайный контакт, отличный от самого себя.
        alter = individual
        while alter === individual
            alter = rand(model.rng, model.all_individuals)
        end

        if alter.status == :I && rand(model.rng) < model.beta
            individual.status = :I
            infection_update!(sim, model)
        end
    end

    if individual.status == :I
        # Для дополнительного эксперимента можно заменить случайную
        # длительность болезни фиксированной величиной 1 / gamma.
        recovery_time = model.deterministic_recovery ?
                        1.0 / model.gamma :
                        rand(model.rng, Exponential(1.0 / model.gamma))
        @yield timeout(sim, recovery_time)
        individual.status = :R
        recovery_update!(sim, model)
    end
end

# Конструктор создаёт популяцию, календарь событий и начальную точку рядов.
function MakeSIRModel(
    u0,
    parameters;
    seed::Integer = 1234,
    deterministic_recovery::Bool = false,
)
    validate_inputs(u0, parameters)
    S, I, R = Int64.(u0)
    beta, contacts, gamma = Float64.(parameters)
    population = S + I + R
    sim = ConcurrentSim.Simulation()
    individuals = SIRPerson[]

    for id in 1:S
        push!(individuals, SIRPerson(id, :S))
    end
    for id in (S + 1):(S + I)
        push!(individuals, SIRPerson(id, :I))
    end
    for id in (S + I + 1):population
        push!(individuals, SIRPerson(id, :R))
    end

    return SIRModel(
        sim,
        beta,
        contacts,
        gamma,
        deterministic_recovery,
        Float64[0.0],
        Int64[S],
        Int64[I],
        Int64[R],
        individuals,
        StableRNG(seed),
        Any[],
        false,
        0.0,
    )
end

# Каждый агент регистрируется как отдельный процесс ConcurrentSim.
function activate!(model::SIRModel)
    model.activated && throw(ArgumentError("model has already been activated"))
    for individual in model.all_individuals
        process = @process live(model.sim, individual, model)
        push!(model.processes, process)
    end
    model.activated = true
    return model
end

# Симуляция продвигается от события к событию до момента tf.
function sir_run!(model::SIRModel, tf::Real)
    model.activated || throw(ArgumentError("activate! must be called before sir_run!"))
    tf >= ConcurrentSim.now(model.sim) || throw(ArgumentError("tf cannot be less than the current simulation time"))
    ConcurrentSim.run(model.sim, Float64(tf))
    model.horizon = Float64(tf)
    return model
end

# Результат отдельного прогона представляется таблицей событий.
function out(model::SIRModel)
    return DataFrame(t = model.ta, S = model.Sa, I = model.Ia, R = model.Ra)
end

# Ключевые метрики позволяют сравнивать несколько сценариев одной таблицей.
function summary_metrics(
    model::SIRModel;
    scenario::AbstractString = "scenario",
    parameter::AbstractString = "base",
    value::Real = NaN,
)
    data = out(model)
    peak_infected, peak_index = findmax(data.I)
    population = data.S[1] + data.I[1] + data.R[1]
    return DataFrame(
        scenario = [String(scenario)],
        parameter = [String(parameter)],
        value = [Float64(value)],
        beta = [model.beta],
        contacts = [model.contacts],
        gamma = [model.gamma],
        recovery_mode = [model.deterministic_recovery ? "fixed" : "exponential"],
        peak_infected = [peak_infected],
        peak_time = [data.t[peak_index]],
        final_susceptible = [data.S[end]],
        final_infected = [data.I[end]],
        final_recovered = [data.R[end]],
        affected_share = [(population - data.S[end]) / population],
        events = [nrow(data) - 1],
    )
end

# Удобная обёртка выполняет полный цикл: создание, активацию, запуск и сбор.
function run_sir(
    u0,
    parameters;
    tmax::Real = 40.0,
    seed::Integer = 1234,
    deterministic_recovery::Bool = false,
    scenario::AbstractString = "scenario",
    parameter::AbstractString = "base",
    value::Real = NaN,
)
    model = MakeSIRModel(
        u0,
        parameters;
        seed = seed,
        deterministic_recovery = deterministic_recovery,
    )
    activate!(model)
    sir_run!(model, tmax)
    return (
        model = model,
        data = out(model),
        summary = summary_metrics(model; scenario = scenario, parameter = parameter, value = value),
    )
end

# Параметрический эксперимент меняет ровно один параметр за один проход.
function sensitivity_scan(
    u0,
    base_parameters;
    parameter::Symbol,
    values,
    tmax::Real = 40.0,
    seed::Integer = 1234,
)
    parameter_index = findfirst(==(parameter), (:beta, :contacts, :gamma))
    isnothing(parameter_index) && throw(ArgumentError("parameter must be :beta, :contacts or :gamma"))
    trajectories = NamedTuple[]
    summaries = DataFrame()

    for (index, value) in enumerate(values)
        parameters = Float64.(base_parameters)
        parameters[parameter_index] = Float64(value)
        result = run_sir(
            u0,
            parameters;
            tmax = tmax,
            seed = seed + index - 1,
            scenario = "sensitivity",
            parameter = String(parameter),
            value = value,
        )
        push!(trajectories, (value = Float64(value), data = result.data))
        append!(summaries, result.summary)
    end

    return (trajectories = trajectories, summary = summaries)
end

# Дополнительное задание: сравнение случайной и фиксированной болезни.
function compare_recovery_modes(
    u0,
    parameters;
    tmax::Real = 40.0,
    seed::Integer = 1234,
)
    exponential = run_sir(
        u0,
        parameters;
        tmax = tmax,
        seed = seed,
        scenario = "recovery_mode",
    )
    fixed = run_sir(
        u0,
        parameters;
        tmax = tmax,
        seed = seed,
        deterministic_recovery = true,
        scenario = "recovery_mode",
    )
    return (exponential = exponential, fixed = fixed)
end

# Правая часть детерминированной системы ОДУ SIR нужна для сравнения с DES.
function sir_rhs(state::NTuple{3, Float64}, beta::Float64, contacts::Float64, gamma::Float64)
    S, I, R = state
    population = S + I + R
    infections = beta * contacts * S * I / population
    return (-infections, infections - gamma * I, gamma * I)
end

# Один шаг классического метода Рунге-Кутты четвёртого порядка.
function rk4_step(state::NTuple{3, Float64}, dt::Float64, beta::Float64, contacts::Float64, gamma::Float64)
    k1 = sir_rhs(state, beta, contacts, gamma)
    k2 = sir_rhs(ntuple(i -> state[i] + dt * k1[i] / 2.0, 3), beta, contacts, gamma)
    k3 = sir_rhs(ntuple(i -> state[i] + dt * k2[i] / 2.0, 3), beta, contacts, gamma)
    k4 = sir_rhs(ntuple(i -> state[i] + dt * k3[i], 3), beta, contacts, gamma)
    return ntuple(i -> state[i] + dt * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]) / 6.0, 3)
end

# Формируется гладкая опорная траектория детерминированной SIR-модели.
function solve_deterministic_sir(u0, parameters; tmax::Real = 40.0, dt::Real = 0.05)
    validate_inputs(u0, parameters)
    beta, contacts, gamma = Float64.(parameters)
    step = Float64(dt)
    step > 0.0 || throw(ArgumentError("dt must be positive"))
    times = collect(0.0:step:Float64(tmax))
    times[end] < tmax && push!(times, Float64(tmax))
    states = Vector{NTuple{3, Float64}}(undef, length(times))
    states[1] = Tuple(Float64.(u0))

    for index in 2:length(times)
        local_dt = times[index] - times[index - 1]
        states[index] = rk4_step(states[index - 1], local_dt, beta, contacts, gamma)
    end

    return DataFrame(
        t = times,
        S = first.(states),
        I = getindex.(states, 2),
        R = last.(states),
    )
end

end
