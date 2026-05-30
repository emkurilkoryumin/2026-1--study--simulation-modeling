# Генератор производных материалов из литературных Julia-сценариев.
# Запускается после 01_sir_des.jl и 02_sir_des_param.jl.

using DrWatson
@quickactivate "project"

using Literate

mkpath("scripts/clean")
mkpath("markdown")
mkpath("notebooks")

# Эти два файла содержат код и пояснения. Из каждого формируются:
# чистый Julia-скрипт, документ Quarto и Jupyter notebook.
scripts_list = [
    "01_sir_des",
    "02_sir_des_param",
]

for script in scripts_list
    input_file = joinpath("scripts", "$script.jl")
    println("Генерация производных форматов для $script")
    # Чистый код без литературных комментариев.
    Literate.script(input_file, "scripts/clean"; credit = false)
    # Документация Quarto с текстом и блоками Julia.
    Literate.markdown(input_file, "markdown"; flavor = Literate.QuartoFlavor(), credit = false)
    # Notebook создаётся без выполнения: исполнение выполняется отдельно.
    Literate.notebook(input_file, "notebooks"; credit = false, execute = false)
end

println("Генерация literate-материалов завершена.")
