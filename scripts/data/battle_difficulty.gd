extends RefCounted
class_name BattleDifficulty

const DEFAULT_ID := "1"
const IDS: Array[String] = ["1", "2", "3"]
# Additional supply relative to the previous density. First five waves exceed
# double supply; the run ends at wave twelve while earlier waves keep their rate.
# Apply to intervals, after integer batch rounding, to avoid tiny batches
# turning a requested +20% into +50% or +100% through ceil().
const SPAWN_DENSITY_CURVE: Array[float] = [
	2.15, 2.15, 2.15, 2.15, 2.15, 2.08667, 2.02333, 1.96, 1.89667, 1.77752,
	1.71825, 1.66125,
]
# Opening waves crowd the player before any talent or relic defense exists, so
# contact damage is scaled down and ramped back to its original value. Waves past
# the curve keep exactly the previous damage numbers.
const EARLY_DAMAGE_SCALE: Array[float] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
# Give opening minibosses less health while the starter build is still forming.
# Wave six onward retains the existing elite progression.
const EARLY_ELITE_HP_SCALE: Array[float] = [0.65, 0.65, 0.75, 0.85, 0.95, 1.0]
# Health and density drive progression; contact damage grows slowly.
const BASELINE := {
	"health": 0.8, "damage": 0.45, "speed": 0.85, "armor": 1.0,
	"spawn_count": 0.15, "spawn_count_multiplier": 1, "spawn_interval": 2.70, "opening_delay": 2.0, "enemy_limit": 48,
	"hp_growth": 0.24, "damage_growth": 1.5, "speed_growth": 0.5, "armor_growth": 0.5,
	# Ordinary HP: standard wave 1 = 24, wave 12 = 140; elites keep hp_growth.
	"normal_hp_growth": 200.0 / (24.0 * 19.0),
	"count_growth": 6.0, "interval_growth": 2.5, "first_elite_wave": 2, "elite_count": 1.0,
}
const PROFILES := {
	"1": {
		"title": "标准难度", "color": Color("#83b77c"), "stat_multiplier": 1.0,
		"description": "",
		"spawn_count_multiplier": 1, "enemy_limit": 48,
	},
	"2": {
		"title": "怪物属性加强20%", "color": Color("#c8ae54"), "stat_multiplier": 1.2,
		"description": "怪物更多",
		"spawn_count": 0.22, "spawn_interval": 2.40, "enemy_limit": 72, "elite_count": 1.15,
	},
	"3": {
		"title": "怪物属性加强30%", "color": Color("#c8794f"), "stat_multiplier": 1.3,
		"description": "怪物密集 · 精英更频繁",
		"spawn_count": 0.30, "spawn_interval": 2.10, "enemy_limit": 96,
		"first_elite_wave": 2, "elite_count": 1.3,
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


static func early_damage_scale(wave_index: int) -> float:
	if EARLY_DAMAGE_SCALE.is_empty():
		return 1.0
	var index := clampi(wave_index, 0, EARLY_DAMAGE_SCALE.size() - 1)
	return EARLY_DAMAGE_SCALE[index]
