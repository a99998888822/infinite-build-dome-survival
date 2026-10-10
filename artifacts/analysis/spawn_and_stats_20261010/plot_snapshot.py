"""Plot the production scheduler export; run from any working directory."""
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator

ROOT = Path(__file__).resolve().parent
data = json.loads((ROOT / "spawn_baseline.json").read_text(encoding="utf-8"))
rows = data["rows"]
font = FontProperties(fname="C:/Windows/Fonts/msyh.ttc")
plt.rcParams.update({"font.family": font.get_name(), "axes.unicode_minus": False,
    "font.size": 11, "axes.spines.top": False, "axes.spines.right": False,
    "axes.labelcolor": "#3b4b59", "text.color": "#233443", "xtick.color": "#52616c",
    "ytick.color": "#52616c", "axes.edgecolor": "#cbd2d8", "savefig.facecolor": "#f5f7fa"})
colors = {"1": "#227d9b", "2": "#bc8430", "3": "#b34e66"}
fig, axs = plt.subplots(2, 2, figsize=(15, 10), facecolor="#f5f7fa")
fig.subplots_adjust(left=.07, right=.96, bottom=.11, top=.85, hspace=.38, wspace=.20)
fig.text(.07, .955, "当前刷怪曲线 · 第 1–20 波", fontsize=24, weight="bold")
fig.text(.07, .915, "侵蚀度 0 · 怪物数量增幅 0% · 无交易/挑战 · 不触发同屏上限", fontsize=12, color="#52616c")
fig.legend(handles=[Line2D([0],[0], color=colors[t], lw=3, label=f"难度 {t}") for t in colors],
           loc="upper right", bbox_to_anchor=(.96,.975), frameon=False, ncol=3)
titles = ["① 每组刷新间隔", "② 每组每次刷新数量", "③ 持续供给速度", "④ 整波累计刷出数量"]
ylabels = ["秒 / 批（越低越频繁）", "只 / 批", "只 / 秒（理论值）", "只 / 波（60 Hz 调度采样）"]
for ax, title, ylabel in zip(axs.flat, titles, ylabels):
    ax.set_facecolor("white")
    ax.set_title(title, loc="left", fontsize=15, pad=13, weight="bold")
    ax.set_xlabel("波次")
    ax.set_ylabel(ylabel)
    ax.set_xlim(.6,20.6)
    ax.set_xticks([1,5,10,15,20])
    ax.grid(axis="y", color="#e3e8ed", linewidth=.8)
    ax.set_axisbelow(True)
for tier, color in colors.items():
    rr = [r for r in rows if r["difficulty"] == tier]
    x = [r["wave"] for r in rr]
    for g, style in [(0,"-"),(1,"--")]:
        axs[0,0].plot(x,[r["groups"][g]["interval_ms"]/1000 for r in rr], style, color=color, lw=2)
        axs[0,1].plot(x,[r["groups"][g]["count"] for r in rr], style, color=color, lw=2, marker="o", ms=3)
    axs[1,0].plot(x,[r["rate"] for r in rr], color=color, lw=2.5, marker="o", ms=3)
    axs[1,1].plot(x,[r["spawned"] for r in rr], color=color, lw=2.5, marker="o", ms=3)
    for ax,key,fmt in [(axs[1,0],"rate",".2f"),(axs[1,1],"spawned","d")]:
        ax.annotate(format(rr[-1][key],fmt), (20,rr[-1][key]), xytext=(-5,9), textcoords="offset points",
                    color=color, ha="right", fontsize=11, weight="bold")
group_handles = [Line2D([0],[0],color="#52616c",lw=2,linestyle=s,label=f"刷怪组 {g}") for g,s in [(1,"-"),(2,"--")]]
for ax in axs[0]: ax.legend(handles=group_handles, frameon=False, fontsize=10, loc="upper left")
axs[0,0].set_ylim(.8,2.6)
axs[0,1].set_ylim(0,9)
axs[0,1].yaxis.set_major_locator(MaxNLocator(integer=True))
axs[1,0].set_ylim(0,11.5)
axs[1,1].set_ylim(0,660)
fig.text(.07,.052,"数量包含替换生成的精英；精英并非额外叠加。每波约 2 秒后开刷，两组错开 0.6 秒。",fontsize=10,color="#52616c")
fig.text(.07,.027,"第 1 波 30 秒，每波 +5 秒，第 7 波起 60 秒。同屏上限：难度 1 / 2 / 3 = 48 / 72 / 96；满员时跳过超额数量。",fontsize=10,color="#52616c")
fig.savefig(ROOT / "spawn_curves.png",dpi=150)
fig.savefig(ROOT / "spawn_curves.svg")

fields = ["difficulty","wave","duration_seconds","group1_count","group1_interval_ms","group2_count","group2_interval_ms","batch_frequency_hz","enemy_supply_per_second","total_spawned","normal_spawned","elite_spawned","elite_expected","population_cap","plus20_no_cap_total"]
with (ROOT / "spawn_table.csv").open("w",encoding="utf-8-sig",newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    for r in rows:
        writer.writerow(dict(zip(fields,[r["difficulty"],r["wave"],r["duration_seconds"],r["groups"][0]["count"],r["groups"][0]["interval_ms"],r["groups"][1]["count"],r["groups"][1]["interval_ms"],sum(1000/g["interval_ms"] for g in r["groups"]),r["rate"],r["spawned"],r["normal_spawned"],r["elite_spawned"],r["elite_expected"],r["cap"],r["spawned"]*120//100])))
print("Created spawn_curves.png, spawn_curves.svg and spawn_table.csv")
