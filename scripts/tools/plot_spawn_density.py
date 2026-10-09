"""Plot before/after production scheduler exports from spawn_density_test.tscn."""
import argparse
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager, ticker

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=ROOT / "artifacts/reviews/spawn_density_20261009")
    args = parser.parse_args()
    directory = args.directory
    before = json.loads((directory / "before.json").read_text(encoding="utf-8"))
    after = json.loads((directory / "after.json").read_text(encoding="utf-8"))
    old = {(r["difficulty"], r["wave"]): r for r in before["rows"]}
    new = {(r["difficulty"], r["wave"]): r for r in after["rows"]}
    assert len(old) == len(new) == 60 and old.keys() == new.keys()
    comparisons = []
    for key, row in new.items():
        prior = old[key]
        ratio = row["normal_spawned"] / prior["normal_spawned"]
        if row["wave"] <= 5:
            assert ratio >= 2, (key, ratio)
        if row["wave"] == 20:
            assert 1.15 <= ratio <= 1.25, (key, ratio)
            assert abs(row["rate"] / prior["rate"] - 1.2) < 1e-5
        if row["wave"] >= 2:
            assert row["elite_spawned"] >= 1 and 0 < row["first_elite_seconds"] < row["duration_seconds"] / 2
        if row["wave"] > 1:
            assert row["rate"] > new[(key[0], key[1] - 1)]["rate"]
        comparisons.append({"difficulty": key[0], "wave": key[1],
                            "normal_before": prior["normal_spawned"], "normal_after": row["normal_spawned"],
                            "normal_ratio": round(ratio, 4), "rate_before": round(prior["rate"], 4),
                            "rate_after": round(row["rate"], 4), "elite_expected_before": prior["elite_expected"],
                            "elite_expected_after": row["elite_expected"], "elite_actual_after": row["elite_spawned"],
                            "cap_after": row["cap"]})

    font = Path("C:/Windows/Fonts/msyh.ttc")
    font_manager.fontManager.addfont(str(font))
    plt.rcParams.update({"font.family": font_manager.FontProperties(fname=str(font)).get_name(),
                         "font.size": 11, "axes.unicode_minus": False,
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.edgecolor": "#d7dedb", "text.color": "#243c36",
                         "axes.labelcolor": "#526860", "xtick.color": "#526860", "ytick.color": "#526860",
                         "figure.facecolor": "#f6f7f2", "savefig.facecolor": "#f6f7f2"})
    fig, axes = plt.subplots(2, 2, figsize=(16, 11), dpi=160)
    fig.subplots_adjust(left=.07, right=.97, top=.84, bottom=.14, hspace=.42, wspace=.24)
    fig.text(.07, .962, "刷怪调整：前期至少翻倍，后期约增加 20%", fontsize=24, weight="bold")
    fig.text(.07, .914, "小怪曲线来自 60 Hz 正式刷怪调度器的整波采样；零侵蚀、无营地数量加成、未接受挑战。",
             fontsize=12, color="#526860")
    xs = list(range(1, 21))
    old_color, new_color = "#9ba5af", "#24775b"
    names = {"1": "标准难度", "2": "难度 2 · 属性加强 20%", "3": "难度 3 · 属性加强 30%"}
    for tier, ax in zip(["1", "2", "3"], axes.flat):
        ys_old = [old[(tier, wave)]["normal_spawned"] for wave in xs]
        ys_new = [new[(tier, wave)]["normal_spawned"] for wave in xs]
        ax.set_facecolor("white")
        ax.axvspan(.8, 5.2, color="#eaf3df", zorder=0)
        ax.plot(xs, ys_old, "--", lw=2, color=old_color, label="调整前")
        ax.plot(xs, ys_new, "-o", lw=2.5, ms=3.5, color=new_color, label="调整后")
        ax.set_title(names[tier], loc="left", pad=13, fontsize=15, weight="bold")
        ax.set(xlim=(.7, 21.7), ylim=(0, max(ys_new)*1.15), xlabel="波次", ylabel="整波累计生成小怪（只）")
        for wave in [1, 5, 20]:
            i = wave - 1
            ax.annotate(f"{ys_old[i]} → {ys_new[i]}", (wave, ys_new[i]), xytext=(2, 11),
                        textcoords="offset points", ha="right" if wave == 20 else "left",
                        color=new_color, fontsize=10, weight="bold")
        ax.legend(loc="upper left", frameon=False, ncol=2, fontsize=10)
        ax.xaxis.set_major_locator(ticker.FixedLocator([1, 5, 10, 15, 20]))
        ax.grid(axis="y", color="#e9ece8", lw=.8)

    ax = axes[1, 1]
    ax.set_facecolor("white")
    colors = {"1": "#24775b", "2": "#bc8a32", "3": "#8b62a0"}
    for tier in ["1", "2", "3"]:
        # Old tier 2 is identical to old tier 1; avoid two overlapping lines.
        if tier != "2":
            ax.plot(xs, [old[(tier, wave)]["elite_expected"] for wave in xs], "--",
                    lw=1.5, color=colors[tier], alpha=.45, label=f"原难度 {'1 / 2' if tier == '1' else '3'}")
        ax.plot(xs, [new[(tier, wave)]["elite_expected"] for wave in xs], lw=2.3,
                color=colors[tier], label=f"现难度 {tier}")
    ax.axvspan(2, 5, color="#eaf3df", zorder=0)
    ax.set_title("小 Boss · 第 2 波起每波至少 1 只", loc="left", pad=13, fontsize=15, weight="bold")
    ax.set(xlim=(.7, 20.5), ylim=(0, 3.4), xlabel="波次", ylabel="每波期望数量（只）")
    ax.xaxis.set_major_locator(ticker.FixedLocator([1, 2, 5, 10, 15, 20]))
    ax.yaxis.set_major_locator(ticker.MultipleLocator(1))
    ax.grid(axis="y", color="#e9ece8", lw=.8)
    ax.legend(loc="upper left", frameon=False, ncol=3, fontsize=9)

    fig.text(.07, .058, "小怪统计已剔除被小 Boss 替换的名额；采样时逐帧移除敌人以排除击杀速度和数量上限的影响。\n"
             "实际同场上限：48 / 72 / 96。小 Boss 图为期望值（例如 1.25 表示 1 只，另有 25% 概率多 1 只）；常规最多 3 只。",
             fontsize=10, color="#526860", linespacing=1.8)
    fig.savefig(directory / "spawn_density_curves.png")
    fig.savefig(directory / "spawn_density_curves.svg")
    plt.close(fig)
    with (directory / "comparison.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(comparisons[0]))
        writer.writeheader()
        writer.writerows(comparisons)
    print(json.dumps({"comparison_rows": len(comparisons), "acceptance_checks": "passed",
                      "standard_anchors": [r for r in comparisons if r["difficulty"] == "1" and r["wave"] in [1, 5, 10, 15, 20]]}, ensure_ascii=True))


if __name__ == "__main__":
    main()
