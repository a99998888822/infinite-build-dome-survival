extends Node

signal state_loaded(success: bool)
signal state_changed
signal building_changed(building_id: String)

const SCHEMA_VERSION: int = 1
const PROFILE_ID: String = "profile_01"
const SAVE_DIR: String = "user://saves"
const SAVE_PATH: String = "user://saves/profile_01.json"
const BACKUP_PATH: String = "user://saves/profile_01.backup.json"
const TEMP_PATH: String = "user://saves/profile_01.tmp.json"
const LEGACY_SAVE_PATH: String = "user://camp_progression.json"
const DEFAULT_VOLUME_SETTINGS: Dictionary = {
	"master_volume": 100,
	"bgm_volume": 80,
	"sfx_volume": 90,
}

var state: Dictionary = {}
var _loaded: bool = false
var _transient_session_active: bool = false
var _transient_session_snapshot: Dictionary = {}


func _ready() -> void:
	_reset_state()
	if DataRegistry.has_table("camp_buildings"):
		reload_state()
	else:
		DataRegistry.data_ready.connect(_on_data_ready)


func _on_data_ready(_load_success: bool) -> void:
	reload_state()


func reload_state() -> bool:
	if _transient_session_active:
		return true
	_reset_state()
	var loaded_state: Dictionary = _build_default_state()
	var saved_state: Dictionary = _load_saved_state()
	if not saved_state.is_empty():
		loaded_state = _merge_state(loaded_state, saved_state)
	state = loaded_state
	_sync_unlocks_from_config()
	_loaded = true
	save_state()
	state_loaded.emit(true)
	state_changed.emit()
	return true


func begin_transient_session() -> void:
	if _transient_session_active:
		return
	_transient_session_snapshot = {
		"state": state.duplicate(true),
		"loaded": _loaded,
	}
	_transient_session_active = true
	state = _build_default_state()
	_sync_unlocks_from_config()


func end_transient_session() -> void:
	if not _transient_session_active:
		return
	var snapshot_state: Variant = _transient_session_snapshot.get("state", {})
	if snapshot_state is Dictionary:
		state = (snapshot_state as Dictionary).duplicate(true)
	else:
		_reset_state()
	_loaded = bool(_transient_session_snapshot.get("loaded", false))
	_transient_session_snapshot.clear()
	_transient_session_active = false
	state_changed.emit()


func save_state() -> bool:
	if _transient_session_active:
		return true
	if state.is_empty():
		_reset_state()
	if not _ensure_save_directory():
		return false
	var serialized_state := JSON.stringify(_sanitize_state(state), "  ")
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		push_error("[CampProgression] failed to open temp save file: %s" % TEMP_PATH)
		return false
	temp_file.store_string(serialized_state)
	temp_file = null
	if FileAccess.file_exists(SAVE_PATH):
		var backup_file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup_file == null:
			push_warning("[CampProgression] failed to open backup file: %s" % BACKUP_PATH)
		else:
			backup_file.store_string(FileAccess.get_file_as_string(SAVE_PATH))
			backup_file = null
		var remove_error := DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			push_error("[CampProgression] failed to replace save file: %s" % SAVE_PATH)
			DirAccess.remove_absolute(TEMP_PATH)
			return false
	var rename_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		push_error("[CampProgression] failed to finalize save file: %s" % SAVE_PATH)
		if FileAccess.file_exists(BACKUP_PATH):
			var restore_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			if restore_file != null:
				restore_file.store_string(FileAccess.get_file_as_string(BACKUP_PATH))
		DirAccess.remove_absolute(TEMP_PATH)
		return false
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


func get_building_unlock_condition(building_id: String) -> Dictionary:
	var record := get_building_record(building_id)
	if record.is_empty():
		return {}
	var condition: Variant = record.get("unlock_condition", {})
	return condition if condition is Dictionary else {}


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


func can_purchase_building_unlock(building_id: String) -> bool:
	if is_building_unlocked(building_id) or is_building_initially_unlocked(building_id):
		return false
	var condition := get_building_unlock_condition(building_id)
	if condition.is_empty():
		return false
	if condition.has("currency") and str(condition.get("currency", "")) != "camp_currency":
		return false
	if not condition.has("cost"):
		return false
	return get_camp_currency() >= int(condition.get("cost", 0))


func purchase_building_unlock(building_id: String) -> bool:
	if not can_purchase_building_unlock(building_id):
		return false
	var condition := get_building_unlock_condition(building_id)
	var cost := int(condition.get("cost", 0))
	_set_camp_currency_value(get_camp_currency() - cost)
	var building_levels: Dictionary = state.get("building_levels", {})
	building_levels[building_id] = maxi(int(building_levels.get(building_id, 0)), 1)
	state["building_levels"] = building_levels
	_sync_unlocks_from_config()
	_save_and_notify(building_id)
	return true


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
	_sync_unlocks_from_config()
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
		if not (record is Dictionary):
			continue
		for option in record.get("upgrade_options", []):
			if option is Dictionary and str(option.get("id", "")) == option_id:
				return option
	return {}


func get_upgrade_option_parent_building_id(option_id: String) -> String:
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if building_id.is_empty():
			continue
		for option in record.get("upgrade_options", []):
			if option is Dictionary and str(option.get("id", "")) == option_id:
				return building_id
	return ""


func can_purchase_upgrade(option_id: String) -> bool:
	var option := get_upgrade_option_record(option_id)
	if option.is_empty():
		return false
	var owner_building_id := get_upgrade_option_parent_building_id(option_id)
	if owner_building_id.is_empty():
		return false
	if option.has("currency") and str(option.get("currency", "")) != "camp_currency":
		return false
	var required_building_level := int(option.get("required_building_level", 0))
	if required_building_level > 0 and get_building_level(owner_building_id) < required_building_level:
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
	_set_camp_currency_value(get_camp_currency() - cost)
	var upgrade_levels: Dictionary = state.get("upgrade_levels", {})
	upgrade_levels[option_id] = get_upgrade_option_level(option_id) + 1
	state["upgrade_levels"] = upgrade_levels
	_save_and_notify(option_id)
	return true


func get_camp_currency() -> int:
	var currencies: Variant = state.get("currencies", {})
	if currencies is Dictionary:
		return int((currencies as Dictionary).get("camp_currency", 0))
	return 0


func set_camp_currency(amount: int) -> void:
	_set_camp_currency_value(amount)
	_save_and_notify("camp_currency")


func add_camp_currency(amount: int) -> void:
	set_camp_currency(get_camp_currency() + amount)


func clear_save_and_refund() -> int:
	var refund := get_camp_currency()
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		var building_level := get_building_level(building_id)
		if building_level > 0 and not bool(record.get("initial_unlocked", false)):
			var unlock_condition: Variant = record.get("unlock_condition", {})
			if unlock_condition is Dictionary:
				refund += int((unlock_condition as Dictionary).get("cost", 0))
		for option in record.get("upgrade_options", []):
			if not (option is Dictionary):
				continue
			var option_id := str(option.get("id", ""))
			refund += get_upgrade_option_level(option_id) * int(option.get("cost", 0))

	var settings := (state.get("settings", {}) as Dictionary).duplicate(true)
	_reset_state()
	state["settings"] = settings
	_set_camp_currency_value(refund)
	if not _transient_session_active:
		save_state()
	state_changed.emit()
	return refund


func apply_final_settlement(camp_currency_gain: int) -> void:
	_set_camp_currency_value(get_camp_currency() + maxi(camp_currency_gain, 0))
	if not _transient_session_active:
		save_state()
	state_changed.emit()


func get_volume_setting(setting_key: String, default_value: int = 100) -> int:
	var sanitized_key := setting_key.strip_edges()
	if sanitized_key.is_empty() or not DEFAULT_VOLUME_SETTINGS.has(sanitized_key):
		return default_value
	var settings: Dictionary = state.get("settings", {})
	return int(settings.get(sanitized_key, default_value))


func set_volume_setting(setting_key: String, volume_percent: int) -> void:
	var sanitized_key := setting_key.strip_edges()
	if sanitized_key.is_empty() or not DEFAULT_VOLUME_SETTINGS.has(sanitized_key):
		return
	var settings: Dictionary = state.get("settings", {})
	settings[sanitized_key] = clampi(volume_percent, 0, 100)
	state["settings"] = settings
	if not _transient_session_active:
		save_state()
	state_changed.emit()


func get_volume_settings() -> Dictionary:
	return _sanitize_settings_dictionary(state.get("settings", {}))


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
	for record in get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if building_id.is_empty():
			continue
		building_levels[building_id] = 1 if bool(record.get("initial_unlocked", false)) else 0
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": PROFILE_ID,
		"currencies": {
			"camp_currency": 0,
		},
		"building_levels": building_levels,
		"upgrade_levels": {},
		"settings": DEFAULT_VOLUME_SETTINGS.duplicate(true),
	}


func _load_saved_state() -> Dictionary:
	var saved_state := _read_state_file(SAVE_PATH)
	if saved_state.is_empty():
		saved_state = _read_state_file(BACKUP_PATH)
	if saved_state.is_empty() and FileAccess.file_exists(LEGACY_SAVE_PATH):
		saved_state = _read_state_file(LEGACY_SAVE_PATH)
	return saved_state


func _read_state_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var raw_text := FileAccess.get_file_as_string(file_path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return parsed
	push_warning("[CampProgression] invalid save file, fallback to defaults: %s" % file_path)
	return {}


func _merge_state(default_state: Dictionary, saved_state: Dictionary) -> Dictionary:
	var merged: Dictionary = default_state.duplicate(true)
	if saved_state.has("schema_version"):
		merged["schema_version"] = int(saved_state.get("schema_version", SCHEMA_VERSION))
	if saved_state.has("profile_id"):
		merged["profile_id"] = str(saved_state.get("profile_id", PROFILE_ID))
	if saved_state.has("building_levels"):
		var building_levels: Dictionary = merged.get("building_levels", {}).duplicate(true)
		var saved_building_levels := _sanitize_string_int_dictionary(saved_state.get("building_levels", {}))
		for key in saved_building_levels.keys():
			building_levels[key] = int(saved_building_levels[key])
		merged["building_levels"] = building_levels
	if saved_state.has("upgrade_levels"):
		merged["upgrade_levels"] = _sanitize_string_int_dictionary(saved_state.get("upgrade_levels", {}))
	var currencies: Dictionary = merged.get("currencies", {}).duplicate(true)
	if saved_state.has("currencies") and saved_state["currencies"] is Dictionary:
		currencies["camp_currency"] = maxi(int((saved_state["currencies"] as Dictionary).get("camp_currency", currencies.get("camp_currency", 0))), 0)
	elif saved_state.has("camp_currency"):
		currencies["camp_currency"] = maxi(int(saved_state.get("camp_currency", 0)), 0)
	merged["currencies"] = currencies
	if saved_state.has("settings"):
		merged["settings"] = _sanitize_settings_dictionary(saved_state.get("settings", {}))
	return _sanitize_state(merged)


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
			if _unlock_condition_met(record, building_levels):
				building_levels[building_id] = 1
				changed = true
	state["building_levels"] = building_levels


func _unlock_condition_met(record: Dictionary, building_levels: Dictionary) -> bool:
	var condition: Variant = record.get("unlock_condition", {})
	if not (condition is Dictionary):
		return false
	var building_id := str(condition.get("building", ""))
	if building_id.is_empty():
		return false
	var required_level := int(condition.get("level", 1))
	return int(building_levels.get(building_id, 0)) >= required_level


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
	var result: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"profile_id": PROFILE_ID,
		"currencies": {
			"camp_currency": 0,
		},
		"building_levels": {},
		"upgrade_levels": {},
		"settings": DEFAULT_VOLUME_SETTINGS.duplicate(true),
	}
	if raw_state.has("schema_version"):
		result["schema_version"] = int(raw_state.get("schema_version", SCHEMA_VERSION))
	if raw_state.has("profile_id"):
		result["profile_id"] = str(raw_state.get("profile_id", PROFILE_ID))
	if raw_state.has("building_levels"):
		result["building_levels"] = _sanitize_string_int_dictionary(raw_state.get("building_levels", {}))
	if raw_state.has("upgrade_levels"):
		result["upgrade_levels"] = _sanitize_string_int_dictionary(raw_state.get("upgrade_levels", {}))
	if raw_state.has("currencies") and raw_state["currencies"] is Dictionary:
		result["currencies"]["camp_currency"] = maxi(int((raw_state["currencies"] as Dictionary).get("camp_currency", 0)), 0)
	elif raw_state.has("camp_currency"):
		result["currencies"]["camp_currency"] = maxi(int(raw_state.get("camp_currency", 0)), 0)
	if raw_state.has("settings"):
		result["settings"] = _sanitize_settings_dictionary(raw_state.get("settings", {}))
	return result


func _sanitize_string_int_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for key in value.keys():
		result[str(key)] = maxi(int(value[key]), 0)
	return result


func _sanitize_settings_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT_VOLUME_SETTINGS.duplicate(true)
	if not (value is Dictionary):
		return result
	for key in DEFAULT_VOLUME_SETTINGS.keys():
		if value.has(key):
			result[key] = clampi(int(value.get(key, result[key])), 0, 100)
	return result


func _set_camp_currency_value(amount: int) -> void:
	var currencies: Dictionary = state.get("currencies", {})
	currencies["camp_currency"] = maxi(amount, 0)
	state["currencies"] = currencies


func _ensure_save_directory() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[CampProgression] failed to create save directory: %s" % SAVE_DIR)
		return false
	return true


func _reset_state() -> void:
	state = _build_default_state()


func _save_and_notify(source_id: String) -> void:
	if not _transient_session_active:
		save_state()
	state_changed.emit()
	if not source_id.is_empty() and source_id.begins_with("camp_"):
		building_changed.emit(source_id)
