"""Build review figures from the current engine's erosion and spawn snapshot."""
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
import numpy as np

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
data = json.loads((HERE / "engine_snapshot.json").read_text(encoding="utf-8"))
rows = data["curves"]
e = np.array([r["erosion"] for r in rows])
hp = np.array([r["max_hp_multiplier"] for r in rows])
damage = np.array([r["damage_multiplier"] for r in rows])
armor = np.array([r["armor_multiplier"] for r in rows])
count = np.array([r["spawn_count_multiplier"] for r in rows])
assert np.allclose(hp, 1 + .018 * e + .018 * np.maximum(e-30, 0) + .018 * np.maximum(e-60, 0))
assert np.allclose(damage, 1 + .009 * e + .003 * np.maximum(e-30, 0) + .003 * np.maximum(e-60, 0))
assert np.allclose(armor, 1 + .0135 * e)
assert np.allclose(count, 1 + e/100)

font = FontProperties(fname="C:/Windows/Fonts/msyh.ttc")
plt.rcParams.update({"font.family": font.get_name(), "axes.unicode_minus": False,
    "font.size": 11, "axes.spines.top": False, "axes.spines.right": False,
    "axes.labelcolor": "#46545f", "text.color": "#253744", "xtick.color": "#52616c",
    "ytick.color": "#52616c", "axes.edgecolor": "#cbd2d8", "savefig.facecolor": "#f5f7fa"})
fig, axes = plt.subplots(2, 2, figsize=(15, 10.5), facecolor="#f5f7fa")
fig.subplots_adjust(left=.07, right=.955, bottom=.13, top=.84, hspace=.39, wspace=.20)
fig.text(.07, .949, "侵蚀度如何改变怪物", fontsize=25, weight="bold")
fig.text(.07, .908, "当前工作区 · 侵蚀度 0–200 · 倍率相对同波次、同难度、侵蚀度 0", fontsize=12, color="#52616c")
fig.text(.955, .949, "100 侵蚀\n数量 ×2　生命 ×4.78", ha="right", va="top", fontsize=14, color="#227d9b", weight="bold")
titles = ["① 单体属性倍率", "② 常规刷怪供给倍率", "③ 精英配额：标准难度", "④ 数量 × 单体生命的叠加效果"]
for ax,title in zip(axes.flat,titles):
    ax.set_facecolor("white")
    ax.set_title(title, loc="left", fontsize=15, pad=14, weight="bold")
    ax.set_xlim(0,205)
    ax.set_xticks([0,30,60,100,150,200])
    ax.set_xlabel("侵蚀度")
    ax.grid(axis="y",color="#e3e8ed",linewidth=.8)
    ax.set_axisbelow(True)
for ax in [axes[0,0],axes[1,1]]:
    for point in [30,60]: ax.axvline(point, color="#b8c3ca", ls=":", lw=1)
axes[0,0].plot(e,hp,color="#227d9b",lw=2.7,label="生命")
axes[0,0].plot(e,damage,color="#b85268",lw=2.2,label="伤害")
axes[0,0].plot(e,armor,color="#bc8430",lw=2.2,ls="--",label="护甲数值")
axes[0,0].set_ylabel("倍率（×）")
axes[0,0].set_ylim(0,11.4)
axes[0,0].legend(loc="upper left",frameon=False,ncol=3,fontsize=10)
axes[0,0].annotate("生命 10.18×",(200,hp[-1]),xytext=(-3,10),textcoords="offset points",ha="right",color="#227d9b",weight="bold")
axes[0,0].annotate("100 侵蚀\n生命 4.78×\n伤害 2.23×\n护甲 2.35×",(100,hp[100]),xytext=(12,28),textcoords="offset points",fontsize=10,
                   bbox={"boxstyle":"round,pad=.5","fc":"#eff4f7","ec":"none"},arrowprops={"arrowstyle":"-","color":"#9cadb7"})
axes[0,1].plot(e,count,color="#a36c25",lw=2.7,label="每批数量 / 持续供给")
axes[0,1].plot(e,np.ones_like(e),color="#84949d",ls="--",lw=1.8,label="刷新间隔（不变）")
axes[0,1].set_ylim(.5,3.55)
axes[0,1].set_ylabel("倍率（×）")
axes[0,1].legend(loc="upper left",frameon=False,fontsize=10)
for point in [100,200]:
    axes[0,1].scatter(point,count[point],color="#a36c25",s=25)
    axes[0,1].annotate(f"{count[point]:.0f}×",(point,count[point]),xytext=(-5,10),textcoords="offset points",ha="right",color="#a36c25",weight="bold")
for wave,col,ls,label in [(2,"#227d9b","-","第 2–8 波"),(10,"#719658","-","第 10 波"),(15,"#bc8430","--","第 15 波"),(20,"#b85268",":","第 20 波")]:
    y=[r["elite_expected"][f"tier1_wave{wave}"] for r in rows]
    axes[1,0].plot(e,y,color=col,lw=2.5,ls=ls,label=label)
axes[1,0].set_ylim(.8,3.3)
axes[1,0].set_ylabel("期望精英数（只 / 波）")
axes[1,0].axvline(100,color="#b8c3ca",ls=":",lw=1)
axes[1,0].legend(loc="lower right",frameon=False,fontsize=10)
axes[1,0].text(6,3.1,"常规精英上限 3 只；第 1 波为 0",fontsize=10,color="#52616c")
axes[1,1].plot(e,count*hp,color="#875c91",lw=2.7)
axes[1,1].set_ylim(0,36)
axes[1,1].set_ylabel("理论生命供给倍率（×）")
for point in [60,100,200]:
    y=count[point]*hp[point]
    axes[1,1].scatter(point,y,color="#875c91",s=25)
    axes[1,1].annotate(f"{y:.2f}×",(point,y),xytext=(-3,10),textcoords="offset points",ha="right",color="#875c91",weight="bold")
axes[1,1].text(.04,.91,"估算：刷出数量 × 单体生命\n不含护甲、精英构成、取整及同屏上限",transform=axes[1,1].transAxes,va="top",fontsize=10,color="#52616c")
fig.text(.07,.074,"侵蚀度在波初读取；负值按 0。生命、伤害、护甲和数量的倍率继续增长；精英的侵蚀加成到 100 点停止增长。",fontsize=10,color="#52616c")
fig.text(.07,.048,"数量与“怪物数量增幅”叠乘，按小数余量累计。同屏上限仍为难度 1 / 2 / 3：48 / 72 / 96；超额整只跳过。",fontsize=10,color="#52616c")
fig.text(.07,.022,"数据：Godot 生产公式的 201 个侵蚀采样点 + 72 组实际生成属性快照。图示倍率不含难度、波次及自适应的额外加成。",fontsize=10,color="#52616c")
fig.savefig(HERE/"erosion_curves.png",dpi=150)
fig.savefig(HERE/"erosion_curves.svg")

with (HERE/"erosion_multipliers.csv").open("w",encoding="utf-8-sig",newline="") as f:
    writer=csv.DictWriter(f,fieldnames=["erosion","spawn_count_multiplier","max_hp_multiplier","damage_multiplier","armor_multiplier","raw_hp_supply_multiplier",*rows[0]["elite_expected"]])
    writer.writeheader()
    for r in rows:
        out={k:v for k,v in r.items() if k!="elite_expected"}
        out["raw_hp_supply_multiplier"]=r["spawn_count_multiplier"]*r["max_hp_multiplier"]
        writer.writerow(out|r["elite_expected"])
with (HERE/"actual_enemy_stats.csv").open("w",encoding="utf-8-sig",newline="") as f:
    flat=[]
    for r in data["samples"]:
        for enemy in r["enemies"]:
            flat.append({k:r[k] for k in ["difficulty","wave","erosion","elite_expected","supply_per_second","population_cap"]}|enemy)
    writer=csv.DictWriter(f,fieldnames=list(flat[0]))
    writer.writeheader()
    writer.writerows(flat)

def number(value):
    return f"{value:.3f}".rstrip("0").rstrip(".")

def link(path):
    return (PROJECT/path).as_posix()

text=["# 侵蚀度数值审阅（2026-10-10）", "",
      "数据来自当前工作区生产公式，已在 Godot 无窗口运行中导出。曲线包含 0–200 每整数点，共 201 点；实际怪物属性覆盖 3 难度 × 3 波次 × 8 个侵蚀值，共 72 组、288 个怪物快照。本次只生成审阅产物，未修改玩法。", "",
      f"![侵蚀度曲线]({(HERE/'erosion_curves.png').as_posix()})", "",
      "## 数值倍率", "", "表中倍率相对于同一难度、同一波次、侵蚀度为 0 的配置计算值，不包含属性整数取整的偏差。", "",
      "| 侵蚀度 | 常规刷怪供给 | 单体生命 | 伤害属性 | 护甲数值 | 数量 × 生命（估算） |",
      "|---:|---:|---:|---:|---:|---:|"]
for p in [0,10,30,50,60,100,150,200]:
    r=rows[p]
    text.append(f"| {p} | {number(count[p])}× | {number(hp[p])}× | {number(damage[p])}× | {number(armor[p])}× | {number(count[p]*hp[p])}× |")
text += ["", "100 侵蚀时，生命是 4.78 倍，即 +378%；数量是 2 倍，即 +100%。两者叠乘约为 9.56 倍的生命供给。200 侵蚀时约 30.54 倍。最后一列不含护甲、精英替换构成、取整及同屏上限，并不是实际难度或击杀耗时的严格倍率。", "",
    "## 当前公式", "", "设 E = max(侵蚀度, 0)：", "", "```text",
    "数量倍率 = 1 + E / 100",
    "生命倍率 = 1 + 0.018E + 0.018max(E−30, 0) + 0.018max(E−60, 0)",
    "伤害倍率 = 1 + 0.009E + 0.003max(E−30, 0) + 0.003max(E−60, 0)",
    "护甲倍率 = 1 + 0.0135E", "```", "",
    "生命与伤害是连续的分段线性增长，30、60 点之后增长斜率变大：", "",
    "| 侵蚀区间 | 每增加 1 点，对基础生命的增加量 | 每增加 1 点，对基础伤害的增加量 |",
    "|---|---:|---:|", "| 0–30 | 1.8% | 0.9% |", "| 30–60 | 3.6% | 1.2% |", "| 60 以上 | 5.4% | 1.5% |", "",
    "不是每一点对上一点继续复利。数量和护甲倍率不分段，每点分别增加基础值的 1% 和 1.35%。这些侵蚀倍率本身不封顶，但最终属性仍经过各属性已有的合法范围和整数处理。", "",
    "## 精英配额", "", "第 1 波恒为 0。第 2 波起：", "", "```text",
    "期望精英数量 = min(3, max(1, 波次 / 8) × (1 + clamp(E / 100, 0, 1)) × 难度精英倍率)", "```", "",
    "难度 1、2、3 的精英倍率分别为 1、1.15、1.3。侵蚀在 100 点时提供最多 +100% 的精英配额加成；单波常规精英仍最多 3 只，额外挑战精英和债务目标单独处理。", "",
    "| 侵蚀度 | 难度1 第10波 | 难度1 第20波 | 难度2 第10波 | 难度2 第20波 | 难度3 第10波 | 难度3 第20波 |",
    "|---:|---:|---:|---:|---:|---:|---:|"]
for p in [0,30,60,100,200]:
    vals=[number(rows[p]["elite_expected"][f"tier{t}_wave{w}"]) for t in [1,2,3] for w in [10,20]]
    text.append(f"| {p} | " + " | ".join(vals) + " |")
text += ["", "期望值在波初抽成相邻整数：2.5 表示 50% 为 2 只、50% 为 3 只。标准难度第 20 波在侵蚀 20 时就已达到 3 只上限。标准难度第 10 波在侵蚀 100 时达到 2.5，再增加侵蚀也不继续提高该波精英配额。", "",
    "精英在前半波替换常规生成槽位，不直接叠加到普通批次总数之外；实际刷出也受可用槽位和时间窗口影响。钢甲骑士与幽焰冥狼共用这份配额，当前类型选择各占 50%。", "",
    "## 实际怪物示例", "", "标准难度第 10 波，无营地/交易/挑战/自适应加成。以下为引擎实际生成天外幼体后的整数属性：", "",
    "| 侵蚀度 | 生命 | 近战伤害属性 | 护甲 | 实际受到伤害百分比 | 移速 |",
    "|---:|---:|---:|---:|---:|---:|"]
for r in data["samples"]:
    if r["difficulty"]=="1" and r["wave"]==10:
        enemy=r["enemies"][0]
        text.append(f"| {r['erosion']} | {int(enemy['max_hp'])} | {int(enemy['melee_damage'])} | {int(enemy['armor'])} | {int(enemy['damage_taken_percent'])}% | {int(enemy['move_speed'])} |")
text += ["", "伤害列是怪物的攻击属性，最终扣除玩家的生命仍取决于技能倍率、护盾和玩家减伤。由于最终取整，不能直接把已取整的面板数字乘倍率来复现下一格。护甲倍率乘的是护甲数值，并非直接乘减伤百分比；若基础及波次加成后的护甲为 0，乘算后仍为 0。", "",
    "同一示例的两组刷新间隔始终约 1.321 秒和 1.953 秒。0 侵蚀每批 3/2 只，100 侵蚀每批 6/4 只，200 侵蚀每批 9/6 只；理论持续供给分别约 3.30、6.59、9.89 只/秒。", "",
    "## 生效与限制", "",
    "- 每波开始时读取侵蚀，波初遗物的侵蚀变化会计入；波中变化在下一波重新快照。",
    "- 数量倍率与玩家“怪物数量增幅”叠乘。例如侵蚀 100、数量增幅 +20%，总供给倍率为 2 × 1.2 = 2.4。",
    "- 小数按万分之一单位跨批、跨刷怪组累计；新波/新局清零。",
    "- 同屏上限仍为难度 1/2/3 的 48/72/96；满员时超额整数丢弃，不积欠。所以上述数量倍率是可供给量，不保证实战总数同倍率增长。",
    "- 侵蚀不会直接改变怪物移速、技能冷却、控制抗性、刷新间隔、同屏上限或单怪掉落表。",
    "- 难度、波次、快速击杀适应和挑战修改器仍会另行影响最终怪物属性。", "",
    "## 代码与数据", "",
    f"- [侵蚀公式]({link('scripts/waves/enemy_wave_pressure.gd')}:19)",
    f"- [增长配置]({link('data_config/erosion_pressure_rules.json')}:3)",
    f"- [刷怪数量与余量]({link('scripts/waves/wave_manager.gd')}:856)",
    f"- [精英配额]({link('scripts/waves/wave_manager.gd')}:790)",
    f"- [201 点倍率与精英配额 CSV]({(HERE/'erosion_multipliers.csv').as_posix()})",
    f"- [288 个实际怪物属性快照 CSV]({(HERE/'actual_enemy_stats.csv').as_posix()})",
    f"- [引擎原始 JSON]({(HERE/'engine_snapshot.json').as_posix()})",
    f"- [可缩放曲线 SVG]({(HERE/'erosion_curves.svg').as_posix()})", ""]
(HERE/"review.md").write_text("\n".join(text),encoding="utf-8")
print("Built erosion curves, detailed review, and CSV tables; all 201 formula points match the engine.")
