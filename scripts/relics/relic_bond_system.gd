extends RefCounted
class_name RelicBondSystem

var owner_player: PlayerController = null
var weapon_ids: Array[String] = []
var relic_instances: Dictionary = {}
var relic_ids_by_name: Dictionary = {}
var instance_sequence: int = 0
var active_special_effects: Array[Dictionary] = []


func initialize(player: PlayerController) -> void:
	owner_player = player
	refresh_effects()


func set_owner(player: PlayerController) -> void:
	owner_player = player
	refresh_effects()


func set_weapon_ids(target_weapon_ids: Array[String]) -> void:
	weapon_ids = target_weapon_ids.duplicate()
	refresh_effects()


func get_weapon_ids() -> Array[String]:
	return weapon_ids.duplicate()


func add_relic(relic_id: String) -> bool:
	var relic_data := DataRegistry.get_record("relics", relic_id)
	if relic_data.is_empty():
		push_warning("[RelicBondSystem] missing relic config: %s" % relic_id)
		return false
	if not can_add_relic(relic_id):
		return false

	var instance_id := _create_instance_id(relic_id)
	relic_instances[instance_id] = {
		"relic_id": relic_id,
		"relic_data": relic_data.duplicate(true),
	}
	if not relic_ids_by_name.has(relic_id):
		relic_ids_by_name[relic_id] = []
	(relic_ids_by_name[relic_id] as Array).append(instance_id)
	refresh_effects()
	return true


func remove_relic(relic_id: String) -> bool:
	if not relic_ids_by_name.has(relic_id):
		return false
	var instance_ids: Array = relic_ids_by_name[relic_id]
	if instance_ids.is_empty():
		return false
	var instance_id := str(instance_ids.pop_back())
	if instance_ids.is_empty():
		relic_ids_by_name.erase(relic_id)
	relic_instances.erase(instance_id)
	refresh_effects()
	return true


func remove_relic_instance(instance_id: String) -> bool:
	if not relic_instances.has(instance_id):
		return false
	var relic_id := str(relic_instances[instance_id].get("relic_id", ""))
	if relic_ids_by_name.has(relic_id):
		var instance_ids: Array = relic_ids_by_name[relic_id]
		instance_ids.erase(instance_id)
		if instance_ids.is_empty():
			relic_ids_by_name.erase(relic_id)
	relic_instances.erase(instance_id)
	refresh_effects()
	return true


func clear_relics() -> void:
	relic_instances.clear()
	relic_ids_by_name.clear()
	refresh_effects()


func clear() -> void:
	weapon_ids.clear()
	clear_relics()
	active_special_effects.clear()


func can_add_relic(relic_id: String) -> bool:
	var relic_data := DataRegistry.get_record("relics", relic_id)
	if relic_data.is_empty():
		return false
	var max_stack := int(relic_data.get("max_stack", 0))
	if max_stack <= 0:
		return true
	return get_relic_count(relic_id) < max_stack


func get_relic_count(relic_id: String) -> int:
	if not relic_ids_by_name.has(relic_id):
		return 0
	return (relic_ids_by_name[relic_id] as Array).size()


func get_total_relic_count() -> int:
	return relic_instances.size()


func get_relic_ids() -> Array[String]:
	var result: Array[String] = []
	for relic_id in relic_ids_by_name.keys():
		result.append(str(relic_id))
	result.sort()
	return result


func get_bond_tag_count(bond_id: String) -> int:
	var bond_data := DataRegistry.get_record("bonds", bond_id)
	if bond_data.is_empty():
		return 0
	var bond_tag := str(bond_data.get("bond_tag", ""))
	if bond_tag.is_empty():
		return 0
	var counts := _collect_tag_counts()
	return int(counts.get(bond_tag, 0))


func get_active_bond_layers(bond_id: String) -> int:
	return get_active_thresholds(bond_id).size()


func get_active_thresholds(bond_id: String) -> Array[int]:
	var bond_data := DataRegistry.get_record("bonds", bond_id)
	if bond_data.is_empty():
		return []
	var bond_tag := str(bond_data.get("bond_tag", ""))
	if bond_tag.is_empty():
		return []
	var bond_count := get_bond_tag_count(bond_id)
	var thresholds: Variant = bond_data.get("thresholds", {})
	if not (thresholds is Dictionary):
		return []
	var result: Array[int] = []
	for threshold_key in thresholds.keys():
		var threshold_value := int(str(threshold_key))
		if bond_count >= threshold_value:
			result.append(threshold_value)
	result.sort()
	return result


func get_active_special_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect in active_special_effects:
		result.append(effect.duplicate(true))
	return result


func refresh_effects() -> void:
	_clear_owner_effects("relic")
	_clear_owner_effects("bond")
	active_special_effects.clear()
	_apply_relic_effects()
	_apply_bond_effects()


func _apply_relic_effects() -> void:
	if owner_player == null:
		return
	for instance_id in relic_instances.keys():
		var relic_instance: Dictionary = relic_instances[instance_id]
		var relic_data: Dictionary = relic_instance.get("relic_data", {})
	var effects: Variant = relic_data.get("effects", [])
	if not (effects is Array):
		continue
		for effect_index in range(effects.size()):
			var effect: Variant = effects[effect_index]
			if not (effect is Dictionary):
				continue
			var modifier_data := _build_modifier_data(effect, str(relic_instance.get("relic_id", "")), str(instance_id), effect_index, "relic")
			owner_player.add_runtime_modifier(modifier_data)


func _apply_bond_effects() -> void:
	var counts := _collect_tag_counts()
	var bonds := DataRegistry.get_table("bonds")
	if bonds.is_empty():
		return
	for bond in bonds:
		if not (bond is Dictionary):
			continue
		var bond_data: Dictionary = bond
		var bond_id := str(bond_data.get("id", ""))
		var bond_name := str(bond_data.get("name", ""))
		var bond_tag := str(bond_data.get("bond_tag", ""))
		var bond_count := int(counts.get(bond_tag, 0))
		var thresholds: Variant = bond_data.get("thresholds", {})
		if not (thresholds is Dictionary):
			continue
		var active_thresholds: Array[int] = []
		for threshold_key in thresholds.keys():
			var threshold_value := int(str(threshold_key))
			if bond_count >= threshold_value:
				active_thresholds.append(threshold_value)
		active_thresholds.sort()
		for threshold_value in active_thresholds:
			var threshold_effects: Variant = thresholds[str(threshold_value)]
			if not (threshold_effects is Array):
				continue
			for effect_index in range(threshold_effects.size()):
				var effect: Variant = threshold_effects[effect_index]
				if not (effect is Dictionary):
					continue
				var effect_data: Dictionary = effect
				if effect_data.has("stat"):
					var modifier_data := _build_bond_modifier_data(effect_data, bond_id, bond_name, bond_tag, threshold_value, effect_index)
					if owner_player != null:
						owner_player.add_runtime_modifier(modifier_data)
				else:
					active_special_effects.append(_build_special_effect_record(effect_data, bond_id, bond_name, bond_tag, threshold_value))


func _build_modifier_data(effect_data: Dictionary, source_id: String, instance_id: String, effect_index: int, source_type: String) -> Dictionary:
	var modifier_id := str(effect_data.get("id", ""))
	if modifier_id.is_empty():
		modifier_id = "%s_%s_%d" % [source_id, source_type, effect_index]
	modifier_id = "%s_%s" % [modifier_id, instance_id]
	return {
		"id": modifier_id,
		"source_type": source_type,
		"source_id": instance_id,
		"target_scope": str(effect_data.get("target_scope", "player")),
		"stat": str(effect_data.get("stat", "")),
		"operation": str(effect_data.get("operation", Modifier.OPERATION_ADD_FLAT)),
		"value": float(effect_data.get("value", 0)),
		"duration": float(effect_data.get("duration", Modifier.PERMANENT_DURATION)),
		"stack_rule": str(effect_data.get("stack_rule", Modifier.STACK_RULE_UNIQUE)),
		"priority": int(effect_data.get("priority", Modifier.DEFAULT_PRIORITY)),
		"tags": ["relic", source_id],
		"metadata": {
			"relic_id": source_id,
			"relic_instance_id": instance_id,
			"relic_effect_index": effect_index,
		},
	}


func _build_bond_modifier_data(effect_data: Dictionary, bond_id: String, bond_name: String, bond_tag: String, threshold_value: int, effect_index: int) -> Dictionary:
	var modifier_id := "%s_threshold_%d_%d" % [bond_id, threshold_value, effect_index]
	return {
		"id": modifier_id,
		"source_type": "bond",
		"source_id": bond_id,
		"target_scope": "player",
		"stat": str(effect_data.get("stat", "")),
		"operation": str(effect_data.get("operation", Modifier.OPERATION_ADD_FLAT)),
		"value": float(effect_data.get("value", 0)),
		"duration": Modifier.PERMANENT_DURATION,
		"stack_rule": Modifier.STACK_RULE_UNIQUE,
		"priority": int(effect_data.get("priority", Modifier.DEFAULT_PRIORITY)),
		"tags": ["bond", bond_id, bond_tag],
		"metadata": {
			"bond_id": bond_id,
			"bond_name": bond_name,
			"bond_tag": bond_tag,
			"threshold": threshold_value,
			"bond_effect_index": effect_index,
		},
	}


func _build_special_effect_record(effect_data: Dictionary, bond_id: String, bond_name: String, bond_tag: String, threshold_value: int) -> Dictionary:
	var record := effect_data.duplicate(true)
	record["bond_id"] = bond_id
	record["bond_name"] = bond_name
	record["bond_tag"] = bond_tag
	record["threshold"] = threshold_value
	return record


func _collect_tag_counts() -> Dictionary:
	var counts: Dictionary = {}
	for weapon_id in weapon_ids:
		var weapon_data := DataRegistry.get_record("weapons", weapon_id)
		_accumulate_tags(counts, weapon_data.get("tags", []))
	for instance_id in relic_instances.keys():
		var relic_instance: Dictionary = relic_instances[instance_id]
		var relic_data: Dictionary = relic_instance.get("relic_data", {})
		_accumulate_tags(counts, relic_data.get("tags", []))
	return counts


func _accumulate_tags(counts: Dictionary, tags_data: Variant) -> void:
	if not (tags_data is Array):
		return
	for tag in tags_data:
		var tag_id := str(tag)
		counts[tag_id] = int(counts.get(tag_id, 0)) + 1


func _clear_owner_effects(source_type: String) -> void:
	if owner_player == null:
		return
	if source_type == "relic":
		owner_player.remove_runtime_modifiers_by_source_type("relic")
	elif source_type == "bond":
		owner_player.remove_runtime_modifiers_by_source_type("bond")


func _create_instance_id(relic_id: String) -> String:
	instance_sequence += 1
	return "%s_instance_%d" % [relic_id, instance_sequence]
