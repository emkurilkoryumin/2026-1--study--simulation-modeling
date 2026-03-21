# Лабораторная работа №3: Агентное моделирование. Модель Daisyworld

## Описание
Реализация классической модели Daisyworld (Мир маргариток) на языке Julia с использованием фреймворка Agents.jl. Модель демонстрирует механизм биологической саморегуляции планетарной температуры.

## Содержимое релиза

### Исходный код модели
- `daisyworld.jl` — основная реализация модели
- `01_daisyworld_visualization.jl` — визуализация тепловых карт
- `02_animate.jl` — анимация динамики
- `03_count.jl` — динамика численности
- `04_luminosity.jl` — сценарий изменения светимости (ramp)
- `05_param_heatmaps.jl` — параметрическое исследование (тепловые карты)
- `06_param_count.jl` — параметрическое исследование (численность)
- `07_param_luminosity.jl` — параметрическое исследование (полная динамика)

### Результаты визуализации
- `daisyworld_step000.png` — начальное состояние (шаг 0)
- `daisyworld_step005.png` — формирование кластеров (шаг 5)
- `daisyworld_step040.png` — динамическое равновесие (шаг 40)
- `daisyworld_count.png` — график динамики численности
- `daisyworld_luminosity.png` — трёхпанельный график (ramp)
- `daisyworld_animation.gif` — анимация эволюции
- Файлы параметрического исследования: `daisyworld_iw*_ma*_step*.png`, `daisy_count_iw*_ma*.png`, `daisy_luminosity_iw*_ma*.png`

### Презентация
- `mathmod-lab03-presentation.html` — HTML-презентация (revealjs)
- `mathmod-lab03-presentation.pdf` — PDF-презентация

### Отчёт
- `report-lab03.qmd` — исходный файл отчёта
- `report-lab03.pdf` — PDF-отчёт

### Производные форматы
- Jupyter notebooks (`.ipynb`)
- Markdown документация (`.qmd`)
- Чистые скрипты (`.jl`)

### Архивы
- `lab03-files.zip` — архив с кодом и графиками
- `lab03-full.zip` — полный архив (все файлы)
- `lab03-full.tar.gz` — TAR.GZ архив

## Запуск
```bash
cd project
julia --project=. scripts/01_daisyworld_visualization.jl
