extends Node

signal state_changed(state: Dictionary)
signal zone_selected(zone_id: String, result: Dictionary)
signal harvest_ready(harvest_payload: Dictionary)
signal state_reset

const ZONE_SOURCE_TYPE: String = "zone"
const DEFAULT_TARGET_POOLS: Array[String] = ["relic", "bond", "weapon"]

var current_zone_id: String = ""
var streak_count: int = 0
var fortune_storage: int = 0
var last_harvest: Dictionary = {}
var pending_harvest: bool = false


func _ready() -> void:
	if GameGlobal != null and not GameGlobal.runtime_state_reset.is_connected(Callable(self, "_on_runtime_state_reset")):
		GameGlobal.runtime_state_reset.connect(_on_runtime_state_reset)
	_sync_runtime_state()


func has_zone_records() -> bool:
	return DataRegistry.has_table("zones") and DataRegistry.get_record_count("zones") > 0


func get_zone_records() -> Array:
	return DataRegistry.get_table("zones")


func get_zone_record(zone_id: String) -> Dictionary:
	return DataRegistry.get_record("zones", zone_id)


func get_current_zone_record() -> Dictionary:
	return get_zone_record(current_zone_id)


func get_current_zone_id() -> String:
	return current_zone_id


func get_current_zone_name() -> String:
	return str(get_current_zone_record().get("display_name", ""))


func get_current_streak_count() -> int:
	return streak_count


func get_fortune_storage() -> int:
	return fortune_storage


func get_last_harvest() -> Dictionary:
	return last_harvest.duplicate(true)


func is_harvest_pending() -> bool:
	return pending_harvest


func get_current_zone_tendency_tags() -> Array[String]:
	return _to_string_array(get_current_zone_record().get("tendency_tags", []))


func get_current_zone_target_pools() -> Array[String]:
	return _to_string_array(_get_reward_bias().get("target_pools", []))


func get_current_zone_tag_weight_bonus() -> int:
	var reward_bias := _get_reward_bias()
	return streak_count * int(reward_bias.get("tag_weight_per_streak", 0))


func get_current_zone_rarity_bonus() -> int:
	var reward_bias := _get_reward_bias()
	return streak_count * int(reward_bias.get("rarity_bonus_per_streak", 0))


func get_zone_runtime_context() -> Dictionary:
	return {
		"zone_id": current_zone_id,
		"zone_name": get_current_zone_name(),
		"zone_tendency_tags": get_current_zone_tendency_tags(),
		"zone_target_pools": get_current_zone_target_pools(),
		"zone_tag_weight_bonus": get_current_zone_tag_weight_bonus(),
		"zone_rarity_bonus": get_current_zone_rarity_bonus(),
		"zone_streak_count": streak_count,
		"zone_fortune_storage": fortune_storage,
	}


func get_state_snapshot() -> Dictionary:
	return {
		"current_zone_id": current_zone_id,
		"streak_count": streak_count,
		"fortune_storage": fortune_storage,
		"last_harvest": last_harvest.duplicate(true),
		"pending_harvest": pending_harvest,
	}


func build_zone_selection_payload(wave_number: int = 0) -> Dictionary:
	var entries: Array[Dictionary] = []
	for zone_record in get_zone_records():
		if zone_record is Dictionary:
			entries.append(_build_zone_entry(zone_record, wave_number))
	return {
		"wave_number": maxi(wave_number, 0),
		"current_zone_id": current_zone_id,
		"current_zone_name": get_current_zone_name(),
		"streak_count": streak_count,
		"fortune_storage": fortune_storage,
		"pending_harvest": pending_harvest,
		"last_harvest": last_harvest.duplicate(true),
		"zones": entries,
	}


func build_shop_context(base_context: Dictionary = {}) -> Dictionary:
	var context := base_context.duplicate(true)
	context.merge(get_zone_runtime_context(), true)
	return context


func build_harvest_context(next_zone_id: String) -> Dictionary:
	if current_zone_id.is_empty() or fortune_storage <= 0:
		return {}
	var sanitized_next_zone_id := _sanitize_text(next_zone_id)
	if sanitized_next_zone_id.is_empty():
		return {}
	return _build_harvest_payload(current_zone_id, sanitized_next_zone_id, streak_count, fortune_storage)


func build_enemy_pressure_modifiers() -> Array[Dictionary]:
	return _build_pressure_modifiers(get_current_zone_record().get("enemy_pressure_per_streak", {}), "enemy")


func get_effective_streak() -> int:
	return maxi(streak_count - 1, 0)


func get_enemy_pressure_per_streak(field_name: String, fallback: int = 0) -> int:
	var pressure := get_current_zone_record().get("enemy_pressure_per_streak", {})
	if not (pressure is Dictionary):
		return fallback
	return int(pressure.get(field_name, fallback))


func build_player_pressure_modifiers() -> Array[Dictionary]:
	return _build_pressure_modifiers(get_current_zone_record().get("player_pressure_per_streak", {}), "player")


func select_zone(zone_id: String, wave_number: int = 0, player: PlayerController = null) -> Dictionary:
	var sanitized_zone_id := _sanitize_text(zone_id)
	var zone_record := get_zone_record(sanitized_zone_id)
	if sanitized_zone_id.is_empty() or zone_record.is_empty():
		return {
			"success": false,
			"reason": "missing_zone_config",
			"selected_zone_id": sanitized_zone_id,
			"state": get_state_snapshot(),
		}

	var previous_zone_id := current_zone_id
	var previous_streak := streak_count
	var previous_fortune := fortune_storage
	var action := "initial"
	var fortune_gain := 0
	var harvest_payload: Dictionary = {}

	if previous_zone_id.is_empty():
		action = "initial"
		current_zone_id = sanitized_zone_id
		streak_count = 1
		fortune_storage = 0
		pending_harvest = false
		last_harvest.clear()
		_apply_player_pressure(player)
	elif previous_zone_id == sanitized_zone_id:
		action = "stay"
		streak_count += 1
		fortune_gain = calculate_fortune_gain(wave_number, streak_count)
		if fortune_gain > 0:
			fortune_storage += fortune_gain
		pending_harvest = false
		_apply_player_pressure(player)
	else:
		action = "switch"
		if previous_fortune > 0:
			harvest_payload = _build_harvest_payload(previous_zone_id, sanitized_zone_id, previous_streak, previous_fortune)
			last_harvest = harvest_payload.duplicate(true)
			pending_harvest = true
			harvest_ready.emit(harvest_payload.duplicate(true))
		else:
			last_harvest.clear()
			pending_harvest = false
		current_zone_id = sanitized_zone_id
		streak_count = 1
		fortune_storage = 0
		_apply_player_pressure(player, previous_zone_id)

	_sync_runtime_state()
	var result := {
		"success": true,
		"action": action,
		"selected_zone_id": current_zone_id,
		"previous_zone_id": previous_zone_id,
		"streak_count": streak_count,
		"fortune_gain": fortune_gain,
		"fortune_storage": fortune_storage,
		"harvested": not harvest_payload.is_empty(),
		"harvest_payload": harvest_payload.duplicate(true),
		"wave_number": maxi(wave_number, 0),
		"state": get_state_snapshot(),
	}
	zone_selected.emit(current_zone_id, result.duplicate(true))
	return result


func acknowledge_harvest_result() -> void:
	if not pending_harvest:
		return
	pending_harvest = false
	_sync_runtime_state()


func calculate_fortune_gain(wave_number: int, target_streak_count: int = -1) -> int:
	var zone_record := get_current_zone_record()
	if zone_record.is_empty() and current_zone_id.is_empty():
		return 0
	var gain_config: Variant = zone_record.get("fortune_gain", {})
	if not (gain_config is Dictionary):
		return 0
	var safe_wave_number := maxi(wave_number, 0)
	var streak_for_gain := streak_count if target_streak_count < 0 else maxi(target_streak_count, 0)
	var start_streak := maxi(2, int(gain_config.get("start_streak", 2)))
	if streak_for_gain < start_streak or safe_wave_number <= 0:
		return 0
	var base_gain := maxi(0, int(gain_config.get("base", 0)))
	var extra_gain := maxi(0, streak_for_gain - start_streak) * maxi(0, int(gain_config.get("per_extra_streak", 0)))
	var wave_gain := safe_wave_number * maxi(0, int(gain_config.get("wave_bonus", 0)))
	return base_gain + extra_gain + wave_gain


func reset_state(player: PlayerController = null) -> void:
	if player != null and not current_zone_id.is_empty():
		player.remove_runtime_modifiers_by_source(ZONE_SOURCE_TYPE, current_zone_id)
	current_zone_id = ""
	streak_count = 0
	fortune_storage = 0
	last_harvest.clear()
	pending_harvest = false
	_sync_runtime_state()
	state_reset.emit()


func _on_runtime_state_reset() -> void:
	reset_state()


func _apply_player_pressure(player: PlayerController, previous_zone_id: String = "") -> void:
	if player == null:
		return
	var zone_ids_to_clear: Array[String] = []
	var previous_id := _sanitize_text(previous_zone_id)
	if not previous_id.is_empty():
		zone_ids_to_clear.append(previous_id)
	if not current_zone_id.is_empty():
		zone_ids_to_clear.append(current_zone_id)
	for zone_id in zone_ids_to_clear:
		player.remove_runtime_modifiers_by_source(ZONE_SOURCE_TYPE, zone_id)
	if current_zone_id.is_empty():
		return
	var player_modifiers := build_player_pressure_modifiers()
	if not player_modifiers.is_empty():
		player.add_runtime_modifiers(player_modifiers)


func _build_zone_entry(zone_record: Dictionary, wave_number: int) -> Dictionary:
	var zone_id := str(zone_record.get("id", ""))
	var is_current_zone := not current_zone_id.is_empty() and current_zone_id == zone_id
	var next_streak_count := 1 if current_zone_id.is_empty() or not is_current_zone else streak_count + 1
	var reward_bias := _get_reward_bias(zone_record)
	return {
		"zone_id": zone_id,
		"display_name": str(zone_record.get("display_name", zone_id)),
		"description": str(zone_record.get("description", "")),
		"tendency_tags": _to_string_array(zone_record.get("tendency_tags", [])),
		"is_current_zone": is_current_zone,
		"choice_mode": _get_choice_mode(is_current_zone),
		"next_streak_count": next_streak_count,
		"enemy_pressure": _scale_pressure(zone_record.get("enemy_pressure_per_streak", {}), next_streak_count),
		"player_pressure": _scale_pressure(zone_record.get("player_pressure_per_streak", {}), next_streak_count),
		"tag_weight_bonus": next_streak_count * int(reward_bias.get("tag_weight_per_streak", 0)),
		"rarity_bonus": next_streak_count * int(reward_bias.get("rarity_bonus_per_streak", 0)),
		"expected_fortune_gain": calculate_fortune_gain(wave_number, next_streak_count) if is_current_zone else 0,
		"harvest_preview": _build_harvest_preview(zone_record, is_current_zone),
	}


func _build_harvest_preview(zone_record: Dictionary, is_current_zone: bool) -> Dictionary:
	if current_zone_id.is_empty() or is_current_zone or fortune_storage <= 0:
		return {}
	return build_harvest_context(str(zone_record.get("id", "")))


func _build_harvest_payload(source_zone_id: String, next_zone_id: String, source_streak_count: int, source_fortune_storage: int) -> Dictionary:
	var source_zone_record := get_zone_record(source_zone_id)
	var reward_bias := _get_reward_bias(source_zone_record)
	var target_pools := _to_string_array(reward_bias.get("target_pools", DEFAULT_TARGET_POOLS))
	return {
		"source_zone_id": source_zone_id,
		"source_zone_name": str(source_zone_record.get("display_name", source_zone_id)),
		"next_zone_id": next_zone_id,
		"next_zone_name": str(get_zone_record(next_zone_id).get("display_name", next_zone_id)),
		"streak_count": source_streak_count,
		"fortune_storage": source_fortune_storage,
		"gold_gain": source_fortune_storage,
		"extra_offer_count": int(floor(float(source_fortune_storage) / 50.0)),
		"tendency_tags": _to_string_array(source_zone_record.get("tendency_tags", [])),
		"target_pools": target_pools,
		"tag_weight_bonus": source_streak_count * int(reward_bias.get("tag_weight_per_streak", 0)),
		"rarity_bonus": source_streak_count * int(reward_bias.get("rarity_bonus_per_streak", 0)),
	}


func _build_pressure_modifiers(pressure_data: Variant, target_scope: String) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if not (pressure_data is Dictionary):
		return modifiers
	var effective_streak := get_effective_streak()
	if effective_streak <= 0:
		return modifiers

	for field_name_variant in pressure_data.keys():
		var field_name := str(field_name_variant)
		var base_value := int(pressure_data[field_name_variant])
		if base_value <= 0:
			continue
		var final_value := base_value * effective_streak
		var modifier := _build_pressure_modifier(field_name, final_value, target_scope)
		if not modifier.is_empty():
			modifiers.append(modifier)
	return modifiers


func _build_pressure_modifier(field_name: String, value: int, target_scope: String) -> Dictionary:
	var modifier_stat := field_name
	var modifier_operation := Modifier.OPERATION_ADD_FLAT
	if field_name == "max_hp_percent":
		modifier_stat = "max_hp"
		modifier_operation = Modifier.OPERATION_ADD_PERCENT
	elif field_name == "armor_flat":
		modifier_stat = "armor"
		modifier_operation = Modifier.OPERATION_ADD_FLAT
	elif field_name == "spawn_interval_percent":
		return {}
	elif not StatDefinitions.has_stat(modifier_stat):
		return {}
	return {
		"id": "%s_%s_%s_%d" % [current_zone_id, target_scope, field_name, streak_count],
		"source_type": ZONE_SOURCE_TYPE,
		"source_id": current_zone_id,
		"target_scope": target_scope,
		"stat": modifier_stat,
		"operation": modifier_operation,
		"value": float(value),
		"duration": Modifier.PERMANENT_DURATION,
		"stack_rule": Modifier.STACK_RULE_UNIQUE,
		"priority": Modifier.DEFAULT_PRIORITY,
		"tags": ["zone", current_zone_id, target_scope, field_name],
		"metadata": {
			"zone_id": current_zone_id,
			"field_name": field_name,
			"target_scope": target_scope,
			"streak_count": streak_count,
		},
	}


func _scale_pressure(pressure_data: Variant, target_streak_count: int) -> Dictionary:
	var result: Dictionary = {}
	if not (pressure_data is Dictionary):
		return result
	var effective_streak := maxi(target_streak_count - 1, 0)
	for key_variant in pressure_data.keys():
		var key := str(key_variant)
		result[key] = int(pressure_data[key_variant]) * effective_streak
	return result


func _get_reward_bias(zone_record: Dictionary = {}) -> Dictionary:
	var source_record := zone_record if not zone_record.is_empty() else get_current_zone_record()
	var reward_bias: Variant = source_record.get("reward_bias", {})
	if reward_bias is Dictionary:
		var result: Dictionary = reward_bias.duplicate(true)
		if not result.has("target_pools") or (result["target_pools"] is Array and (result["target_pools"] as Array).is_empty()):
			result["target_pools"] = DEFAULT_TARGET_POOLS.duplicate()
		return result
	return {
		"target_pools": DEFAULT_TARGET_POOLS.duplicate(),
		"tag_weight_per_streak": 0,
		"rarity_bonus_per_streak": 0,
	}


func _get_choice_mode(is_current_zone: bool) -> String:
	if current_zone_id.is_empty():
		return "initial"
	return "stay" if is_current_zone else "switch"


func _sync_runtime_state() -> void:
	if GameGlobal != null:
		GameGlobal.set_runtime_flag("zone_state", get_state_snapshot())
	state_changed.emit(get_state_snapshot())


func _to_string_array(value_data: Variant) -> Array[String]:
	var result: Array[String] = []
	if value_data is Array:
		for item in value_data:
			var item_text := str(item).strip_edges()
			if not item_text.is_empty():
				result.append(item_text)
	return result


func _sanitize_text(value: Variant) -> String:
	return str(value).strip_edges()
