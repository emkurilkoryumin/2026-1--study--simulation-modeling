from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
PLOTS = ROOT / "plots"
PLOTS.mkdir(parents=True, exist_ok=True)


def read_csv(path: Path, delimiter: str = ",") -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=delimiter))


def to_float(values: list[dict[str, str]], key: str) -> list[float]:
    return [float(row[key]) for row in values]


def to_int(values: list[dict[str, str]], key: str) -> list[int]:
    return [int(float(row[key])) for row in values]


def render_mmc_base() -> None:
    state = read_csv(DATA / "mmc_state.csv")
    customers = read_csv(DATA / "mmc_customers.csv")
    summary = read_csv(DATA / "mmc_summary.tsv", delimiter="\t")[0]
    warmup = int(float(summary["warmup_customers"]))

    times = to_float(state, "time")
    queue = to_int(state, "queue_length")
    busy = to_int(state, "busy_servers")

    plt.figure(figsize=(10, 5.5))
    plt.step(times, queue, where="post", label="Длина очереди", color="firebrick", linewidth=2)
    plt.step(times, busy, where="post", label="Занятые каналы", color="royalblue", linewidth=2)
    plt.xlabel("Время")
    plt.ylabel("Число заявок")
    plt.title("M/M/c: динамика длины очереди и занятых каналов")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(PLOTS / "mmc_queue_timeline.png", dpi=160)
    plt.close()

    wait_times = [float(row["wait_time"]) for row in customers[warmup:]]
    plt.figure(figsize=(10, 5.5))
    plt.hist(wait_times, bins=30, density=True, color="darkorange", alpha=0.8)
    plt.xlabel("Время ожидания")
    plt.ylabel("Плотность")
    plt.title("M/M/c: распределение времени ожидания")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(PLOTS / "mmc_wait_hist.png", dpi=160)
    plt.close()


def render_mmc_scan() -> None:
    scan = read_csv(DATA / "mmc_scan.tsv", delimiter="\t")
    lambdas = to_float(scan, "arrival_rate")
    mean_wait_sim = to_float(scan, "mean_wait_sim")
    mean_wait_theory = to_float(scan, "mean_wait_theory")
    prob_wait_sim = to_float(scan, "prob_wait_sim")
    prob_wait_theory = to_float(scan, "prob_wait_theory")

    fig, axes = plt.subplots(2, 1, figsize=(10, 10), sharex=True)

    axes[0].plot(lambdas, mean_wait_sim, marker="o", linewidth=2, color="firebrick", label="Имитация")
    axes[0].plot(
        lambdas,
        mean_wait_theory,
        marker="D",
        linewidth=2,
        linestyle="--",
        color="royalblue",
        label="Теория Эрланга C",
    )
    axes[0].set_ylabel("Среднее ожидание")
    axes[0].set_title("M/M/c: среднее время ожидания")
    axes[0].grid(True, alpha=0.3)
    axes[0].legend()

    axes[1].plot(lambdas, prob_wait_sim, marker="o", linewidth=2, color="darkgreen", label="Имитация")
    axes[1].plot(
        lambdas,
        prob_wait_theory,
        marker="D",
        linewidth=2,
        linestyle="--",
        color="purple",
        label="Теория Эрланга C",
    )
    axes[1].set_xlabel("λ")
    axes[1].set_ylabel("Вероятность ожидания")
    axes[1].set_title("M/M/c: вероятность ожидания")
    axes[1].grid(True, alpha=0.3)
    axes[1].legend()

    fig.tight_layout()
    fig.savefig(PLOTS / "mmc_wait_vs_lambda.png", dpi=160)
    plt.close(fig)


def render_ross_base() -> None:
    state = read_csv(DATA / "ross_state.csv")
    times = to_float(state, "time")
    healthy = to_int(state, "healthy")
    busy = to_int(state, "busy_repairers")
    queue = to_int(state, "repair_queue")

    plt.figure(figsize=(10, 5.5))
    plt.step(times, healthy, where="post", linewidth=2, color="royalblue", label="Исправные машины")
    plt.xlabel("Время")
    plt.ylabel("Число машин")
    plt.title("Модель Росса: число исправных машин во времени")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(PLOTS / "ross_healthy_timeline.png", dpi=160)
    plt.close()

    plt.figure(figsize=(10, 5.5))
    plt.step(times, busy, where="post", linewidth=2, color="darkgreen", label="Занятые ремонтники")
    plt.step(times, queue, where="post", linewidth=2, color="firebrick", label="Очередь на ремонт")
    plt.xlabel("Время")
    plt.ylabel("Число ресурсов")
    plt.title("Модель Росса: загрузка ремонтников и очередь")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(PLOTS / "ross_repair_monitor.png", dpi=160)
    plt.close()


def render_ross_scan() -> None:
    scan = read_csv(DATA / "ross_machine_scan.tsv", delimiter="\t")
    repairers = sorted({int(float(row["num_repairers"])) for row in scan})
    colors = ["firebrick", "royalblue", "darkgreen", "darkorange"]

    fig, axes = plt.subplots(3, 1, figsize=(10, 13), sharex=True)

    for index, repairers_count in enumerate(repairers):
        subset = [row for row in scan if int(float(row["num_repairers"])) == repairers_count]
        subset.sort(key=lambda row: int(float(row["N"])))
        machines = [int(float(row["N"])) for row in subset]
        color = colors[index % len(colors)]

        axes[0].plot(
            machines,
            [float(row["crash_time_sim"]) for row in subset],
            marker="o",
            linewidth=2,
            color=color,
            label=f"Имитация, r={repairers_count}",
        )
        axes[0].plot(
            machines,
            [float(row["crash_time_theory"]) for row in subset],
            marker="D",
            linewidth=2,
            linestyle="--",
            color=color,
            label=f"Аналитика, r={repairers_count}",
        )
        axes[1].plot(
            machines,
            [float(row["utilization"]) for row in subset],
            marker="o",
            linewidth=2,
            color=color,
            label=f"r={repairers_count}",
        )
        axes[2].plot(
            machines,
            [float(row["avg_queue_length"]) for row in subset],
            marker="o",
            linewidth=2,
            color=color,
            label=f"r={repairers_count}",
        )

    axes[0].set_ylabel("Среднее время до отказа")
    axes[0].set_title("Модель Росса: имитация и аналитика")
    axes[0].grid(True, alpha=0.3)
    axes[0].legend()

    axes[1].set_ylabel("Средняя загрузка")
    axes[1].set_title("Загрузка ремонтников")
    axes[1].grid(True, alpha=0.3)
    axes[1].legend()

    axes[2].set_xlabel("N")
    axes[2].set_ylabel("Средняя длина очереди")
    axes[2].set_title("Очередь на ремонт")
    axes[2].grid(True, alpha=0.3)
    axes[2].legend()

    fig.tight_layout()
    fig.savefig(PLOTS / "ross_scan.png", dpi=160)
    plt.close(fig)


def main() -> None:
    render_mmc_base()
    render_mmc_scan()
    render_ross_base()
    render_ross_scan()
    print("Plots rendered to", PLOTS)


if __name__ == "__main__":
    main()
