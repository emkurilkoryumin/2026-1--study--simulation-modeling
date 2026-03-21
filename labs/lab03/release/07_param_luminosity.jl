# # Параметрическое исследование: полная динамика (сценарий ramp)
# 
# **Цель:** Исследовать влияние параметров на реакцию системы на изменение светимости.

using DrWatson
@quickactivate "project"
using Agents
using Plots
include(srcdir("daisyworld.jl"))

# Функции для агрегации
black(a) = a.breed == :black
white(a) = a.breed == :white

init_white_vals = [0.2, 0.8]
max_age_vals = [25, 40]

function run_simulation(init_white, max_age)
    println("  Запуск симуляции...")
    
    model = daisyworld(; init_white, max_age, scenario=:ramp, solar_change=0.005)
    
    # Массивы для данных
    times = Int[]
    black_counts = Int[]
    white_counts = Int[]
    temperatures = Float64[]
    luminosities = Float64[]
    
    # Начальное состояние
    push!(times, 0)
    push!(black_counts, count(a -> a.breed == :black, allagents(model)))
    push!(white_counts, count(a -> a.breed == :white, allagents(model)))
    push!(temperatures, mean(model.temperature))
    push!(luminosities, model.solar_luminosity)
    
    # Запускаем 1000 шагов
    for step in 1:1000
        Agents.step!(model, 1)
        
        if step % 100 == 0
            println("    Шаг $step...")
        end
        
        push!(times, step)
        push!(black_counts, count(a -> a.breed == :black, allagents(model)))
        push!(white_counts, count(a -> a.breed == :white, allagents(model)))
        push!(temperatures, mean(model.temperature))
        push!(luminosities, model.solar_luminosity)
    end
    
    return times, black_counts, white_counts, temperatures, luminosities
end

for init_white in init_white_vals
    for max_age in max_age_vals
        println("\nИсследование: init_white=$init_white, max_age=$max_age")
        
        times, black_counts, white_counts, temperatures, luminosities = run_simulation(init_white, max_age)
        
        # Трёхпанельный график
        p1 = plot(times, [black_counts white_counts],
            label=["Чёрные" "Белые"],
            xlabel="", ylabel="Численность",
            color=[:black :orange], linewidth=2, legend=:topright,
            title="init_white=$init_white, max_age=$max_age")
        
        p2 = plot(times, temperatures,
            label="Температура", color=:red, linewidth=2,
            xlabel="", ylabel="Температура, °C")
        
        p3 = plot(times, luminosities,
            label="Светимость", color=:blue, linewidth=2,
            xlabel="Время (шаги)", ylabel="Светимость")
        
        p = plot(p1, p2, p3, layout=(3,1), size=(800, 900))
        
        fname = "daisy_luminosity_iw$(init_white)_ma$(max_age).png"
        savefig(plotsdir(fname))
        println("  ✅ Сохранён: $fname")
        println("     Маргариток в конце: ", black_counts[end] + white_counts[end])
    end
end

println("\n✅ Параметрическое исследование (полная динамика) завершено!")
