extends RefCounted
class_name BattleDifficulty

const DEFAULT_ID := "1"
const IDS: Array[String] = ["1", "2", "3"]
# All tiers share the verified no-talent baseline and the same wave growth.
const BASELINE := {
	"health": 0.8, "damage": 0.45, "speed": 0.85, "armor": 1.0,
	"spawn_count": 0.30, "spawn_interval": 1.35, "opening_delay": 2.0, "enemy_limit": 75,
	"hp_growth": 0.14, "damage_growth": 3.0, "speed_growth": 0.5, "armor_growth": 0.5,
	"count_growth": 3.0, "interval_growth": 2.0, "first_elite_wave": 4, "elite_count": 0.5,
}
const PROFILES := {
	"1": {
		"title": "标准难度", "color": Color("#83b77c"), "stat_multiplier": 1.0,
		"description": "",
	},
	"2": {
		"title": "怪物属性加强20%", "color": Color("#c8ae54"), "stat_multiplier": 1.2,
		"description": "",
	},
	"3": {
		"title": "怪物属性加强30%", "color": Color("#c8794f"), "stat_multiplier": 1.3,
		"description": "精英到来更频繁",
		"first_elite_wave": 2, "elite_count": 1.0,
	},
}


static func normalize(id: String) -> String:
	var key := id.strip_edges()
	if key in ["beginner", "standard"]: return "1"
	if key in ["hard", "nightmare"]: return "3"
	return key if PROFILES.has(key) else DEFAULT_ID


static func get_profile(id: String) -> Dictionary:
	var profile := BASELINE.duplicate(true)
	profile.merge(PROFILES[normalize(id)], true)
	for stat in ["health", "damage", "speed", "armor"]:
		profile[stat] = float(profile[stat]) * float(profile.stat_multiplier)
	return profile
