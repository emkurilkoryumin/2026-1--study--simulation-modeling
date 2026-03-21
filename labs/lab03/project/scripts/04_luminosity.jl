# # Полная динамика Daisyworld (сценарий ramp)
# 
# **Цель:** Исследовать реакцию системы на циклическое изменение светимости.

using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
include(srcdir("daisyworld.jl"))

# Функции для агрегации
black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]

# Функция для средней температуры
global_temperature(model) = mean(model.temperature)

# Данные для сбора
mdata = [global_temperature, :solar_luminosity]

println("Запускаем симуляцию со сценарием ramp...")
model = daisyworld(; scenario=:ramp, solar_change=0.005)
agent_df, model_df = run!(model, 1000; adata, mdata)

# Переименовываем столбцы для удобства
if "global_temperature" in names(model_df)
    rename!(model_df, "global_temperature" => "temperature")
end

# Трёхпанельный график
p1 = plot(agent_df.time, [agent_df.count_black agent_df.count_white],
    label=["Чёрные" "Белые"],
    xlabel="", ylabel="Численность",
    color=[:black :orange], linewidth=2, legend=:topright)

p2 = plot(model_df.time, model_df.temperature,
    label="Температура", color=:red, linewidth=2,
    xlabel="", ylabel="Температура, °C")

p3 = plot(model_df.time, model_df.solar_luminosity,
    label="Светимость", color=:blue, linewidth=2,
    xlabel="Время (шаги)", ylabel="Светимость")

p = plot(p1, p2, p3, layout=(3,1), size=(800, 900), 
    title=["Численность маргариток" "Температура" "Солнечная светимость"])

savefig(plotsdir("daisyworld_luminosity.png"))
println("✅ График сохранён: plots/daisyworld_luminosity.png")
