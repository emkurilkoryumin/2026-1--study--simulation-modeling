using DrWatson
@quickactivate "project"
using Literate

mkpath("scripts/clean")
mkpath("markdown")
mkpath("notebooks")

scripts_list = [
    "sirpetri_run",
    "sirpetri_scan_parameters",
]

for script in scripts_list
    input_file = joinpath("scripts", "$script.jl")
    if !isfile(input_file)
        println("Файл не найден: $input_file")
        continue
    end

    println("Генерация производных форматов для $script")
    Literate.script(input_file, "scripts/clean"; credit = false)
    Literate.markdown(input_file, "markdown"; flavor = Literate.QuartoFlavor(), credit = false)
    Literate.notebook(input_file, "notebooks"; credit = false, execute = false)
end

println("Генерация literate-материалов завершена.")
