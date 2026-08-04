extends RefCounted
class_name UnlockRegistry

const BUILDING_UNLOCKS: Array[String] = [
	"weapon_pool_basic_melee",
	"weapon_pool_ranged",
	"weapon_pool_rare",
	"special_weapon_slot",
	"weapon_blueprint_legendary",
	"relic_pool_common",
	"relic_pool_rare",
	"relic_pool_epic",
	"relic_pool_void",
	"relic_pool_legendary",
	"camp_upgrade_summon_damage",
	"run_start_random_summon",
	"corrupted_affix_pool",
	"camp_upgrade_max_hp",
	"camp_upgrade_hp_regen",
	"camp_upgrade_shield",
	"camp_upgrade_armor",
	"camp_upgrade_move_speed",
	"run_start_random_relic",
]

const BUILDING_STAGES: Array[String] = [
	"void_corruption",
]

static func has_unlock(unlock_id: String) -> bool:
	return BUILDING_UNLOCKS.has(unlock_id)

static func has_stage(stage_id: String) -> bool:
	return BUILDING_STAGES.has(stage_id)
