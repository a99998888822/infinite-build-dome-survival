extends RefCounted
class_name RewardSnapshot

var wave_id: String = ""
var drop_table_id: String = ""
var spawned_exp_orbs: int = 0
var spawned_health_packs: int = 0
var spawned_relics: int = 0
var spawned_unknown: int = 0
var collected_exp_orbs: int = 0
var collected_health_packs: int = 0
var exp_gained: int = 0
var gold_gained: int = 0
var health_restored: int = 0
var level_ups: int = 0
var generated_offers: int = 0


func reset(next_wave_id: String = "", next_drop_table_id: String = "") -> void:
	wave_id = next_wave_id
	drop_table_id = next_drop_table_id
	spawned_exp_orbs = 0
	spawned_health_packs = 0
	spawned_relics = 0
	spawned_unknown = 0
	collected_exp_orbs = 0
	collected_health_packs = 0
	exp_gained = 0
	gold_gained = 0
	health_restored = 0
	level_ups = 0
	generated_offers = 0


func record_spawned_drop(drop_type: String, quantity: int = 1) -> void:
	var safe_quantity := maxi(quantity, 0)
	match drop_type:
		"exp_orb":
			spawned_exp_orbs += safe_quantity
		"health_pack":
			spawned_health_packs += safe_quantity
		"relic":
			spawned_relics += safe_quantity
		_:
			spawned_unknown += safe_quantity


func record_exp_collection(exp_amount: int, gold_amount: int) -> void:
	collected_exp_orbs += 1
	exp_gained += maxi(exp_amount, 0)
	gold_gained += maxi(gold_amount, 0)


func record_health_collection(heal_amount: int) -> void:
	collected_health_packs += 1
	health_restored += maxi(heal_amount, 0)


func record_level_up() -> void:
	level_ups += 1


func record_generated_offer() -> void:
	generated_offers += 1


func to_dictionary() -> Dictionary:
	return {
		"wave_id": wave_id,
		"drop_table_id": drop_table_id,
		"spawned_exp_orbs": spawned_exp_orbs,
		"spawned_health_packs": spawned_health_packs,
		"spawned_relics": spawned_relics,
		"spawned_unknown": spawned_unknown,
		"collected_exp_orbs": collected_exp_orbs,
		"collected_health_packs": collected_health_packs,
		"exp_gained": exp_gained,
		"gold_gained": gold_gained,
		"health_restored": health_restored,
		"level_ups": level_ups,
		"generated_offers": generated_offers,
	}
