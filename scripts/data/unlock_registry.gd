extends RefCounted
class_name UnlockRegistry

const BUILDING_UNLOCKS: Array[String] = [
	"weapon_pool_basic_melee",
	"weapon_pool_basic_fine",
	"weapon_pool_ranged",
	"weapon_pool_rare",
	"weapon_pool_epic",
	"weapon_pool_legendary",
	"weapon_pool_precious",
	"special_weapon_slot",
	"weapon_blueprint_legendary",
	"relic_pool_common",
	"relic_pool_common_fine",
	"relic_pool_rare",
	"relic_pool_epic",
	"relic_pool_void",
	"relic_pool_legendary",
	"relic_pool_legendary_void",
	"relic_pool_precious",
	"camp_upgrade_armory",
	"camp_upgrade_relic_archive",
	"camp_upgrade_blade_arena",
	"camp_upgrade_farstar_range",
	"camp_upgrade_kin_nursery",
	"camp_upgrade_dome_shelter",
	"camp_upgrade_council_hall",
	"camp_upgrade_summon_damage",
	"run_start_random_summon",
	"run_start_random_relic",
	"run_start_double_level",
]

const BUILDING_STAGES: Array[String] = [
	"void_corruption",
]

static func has_unlock(unlock_id: String) -> bool:
	return BUILDING_UNLOCKS.has(unlock_id)

static func has_stage(stage_id: String) -> bool:
	return BUILDING_STAGES.has(stage_id)
