using DrWatson
@quickactivate "project"
using Literate

mkpath("scripts/clean")
mkpath("markdown")
mkpath("notebooks")

scripts_list = [
    "01_daisyworld_visualization",
    "02_animate",
    "03_count",
    "04_luminosity",
    "05_param_heatmaps",
    "06_param_count",
    "07_param_luminosity"
]

for script in scripts_list
    input_file = joinpath("scripts", "$script.jl")
    
    if isfile(input_file)
        println("Обработка: $script")
        
        Literate.script(input_file, "scripts/clean"; credit=false)
        Literate.markdown(input_file, "markdown"; 
            flavor=Literate.QuartoFlavor(), credit=false)
        Literate.notebook(input_file, "notebooks"; 
            credit=false, execute=false)
        
        println("  ✓ $script — готово")
    else
        println("  ✗ $script — файл не найден")
    end
end

println("\n✅ Все производные форматы успешно сгенерированы!")
