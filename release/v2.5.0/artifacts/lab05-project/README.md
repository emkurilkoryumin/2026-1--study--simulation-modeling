# project

Лабораторная работа 5 по курсу "Имитационное моделирование".

В этом проекте реализована задача обедающих философов в аппарате сетей Петри.
Основной сценарий сравнивает классическую постановку и модификацию с арбитром,
а сценарий с набором параметров исследует влияние скорости захвата первой
вилки на вероятность взаимной блокировки и среднюю активность системы.

## Структура

- `src/DiningPhilosophers.jl` - модель сети Петри и функции симуляции.
- `scripts/01_dining_philosophers.jl` - базовый literate-сценарий.
- `scripts/02_dining_philosophers_param.jl` - исследование для набора параметров.
- `scripts/dining_philosophers_animation.jl` - построение GIF-анимации.
- `scripts/dining_philosophers_report.jl` - итоговый сравнительный график.
- `scripts/generate_all.jl` - генерация чистого кода, `qmd` и `ipynb`.
- `markdown/` - Quarto-файлы, полученные из literate-скриптов.
- `notebooks/` - Jupyter notebook.
- `plots/` - графики и анимации.
- `data/` - CSV-файлы, сводные таблицы и текстовые итоги.

## Быстрый запуск

```bash
cd labs/lab05/project
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/generate_all.jl
julia --project=. scripts/01_dining_philosophers.jl
julia --project=. scripts/02_dining_philosophers_param.jl
julia --project=. scripts/dining_philosophers_animation.jl
julia --project=. scripts/dining_philosophers_report.jl
```

## Выполнение notebook

```bash
python3 -m nbconvert --to notebook --execute --inplace notebooks/01_dining_philosophers.ipynb --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=julia-1.10
python3 -m nbconvert --to notebook --execute --inplace notebooks/02_dining_philosophers_param.ipynb --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=julia-1.10
```
