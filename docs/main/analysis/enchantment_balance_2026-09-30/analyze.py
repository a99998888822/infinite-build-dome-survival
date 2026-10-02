"""Read-only balance model. Run from any directory; never edits game data.

Requires scipy and matplotlib. Proposed drop rules are a design experiment,
not production behavior. Probability distributions use exact finite-state DP.
"""
from pathlib import Path
import hashlib
import json
import math

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from scipy.stats import binom

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def read(name):
    return json.loads((ROOT / "data_config" / (name + ".json")).read_text(encoding="utf-8"))


def current_p(base, luck, bonus):
    return min(1.0, max(0, base * (1 + max(0, luck) * .001) * max(0, 1 + bonus / 100)))


def proposed_multiplier(luck, bonus):
    luck = max(0, luck)
    l = 1 + .6 * luck / (luck + 200)
    d = 1 + .4 * bonus / (bonus + 100) if bonus >= 0 else max(.25, 1 + bonus / 100)
    return l * d


def proposed_distribution(kills, luck, bonus, cap=4, elites=0):
    # Ordinary kills followed by elites is an explicit ordering assumption.
    # Elite chance does not decay, but shares the same cap. No pity here.
    state = [1.] + [0.] * cap
    mult = proposed_multiplier(luck, bonus)
    for elite, count in ((False, kills), (True, elites)):
        for _ in range(count):
            nxt = [0.] * (cap + 1)
            for n, mass in enumerate(state):
                p = 0 if n == cap else min(1., (.15 if elite else .008 * .45**n) * mult)
                nxt[n] += mass * (1 - p)
                if n < cap:
                    nxt[n + 1] += mass * p
            state = nxt
    assert abs(sum(state) - 1) < 1e-10
    return state


def summarize(probs):
    cumulative = 0
    q95 = None
    for n, p in enumerate(probs):
        cumulative += p
        if q95 is None and cumulative >= .95:
            q95 = n
    return {"mean": sum(n*p for n, p in enumerate(probs)), "zero": probs[0],
            "p95": q95, "ge5": sum(probs[5:]), "ge10": sum(probs[10:])}


def current_summary(k, luck, bonus):
    p = current_p(.015, luck, bonus)
    return {"mean": k*p, "zero": float(binom.pmf(0, k, p)),
            "p95": int(binom.ppf(.95, k, p)), "ge5": float(binom.sf(4, k, p)),
            "ge10": float(binom.sf(9, k, p))}


def wave_capacity(wave, number, difficulty):
    # 60 Hz, no living-enemy blockage, streak=0, player spawn-rate bonus=0.
    profiles = {1: (.30, 1.35, 240), 2: (.45, 1.20, 360), 3: (.65, 1.05, 480)}
    scale, interval_scale, live_limit = profiles[difficulty]
    groups = wave["spawn_groups"]
    timers = [2.0 + .6 * i for i in range(len(groups))]
    batches = [0] * len(groups)
    dt = 1/60
    for frame in range(1, int(wave["duration_seconds"] * 60)):
        for i, group in enumerate(groups):
            timers[i] -= dt
            if timers[i] <= 1e-10:
                batches[i] += 1
                timers[i] = max(.3, group["spawn_interval_ms"] / 1000 * interval_scale / (1 + .025*(number-1)))
    count = sum(batches[i] * math.ceil(g["count_per_spawn"] * scale * (1 + .06*(number-1))) * 2
                for i, g in enumerate(groups))
    return {"difficulty": difficulty, "wave": number, "spawn_opportunities": count,
            "living_enemy_cap": live_limit, "batches": batches}


def main():
    augmentations = read("augmentations")
    drops = read("drop_tables")
    waves = read("waves")
    by_id = {a["id"]: a for a in augmentations}
    probabilities = []
    for a in augmentations:
        row = {"id": a["id"], "name": a["display_name"], "rarity": a["rarity"]}
        for table in drops:
            entries = [e for e in table["entries"] if e["type"] == "augmentation"]
            same = [e for e in entries if by_id[e["item_id"]]["rarity"] == a["rarity"]]
            weight = sum(e["weight"] for e in same if e["item_id"] == a["id"])
            rarity_weights = table["augmentation_rarity_weights"]
            active = {by_id[e["item_id"]]["rarity"] for e in entries if e["weight"] > 0}
            conditional = rarity_weights[a["rarity"]] / sum(rarity_weights[r] for r in active) * weight / sum(e["weight"] for e in same)
            row[table["id"]] = {"weight": weight, "given_scroll_percent": conditional*100,
                                  "per_kill_percent_luck0_bonus0": conditional*table["augmentation_chance_percent"]}
        probabilities.append(row)
    for table in drops:
        assert abs(sum(row[table["id"]]["given_scroll_percent"] for row in probabilities) - 100) < 1e-10
    scenarios = []
    for k in (30, 40, 100, 150, 300, 600, 1000):
        for luck, bonus in ((0,0), (100,0), (300,0), (1000,0), (9999,0), (300,50), (1000,100), (9999,10000)):
            proposed = summarize(proposed_distribution(k, luck, bonus))
            # Repeated identical eligible waves; one pity reward after two zeros.
            # Stationary fraction of second-zero waves = q^2/(1+q).
            q = proposed["zero"]
            scenarios.append({"kills": k, "luck": luck, "drop_bonus": bonus,
                              "current": current_summary(k, luck, bonus), "proposed_no_pity": proposed,
                              "proposed_mean_with_pity_stationary": proposed["mean"] + q*q/(1+q)})
    capacities = [wave_capacity(waves[n-1], n, d) for d in (1,2,3) for n in (1,5,10,15,20)]
    crit = [{"crit_percent": p, "precision_gain_percent": 100*(1 + min(1,p/100+.25)*.5)/(1+p/100*.5)-100,
             "lethality_gain_percent": 100*(1+p/100*1.5)/(1+p/100*.5)-100} for p in (5,30,50,75,100)]
    inputs = [ROOT/"data_config"/(s+".json") for s in ("augmentations", "drop_tables", "waves", "weapons", "enemies")]
    inputs += [ROOT/"scripts/rewards/drop_reward_system.gd", ROOT/"scripts/waves/wave_manager.gd", ROOT/"scripts/data/battle_difficulty.gd"]
    payload = {"input_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
               "assumptions": {"proposed_base_normal": .008, "proposed_base_elite": .15, "normal_decay": .45,
                               "cap": 4, "pity": "one after two eligible zero-drop waves; >=30 kills each",
                               "spawn_model": "60 Hz, no living-cap blockage, no streak/player bonus; excludes challenge elites"},
               "item_probabilities": probabilities, "scenarios": scenarios, "spawn_opportunities": capacities,
               "critical_examples": crit,
               "proposed_600_normal_2_elites_luck0": summarize(proposed_distribution(600,0,0,elites=2))}
    (OUT/"results.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    font_path = Path("C:/Windows/Fonts/msyh.ttc")
    if font_path.exists():
        font_manager.fontManager.addfont(str(font_path))
        plt.rcParams["font.family"] = font_manager.FontProperties(fname=str(font_path)).get_name()
    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
    fig, axes = plt.subplots(1,2,figsize=(12,4.5),layout="constrained")
    xs = list(range(0,1001,20))
    for luck, color in ((0,"#357c9c"),(300,"#c78332"),(1000,"#a84958")):
        axes[0].plot(xs, [k*current_p(.015,luck,0) for k in xs], color=color, ls="--", alpha=.7)
        axes[0].plot(xs, [summarize(proposed_distribution(k,luck,0))["mean"] for k in xs], color=color, label=f"幸运 {luck}")
    axes[0].set(xlabel="每波普通怪击杀数", ylabel="附魔平均掉落数量",
                title="当前（虚线）与建议（实线）\n掉落加成 0%；建议上限 4 个；不含保底")
    axes[0].legend()
    x = list(range(0,22))
    axes[1].bar([n-.2 for n in x],binom.pmf(x,300,current_p(.015,1000,0)),width=.4,color="#a84958",label="当前")
    pd = proposed_distribution(300,1000,0)
    axes[1].bar([n+.2 for n in range(len(pd))],pd,width=.4,color="#357c9c",label="建议")
    axes[1].set(xlabel="一波掉落的附魔数量",ylabel="概率",title="300 次击杀，幸运 1000，掉落加成 0%\n精确概率分布；不含保底")
    axes[1].legend()
    fig.savefig(OUT/"drop_comparison.png",dpi=170)
    plt.close(fig)
    print("SPAWN", json.dumps(capacities))
    print("SCENARIOS",json.dumps([s for s in scenarios if s["kills"] in (40,100,300,600) and (s["luck"],s["drop_bonus"]) in ((0,0),(300,0),(1000,0),(1000,100))]))
    print("CRIT",json.dumps(crit))
    for row in probabilities:
        print(row["id"],row["rarity"],[(t["id"],round(row[t["id"]]["given_scroll_percent"],4)) for t in drops])


if __name__ == "__main__":
    main()
