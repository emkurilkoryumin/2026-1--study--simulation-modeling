# project

Лабораторная работа 4 по курсу "Имитационное моделирование".

В этом варианте проекта оставлена только агентная реализация модели болезни
`SIR` и её параметрическое исследование.

## Структура

- `src/sir_agents_model.jl` - исходная агентная модель `SIR`.
- `scripts/01_sir_agents.jl` - базовый сценарий.
- `scripts/02_sir_agents_param.jl` - дополнительное задание с набором параметров.
- `scripts/generate_all.jl` - генерация чистого кода, `qmd` и `ipynb`.
- `markdown/` - Quarto-файлы, сгенерированные из literate-кода.
- `notebooks/` - Jupyter notebook.
- `plots/` - графики.
- `data/` - сводные таблицы и текстовые итоги.

## Быстрый запуск

```bash
cd labs/lab04/project
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/generate_all.jl
julia --project=. scripts/01_sir_agents.jl
julia --project=. scripts/02_sir_agents_param.jl
```

## Выполнение notebook

```bash
python3 -m nbconvert --to notebook --execute --inplace notebooks/01_sir_agents.ipynb --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=julia-1.10
python3 -m nbconvert --to notebook --execute --inplace notebooks/02_sir_agents_param.ipynb --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=julia-1.10
```

