extends RefCounted
class_name ShopOfferGenerator

const OFFER_NEW_WEAPON: String = "new_weapon"
const OFFER_RELIC: String = "relic"
const OFFER_WEAPON_UPGRADE: String = "weapon_upgrade"

const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
const BASE_TYPE_WEIGHTS: Dictionary = {
	OFFER_NEW_WEAPON: 25,
	OFFER_RELIC: 50,
	OFFER_WEAPON_UPGRADE: 25,
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

	for weapon_data in DataRegistry.get_table("weapons"):
		var weapon_id := str(weapon_data.get("id", ""))
		if weapon_id.is_empty() or owned_weapon_ids.has(weapon_id):
			continue
		if not unlocked_weapon_ids.is_empty() and not unlocked_weapon_ids.has(weapon_id):
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
			"tags": weapon_tags,
		}, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus))

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
		candidates.append(_build_candidate_entry({
			"offer_id": "relic:%s" % relic_id,
			"offer_type": OFFER_RELIC,
			"pool_key": "relic",
			"rarity": str(relic_data.get("rarity", "common")),
			"target_id": relic_id,
			"display_name": str(relic_data.get("display_name", relic_id)),
			"description": str(relic_data.get("description", "")),
			"icon": str(relic_data.get("icon", "")),
			"effects": (relic_data.get("effects", []) as Array).duplicate(true),
			"runtime_effects": (relic_data.get("runtime_effects", []) as Array).duplicate(true),
			"tags": relic_tags,
		}, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus))

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
			"icon": str(weapon_data.get("icon", "")),
			"effects": (upgrade_entry.get("effects", []) as Array).duplicate(true),
			"tags": upgrade_tags,
		}, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus))

	return candidates


func get_shop_rarity_weights(luck: int, zone_rarity_bonus: int = 0) -> Dictionary:
	var safe_luck := maxi(0, luck)
	var weights := {
		"common": maxi(20, 100 - int(floor(safe_luck * 0.30))),
		"uncommon": maxi(25, 55 - int(floor(safe_luck * 0.10))),
		"rare": 25 + int(floor(safe_luck * 0.20)),
		"epic": 10 + int(floor(safe_luck * 0.12)),
		"mythic": 4 + int(floor(safe_luck * 0.06)),
		"legendary": 1 + int(floor(safe_luck * 0.03)),
	}
	var safe_zone_bonus := maxi(0, zone_rarity_bonus)
	if safe_zone_bonus > 0:
		weights["rare"] += safe_zone_bonus
		weights["epic"] += int(ceil(float(safe_zone_bonus) * 0.75))
		weights["mythic"] += int(ceil(float(safe_zone_bonus) * 0.5))
		weights["legendary"] += int(ceil(float(safe_zone_bonus) * 0.25))
	return weights


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
		var miss_count := maxi(0, int(context.get("upgrade_miss_count", 0)))
		weights[OFFER_WEAPON_UPGRADE] = mini(100, 25 + miss_count * 15)

	var zone_target_pools := _to_string_set(context.get("zone_target_pools", []))
	var zone_tag_weight_bonus := maxi(0, int(context.get("zone_tag_weight_bonus", 0)))
	if zone_target_pools.has("weapon"):
		weights[OFFER_NEW_WEAPON] += zone_tag_weight_bonus
		weights[OFFER_WEAPON_UPGRADE] += maxi(1, int(ceil(float(zone_tag_weight_bonus) * 0.5)))
	if zone_target_pools.has("relic"):
		weights[OFFER_RELIC] += zone_tag_weight_bonus
	return weights


func roll_shop_offers(rarity_weights: Dictionary, type_weights: Dictionary, candidate_pool: Array, refresh_count: int) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = []
	for candidate in candidate_pool:
		if candidate is Dictionary:
			remaining.append(candidate.duplicate(true))
	var offers: Array[Dictionary] = []
	var used_upgrade_keys := {}

	for _slot in maxi(0, refresh_count):
		if remaining.is_empty():
			break
		var offer_type := _roll_weighted_key(type_weights)
		var rarity := _roll_weighted_key(rarity_weights)
		var candidate := _pick_candidate(remaining, offer_type, rarity, used_upgrade_keys)
		if candidate.is_empty():
			candidate = _pick_candidate(remaining, offer_type, "", used_upgrade_keys)
		if candidate.is_empty():
			candidate = _pick_candidate(remaining, "", rarity, used_upgrade_keys)
		if candidate.is_empty():
			candidate = _pick_weighted_candidate(_filter_available_candidates(remaining, used_upgrade_keys))
		if candidate.is_empty():
			break
		if candidate.get("offer_type", "") == OFFER_WEAPON_UPGRADE:
			used_upgrade_keys[_upgrade_key(candidate)] = true
		remaining.erase(candidate)
		offers.append(candidate)
	return offers


func _pick_candidate(candidates: Array[Dictionary], offer_type: String, rarity: String, used_upgrade_keys: Dictionary) -> Dictionary:
	var matches: Array[Dictionary] = []
	for candidate in candidates:
		if not offer_type.is_empty() and str(candidate.get("offer_type", "")) != offer_type:
			continue
		if not rarity.is_empty() and str(candidate.get("rarity", "")) != rarity:
			continue
		if candidate.get("offer_type", "") == OFFER_WEAPON_UPGRADE and used_upgrade_keys.has(_upgrade_key(candidate)):
			continue
		matches.append(candidate)
	if matches.is_empty():
		return {}
	return _pick_weighted_candidate(matches)


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


func _filter_available_candidates(candidates: Array[Dictionary], used_upgrade_keys: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in candidates:
		if candidate.get("offer_type", "") == OFFER_WEAPON_UPGRADE and used_upgrade_keys.has(_upgrade_key(candidate)):
			continue
		result.append(candidate)
	return result


func _build_candidate_entry(candidate: Dictionary, zone_tendency_tags: Array[String], zone_target_pools: Dictionary, zone_tag_weight_bonus: int) -> Dictionary:
	var pool_key := str(candidate.get("pool_key", ""))
	var tags := _to_string_array(candidate.get("tags", []))
	candidate["weight"] = _calculate_candidate_weight(pool_key, tags, zone_tendency_tags, zone_target_pools, zone_tag_weight_bonus)
	return candidate


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
