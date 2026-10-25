"""Install the reviewed weapon records and their Chinese/English catalog rows."""
import csv
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
entries = []
messages = []
for kind, name, english, damage, load, cooldown, reach, radius in [
    ("furnace", "刚焰炉", "Steel-Flame Furnace", 24, 24, 3000, 160, 160),
    ("saber", "斩马刀", "Horse-Cleaving Saber", 32, 28, 5000, 300, 8),
]:
    furnace = kind == "furnace"
    stat = "element_damage" if furnace else "melee_damage"
    description = (
        "受到伤害时弹开周围敌人，喷出火圈并点燃。投射物数量增加火圈数；分裂在外沿生成小火簇。"
        if furnace else
        "朝瞄准方向起跳，在跳跃一半时闪现，斩击沿途敌人。投射物数量增加刀光与伤害次数；攻击距离增加闪现长度，伤害范围增加刀光宽度。"
    )
    translation = (
        "Taking damage pushes nearby enemies away and releases burning fire rings. Projectiles add rings; Split creates small flares around the outer edge."
        if furnace else
        "Jump toward your aim, blink halfway through the jump, and slash enemies along the path. Projectiles add slashes and hits; Attack Range extends the blink and Damage Area widens the slash."
    )
    key = "content.weapons.weapon_" + kind
    messages.extend([(key + ".display_name", name, english), (key + ".description", description, translation)])
    record = {
        "id": "weapon_" + kind, "display_name": name, "description": description,
        "shop_description": description, "shop_weight": 90,
        "combat_tags": ["范围"] if furnace else ["近战", "范围", "位移"],
        "icon": f"res://assets/ui/icons/weapons/weapon_{kind}.svg",
        "hit_sfx": "res://assets/audio/sfx/combat/wood_arrow_01.wav",
        "rarity": "uncommon", "attack_kind": "element" if furnace else "melee",
        "tags": ["fire"] if furnace else ["melee", "heavy"],
        "load_cost": load, "max_level": 5, "attachment_slots": 1,
        "active_cooldown_ms": cooldown, "attack_interval_ms": cooldown,
        "attack_range": reach, "hit_radius": radius, "projectile_speed": 0,
        "spread_angle": 0, "projectile_behavior": kind, "player_damage_coefficient": 0.8,
        "unsupported_effects": ["pierce"] if furnace else ["pierce", "split"],
        "base_stats": {stat: damage, "attack_speed": 0, "crit_chance": 5, "crit_damage": 150, "projectile_count": 1},
        "level_upgrades": {},
    }
    for level in range(2, 6):
        gain = (8 if furnace else 7) if level == 5 else (4 if furnace else 5)
        effects = [{"stat": stat, "value": gain}]
        zh = [("元素" if furnace else "近战") + f"基础伤害 [color=#7FD88F]+{gain}[/color]"]
        en = [("Base elemental" if furnace else "Base melee") + f" damage [color=#7FD88F]+{gain}[/color]"]
        if level < 5:
            effects.append({"field": "active_cooldown_ms", "value": -100})
            zh.append("基础冷却 [color=#7FD88F]-0.1s[/color]")
            en.append("Base cooldown [color=#7FD88F]-0.1s[/color]")
        else:
            effects.append({"stat": "projectile_count", "value": 1})
            zh.append(("火圈数量" if furnace else "刀光次数") + " [color=#7FD88F]+1[/color]")
            en.append(("Fire rings" if furnace else "Slashes") + " [color=#7FD88F]+1[/color]")
        if level in (2, 4):
            effects.append({"field": "attachment_slots", "value": 1})
            zh.append("附魔槽 [color=#7FD88F]+1[/color]")
            en.append("Enchantment slots [color=#7FD88F]+1[/color]")
        text = "\n".join(zh)
        record["level_upgrades"][str(level)] = {"rarity": {2:"uncommon",3:"rare",4:"epic",5:"mythic"}[level], "description": text, "effects": effects}
        messages.append((key + f".level_{level}.description", text, "\n".join(en)))
    entries.append(record)

path = ROOT / "data_config/weapons.json"
raw = path.read_bytes()
data = json.loads(raw.decode("utf-8"))
ids = {row["id"] for row in data}
new = [row for row in entries if row["id"] not in ids]
if new:
    newline = "\r\n" if b"\r\n" in raw else "\n"
    tail = ",\n".join("\n".join("  " + line for line in json.dumps(row, indent=2, ensure_ascii=False).splitlines()) for row in new)
    original = raw.decode("utf-8").rstrip()
    path.write_bytes((original[:-1].rstrip() + "," + newline + tail.replace("\n", newline) + newline + "]" + newline).encode("utf-8"))
catalog = ROOT / "localization/catalogs/furnace_saber.csv"
buffer = io.StringIO(newline="")
writer = csv.writer(buffer)
writer.writerow(["keys", "zh_CN", "en"])
writer.writerows(messages)
catalog.write_text(buffer.getvalue(), encoding="utf-8", newline="")
print("FURNACE_SABER_CONFIG", len(new), "new records", len(messages), "translations")
