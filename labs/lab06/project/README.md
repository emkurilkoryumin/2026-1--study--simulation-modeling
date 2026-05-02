# project

Лабораторная работа 6 по курсу "Имитационное моделирование".

В проекте реализована модель SIR в подходе сетей Петри. Базовый сценарий
сравнивает детерминированную и стохастическую динамику эпидемии, а отдельный
сценарий исследует чувствительность модели к изменению коэффициента заражения
`β`.

## Структура

- `src/SIRPetri.jl` - вычислительная модель и вспомогательная визуализация.
- `scripts/sirpetri_run.jl` - базовый literate-сценарий.
- `scripts/sirpetri_scan_parameters.jl` - исследование для набора параметров.
- `scripts/sirpetri_animate.jl` - построение GIF-анимации.
- `scripts/sirpetri_report.jl` - итоговые сравнительные графики.
- `scripts/generate_all.jl` - генерация чистого кода, `qmd` и `ipynb`.
- `markdown/` - Quarto-файлы, полученные из literate-скриптов.
- `notebooks/` - Jupyter notebook.
- `plots/` - графики и анимации.
- `data/` - CSV-файлы и сводные таблицы.

## Быстрый запуск

```bash
cd labs/lab06/project
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/generate_all.jl
julia --project=. scripts/sirpetri_run.jl
julia --project=. scripts/sirpetri_scan_parameters.jl
julia --project=. scripts/sirpetri_animate.jl
julia --project=. scripts/sirpetri_report.jl
```

## Выполнение notebook

```bash
python3 -m nbconvert --to notebook --execute --inplace notebooks/sirpetri_run.ipynb --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=julia-1.10
python3 -m nbconvert --to notebook --execute --inplace notebooks/sirpetri_scan_parameters.ipynb --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=julia-1.10
```

## Сборка отчёта

```bash
cd ../report
quarto render
```
