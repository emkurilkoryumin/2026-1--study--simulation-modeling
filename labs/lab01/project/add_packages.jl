#!/usr/bin/env julia
# add_packages.jl
using Pkg

# Активируем текущий проект
Pkg.activate(".")

# Список пакетов для установки
packages = [
    "DrWatson",
    "DataFrames",
    "Plots",
    "StatsBase",
    "CSV",
    "JLD2"
]

# Устанавливаем пакеты
for pkg in packages
    println("Устанавливаю $pkg...")
    Pkg.add(pkg)
end

println("✅ Все пакеты установлены!")
Pkg.status()
