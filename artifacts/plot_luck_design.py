# -*- coding: utf-8 -*-
"""Plot how `luck` affects relic / new weapon / weapon upgrade probabilities.

Replicates the exact formulas from scripts/ui/shop_offer_generator.gd.
Run:  python artifacts/plot_luck_design.py
Output: artifacts/luck_design.png
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

OUT = Path(__file__).resolve().parent / "luck_design.png"


def pick_cjk_font() -> None:
    candidates = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "WenQuanYi Zen Hei", "PingFang SC"]
    available = {f.name for f in fm.fontManager.ttflist}
    for name in candidates:
        if name in available:
            plt.rcParams["font.family"] = name
            return
    plt.rcParams["font.family"] = "sans-serif"


def threshold_ramp(luck: float, start: float, duration: float, power: float) -> float:
    if luck <= start:
        return 0.0
    if duration <= 0.0 or luck >= start + duration:
        return 1.0
    return ((max(0.0, luck - start)) / duration) ** max(power, 0.01)


def rarity_weights(luck: int, zone_bonus: int = 0) -> dict:
    """Mirror of ShopOfferGenerator.get_shop_rarity_weights (weights sum to 10000)."""
    safe = float(max(0, luck))
    uncommon = 17.0 - 2.0 * threshold_ramp(safe, 0.0, 240.0, 1.0)
    rare = 5.0 + 25.0 * threshold_ramp(safe, 0.0, 240.0, 0.8)
    epic = 25.0 * threshold_ramp(safe, 40.0, 260.0, 1.15)
    mythic = 15.0 * threshold_ramp(safe, 150.0, 220.0, 1.4)
    legendary = 5.0 * threshold_ramp(safe, 350.0, 180.0, 2.1)
    uncommon_w = round(uncommon * 100.0)
    rare_w = round(rare * 100.0)
    epic_w = round(epic * 100.0)
    mythic_w = round(mythic * 100.0)
    legendary_w = round(legendary * 100.0)
    common_w = max(0, 10000 - uncommon_w - rare_w - epic_w - mythic_w - legendary_w)
    weights = {
        "common": common_w,
        "uncommon": uncommon_w,
        "rare": rare_w,
        "epic": epic_w,
        "mythic": mythic_w,
        "legendary": legendary_w,
    }
    promotion_budget = min(common_w, max(0, zone_bonus) * 100)
    if promotion_budget <= 0:
        return weights
    promotable = [r for r in ["rare", "epic", "mythic", "legendary"] if weights[r] > 0]
    total = sum(weights[r] for r in promotable)
    if total <= 0:
        return weights
    weights["common"] -= promotion_budget
    distributed = 0
    for i, rarity in enumerate(promotable):
        if i == len(promotable) - 1:
            budget = promotion_budget - distributed
        else:
            budget = int(promotion_budget * weights[rarity] / total)
        weights[rarity] += budget
        distributed += budget
    return weights


RARITIES = ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
LABELS = {
    "common": "普通",
    "uncommon": "精良",
    "rare": "稀有",
    "epic": "史诗",
    "mythic": "神话",
    "legendary": "传说",
}
COLORS = {
    "common": "#9aa5ad",
    "uncommon": "#4aa35a",
    "rare": "#4aa3c8",
    "epic": "#a05ac8",
    "mythic": "#e07b39",
    "legendary": "#e0b53a",
}

luck_values = list(range(0, 601))
series = {r: [] for r in RARITIES}
for lv in luck_values:
    w = rarity_weights(lv)
    for r in RARITIES:
        series[r].append(w[r] / 100.0)

pick_cjk_font()
plt.rcParams["axes.unicode_minus"] = False

fig = plt.figure(figsize=(17.0, 8.4), dpi=150)

# ---------------- Left panel: rarity probability vs luck ----------------
ax = fig.add_axes([0.06, 0.11, 0.50, 0.78])
for r in RARITIES:
    ax.plot(luck_values, series[r], color=COLORS[r], lw=2.4, label="%s (%s)" % (LABELS[r], r))

for gate, label in [(40, "幸运≥40：史诗解锁"), (150, "≥150：神话解锁"), (350, "≥350：传说解锁")]:
    ax.axvline(gate, color="#666666", ls="--", lw=1.1, alpha=0.9)
    ax.text(gate + 3, 96.5, label, fontsize=8.5, color="#444444", rotation=90, va="top")

ax.set_xlim(0, 600)
ax.set_ylim(0, 100)
ax.set_xlabel("幸运 luck", fontsize=12)
ax.set_ylabel("该档位当选概率（%）", fontsize=12)
ax.set_title(
    "幸运 → 奖励/商店抽取中每个稀有度档位的概率\n（get_shop_rarity_weights，六档权重合计恒为 10000）",
    fontsize=12.5,
)
ax.grid(alpha=0.25, lw=0.6)
ax.legend(loc="center right", fontsize=9.5, framealpha=0.95, title="稀有度", title_fontsize=10.5)

ax.annotate(
    "幸运 ≥ 530 后曲线饱和：\n普通10% 精良15% 稀有30%\n史诗25% 神话15% 传说5%",
    xy=(530, 15),
    xytext=(285, 7),
    fontsize=9.5,
    color="#333333",
    bbox=dict(boxstyle="round,pad=0.35", fc="#fdf6e3", ec="#cccccc", lw=0.8),
    arrowprops=dict(arrowstyle="->", color="#888888", lw=1.0),
)

# ---------------- Right panel: mechanism diagram ----------------
ax2 = fig.add_axes([0.60, 0.11, 0.38, 0.78])
ax2.set_xlim(0, 100)
ax2.set_ylim(0, 100)
ax2.axis("off")


def box(x, y, w, h, text, fc, ec, fs=8.8, bold=False):
    b = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0.6,rounding_size=1.4",
        linewidth=1.2,
        facecolor=fc,
        edgecolor=ec,
    )
    ax2.add_patch(b)
    ax2.text(
        x + w / 2,
        y + h / 2,
        text,
        ha="center",
        va="center",
        fontsize=fs,
        color="#1a1a1a",
        weight="bold" if bold else "normal",
        linespacing=1.5,
    )


def arrow(x1, y1, x2, y2):
    ax2.add_patch(
        FancyArrowPatch(
            (x1, y1),
            (x2, y2),
            arrowstyle="-|>",
            mutation_scale=14,
            lw=1.4,
            color="#555555",
        )
    )


box(20, 91, 60, 7, "幸运 luck（玩家属性，最小值 0，可被遗物/营地叠加）", "#e8d9f5", "#8a5bb5", fs=9.5, bold=True)

box(4, 70, 46, 12, "① 稀有度硬门槛\nRARITY_LUCK_REQUIREMENTS\n史诗≥40 · 神话≥150 · 传说≥350", "#d7ecf7", "#3f7fa8", fs=8.5)
box(3, 43, 25, 17, "武器升级：未达门槛 →\n候选直接被剔除\n（build_shop_candidate_pool\n过滤，不出现在候选池）", "#eef7ef", "#4a9053", fs=8.0)
box(30, 43, 25, 17, "遗物 / 新武器：未达门槛 →\n该稀有度权重=0，抽取时\n被滤掉（等效门槛）", "#fdf3e7", "#c07a3a", fs=8.0)

box(55, 70, 42, 12, "② 稀有度权重曲线（三类共用）\nget_shop_rarity_weights(luck)\n抽取顺序：类型 → 稀有度 → 具体条目", "#f2e6d0", "#b08a2e", fs=8.5)
box(55, 43, 42, 17, "· 遗物、新武器、武器升级共用\n  同一组六档稀有度权重\n· 区域加成 zone_rarity_bonus\n  再从普通档按比例提升到\n  稀有+档（不影响总额）", "#fbf3d9", "#c9a34a", fs=8.0)

arrow(30, 91, 27, 83.5)
arrow(76, 91, 76, 83.5)
arrow(27, 70, 16, 61.5)
arrow(41, 70, 44, 61.5)
arrow(76, 70, 76, 61.5)

box(4, 6, 93, 24, "不受 luck 影响的部分\n"
                   "· 类型权重：遗物 60 / 新武器 25 / 武器升级 8（连续未刷出 +2，上限 20）\n"
                   "· 新武器权重随剩余负载空间打折（≥50% / 30% / 15% 三档，下限 1）\n"
                   "· 敌人掉落的遗物/血包/技能：只按 drop_rate_percent 加成概率",
     "#eceff3", "#888888", fs=8.0)

ax2.text(
    50,
    97.2,
    "注：8-ui_flow_design.md 中的旧公式与当前实现不同，以 shop_offer_generator.gd 为准",
    ha="center",
    va="center",
    fontsize=7.8,
    color="#8a5bb5",
)

fig.savefig(OUT, dpi=150, bbox_inches="tight")

# ---------------- console sanity table ----------------
print("luck | " + " | ".join("%-9s" % r for r in RARITIES))
for lv in [0, 20, 39, 40, 41, 150, 155, 350, 360, 400, 530]:
    w = rarity_weights(lv)
    row = " | ".join("%7.2f%%" % (w[r] / 100.0) for r in RARITIES)
    print("%4d | %s" % (lv, row))
print("saved:", OUT)
