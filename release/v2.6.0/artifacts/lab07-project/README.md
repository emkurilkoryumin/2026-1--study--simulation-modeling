# Lab 07 Project

Проект лабораторной работы №7 по дисциплине "Имитационное моделирование".

Содержимое проекта:

- `src/DiscreteEventLab07Core.jl` — модуль с реализацией моделей `M/M/c` и Росса;
- `scripts/01_discrete_event_models.jl` — базовые сценарии;
- `scripts/02_discrete_event_models_param.jl` — параметрические эксперименты;
- `scripts/generate_all.jl` — генерация `clean`, `qmd` и `ipynb`;
- `test/runtests.jl` — короткие проверки модели.

Основные команды:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/01_discrete_event_models.jl
julia --project=. scripts/02_discrete_event_models_param.jl
julia --project=. scripts/generate_all.jl
julia --project=. test/runtests.jl
```
