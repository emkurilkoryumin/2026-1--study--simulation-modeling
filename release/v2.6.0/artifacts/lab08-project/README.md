# Лабораторная работа 8

Дискретно-событийная модель распространения инфекции SIR на Julia.

## Файлы с кодом

- `scripts/01_sir_des.jl` — базовый запуск DES-SIR и сравнение с ОДУ.
- `scripts/02_sir_des_param.jl` — анализ чувствительности и фиксированная
  длительность болезни.
- `scripts/03_sir_benchmark.jl` — дополнительная оценка производительности
  для популяции из `10000` индивидов.
- `scripts/generate_all.jl` — генерация чистых `.jl`, notebook и
  документации Quarto.
- `src/SIRDESLab08.jl` — ядро модели с комментариями к основным этапам DES.

Первые два файла оформлены в литературном стиле: строки комментариев
становятся поясняющим текстом при генерации notebook и Quarto-документации.

## Порядок запуска

Команды выполняются из каталога `labs/lab08/project`.

```bash
# Установить зависимости проекта.
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Выполнить основной и параметрический эксперименты.
julia --project=. scripts/01_sir_des.jl
julia --project=. scripts/02_sir_des_param.jl

# Выполнить дополнительное измерение производительности.
julia --project=. scripts/03_sir_benchmark.jl

# Сгенерировать чистый код, notebook и документацию Quarto.
julia --project=. scripts/generate_all.jl

# Проверить корректность модели.
julia --project=. test/runtests.jl
```

Исходные literate-сценарии находятся в `scripts`, сгенерированные материалы
сохраняются в `scripts/clean`, `notebooks` и `markdown`.
