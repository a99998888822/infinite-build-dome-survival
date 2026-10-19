"""Build review tables only from completed, error-free private-desktop runs."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "artifacts/reports"
WEAPONS = {row["id"]: row["display_name"] for row in json.loads(
    (ROOT / "data_config/weapons.json").read_text(encoding="utf-8"))}
SPELLS = {
    "baseline": "无附魔基线", "fire": "火焰", "water": "水", "ice": "冰",
    "lightning": "闪电链", "electric_spark": "电火花", "wind": "风",
    "light_sword": "光剑", "black_hole": "黑洞", "explosion": "冲击波（纯控制）",
    "fire_chain": "火焰＋闪电链", "fire_spark": "火焰＋电火花",
    "reflection": "水＋冰＋光", "holy": "火焰＋光", "dark": "火焰＋黑洞",
    "freeze": "水＋冰", "steam": "火焰＋水",
}


def load_run(stem):
    log = (REPORTS / f"{stem}.log").read_text(encoding="utf-8")
    if any(marker in log for marker in ("SCRIPT ERROR", "ERROR:", "Parse Error", "Compile Error")):
        raise RuntimeError(f"Refusing invalid run: {stem}")
    proof = json.loads((REPORTS / f"{stem}.json").read_text(encoding="utf-8"))
    if proof["exit_code"] or proof["foreground_samples"] or proof["private_desktop"] != proof["verified_desktop"]:
        raise RuntimeError(f"Invalid desktop/exit proof: {stem}")
    data = json.loads((REPORTS / f"{stem}_metrics.json").read_text(encoding="utf-8"))
    if data["failures"]:
        raise RuntimeError(f"Failed workload: {stem}: {data['failures']}")
    return data["rows"]


def table(rows, label):
    lines = ["| 用例 | 实际秒数 | 前段最大 ms | 后段平均 ms | 后段 P95 ms | 后段最大 ms | 伤害事件数 | 停顿触发数 |",
             "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for row in rows:
        first = row["first_window"].get("frame_ms", {}).get("max", 0)
        steady = row["steady"]["frame_ms"]
        elapsed = row["samples"][-1]["time"]
        lines.append(f"| {label(row)} | {elapsed:.2f} | {first:.1f} | {steady['mean']:.1f} | {steady['p95']:.1f} | {steady['max']:.1f} | {row['hits']:,} | {len(row['feedback'])} |")
    return "\n".join(lines)


def main():
    sections = ["# 主战斗性能测量明细", "数值单位为毫秒。60 FPS 对应约 16.67 ms；30 FPS 对应约 33.33 ms。最大值包含偶发峰值，不单独用来给技能排序。前段/后段长度见各测量配置。所有用例保留高生命值目标，因此伤害事件数不是击杀数。"]
    specs = [
        ("dense_cost_subsystems_fixed", "子系统：前 3 秒 / 后 5 秒，两轮", lambda r: f"{r['id']}（第 {r['repeat'] + 1} 轮）"),
        ("dense_cost_weapons", "单武器：前 2 秒 / 后 10 秒", lambda r: WEAPONS[r["config"]["weapon"]]),
        ("dense_cost_enchantments", "附魔隔离：前 3 秒 / 后 5 秒", lambda r: SPELLS[r["id"]]),
        ("dense_cost_builds", "合法槽位组合：前 2 秒 / 后 10 秒", lambda r: f"{WEAPONS[r['config']['weapon']]} Lv.{r['weapon_level']}：" + "＋".join(SPELLS.get(s, s) for s in r["config"].get("attach", []))),
        ("dense_cost_ritual", "法阵定位：前 2 秒 / 后 10 秒", lambda r: r["id"]),
        ("dense_cost_ablations", "火焰＋电火花对照：前 3 秒 / 后 5 秒", lambda r: r["id"]),
        ("dense_cost_reflection", "反射实例定位：前 2 秒 / 后 10 秒", lambda r: r["id"]),
    ]
    total = 0
    for stem, title, label in specs:
        rows = load_run(stem)
        total += len(rows)
        sections.extend([f"## {title}", table(rows, label), f"原始数据：[{stem}_metrics.json]({stem}_metrics.json)"])
        if stem == "dense_cost_reflection":
            sections.append("注意：隐藏反射视觉的诊断轮发生了实例数和伤害事件数分化，且长帧使计时超出目标；该轮不用于等负载收益比较，也不据此声称隐藏画面会更慢。极端最大帧尚未完整归因。")
    sections.append(f"共 {total} 次无报错测量（含诊断变体）；每个运行日志与独立桌面记录均通过校验。导入失败轮次和早期未固定玩家的探索数据不列入以上表格。")
    target = REPORTS / "dense_combat_cost_tables.md"
    target.write_text("\n\n".join(sections) + "\n", encoding="utf-8")
    print(f"DENSE_COST_TABLES rows={total} output={target}")


if __name__ == "__main__":
    main()
