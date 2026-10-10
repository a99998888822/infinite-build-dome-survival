import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
specs = json.loads((HERE / "confirmed_values.json").read_text(encoding="utf-8"))
records = {r["id"]: r for r in json.loads((ROOT / "data_config/relics.json").read_text(encoding="utf-8"))}
tiers = {"common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗"}
lines = ["# 攻击遗物最终确认与实装（2026-10-10）", "",
         "按用户最终列表替换25件正式遗物，以下是实际生效值。重复编号视为不同遗物条目。完整属性列表覆盖原固定效果，未继续列出的旧减益已删除；稀有度、持有上限、图标及其他遗物保持原配置。", "",
         "| 遗物 | 品阶 | 当前正式效果 |", "| --- | --- | --- |"]
for rid in specs:
    r = records[rid]
    lines.append(f"| {r['display_name']} | {tiers[r['rarity']]} | {r['description']} |")
lines += ["", "说明：", "",
          "- 范围对应原有伤害范围属性；金币获取与通用伤害仍为百分比属性；攻速为属性点，沿用现有攻速公式。",
          "- 负重铁皮护腕删除移速-5；粗糙研磨透镜删除暴击伤害+10；血肉肩甲删除回血-0.1、侵蚀+2、理智-2；屏障结晶删除侵蚀+5；受难甲壳删除移速-15；苦痛祭皿删除最大生命-1、理智-3。",
          "- 余震沙漏按此前建议：元素+6替换通用伤害+12%，保留初始范围+20及每完成一波范围+2。",
          "- 黄金测距仪固定远程+5不依赖本金；每满100本金通用伤害+1%，上限10%；本金距离规则仍为每满100本金+3，上限30。取款只撤销相应的本金加成。",
          "- 同步了中英文内容目录、生成的本地化资源与遗物清单。", "", "## 验证", ""]
summaries = []
for name in ["confirmed", "range", "consistency", "player_stats", "balance"]:
    data = (HERE / (name + ".log")).read_text(encoding="utf-8-sig")
    matches = re.findall(r'^.*_COMPLETE.*checks=(\d+) failures=(\d+).*$', data, re.M)
    assert len(matches) == 1 and int(matches[0][1]) == 0, name
    summaries.append(int(matches[0][0]))
lines.append(f"25件实际获取、重复叠加、移除旧效果、属性预览，以及范围、存取本金、波初护盾、回血和金币小数累计等相关测试合计{sum(summaries)}项通过。")
lines += ["", "Godot无界面编辑器检查无脚本解析/编译错误。本地化构建0错误。", "",
          "额外生命成长旧套件有53/63项失败，主要仍假定初始5生命等旧配置。已在独立无界面进程内还原修改前遗物，并运行原版测试；失败条目与当前版本完全一致，确认不是本轮引入。未改变角色、敌人或复活规则来满足这些旧断言。", "",
          "原始日志与逐项确认数据位于 `artifacts/validation/confirmed_relic_balance_20261010/`。", ""]
(ROOT / "docs/main/checklist/confirmed_attack_relic_balance_2026-10-10.md").write_text("\n".join(lines), encoding="utf-8")
old_fails = [s for s in (HERE / "baseline_health.log").read_text(encoding="utf-8-sig").splitlines() if s.startswith("FAIL ")]
new_fails = [s for s in (HERE / "health.log").read_text(encoding="utf-8-sig").splitlines() if s.startswith("FAIL ")]
assert old_fails == new_fails and len(old_fails) == 53
print("RELATED_CHECKS", sum(summaries), "BASELINE_FAILURES_IDENTICAL", len(old_fails))
