"""Plot runtime-exported pressure data; run after enemy_adaptation_test.tscn."""
from pathlib import Path
import csv
import json
import math

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager, ticker

ROOT = Path(__file__).resolve().parent
DATA = json.loads((ROOT / "runtime_curves.json").read_text(encoding="utf-8"))
FONT = Path("C:/Windows/Fonts/msyh.ttc")
font_manager.fontManager.addfont(str(FONT))
plt.rcParams.update({
    "font.family": font_manager.FontProperties(fname=str(FONT)).get_name(),
    "font.size": 11, "axes.unicode_minus": False,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.edgecolor": "#d2d9e1", "axes.labelcolor": "#334155",
    "text.color": "#172b42", "xtick.color": "#526477", "ytick.color": "#526477",
    "savefig.facecolor": "#f5f7fb", "figure.facecolor": "#f5f7fb",
})

rows = DATA["erosion"]
xs = [row["erosion"] for row in rows]
assert xs == list(range(201))
for row in rows:
    e = row["erosion"]
    assert math.isclose(row["max_hp_multiplier"], 1 + .018*e + .018*max(e-30, 0) + .018*max(e-60, 0))
    assert math.isclose(row["damage_multiplier"], 1 + .009*e + .003*max(e-30, 0) + .003*max(e-60, 0))

fig = plt.figure(figsize=(14, 10), dpi=150)
grid = fig.add_gridspec(2, 2, height_ratios=[1, .84], hspace=.55, wspace=.22)
fig.suptitle("侵蚀与秒怪强化：正式数值", x=.075, y=.98, ha="left", fontsize=23, weight="bold")
fig.text(.075, .915, "侵蚀提高生命与伤害；秒怪适应只额外提高生命。所有加成在波次开始时锁定。", fontsize=11, color="#526477")
new_color, old_color = "#d85e35", "#72839c"
for col, key, title, old_slope, limit in [
    (0, "max_hp_multiplier", "怪物生命倍率", .018, 11),
    (1, "damage_multiplier", "怪物伤害倍率", .009, 4.05),
]:
    ax = fig.add_subplot(grid[0, col])
    ax.set_facecolor("white")
    ax.plot(xs, [1+old_slope*e for e in xs], "--", color=old_color, lw=2, label="修改前")
    ax.plot(xs, [row[key] for row in rows], color=new_color, lw=2.8, label="修改后")
    for threshold in [30, 60]:
        ax.axvline(threshold, color="#ccd4df", lw=1, ls=":")
        ax.text(threshold+2, limit*.93, str(threshold), fontsize=9, color="#72839c")
    for erosion in [100, 200]:
        value = rows[erosion][key]
        ax.scatter([erosion], [value], color=new_color, s=27, zorder=4)
        ax.annotate(f"×{value:.2f}", (erosion, value), xytext=(-8, 9), textcoords="offset points",
                    ha="right", color=new_color, fontsize=11, weight="bold")
    ax.set_title(title, loc="left", fontsize=15, pad=14, weight="bold")
    ax.set(xlim=(0, 212), ylim=(1, limit), xlabel="侵蚀度", ylabel="相对零侵蚀的倍率")
    ax.yaxis.set_major_formatter(ticker.StrMethodFormatter("×{x:g}"))
    ax.grid(axis="y", color="#e9edf3", lw=.8)
    ax.legend(loc="upper left", frameon=False, bbox_to_anchor=(0, .84))

ax = fig.add_subplot(grid[1, :])
ax.set_facecolor("white")
adaptive = DATA["adaptation"]
for kind, label, color in [("normal", "小怪：每次 +10 个百分点，最多 +60%", "#287c93"),
                           ("elite", "小Boss：每次 +5 个百分点，最多 +30%", "#a57731")]:
    ax.plot([r["qualifying_waves"] for r in adaptive], [r[kind] for r in adaptive],
            marker="o", ms=4, lw=2.5, color=color, label=label)
ax.set_title("连续满足秒怪条件时，下波额外生命如何增长", loc="left", fontsize=15, pad=16, weight="bold")
ax.set(xlim=(0, 10), ylim=(0, 70), xlabel="累计达标波数（示意；两类分别判断）", ylabel="额外生命加成")
ax.xaxis.set_major_locator(ticker.MultipleLocator(1))
ax.yaxis.set_major_formatter(ticker.StrMethodFormatter("+{x:g}%"))
ax.grid(axis="y", color="#e9edf3", lw=.8)
ax.legend(loc="upper left", frameon=False, ncol=2, fontsize=10)
fig.subplots_adjust(left=.075, right=.96, top=.84, bottom=.18)
fig.text(.075, .046, "最早第4波生效；秒怪占比≥80%，小怪≥20个样本、小Boss≥1个；观察≥15秒且未明显吃力。\n吃力时回退一档，或连续两波秒怪占比<50%时回退一档。护甲保留原公式，未加入本金压力。",
         fontsize=10, color="#526477", linespacing=1.8)
fig.savefig(ROOT / "pressure_curves.png")
fig.savefig(ROOT / "pressure_curves.svg")
plt.close(fig)

with (ROOT / "erosion_comparison.csv").open("w", encoding="utf-8-sig", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(["erosion", "old_hp_multiplier", "new_hp_multiplier", "old_damage_multiplier", "new_damage_multiplier", "armor_multiplier"])
    for row in rows:
        e = row["erosion"]
        writer.writerow([e, round(1+.018*e, 6), round(row["max_hp_multiplier"], 6),
                         round(1+.009*e, 6), round(row["damage_multiplier"], 6), round(row["armor_multiplier"], 6)])
print("CHART_COMPLETE erosion_rows=201 adaptive_rows=11")
