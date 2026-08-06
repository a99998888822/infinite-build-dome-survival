extends Node

signal state_loaded(success: bool)
signal state_changed
signal building_changed(building_id: String)

const SAVE_PATH: String = "user://camp_progression.json"
const DEFAULT_CHARACTER_ID: String = "character_void_hunter"

var state: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	_reset_state()
	if DataRegistry.has_table("camp_buildings"):
		reload_state()
	else:
		DataRegistry.data_ready.connect(_on_data_ready)


func _on_data_ready(_load_success: bool) -> void:
	reload_state()


func reload_state() -> bool:
	_reset_state()
	var loaded_state: Dictionary = _build_default_state()
	if FileAccess.file_exists(SAVE_PATH):
		var raw_text := FileAccess.get_file_as_string(SAVE_PATH)
		var parsed: Variant = JSON.parse_string(raw_text)
		if parsed is Dictionary:
			loaded_state = _merge_state(loaded_state, parsed)
		else:
			push_warning("[CampProgression] invalid save file, fallback to defaults.")
	state = loaded_state
	_sync_unlocks_from_config()
	_loaded = true
	save_state()
	state_loaded.emit(true)
	state_changed.emit()
	return true


func save_state() -> bool:
	if state.is_empty():
		_reset_state()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[CampProgression] failed to open save file: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(_sanitize_state(state), "  "))
	return true


func is_loaded() -> bool:
	return _loaded


func get_state() -> Dictionary:
	return _sanitize_state(state)


func get_building_records() -> Array:
	if not DataRegistry.has_table("camp_buildings"):
		return []
	return DataRegistry.get_table("camp_buildings")


func get_building_record(building_id: String) -> Dictionary:
	return DataRegistry.get_record("camp_buildings", building_id)


func is_building_initially_unlocked(building_id: String) -> bool:
	var record := get_building_record(building_id)
	if record.is_empty():
		return false
	return bool(record.get("initial_unlocked", false))


func get_building_level(building_id: String) -> int:
	return int(state.get("building_levels", {}).get(building_id, 0))


func is_building_unlocked(building_id: String) -> bool:
	return get_building_level(building_id) > 0


func get_building_display_state(building_id: String) -> String:
	if is_building_unlocked(building_id) or is_building_initially_unlocked(building_id):
		return "unlocked"
	return "ruins"


func get_building_max_level(building_id: String) -> int:
	var record := get_building_record(building_id)
	if record.is_empty():
		return 1
	var levels: Variant = record.get("levels", {})
	if levels is Dictionary and not levels.is_empty():
		var max_level := 1
		for level_key in levels.keys():
			max_level = maxi(max_level, int(str(level_key)))
		return max_level
	return 1


func set_building_level(building_id: String, level: int) -> bool:
	var record := get_building_record(building_id)
	if record.is_empty():
		return false
	var clamped_level := clampi(level, 0, get_building_max_level(building_id))
	if clamped_level <= 0:
		return false
	var building_levels: Dictionary = state.get("building_levels", {})
	if building_levels.get(building_id, -1) == clamped_level:
		return true
	building_levels[building_id] = clamped_level
	state["building_levels"] = building_levels
	_refresh_unlocks()
	_save_and_notify(building_id)
	return true


func upgrade_building(building_id: String) -> bool:
	var current_level := get_building_level(building_id)
	if current_level <= 0:
		return false
	var max_level := get_building_max_level(building_id)
	if current_level >= max_level:
		return false
	return set_building_level(building_id, current_level + 1)


func get_upgrade_option_level(option_id: String) -> int:
	return int(state.get("upgrade_levels", {}).get(option_id, 0))


func get_upgrade_option_record(option_id: String) -> Dictionary:
	for record in get_building_records():
		for option in record.get("upgrade_options", []):
			if option is Dictionary and str(option.get("id", "")) == option_id:
				return option
	return {}


func can_purchase_upgrade(option_id: String) -> bool:
	var option := get_upgrade_option_record(option_id)
	if option.is_empty():
		return false
	var current_level := get_upgrade_option_level(option_id)
	if current_level >= int(option.get("max_level", 0)):
		return false
	return get_camp_currency() >= int(option.get("cost", 0))


func purchase_upgrade(option_id: String) -> bool:
	if not can_purchase_upgrade(option_id):
		return false
	var option := get_upgrade_option_record(option_id)
	var cost := int(option.get("cost", 0))
	set_camp_currency(get_camp_currency() - cost)
	var upgrade_levels: Dictionary = state.get("upgrade_levels", {})
	upgrade_levels[option_id] = get_upgrade_option_level(option_id) + 1
	state["upgrade_levels"] = upgrade_levels
	_save_and_notify(option_id)
	return true


func get_camp_currency() -> int:
	return int(state.get("camp_currency", 0))


func set_camp_currency(amount: int) -> void:
	state["camp_currency"] = maxi(amount, 0)
	_save_and_notify("camp_currency")


func add_camp_currency(amount: int) -> void:
	set_camp_currency(get_camp_currency() + amount)


func get_selected_character_id() -> String:
	return str(state.get("selected_character_id", DEFAULT_CHARACTER_ID))


func set_selected_character_id(character_id: String) -> void:
	state["selected_character_id"] = character_id.strip_edges()
	_save_and_notify("selected_character_id")


func get_selected_start_weapons() -> Array[String]:
	var result: Array[String] = []
	for weapon_id in state.get("selected_start_weapons", []):
		var text_id := str(weapon_id).strip_edges()
		if not text_id.is_empty():
			result.append(text_id)
	return result


func set_selected_start_weapons(weapon_ids: Array[String]) -> void:
	var result: Array[String] = []
	for weapon_id in weapon_ids:
		var text_id := weapon_id.strip_edges()
		if not text_id.is_empty():
			result.append(text_id)
	state["selected_start_weapons"] = result
	_save_and_notify("selected_start_weapons")


func get_outgame_modifiers() -> Array:
	var modifiers: Array = []
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		var building_level := get_building_level(building_id)
		if building_level <= 0:
			continue
		modifiers.append_array(_collect_building_level_modifiers(record, building_level))
		modifiers.append_array(_collect_upgrade_option_modifiers(record))
	return modifiers


func get_building_texture_path(building_id: String) -> String:
	return "res://assets/sprites/camp/buildings/unlocked/%s.png" % building_id


func get_building_ruins_texture_path(building_id: String) -> String:
	return "res://assets/sprites/camp/buildings/ruins/%s_ruins.png" % building_id


func _build_default_state() -> Dictionary:
	var building_levels: Dictionary = {}
	var unlocks: Dictionary = {}
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		var initial_unlocked := bool(record.get("initial_unlocked", false))
		building_levels[building_id] = 1 if initial_unlocked else 0
		unlocks[building_id] = initial_unlocked
	return {
		"building_levels": building_levels,
		"upgrade_levels": {},
		"unlocks": unlocks,
		"camp_currency": 0,
		"selected_character_id": DEFAULT_CHARACTER_ID,
		"selected_start_weapons": [],
		"records": {},
	}


func _merge_state(default_state: Dictionary, saved_state: Dictionary) -> Dictionary:
	var merged: Dictionary = default_state.duplicate(true)
	for key in saved_state.keys():
		merged[key] = saved_state[key]
	return merged


func _sync_unlocks_from_config() -> void:
	var building_levels: Dictionary = state.get("building_levels", {})
	var changed := true
	while changed:
		changed = false
		for record in get_building_records():
			if not (record is Dictionary):
				continue
			var building_id := str(record.get("id", ""))
			if building_id.is_empty():
				continue
			if int(building_levels.get(building_id, 0)) > 0:
				continue
			if bool(record.get("initial_unlocked", false)) or _unlock_condition_met(record, building_levels):
				building_levels[building_id] = 1
				changed = true
	state["building_levels"] = building_levels
	_rebuild_unlocks_cache()


func _unlock_condition_met(record: Dictionary, building_levels: Dictionary) -> bool:
	var condition: Variant = record.get("unlock_condition", {})
	if not (condition is Dictionary):
		return false
	var building_id := str(condition.get("building", ""))
	if building_id.is_empty():
		return false
	var required_level := int(condition.get("level", 1))
	return int(building_levels.get(building_id, 0)) >= required_level


func _refresh_unlocks() -> void:
	var building_levels: Dictionary = state.get("building_levels", {})
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if building_id.is_empty():
			continue
		if int(building_levels.get(building_id, 0)) > 0:
			continue
		if _unlock_condition_met(record, building_levels):
			building_levels[building_id] = 1
	state["building_levels"] = building_levels
	_rebuild_unlocks_cache()


func _rebuild_unlocks_cache() -> void:
	var building_levels: Dictionary = state.get("building_levels", {})
	var unlocks: Dictionary = {}
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if building_id.is_empty():
			continue
		unlocks[building_id] = int(building_levels.get(building_id, 0)) > 0
	state["unlocks"] = unlocks


func _collect_building_level_modifiers(record: Dictionary, building_level: int) -> Array:
	var modifiers: Array = []
	var levels: Variant = record.get("levels", {})
	if not (levels is Dictionary):
		return modifiers
	var building_id := str(record.get("id", ""))
	for level_key in levels.keys():
		var target_level := int(str(level_key))
		if target_level <= 0 or target_level > building_level:
			continue
		var effects: Variant = levels[level_key]
		if not (effects is Array):
			continue
		for effect in effects:
			if not (effect is Dictionary):
				continue
			if not effect.has("stat"):
				continue
			modifiers.append(_effect_to_modifier(effect, "camp", "%s_level_%d" % [building_id, target_level]))
	return modifiers


func _collect_upgrade_option_modifiers(record: Dictionary) -> Array:
	var modifiers: Array = []
	var building_id := str(record.get("id", ""))
	for option in record.get("upgrade_options", []):
		if not (option is Dictionary):
			continue
		var option_id := str(option.get("id", ""))
		var option_level := get_upgrade_option_level(option_id)
		if option_level <= 0:
			continue
		var effect := {
			"stat": str(option.get("stat", "")),
			"value": int(option.get("value_per_level", 0)) * option_level,
		}
		modifiers.append(_effect_to_modifier(effect, "camp", "%s_%s" % [building_id, option_id]))
	return modifiers


func _effect_to_modifier(effect: Dictionary, source_type: String, source_id: String) -> Dictionary:
	return {
		"id": "mod_%s_%s_%s" % [source_type, source_id, str(effect.get("stat", "stat"))],
		"source_type": source_type,
		"source_id": source_id,
		"target_scope": "player",
		"stat": str(effect.get("stat", "")),
		"operation": "add_flat",
		"value": int(effect.get("value", 0)),
		"duration": -1,
		"stack_rule": "unique",
	}


func _sanitize_state(raw_state: Dictionary) -> Dictionary:
	var result: Dictionary = raw_state.duplicate(true)
	result["building_levels"] = _sanitize_string_int_dictionary(result.get("building_levels", {}))
	result["upgrade_levels"] = _sanitize_string_int_dictionary(result.get("upgrade_levels", {}))
	result["unlocks"] = _sanitize_string_bool_dictionary(result.get("unlocks", {}))
	result["camp_currency"] = maxi(int(result.get("camp_currency", 0)), 0)
	result["selected_character_id"] = str(result.get("selected_character_id", DEFAULT_CHARACTER_ID))
	result["selected_start_weapons"] = _sanitize_string_array(result.get("selected_start_weapons", []))
	result["records"] = result.get("records", {}) if result.get("records", {}) is Dictionary else {}
	return result


func _sanitize_string_int_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for key in value.keys():
		result[str(key)] = int(value[key])
	return result


func _sanitize_string_bool_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for key in value.keys():
		result[str(key)] = bool(value[key])
	return result


func _sanitize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item in value:
		var text_id := str(item).strip_edges()
		if not text_id.is_empty():
			result.append(text_id)
	return result


func _reset_state() -> void:
	state = {
		"building_levels": {},
		"upgrade_levels": {},
		"unlocks": {},
		"camp_currency": 0,
		"selected_character_id": DEFAULT_CHARACTER_ID,
		"selected_start_weapons": [],
		"records": {},
	}


func _save_and_notify(_source_id: String) -> void:
	print("[Debug] _save_and_notify enter: %s" % _source_id)
	_rebuild_unlocks_cache()
	print("[Debug] after _rebuild_unlocks_cache")
	save_state()
	print("[Debug] after save_state")
	state_changed.emit()
	print("[Debug] after state_changed")
	if not _source_id.is_empty():
		building_changed.emit(_source_id)
	print("[Debug] _save_and_notify exit")
