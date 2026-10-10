"""Apply the user's confirmed 25 relic definitions, preserving unrelated text."""
import copy
import csv
import io
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SPECS = [
    ("worn_fighting_gloves", {"melee_damage": 2, "armor": -3}, "近战伤害 +2；护甲 -3", "Melee Damage +2; Armor -3"),
    ("cracked_stone_bullet", {"ranged_damage": 2, "pickup_radius": -10}, "远程伤害 +2；拾取范围 -10", "Ranged Damage +2; Pickup Range -10"),
    ("bloodstained_belt", {"melee_damage": 5, "hp_regen": -0.1}, "近战伤害 +5；每秒回血 -0.1", "Melee Damage +5; HP Regen -0.1/s"),
    ("poison_mist_pouch", {"ranged_damage": 4, "hp_regen": -0.1}, "远程伤害 +4；每秒回血 -0.1", "Ranged Damage +4; HP Regen -0.1/s"),
    ("berserker_copper_badge", {"melee_damage": 8, "armor": -8}, "近战伤害 +8；护甲 -8", "Melee Damage +8; Armor -8"),
    ("corroded_blowpipe", {"ranged_damage": 7, "max_hp": -3}, "远程伤害 +7；最大生命 -3", "Ranged Damage +7; Max HP -3"),
    ("executioner_bracer", {"melee_damage": 11, "move_speed": -10}, "近战伤害 +11；移动速度 -10", "Melee Damage +11; Move Speed -10"),
    ("abyssal_echo_shell", {"element_damage": 9, "humanity": -2, "damage_area_size": 12}, "元素伤害 +9；理智值 -2；伤害范围 +12", "Elemental Damage +9; Sanity -2; Damage Area +12"),
    ("load_iron_bracer", {"armor": 6, "melee_damage": 1}, "护甲 +6；近战伤害 +1", "Armor +6; Melee Damage +1"),
    ("rough_grinding_lens", {"ranged_damage": 1, "crit_chance": 3}, "远程伤害 +1；暴击几率 +3 个百分点", "Ranged Damage +1; Crit Chance +3 percentage points"),
    ("blocking_counterweight", {"control_power": 4, "element_damage": 2}, "控制强度 +4；元素伤害 +2", "Control Power +4; Elemental Damage +2"),
    ("turtle_shell_pendant", {"armor": 8, "max_hp": 2, "melee_damage": 2}, "护甲 +8；最大生命 +2；近战伤害 +2", "Armor +8; Max HP +2; Melee Damage +2"),
    ("black_spot_eagle_eye", {"crit_chance": 7, "ranged_damage": 2}, "暴击几率 +7 个百分点；远程伤害 +2", "Crit Chance +7 percentage points; Ranged Damage +2"),
    ("dead_shield_badge", {"shield": 6, "element_damage": 2}, "每波初始护盾 +6；元素伤害 +2", "Starting Shield each wave +6; Elemental Damage +2"),
    ("diffusion_nozzle", {"damage_percent": 8, "damage_area_size": 15, "element_damage": 4, "attack_speed": -6}, "通用伤害 +8%；伤害范围 +15；元素伤害 +4；攻击速度 -6", "Damage Bonus +8%; Damage Area +15; Elemental Damage +4; Attack Speed -6"),
    ("flesh_pauldron", {"max_hp": 4, "armor": 12, "melee_damage": 3}, "最大生命 +4；护甲 +12；近战伤害 +3", "Max HP +4; Armor +12; Melee Damage +3"),
    ("gold_compass", {"pickup_radius": 10, "currency_gain_percent": 8, "ranged_damage": 3}, "拾取范围 +10；金币获取 +8%；远程伤害 +3", "Pickup Range +10; Gold Gain +8%; Ranged Damage +3"),
    ("barrier_crystal", {"shield_regen": 0.3, "element_damage": 3}, "每秒护盾 +0.3；元素伤害 +3", "Shield Regen +0.3/s; Elemental Damage +3"),
    ("aftershock_hourglass", {"damage_area_size": 20, "element_damage": 6}, "伤害范围 +20；元素伤害 +6；获得后每完成一波，伤害范围再 +2", "Damage Area +20; Elemental Damage +6. Each wave completed after acquisition grants another +2 Damage Area."),
    ("suffering_carapace", {"armor": 20, "max_hp": 4, "melee_damage": 5}, "护甲 +20；最大生命 +4；近战伤害 +5", "Armor +20; Max HP +4; Melee Damage +5"),
    ("golden_rangefinder", {"ranged_damage": 5}, "远程伤害 +5；每满100本金，攻击距离 +3（上限30）、通用伤害 +1%（上限10%）", "Ranged Damage +5; every full 100 Principal grants Attack Range +3 (up to +30) and Damage Bonus +1% (up to +10%)."),
    ("pain_vessel", {"hp_regen": 0.5, "element_damage": 4}, "每秒回血 +0.5；元素伤害 +4", "HP Regen +0.5/s; Elemental Damage +4"),
    ("hasty_spring_trigger", {"attack_speed": 5, "move_speed": -2}, "攻击速度 +5；移动速度 -2", "Attack Speed +5; Move Speed -2"),
    ("tremor_grip", {"attack_speed": 10, "damage_percent": -3}, "攻击速度 +10；通用伤害 -3%", "Attack Speed +10; Damage Bonus -3%"),
    ("gale_roulette", {"attack_speed": 18, "damage_percent": -5}, "攻击速度 +18；通用伤害 -5%", "Attack Speed +18; Damage Bonus -5%"),
]
specs = {"relic_" + name: {"stats": stats, "zh": zh, "en": en} for name, stats, zh, en in SPECS}
assert len(specs) == 25
path = ROOT / "data_config/relics.json"
source = path.read_bytes().decode("utf-8")
newline = "\r\n" if "\r\n" in source else "\n"
before = json.loads(source)
by_id = {r["id"]: r for r in before}
assert set(specs) <= set(by_id)
backup = HERE / "before_relics.json"
if not backup.exists():
    backup.write_text(json.dumps([r for r in before if r["id"] in specs], ensure_ascii=False, indent=2), encoding="utf-8")

def replace_field(block, field, value):
    marker = re.search(r'"' + field + r'"\s*:\s*', block)
    assert marker, field
    _, size = json.JSONDecoder().raw_decode(block[marker.end():])
    return block[:marker.end()] + value + block[marker.end()+size:]

changed = {}
def update_record(match):
    block = match.group(0)
    record = json.loads(block)
    relic_id = record["id"]
    if relic_id not in specs: return block
    spec = specs[relic_id]
    effects = []
    for stat, value in spec["stats"].items():
        effects.append({"id": f"mod_{relic_id}_{stat}", "source_type": "relic", "source_id": relic_id,
                        "target_scope": "player", "stat": stat, "operation": "add_flat", "value": value, "duration": -1})
    runtime = copy.deepcopy(record.get("runtime_effects", []))
    if relic_id == "relic_golden_rangefinder":
        assert len(runtime) == 2
        for effect in runtime:
            if effect["stat"] == "damage_percent":
                effect["per_unit"] = 1
                effect["max_bonus"] = 10
    elif relic_id == "relic_aftershock_hourglass":
        assert runtime == [{"trigger": "wave_end", "effect": "add_stat", "stat": "damage_area_size", "value": 2}]
    else:
        assert not runtime, relic_id
    effect_text = "[" + newline + ("," + newline).join("      " + json.dumps(e, ensure_ascii=False) for e in effects) + newline + "    ]"
    block = replace_field(block, "description", json.dumps(spec["zh"], ensure_ascii=False))
    block = replace_field(block, "effects", effect_text)
    if runtime != record.get("runtime_effects", []):
        runtime_text = "[" + newline + ("," + newline).join("      " + json.dumps(e, ensure_ascii=False) for e in runtime) + newline + "    ]"
        block = replace_field(block, "runtime_effects", runtime_text)
    changed[relic_id] = json.loads(block)
    return block

result = re.sub(r'^  \{\r?\n.*?^  \}', update_record, source, flags=re.M | re.S)
assert len(changed) == 25
after = json.loads(result)
for old, new in zip(before, after):
    if old["id"] not in specs:
        assert old == new
    else:
        for key in old:
            if key not in ["description", "effects", "runtime_effects"]: assert old[key] == new[key], (old["id"], key)
path.write_bytes(result.encode("utf-8"))

# Replace just the matching CSV rows; preserve all unrelated rows and line endings.
catalog = ROOT / "localization/catalogs/content.csv"
raw = catalog.read_bytes().decode("utf-8")
lines = raw.splitlines(keepends=True)
found = set()
for i, line in enumerate(lines):
    fields = next(csv.reader([line]))
    for relic_id, spec in specs.items():
        if fields and fields[0] == f"content.relics.{relic_id}.description":
            ending = "\r\n" if line.endswith("\r\n") else "\n"
            stream = io.StringIO(newline="")
            csv.writer(stream, lineterminator=ending).writerow([fields[0], spec["zh"], spec["en"], *fields[3:]])
            lines[i] = stream.getvalue()
            found.add(relic_id)
assert found == set(specs)
catalog.write_bytes("".join(lines).encode("utf-8"))

# Synchronize the existing inventory rows by name; do not rewrite other entries.
inventory = ROOT / "augmentations_list.md"
lines = inventory.read_bytes().decode("utf-8").splitlines(keepends=True)
updated = set()
for i, line in enumerate(lines):
    cells = line.split("|")
    if len(cells) < 6: continue
    for relic_id, record in changed.items():
        if cells[1].strip() == record["display_name"]:
            cells[4] = " " + record["description"] + " "
            lines[i] = "|".join(cells)
            updated.add(relic_id)
inventory.write_bytes("".join(lines).encode("utf-8"))

(HERE / "confirmed_values.json").write_text(json.dumps({rid: {**spec, "rarity": changed[rid]["rarity"],
    "max_stack": changed[rid].get("max_stack", 0), "runtime_effects": changed[rid]["runtime_effects"]} for rid, spec in specs.items()}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"CONFIRMED_APPLIED records={len(changed)} catalog={len(found)} inventory={len(updated)}")
