extends RefCounted
class_name ShopOfferGenerator

const OFFER_NEW_WEAPON: String = "new_weapon"
const OFFER_RELIC: String = "relic"
const OFFER_WEAPON_UPGRADE: String = "weapon_upgrade"

const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
const BASE_TYPE_WEIGHTS: Dictionary = {
	OFFER_NEW_WEAPON: 25,
	OFFER_RELIC: 60,
	OFFER_WEAPON_UPGRADE: 15,
}
const RELIC_RARITY_STEPS: Dictionary = {
	"common": 3,
	"uncommon": 4,
	"rare": 5,
	"epic": 6,
	"mythic": 8,
	"legendary": 10,
}


func build_shop_candidate_pool(context: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var owned_weapon_ids := _to_string_set(context.get("owned_weapon_ids", []))
	var unlocked_weapon_ids := _to_string_set(context.get("unlocked_weapon_ids", []))
	var unlocked_relic_ids := _to_string_set(context.get("unlocked_relic_ids", []))
	var relic_counts: Dictionary = context.get("owned_relic_counts", {})
	var zone_tendency_tags := _to_string_array(context.get("zone_tendency_tags", []))
	var zone_target_pools := _to_string_set(context.get("zone_target_pools", []))
	var zone_tag_weight_bonus := maxi(0, int(context.get("zone_tag_weight_bonus", 0)))
	var shop_price_percent := float(context.get("shop_price_percent", 0.0))
	var load_capacity := int(context.get("load_capacity", 0))
	var current_load := int(context.get("current_load", 0))
	var owned_rarity_counts: Dictionary = context.get("owned_rarity_counts", {})

	for weapon_data in DataRegistry.get_table("weapons"):
		var weapon_id := str(weapon_data.get("id", ""))
		if weapon_id.is_empty() or owned_weapon_ids.has(weapon_id):
			continue
		if not unlocked_weapon_ids.is_empty() and not unlocked_weapon_ids.has(weapon_id):
			continue
		var weapon_load_cost := int(weapon_data.get("load_cost", 0))
		if load_capacity > 0 and current_load + weapon_load_cost > load_capacity:
			continue
		var weapon_tags := _to_string_array(weapon_data.get("tags", []))
		candidates.append(_build_candidate_entry({
			"offer_id": "new_weapon:%s" % weapon_id,
			"offer_type": OFFER_NEW_WEAPON,
			"pool_key": "weapon",
			"rarity": str(weapon_data.get("rarity", "common")),
			"target_id": weapon_id,
			"display_name": str(weapon_data.get("display_name", weapon_id)),
			"icon": str(weapon_data.get("icon", "")),
			"load_cost": int(weapon_data.get("load_cost", 0)),
			"description": str(weapon_data.get("description", "")),
			"bond_id": str(weapon_data.get("bond_id", "")),
			"tags": weapon_tags,
		}, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus, shop_price_percent))

	for relic_data in DataRegistry.get_table("relics"):
		var relic_id := str(relic_data.get("id", ""))
		if relic_id.is_empty():
			continue
		if not unlocked_relic_ids.is_empty() and not unlocked_relic_ids.has(relic_id):
			continue
		var max_stack := int(relic_data.get("max_stack", 0))
		var owned_count := int(relic_counts.get(relic_id, 0))
		if max_stack > 0 and owned_count >= max_stack:
			continue
		var relic_tags := _to_string_array(relic_data.get("tags", []))
		var relic_rarity := str(relic_data.get("rarity", "common"))
		candidates.append(_build_candidate_entry({
			"offer_id": "relic:%s" % relic_id,
			"offer_type": OFFER_RELIC,
			"pool_key": "relic",
			"rarity": relic_rarity,
			"rarity_bucket_count": int(owned_rarity_counts.get(relic_rarity, 0)),
			"target_id": relic_id,
			"display_name": str(relic_data.get("display_name", relic_id)),
			"description": str(relic_data.get("description", "")),
			"icon": str(relic_data.get("icon", "")),
			"bond_id": str(relic_data.get("bond_id", "")),
			"effects": (relic_data.get("effects", []) as Array).duplicate(true),
			"runtime_effects": (relic_data.get("runtime_effects", []) as Array).duplicate(true),
			"tags": relic_tags,
		}, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus, shop_price_percent))

	for weapon_data in _get_equipped_weapon_data(context):
		var weapon_id := str(weapon_data.get("id", ""))
		var current_level := int(_get_equipped_weapon_level(context, weapon_id))
		var max_level := int(weapon_data.get("max_level", 1))
		if weapon_id.is_empty() or current_level >= max_level:
			continue
		var upgrade_entry: Dictionary = weapon_data.get("level_upgrades", {}).get(str(current_level + 1), {})
		if upgrade_entry.is_empty():
			continue
		var upgrade_tags := _to_string_array(weapon_data.get("tags", []))
		candidates.append(_build_candidate_entry({
			"offer_id": "weapon_upgrade:%s:%d" % [weapon_id, current_level + 1],
			"offer_type": OFFER_WEAPON_UPGRADE,
			"pool_key": "weapon",
			"rarity": str(upgrade_entry.get("rarity", "common")),
			"target_id": weapon_id,
			"from_level": current_level,
			"to_level": current_level + 1,
			"display_name": "%s 升至%d级" % [str(weapon_data.get("display_name", weapon_id)), current_level + 1],
			"description": str(upgrade_entry.get("description", "")),
			"icon": str(weapon_data.get("icon", "")),
			"effects": (upgrade_entry.get("effects", []) as Array).duplicate(true),
			"bond_id": str(weapon_data.get("bond_id", "")),
			"tags": upgrade_tags,
		}, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus, shop_price_percent))

	return candidates


func get_shop_rarity_weights(luck: int, _zone_rarity_bonus: int = 0) -> Dictionary:
	var safe_luck := float(maxi(0, luck))
	var epic := 25.0 * _diminishing_luck(safe_luck, 173.0, 0.738)
	var mythic := 12.0 * _diminishing_luck(safe_luck, 1893.0, 0.8)
	var legendary := 6.0 * _diminishing_luck(safe_luck, 3940.0, 0.8)
	var rare := 5.0 + 15.0 * _diminishing_luck(safe_luck, 300.0, 0.75)
	var uncommon := 17.0 + 10.0 * _diminishing_luck(safe_luck, 350.0, 0.7)
	var uncommon_weight := roundi(uncommon * 100.0)
	var rare_weight := roundi(rare * 100.0)
	var epic_weight := roundi(epic * 100.0)
	var mythic_weight := roundi(mythic * 100.0)
	var legendary_weight := roundi(legendary * 100.0)
	var common_weight := maxi(0, 10000 - uncommon_weight - rare_weight - epic_weight - mythic_weight - legendary_weight)
	return {
		"common": common_weight,
		"uncommon": uncommon_weight,
		"rare": rare_weight,
		"epic": epic_weight,
		"mythic": mythic_weight,
		"legendary": legendary_weight,
	}


func get_shop_type_weights(context: Dictionary) -> Dictionary:
	var candidates: Array = context.get("candidate_pool", [])
	var weights: Dictionary = BASE_TYPE_WEIGHTS.duplicate()
	var type_counts := _count_offer_types(candidates)
	for offer_type in weights.keys():
		if int(type_counts.get(offer_type, 0)) <= 0:
			weights[offer_type] = 0

	var load_capacity := int(context.get("load_capacity", 0))
	var current_load := int(context.get("current_load", 0))
	if int(type_counts.get(OFFER_NEW_WEAPON, 0)) > 0 and load_capacity > 0:
		var remaining_ratio := float(maxi(0, load_capacity - current_load)) / float(load_capacity)
		var multiplier := 0.15
		if remaining_ratio >= 0.50:
			multiplier = 1.0
		elif remaining_ratio >= 0.30:
			multiplier = 0.70
		elif remaining_ratio >= 0.15:
			multiplier = 0.45
		elif remaining_ratio > 0.0:
			multiplier = 0.25
		weights[OFFER_NEW_WEAPON] = maxi(1, int(ceil(float(weights[OFFER_NEW_WEAPON]) * multiplier)))

	if int(type_counts.get(OFFER_WEAPON_UPGRADE, 0)) > 0:
		var miss_count := maxi(0, int(context.get("weapon_upgrade_miss_count", 0)))
		weights[OFFER_WEAPON_UPGRADE] = mini(45, 15 + miss_count * 6)

	var zone_target_pools := _to_string_set(context.get("zone_target_pools", []))
	var zone_tag_weight_bonus := maxi(0, int(context.get("zone_tag_weight_bonus", 0)))
	if zone_target_pools.has("weapon"):
		weights[OFFER_NEW_WEAPON] += zone_tag_weight_bonus
		weights[OFFER_WEAPON_UPGRADE] += maxi(1, int(ceil(float(zone_tag_weight_bonus) * 0.5)))
	if zone_target_pools.has("relic"):
		weights[OFFER_RELIC] += zone_tag_weight_bonus
	return weights


func roll_shop_offers(rarity_weights: Dictionary, type_weights: Dictionary, candidate_pool: Array, offer_count: int) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = []
	for candidate in candidate_pool:
		if candidate is Dictionary:
			remaining.append(candidate.duplicate(true))
	var offers: Array[Dictionary] = []
	var upgrade_selected := false

	for _slot in maxi(0, offer_count):
		if remaining.is_empty():
			break
		var available := _filter_available_candidates(remaining, upgrade_selected)
		available = _filter_candidates_by_rarity_weights(available, rarity_weights)
		if available.is_empty():
			break
		var available_type_weights := _get_available_type_weights(type_weights, available)
		var offer_type := _roll_weighted_key(available_type_weights)
		var typed_candidates := _filter_candidates_by_type(available, offer_type)
		var candidate := _pick_candidate_by_rarity(typed_candidates, rarity_weights)
		if candidate.is_empty():
			break
		if candidate.get("offer_type", "") == OFFER_WEAPON_UPGRADE:
			upgrade_selected = true
		remaining.erase(candidate)
		offers.append(candidate)
	return offers


func _pick_candidate_by_rarity(candidates: Array[Dictionary], rarity_weights: Dictionary) -> Dictionary:
	if candidates.is_empty():
		return {}
	var available_rarity_weights := {}
	for candidate in candidates:
		var rarity := str(candidate.get("rarity", "common"))
		if not available_rarity_weights.has(rarity):
			available_rarity_weights[rarity] = maxi(0, int(rarity_weights.get(rarity, 0)))
	var rarity := _roll_weighted_key(available_rarity_weights)
	if rarity.is_empty():
		return {}
	var rarity_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if str(candidate.get("rarity", "common")) == rarity:
			rarity_candidates.append(candidate)
	return _pick_weighted_candidate(rarity_candidates)


func _pick_weighted_candidate(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total_weight := 0
	for candidate in candidates:
		total_weight += maxi(1, int(candidate.get("weight", 100)))
	if total_weight <= 0:
		return candidates[0]
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for candidate in candidates:
		cumulative += maxi(1, int(candidate.get("weight", 100)))
		if roll <= cumulative:
			return candidate
	return candidates[0]


func _filter_available_candidates(candidates: Array[Dictionary], upgrade_selected: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in candidates:
		if upgrade_selected and candidate.get("offer_type", "") == OFFER_WEAPON_UPGRADE:
			continue
		result.append(candidate)
	return result


func _get_available_type_weights(type_weights: Dictionary, candidates: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	var counts := _count_offer_types(candidates)
	for offer_type in type_weights.keys():
		if int(counts.get(offer_type, 0)) > 0:
			result[offer_type] = maxi(0, int(type_weights.get(offer_type, 0)))
	return result


func _filter_candidates_by_type(candidates: Array[Dictionary], offer_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in candidates:
		if str(candidate.get("offer_type", "")) == offer_type:
			result.append(candidate)
	return result


func _filter_candidates_by_rarity_weights(candidates: Array[Dictionary], rarity_weights: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in candidates:
		var rarity := str(candidate.get("rarity", "common"))
		if int(rarity_weights.get(rarity, 0)) > 0:
			result.append(candidate)
	return result


func _diminishing_luck(luck: float, midpoint: float, exponent: float) -> float:
	if luck <= 0.0:
		return 0.0
	var luck_power := pow(luck, exponent)
	var midpoint_power := pow(midpoint, exponent)
	return luck_power / (luck_power + midpoint_power)


func _build_candidate_entry(candidate: Dictionary, zone_tendency_tags: Array[String], zone_target_pools: Dictionary, zone_tag_weight_bonus: int, shop_price_percent: float) -> Dictionary:
	var pool_key := str(candidate.get("pool_key", ""))
	var tags := _to_string_array(candidate.get("tags", []))
	candidate["weight"] = _calculate_candidate_weight(pool_key, tags, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus)
	candidate["shop_cost"] = _calculate_shop_cost(candidate, shop_price_percent)
	return candidate


func _calculate_shop_cost(candidate: Dictionary, shop_price_percent: float) -> int:
	var rarity_index := RARITIES.find(str(candidate.get("rarity", "common")))
	if rarity_index < 0:
		rarity_index = 0
	var base_cost := 15
	var offer_type := str(candidate.get("offer_type", ""))
	if offer_type == OFFER_WEAPON_UPGRADE:
		base_cost = 10
	elif offer_type == OFFER_RELIC:
		var rarity := str(candidate.get("rarity", "common"))
		var step := int(RELIC_RARITY_STEPS.get(rarity, 3))
		base_cost += step * maxi(0, int(candidate.get("rarity_bucket_count", 0)))
	return StatDefinitions.calculate_shop_cost(base_cost + rarity_index * 5, shop_price_percent)


func _calculate_candidate_weight(pool_key: String, tags: Array[String], zone_tendency_tags: Array[String], zone_target_pools: Dictionary, zone_tag_weight_bonus: int) -> int:
	var weight := 100
	if not zone_target_pools.is_empty() and not zone_target_pools.has(pool_key):
		return weight
	var match_count := 0
	for tag in tags:
		if zone_tendency_tags.has(tag):
			match_count += 1
	if match_count > 0:
		weight += zone_tag_weight_bonus * match_count
	return maxi(1, weight)


func _roll_weighted_key(weights: Dictionary) -> String:
	var total := 0
	for value in weights.values():
		total += maxi(0, int(value))
	if total <= 0:
		return ""
	var roll := randi_range(1, total)
	var cumulative := 0
	for key in weights.keys():
		cumulative += maxi(0, int(weights[key]))
		if roll <= cumulative:
			return str(key)
	return ""


func _count_offer_types(candidates: Array) -> Dictionary:
	var counts := {}
	for candidate in candidates:
		var offer_type := str(candidate.get("offer_type", ""))
		counts[offer_type] = int(counts.get(offer_type, 0)) + 1
	return counts


func _upgrade_key(candidate: Dictionary) -> String:
	return "%s:%s" % [str(candidate.get("target_id", "")), str(candidate.get("to_level", 0))]


func _to_string_set(values: Variant) -> Dictionary:
	var result := {}
	if values is Array:
		for value in values:
			var value_text := str(value).strip_edges()
			if not value_text.is_empty():
				result[value_text] = true
	return result


func _get_equipped_weapon_data(context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var equipped: Variant = context.get("equipped_weapons", [])
	for item in equipped:
		if item is Dictionary:
			var weapon_id := str(item.get("weapon_id", item.get("id", "")))
			var weapon_data := DataRegistry.get_record("weapons", weapon_id)
			if not weapon_data.is_empty():
				result.append(weapon_data)
		elif item is String:
			var string_weapon_data := DataRegistry.get_record("weapons", str(item))
			if not string_weapon_data.is_empty():
				result.append(string_weapon_data)
	return result


func _get_equipped_weapon_level(context: Dictionary, weapon_id: String) -> int:
	var equipped: Variant = context.get("equipped_weapons", [])
	for item in equipped:
		if item is Dictionary and str(item.get("weapon_id", item.get("id", ""))) == weapon_id:
			return int(item.get("level", 1))
	return 1


func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			var value_text := str(value).strip_edges()
			if not value_text.is_empty() and not result.has(value_text):
				result.append(value_text)
	return result
