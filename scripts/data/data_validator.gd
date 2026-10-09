extends RefCounted
class_name DataValidator

const REQUIRED_TABLES: Array[String] = [
	"weapons",
	"relics",
	"bonds",
	"characters",
	"enemies",
	"erosion_pressure_rules",
	"enemy_adaptation_rules",
	"camp_buildings",
	"waves",
	"drop_tables",
	"augmentations",
]

const TABLE_REQUIRED_FIELDS: Dictionary = {
	"weapons": ["id", "display_name", "icon", "rarity", "tags", "weapon_type", "load_cost", "max_level", "attack_interval_ms", "attack_range", "hit_radius", "projectile_speed", "spread_angle", "base_stats", "level_upgrades"],
	"relics": ["id", "display_name", "rarity", "tags", "effects"],
	"bonds": ["id", "name", "bond_tag", "thresholds"],
	"characters": ["id", "icon", "base_stats", "start_weapons"],
	"enemies": ["id", "base_stats", "drop_table_id"],
	"erosion_pressure_rules": ["id", "erosion_full_at", "max_hp_bonus_percent", "damage_bonus_percent", "armor_bonus_percent", "growth_steps"],
	"enemy_adaptation_rules": ["id", "first_effective_wave", "fast_kill_ms", "minimum_observed_seconds", "fast_ratio_percent", "slow_ratio_percent", "slow_waves_to_relax", "normal", "elite"],
	"camp_buildings": ["id", "name", "levels", "upgrade_options"],
	"waves": ["id", "duration_seconds", "spawn_groups"],
	"drop_tables": ["id", "entries"],
	"augmentations": ["id", "display_name", "category", "rarity", "effect_ids", "modifiers"],
}

const MODIFIER_REQUIRED_FIELDS: Array[String] = [
	"id",
	"source_type",
	"source_id",
	"target_scope",
	"stat",
	"operation",
	"value",
	"duration",
]

const VALID_DROP_TYPES: Array[String] = ["exp_orb", "relic", "health_pack", "augmentation"]
const VALID_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
const BOND_ALLOWED_RARITIES: Array[String] = ["epic", "mythic", "legendary"]
const VALID_RELIC_RUNTIME_TRIGGERS: Array[String] = [
	BattleFinanceSystem.TRIGGER_ON_ACQUIRE,
	BattleFinanceSystem.TRIGGER_WAVE_START,
	BattleFinanceSystem.TRIGGER_DEPOSIT,
	BattleFinanceSystem.TRIGGER_WAVE_END,
	BattleFinanceSystem.TRIGGER_INTEREST_SETTLE,
	BattleFinanceSystem.TRIGGER_INTEREST_SUCCESS,
	BattleFinanceSystem.TRIGGER_PRINCIPAL_ZERO,
	BattleFinanceSystem.TRIGGER_DERIVED,
	BattleFinanceSystem.TRIGGER_ENEMY_KILL,
	BattleFinanceSystem.TRIGGER_DYNAMIC,
	BattleFinanceSystem.TRIGGER_ON_REVIVE,
	BattleFinanceSystem.TRIGGER_SHIELD_BREAK,
	BattleFinanceSystem.TRIGGER_LETHAL_DAMAGE,
]
const VALID_RELIC_RUNTIME_EFFECTS: Array[String] = [
	BattleFinanceSystem.EFFECT_ADD_PRINCIPAL_FLAT,
	BattleFinanceSystem.EFFECT_ADD_PRINCIPAL_FROM_GOLD_PERCENT,
	BattleFinanceSystem.EFFECT_ADD_PRINCIPAL_PER_WAVE,
	BattleFinanceSystem.EFFECT_SETTLE_INTEREST_ONCE,
	BattleFinanceSystem.EFFECT_DIVIDEND_DOUBLE,
	BattleFinanceSystem.EFFECT_ADD_INTEREST_RATE_BONUS,
	BattleFinanceSystem.EFFECT_SETTLE_INTEREST_EVERY_N_WAVES,
	BattleFinanceSystem.EFFECT_EXTRA_SETTLEMENT_PER_WAVE,
	BattleFinanceSystem.EFFECT_INTEREST_RATE_ON_WAVE_DEPOSIT,
	BattleFinanceSystem.EFFECT_ADD_EROSION,
	BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PRINCIPAL,
	BattleFinanceSystem.EFFECT_DERIVED_INTEREST_FROM_EROSION,
	BattleFinanceSystem.EFFECT_BANKRUPTCY_RECOVERY,
	BattleFinanceSystem.EFFECT_TIP_TRAY_DROP,
	BattleFinanceSystem.EFFECT_ADD_STAT,
	BattleFinanceSystem.EFFECT_GRANT_SHIELD,
	BattleFinanceSystem.EFFECT_HEAL,
	BattleFinanceSystem.EFFECT_CONDITIONAL_STAT,
	BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PLAYER_STAT,
	BattleFinanceSystem.EFFECT_BLOCK_STAT_INCREASE,
	BattleFinanceSystem.EFFECT_PRINCIPAL_REVIVE,
]

var errors: Array[String] = []
var warnings: Array[String] = []


func validate_all(tables: Dictionary, records_by_id: Dictionary) -> bool:
	# 统一执行基础校验、类型校验和跨表引用校验。
	errors.clear()
	warnings.clear()

	_validate_required_tables(tables)
	for table_name in tables.keys():
		_validate_table(str(table_name), tables[table_name])
		_validate_integer_values(tables[table_name], str(table_name))
		_validate_stat_references(tables[table_name], str(table_name))

	_validate_weapon_records(tables.get("weapons", []), records_by_id)
	_validate_relic_records(tables.get("relics", []), records_by_id)
	_validate_bond_records(tables.get("bonds", []))
	_validate_character_records(tables.get("characters", []), records_by_id)
	_validate_enemy_records(tables.get("enemies", []), records_by_id)
	_validate_erosion_pressure_records(tables.get("erosion_pressure_rules", []))
	_validate_enemy_adaptation_records(tables.get("enemy_adaptation_rules", []))
	_validate_camp_building_records(tables.get("camp_buildings", []), records_by_id)
	_validate_wave_records(tables.get("waves", []), records_by_id)
	_validate_drop_table_records(tables.get("drop_tables", []), records_by_id)
	_validate_augmentation_records(tables.get("augmentations", []))

	return errors.is_empty()


func get_errors() -> Array[String]:
	return errors.duplicate()


func get_warnings() -> Array[String]:
	return warnings.duplicate()


func _validate_required_tables(tables: Dictionary) -> void:
	for table_name in REQUIRED_TABLES:
		if not tables.has(table_name):
			errors.append("Missing loaded config table: %s" % table_name)


func _validate_table(table_name: String, records: Variant) -> void:
	if not (records is Array):
		errors.append("%s must be an array." % table_name)
		return

	var seen_ids := {}
	var required_fields: Array = TABLE_REQUIRED_FIELDS.get(table_name, [])
	for record_index in records.size():
		var record: Variant = records[record_index]
		var record_path := "%s[%d]" % [table_name, record_index]
		if not (record is Dictionary):
			errors.append("%s must be an object." % record_path)
			continue

		_validate_required_fields(record, required_fields, record_path)
		var record_id := str(record.get("id", ""))
		if record_id.strip_edges().is_empty():
			errors.append("%s.id cannot be empty." % record_path)
			continue
		if seen_ids.has(record_id):
			errors.append("Duplicate id in %s: %s" % [table_name, record_id])
		seen_ids[record_id] = true


func _validate_required_fields(record: Dictionary, required_fields: Array, path: String) -> void:
	for field_name in required_fields:
		if not record.has(field_name):
			errors.append("Missing required field: %s.%s" % [path, field_name])


func _validate_bool(record: Dictionary, field_name: String, path: String) -> void:
	if not record.has(field_name):
		return
	if not (record[field_name] is bool):
		errors.append("%s.%s must be a bool." % [path, field_name])


func _validate_non_empty_text(record: Dictionary, field_name: String, path: String) -> void:
	if not record.has(field_name):
		return
	if str(record.get(field_name, "")).strip_edges().is_empty():
		errors.append("%s.%s cannot be empty." % [path, field_name])


func _validate_non_negative_int(record: Dictionary, field_name: String, path: String) -> void:
	if not record.has(field_name):
		return
	var value: Variant = record[field_name]
	if not (value is int or value is float):
		errors.append("%s.%s must be a number." % [path, field_name])
		return
	if int(value) != value or int(value) < 0:
		errors.append("%s.%s must be a non-negative integer." % [path, field_name])


func _validate_integer_values(value_data: Variant, path: String) -> void:
	match typeof(value_data):
		TYPE_DICTIONARY:
			for key in value_data.keys():
				if str(key) == "value" and value_data.has("stat") and not StatDefinitions.is_integer_stat(str(value_data.get("stat", ""))):
					continue
				_validate_integer_values(value_data[key], "%s.%s" % [path, key])
		TYPE_ARRAY:
			for index in value_data.size():
				_validate_integer_values(value_data[index], "%s[%d]" % [path, index])
		TYPE_FLOAT:
			if _allows_fractional_config_value(path):
				return
			if not is_equal_approx(value_data, roundf(value_data)):
				errors.append("Numeric config value must be integer: %s = %s" % [path, value_data])
		TYPE_INT:
			pass
		_:
			pass


func _allows_fractional_config_value(path: String) -> bool:
	if path.begins_with("characters[") and path.ends_with(".combat_visuals.walk_fps"):
		return true
	if path.begins_with("drop_tables[") and path.ends_with(".augmentation_chance_percent"):
		return true
	if path.begins_with("weapons[") and (path.ends_with(".flail_outer_threshold") or path.ends_with(".flail_outer_multiplier")):
		return true
	if path.begins_with("enemies[") and path.ends_with(".elite_profile.dash_half_width"):
		return true
	if path.begins_with("weapons[") and path.ends_with(".principal_damage_coefficient"):
		return true
	if path.begins_with("weapons[") and (path.ends_with(".grenade_flight_seconds") or path.ends_with(".player_damage_coefficient") or path.ends_with(".grenade_split_radius_multiplier") or path.ends_with(".grenade_split_flight_seconds")):
		return true
	return (path.contains(".runtime_effects[") and (
		path.ends_with(".value") or path.ends_with(".principal_percent")
	)) or (path.contains(".runtime_effects[") and (
		path.ends_with(".per_unit") or path.ends_with(".divisor")
	)) or path.contains("augmentations[") and path.contains(".modifiers[") and (
		path.ends_with(".value") or path.contains(".value[")
	) or path.contains("augmentations[") and (
		path.contains(".effect_parameters.") or path.contains(".instance_parameter_ranges[")
	) or path.contains("weapons[") and path.ends_with(".plasma_tick_interval") or path.contains("weapons[") and (
		path.ends_with(".plasma_rotation_speed") or path.ends_with(".plasma_arc_jitter")
	) or path.contains("camp_buildings[") and path.contains(".upgrade_options[") and path.ends_with(".value_per_level")


func _validate_stat_references(value_data: Variant, path: String) -> void:
	match typeof(value_data):
		TYPE_DICTIONARY:
			if value_data.has("stat"):
				var stat_id := str(value_data["stat"])
				if not StatDefinitions.has_stat(stat_id):
					errors.append("Unknown stat reference in %s: %s" % [path, stat_id])
			for key in value_data.keys():
				_validate_stat_references(value_data[key], "%s.%s" % [path, key])
		TYPE_ARRAY:
			for index in value_data.size():
				_validate_stat_references(value_data[index], "%s[%d]" % [path, index])
		_:
			pass


func _validate_weapon_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "weapons[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_rarity(record, path)
		_validate_bond_rarity_rule(record, path, records_by_id)
		if not record.has("description") or str(record.get("description", "")).strip_edges().is_empty():
			errors.append("%s.description cannot be empty." % path)
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		_validate_weapon_runtime_fields(record, path)
		_validate_weapon_level_upgrades(record, path)


func _validate_weapon_runtime_fields(record: Dictionary, path: String) -> void:
	var behavior := str(record.get("projectile_behavior", ""))
	var timed_fields: Array = []
	if behavior == "copper_lamp":
		timed_fields = ["lamp_spray_ms", "lamp_tick_ms", "lamp_proc_ms", "lamp_proc_percent", "lamp_cone_degrees", "lamp_turn_degrees_per_second"]
		if str(record.get("attack_kind", "")) != "element" or int(record.get("lamp_cone_degrees", 0)) > 90:
			errors.append("%s lamp requires elemental damage and a narrow cone." % path)
	elif behavior == "mutant_tentacle":
		timed_fields = ["tentacle_hit_ms", "tentacle_motion_ms"]
		if int(record.get("tentacle_hit_ms", 0)) >= int(record.get("tentacle_motion_ms", 0)):
			errors.append("%s tentacle hit must precede recovery." % path)
	elif behavior == "earth_hammer":
		timed_fields = ["hammer_appear_ms", "hammer_slam_ms", "hammer_contact_ms", "hammer_fade_ms", "ground_node_count", "ground_node_interval_ms", "ground_node_spacing", "ground_first_offset", "ground_branch_length"]
		if int(record.get("ground_node_count", 0)) > 8:
			errors.append("%s ground nodes exceed the supported limit." % path)
	if not timed_fields.is_empty():
		for field in timed_fields:
			_validate_non_negative_int(record, field, path)
			if int(record.get(field, 0)) <= 0:
				errors.append("%s.%s must be positive." % [path, field])
		if float(record.get("attack_range", 0)) <= 0 or float(record.get("hit_radius", 0)) <= 0 or not "pierce" in record.get("unsupported_effects", []):
			errors.append("%s requires positive reach/width and must reject ineffective pierce." % path)
		if behavior != "copper_lamp" and str(record.get("attack_kind", "")) != "melee":
			errors.append("%s requires melee damage." % path)
	_validate_non_negative_int(record, "load_cost", path)
	_validate_non_negative_int(record, "attack_interval_ms", path)
	_validate_non_negative_int(record, "active_cooldown_ms", path)
	if int(record.get("active_cooldown_ms", 0)) <= 0:
		errors.append("%s.active_cooldown_ms must be positive; it starts after execution." % path)
	_validate_non_negative_int(record, "attack_range", path)
	_validate_non_negative_int(record, "hit_radius", path)
	_validate_non_negative_int(record, "projectile_speed", path)
	_validate_non_negative_int(record, "spread_angle", path)
	if record.has("projectile_spacing_degrees"):
		var gap: Variant = record.projectile_spacing_degrees
		if not (gap is int or gap is float) or float(gap) <= 0 or float(gap) > 180:
			errors.append("%s.projectile_spacing_degrees must be greater than zero and at most 180." % path)
	if str(record.get("projectile_behavior", "")) == "camp_dagger":
		if str(record.get("attack_kind", "")) != "melee" or float(record.get("attack_range", 0)) <= 0 or float(record.get("hit_radius", 0)) <= 0:
			errors.append("%s dagger requires melee damage and positive reach/contact radius." % path)
		var angle := float(record.get("dagger_arc_degrees", 0))
		if angle <= 0 or angle > 180:
			errors.append("%s.dagger_arc_degrees must be in (0,180]." % path)
		var duration := 0
		for field in ["dagger_windup_ms", "dagger_sweep_ms", "dagger_recover_ms", "dagger_split_window_ms"]:
			_validate_non_negative_int(record, field, path)
			if int(record.get(field, 0)) <= 0:
				errors.append("%s.%s must be positive." % [path, field])
			duration += int(record.get(field, 0))
		# Active actions finish before cooldown starts; combo length is independent.
		if not "pierce" in record.get("unsupported_effects", []):
			errors.append("%s must reject pierce for contact slashes." % path)
	if str(record.get("projectile_behavior", "")) == "nightwatch_spear":
		if not "pierce" in record.get("unsupported_effects", []):
			errors.append("%s must reject pierce for inherent line piercing." % path)
		if str(record.get("attack_kind", "")) != "melee" or float(record.get("attack_range", 0)) <= 0 or float(record.get("hit_radius", 0)) <= 0 or float(record.get("projectile_speed", 0)) <= 0:
			errors.append("%s spear requires melee damage and positive reach, width and shard speed." % path)
		for field in ["spear_windup_ms", "spear_extend_ms", "spear_recover_ms"]:
			_validate_non_negative_int(record, field, path)
			if int(record.get(field, 0)) <= 0:
				errors.append("%s.%s must be positive." % [path, field])
	_validate_non_negative_int(record, "attachment_slots", path)
	if int(record.get("attachment_slots", 0)) != WeaponInstance.get_attachment_slots_for_rarity(str(record.get("rarity", "common"))):
		errors.append("%s.attachment_slots must match rarity: common/uncommon=1, rare or higher=2." % path)
	if str(record.get("projectile_behavior", "")) == "meteor_flail":
		if str(record.get("attack_kind", "")) != "melee" or float(record.get("attack_range", 0)) <= 0 or float(record.get("hit_radius", 0)) <= 0:
			errors.append("%s requires melee damage and positive flail reach/head radius." % path)
		var threshold := float(record.get("flail_outer_threshold", 0))
		if threshold <= 0 or threshold > 1 or float(record.get("flail_outer_multiplier", 0)) < 1:
			errors.append("%s requires an outer threshold in (0,1] and a multiplier >= 1." % path)
		if not "pierce" in record.get("unsupported_effects", []):
			errors.append("%s must reject pierce for contact sweeps." % path)
	if str(record.get("projectile_behavior", "")) == "ritual_domain":
		_validate_non_negative_int(record, "domain_minor_axis", path)
		if str(record.get("attack_kind", "")) != "element" or float(record.get("domain_minor_axis", 0)) <= 0 or float(record.get("attack_range", 0)) <= 0:
			errors.append("%s requires elemental damage and positive ellipse axes." % path)
	if str(record.get("projectile_behavior", "")) == "coin":
		for field in ["player_damage_coefficient", "principal_damage_coefficient"]:
			var value: Variant = record.get(field)
			if not (value is int or value is float) or float(value) < 0.0:
				errors.append("%s.%s must be a non-negative number." % [path, field])
		if str(record.get("attack_kind", "")) != "ranged" or float(record.get("projectile_speed", 0)) <= 0:
			errors.append("%s requires ranged damage and positive projectile speed." % path)
	if str(record.get("projectile_behavior", "")) == "grenade":
		for field in ["grenade_flight_seconds", "grenade_blast_radius", "player_damage_coefficient", "grenade_split_radius_multiplier", "grenade_split_flight_seconds", "grenade_split_arc_height"]:
			var value: Variant = record.get(field)
			if not (value is int or value is float) or float(value) <= 0.0:
				errors.append("%s.%s must be a positive number." % [path, field])
		var unsupported: Variant = record.get("unsupported_effects", [])
		if not (unsupported is Array) or not unsupported.has("pierce") or unsupported.has("split"):
			errors.append("%s must reject pierce and support split for grenades." % path)
	if record.has("hit_sfx") and not (record["hit_sfx"] is String):
		errors.append("%s.hit_sfx must be a string resource path." % path)


func _validate_weapon_level_upgrades(record: Dictionary, path: String) -> void:
	var max_level := int(record.get("max_level", 1))
	var upgrades: Variant = record.get("level_upgrades", {})
	if not (upgrades is Dictionary):
		errors.append("%s.level_upgrades must be an object." % path)
		return
	for level_key in upgrades.keys():
		var level := int(str(level_key))
		if level < 2 or level > max_level:
			warnings.append("%s.level_upgrades.%s is outside 2..max_level." % [path, str(level_key)])
		var upgrade_entry: Variant = upgrades[level_key]
		if not (upgrade_entry is Dictionary):
			errors.append("%s.level_upgrades.%s must be an object with rarity and effects." % [path, str(level_key)])
			continue
		var upgrade_path := "%s.level_upgrades.%s" % [path, str(level_key)]
		if not upgrade_entry.has("rarity"):
			errors.append("Missing required field: %s.rarity" % upgrade_path)
		else:
			_validate_rarity(upgrade_entry, upgrade_path)
		if not upgrade_entry.has("description") or str(upgrade_entry.get("description", "")).strip_edges().is_empty():
			errors.append("%s.description cannot be empty." % upgrade_path)
		var upgrade_list: Variant = upgrade_entry.get("effects", [])
		if not (upgrade_list is Array):
			errors.append("%s.effects must be an array." % upgrade_path)
			continue
		for upgrade_index in upgrade_list.size():
			var upgrade: Variant = upgrade_list[upgrade_index]
			var effect_path := "%s.effects[%d]" % [upgrade_path, upgrade_index]
			if not (upgrade is Dictionary):
				errors.append("%s must be an object." % effect_path)
				continue
			if not upgrade.has("value"):
				errors.append("Missing required field: %s.value" % effect_path)
			if not upgrade.has("stat") and not upgrade.has("field"):
				errors.append("%s must define stat or field." % effect_path)


func _validate_relic_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "relics[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_rarity(record, path)
		if not record.has("description") or str(record.get("description", "")).strip_edges().is_empty():
			errors.append("%s.description cannot be empty." % path)
		_validate_bond_rarity_rule(record, path, records_by_id)
		if record.has("max_stack"):
			_validate_non_negative_int(record, "max_stack", path)
		var effects: Variant = record.get("effects", [])
		if not (effects is Array):
			errors.append("%s.effects must be an array." % path)
			continue
		for effect_index in effects.size():
			_validate_modifier_record(effects[effect_index], "%s.effects[%d]" % [path, effect_index])
		var runtime_effects: Variant = record.get("runtime_effects", [])
		if not (runtime_effects is Array):
			errors.append("%s.runtime_effects must be an array." % path)
			continue
		for runtime_index in runtime_effects.size():
			_validate_relic_runtime_effect(runtime_effects[runtime_index], "%s.runtime_effects[%d]" % [path, runtime_index])


func _validate_bond_rarity_rule(record: Dictionary, path: String, records_by_id: Dictionary) -> void:
	# 羁绊只允许出现在高稀有度（史诗/罕见/传说）的武器与遗物上。
	_validate_reference(record, "bond_id", "bonds", records_by_id, path)
	if not record.has("bond_id"):
		return
	var bond_id := str(record.get("bond_id", "")).strip_edges()
	if bond_id.is_empty():
		return
	var rarity := str(record.get("rarity", ""))
	if not BOND_ALLOWED_RARITIES.has(rarity):
		errors.append("%s.bond_id is only allowed on epic or higher rarity (current: %s)" % [path, rarity])


func _validate_relic_runtime_effect(effect: Variant, path: String) -> void:
	if not (effect is Dictionary):
		errors.append("%s must be an object." % path)
		return
	var effect_data: Dictionary = effect
	_validate_required_fields(effect_data, ["trigger", "effect"], path)
	if effect_data.has("trigger") and not VALID_RELIC_RUNTIME_TRIGGERS.has(str(effect_data["trigger"])):
		warnings.append("Unknown relic runtime trigger in %s: %s" % [path, str(effect_data["trigger"])])
	if effect_data.has("effect") and not VALID_RELIC_RUNTIME_EFFECTS.has(str(effect_data["effect"])):
		warnings.append("Unknown relic runtime effect in %s: %s" % [path, str(effect_data["effect"])])
	for key in ["value", "else_value", "threshold", "value_percent", "double_chance_percent", "zero_chance_percent", "principal_percent", "value_per_wave", "chance_percent", "gold_multiplier", "divisor", "per_unit", "amount", "minimum_deposit", "max_bonus"]:
		if not effect_data.has(key):
			continue
		if not (effect_data[key] is int or effect_data[key] is float):
			errors.append("%s.%s must be a number." % [path, key])
			continue
		var allows_negative_value: bool = key == "threshold" or (key == "per_unit" and str(effect_data.get("effect", "")) == BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PRINCIPAL) or (key in ["value", "else_value"] and str(effect_data.get("effect", "")) in [
			BattleFinanceSystem.EFFECT_ADD_STAT,
			BattleFinanceSystem.EFFECT_CONDITIONAL_STAT,
		])
		if float(effect_data[key]) < 0.0 and not allows_negative_value:
			errors.append("%s.%s must be greater than or equal to 0." % [path, key])
	if effect_data.has("max_bonus"):
		if str(effect_data.get("effect", "")) != BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PRINCIPAL:
			errors.append("%s.max_bonus requires principal-stat derivation." % path)
		if (effect_data.max_bonus is int or effect_data.max_bonus is float) and not is_finite(float(effect_data.max_bonus)):
			errors.append("%s.max_bonus must be finite." % path)
	if str(effect_data.get("effect", "")) == BattleFinanceSystem.EFFECT_ADD_STAT and effect_data.has("condition"):
		_validate_required_fields(effect_data, ["value", "threshold"], path)
		if str(effect_data.condition) not in ["humanity_below", "hp_percent_below"]:
			errors.append("%s.condition is not a supported stat condition." % path)
	if effect_data.has("else_value") and not effect_data.has("condition"):
		errors.append("%s.else_value requires a condition." % path)
	if str(effect_data.get("effect", "")) == BattleFinanceSystem.EFFECT_CONDITIONAL_STAT:
		_validate_required_fields(effect_data, ["condition", "threshold", "stat", "value"], path)
		if str(effect_data.get("condition", "")) not in ["humanity_below", "hp_percent_below", "stationary_seconds"]:
			errors.append("%s.condition is not a supported stat condition." % path)
		if str(effect_data.get("trigger", "")) != BattleFinanceSystem.TRIGGER_DYNAMIC:
			errors.append("%s requires the dynamic trigger." % path)
		if str(effect_data.get("condition", "")) == "stationary_seconds":
			var threshold: Variant = effect_data.get("threshold")
			if (threshold is int or threshold is float) and (not is_finite(float(threshold)) or float(threshold) <= 0.0):
				errors.append("%s.threshold must be finite and positive." % path)
	if effect_data.has("positive_source_only"):
		if not effect_data.positive_source_only is bool:
			errors.append("%s.positive_source_only must be a boolean." % path)
		if str(effect_data.get("effect", "")) != BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PLAYER_STAT:
			errors.append("%s.positive_source_only requires player-stat derivation." % path)
	if str(effect_data.get("effect", "")) == BattleFinanceSystem.EFFECT_INTEREST_RATE_ON_WAVE_DEPOSIT:
		_validate_required_fields(effect_data, ["minimum_deposit", "value"], path)
		_validate_non_negative_int(effect_data, "minimum_deposit", path)
		if (effect_data.get("minimum_deposit") is int or effect_data.get("minimum_deposit") is float) and float(effect_data.minimum_deposit) <= 0.0:
			errors.append("%s.minimum_deposit must be positive." % path)
		if str(effect_data.get("trigger", "")) != BattleFinanceSystem.TRIGGER_DERIVED:
			errors.append("%s requires the derived trigger." % path)
	if str(effect_data.get("effect", "")) == BattleFinanceSystem.EFFECT_PRINCIPAL_REVIVE:
		_validate_required_fields(effect_data, ["minimum_principal", "principal_cost", "health_percent", "max_uses"], path)
		for field in ["minimum_principal", "principal_cost", "health_percent", "max_uses"]:
			_validate_non_negative_int(effect_data, field, path)
			if (effect_data.get(field) is int or effect_data.get(field) is float) and float(effect_data[field]) <= 0.0:
				errors.append("%s.%s must be positive." % [path, field])
		if str(effect_data.get("trigger", "")) != BattleFinanceSystem.TRIGGER_LETHAL_DAMAGE:
			errors.append("%s requires the lethal_damage trigger." % path)
		if (effect_data.get("health_percent") is int or effect_data.get("health_percent") is float) and float(effect_data.health_percent) > 100.0:
			errors.append("%s.health_percent must not exceed 100." % path)
		if (effect_data.get("minimum_principal") is int or effect_data.get("minimum_principal") is float) and (effect_data.get("principal_cost") is int or effect_data.get("principal_cost") is float) and float(effect_data.minimum_principal) < float(effect_data.principal_cost):
			errors.append("%s.minimum_principal must cover principal_cost." % path)
	for stat_key in ["stat", "source_stat", "target_stat"]:
		if effect_data.has(stat_key) and not StatDefinitions.has_stat(str(effect_data.get(stat_key, ""))):
			errors.append("Unknown stat reference in %s.%s: %s" % [path, stat_key, str(effect_data.get(stat_key, ""))])
	if effect_data.has("waves") and int(effect_data["waves"]) < 0:
		errors.append("%s.waves must be greater than or equal to 0." % path)
	if effect_data.has("interval_waves") and int(effect_data["interval_waves"]) <= 0:
		errors.append("%s.interval_waves must be greater than 0." % path)


func _validate_modifier_record(effect: Variant, path: String) -> void:
	# 遗物和羁绊使用统一 Modifier 结构，先校验必填字段再校验枚举值。
	if not (effect is Dictionary):
		errors.append("%s must be an object." % path)
		return
	_validate_required_fields(effect, MODIFIER_REQUIRED_FIELDS, path)
	if effect.has("operation") and not Modifier.is_valid_operation(str(effect["operation"])):
		errors.append("Invalid modifier operation in %s: %s" % [path, str(effect["operation"])])
	if effect.has("stack_rule") and not Modifier.is_valid_stack_rule(str(effect["stack_rule"])):
		errors.append("Invalid modifier stack_rule in %s: %s" % [path, str(effect["stack_rule"])])


func _validate_bond_records(records: Array) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "bonds[%d:%s]" % [record_index, str(record.get("id", ""))]
		var thresholds: Variant = record.get("thresholds", {})
		if not (thresholds is Dictionary):
			errors.append("%s.thresholds must be an object." % path)
			continue
		for threshold_key in thresholds.keys():
			var effects: Variant = thresholds[threshold_key]
			if not (effects is Array):
				errors.append("%s.thresholds.%s must be an array." % [path, str(threshold_key)])
				continue
			for effect_index in effects.size():
				_validate_bond_effect(effects[effect_index], "%s.thresholds.%s[%d]" % [path, str(threshold_key), effect_index])


func _validate_bond_effect(effect: Variant, path: String) -> void:
	# 羁绊效果支持普通属性与特殊效果两类写法。
	if not (effect is Dictionary):
		errors.append("%s must be an object." % path)
		return
	if effect.has("stat"):
		if not effect.has("value"):
			errors.append("Missing required field: %s.value" % path)
	elif effect.has("effect"):
		if not effect.has("value"):
			errors.append("Missing required field: %s.value" % path)
	else:
		errors.append("%s must define stat or effect." % path)


func _validate_character_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "characters[%d:%s]" % [record_index, str(record.get("id", ""))]
		if record.has("display_sprite") and not (record["display_sprite"] is String):
			errors.append("%s.display_sprite must be a string resource path." % path)
		if record.has("display_stats"):
			var display_stats: Variant = record["display_stats"]
			if not (display_stats is Array):
				errors.append("%s.display_stats must be an array." % path)
			else:
				for stat_index in display_stats.size():
					var stat_id := str(display_stats[stat_index])
					if stat_id.is_empty() or not StatDefinitions.has_stat(stat_id):
						errors.append("Unknown display stat in %s.display_stats[%d]: %s" % [path, stat_index, stat_id])
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		_validate_character_starting_content(record, records_by_id, path)
		var start_weapons: Variant = record.get("start_weapons", [])
		if not (start_weapons is Array):
			errors.append("%s.start_weapons must be an array." % path)
			continue
		for weapon_index in start_weapons.size():
			_validate_id_reference(str(start_weapons[weapon_index]), "weapons", records_by_id, "%s.start_weapons[%d]" % [path, weapon_index])
		var start_attachments: Variant = record.get("start_weapon_attachments", [])
		if not (start_attachments is Array):
			errors.append("%s.start_weapon_attachments must be an array." % path)
		else:
			for attachment_index in start_attachments.size():
				var attachment: Variant = start_attachments[attachment_index]
				var attachment_path := "%s.start_weapon_attachments[%d]" % [path, attachment_index]
				if not (attachment is Dictionary):
					errors.append("%s must be an object." % attachment_path)
					continue
				_validate_required_fields(attachment, ["weapon_id", "item_id"], attachment_path)
				_validate_reference(attachment, "weapon_id", "weapons", records_by_id, attachment_path)
				_validate_reference(attachment, "item_id", "augmentations", records_by_id, attachment_path)


func _validate_character_starting_content(record: Dictionary, records_by_id: Dictionary, path: String) -> void:
	if record.has("max_hp_per_level"):
		_validate_non_negative_int(record, "max_hp_per_level", path)
	if record.has("manual_withdrawal_allowed") and not (record.manual_withdrawal_allowed is bool):
		errors.append("%s.manual_withdrawal_allowed must be a boolean." % path)
	var relics: Variant = record.get("start_relics", [])
	if not (relics is Array):
		errors.append("%s.start_relics must be an array." % path)
	else:
		var counts: Dictionary = {}
		for relic_index in relics.size():
			var relic_id := str(relics[relic_index])
			_validate_id_reference(relic_id, "relics", records_by_id, "%s.start_relics[%d]" % [path, relic_index])
			counts[relic_id] = int(counts.get(relic_id, 0)) + 1
			var cap := int(records_by_id.get("relics", {}).get(relic_id, {}).get("max_stack", 0))
			if cap > 0 and counts[relic_id] > cap:
				errors.append("%s.start_relics exceeds max_stack for %s." % [path, relic_id])
	var traits: Variant = record.get("traits", [])
	if not (traits is Array):
		errors.append("%s.traits must be an array." % path)
	else:
		for trait_data in traits:
			if not (trait_data is Dictionary):
				errors.append("%s.traits entries must be objects." % path)
				continue
			_validate_required_fields(trait_data, ["title", "description"], path + ".traits")
			_validate_non_empty_text(trait_data, "title", path + ".traits")
			_validate_non_empty_text(trait_data, "description", path + ".traits")
	if not record.has("combat_visuals"):
		return
	var visuals: Variant = record.combat_visuals
	if not (visuals is Dictionary):
		errors.append("%s.combat_visuals must be an object." % path)
		return
	for field in ["idle", "walk"]:
		var asset: Variant = visuals.get(field, "")
		if not (asset is String) or str(asset).is_empty() or not ResourceLoader.exists(str(asset), "Texture2D"):
			errors.append("%s.combat_visuals.%s must reference an existing texture." % [path, field])
	_validate_non_negative_int(visuals, "walk_frames", path + ".combat_visuals")
	if float(visuals.get("walk_frames", 0)) < 1:
		errors.append("%s.combat_visuals.walk_frames must be positive." % path)
	var fps: Variant = visuals.get("walk_fps", 0)
	if not (fps is int or fps is float) or float(fps) <= 0:
		errors.append("%s.combat_visuals.walk_fps must be positive." % path)


func _validate_enemy_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "enemies[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		_validate_reference(record, "drop_table_id", "drop_tables", records_by_id, path)
		if record.has("elite_replacement_id"):
			_validate_reference(record, "elite_replacement_id", "enemies", records_by_id, path)
		for pool_key in ["spawn_variants", "miniboss_variants"]:
			if not record.has(pool_key): continue
			var variants: Variant = record[pool_key]
			if not (variants is Array) or variants.is_empty():
				errors.append("%s.%s must be a nonempty array." % [path, pool_key])
			else:
				for index in variants.size():
					var entry: Variant = variants[index]
					var variant_path := "%s.%s[%d]" % [path, pool_key, index]
					if not (entry is Dictionary):
						errors.append("%s must be an object." % variant_path)
						continue
					_validate_required_fields(entry, ["enemy_id", "weight"], variant_path)
					_validate_reference(entry, "enemy_id", "enemies", records_by_id, variant_path)
					if pool_key == "miniboss_variants":
						var target: Dictionary = records_by_id.get("enemies", {}).get(str(entry.get("enemy_id", "")), {})
						if target.get("enemy_type", "") != "elite" or not bool(target.get("enabled", true)):
							errors.append("%s must select an enabled elite enemy." % variant_path)
					var weight: Variant = entry.get("weight", 0)
					if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight) <= 0.0:
						errors.append("%s.weight must be positive." % variant_path)
		if record.has("wolf_profile"):
			_validate_wolf_profile(record.wolf_profile, path + ".wolf_profile")
		if record.has("elite_profile"):
			var profile: Variant = record["elite_profile"]
			if not (profile is Dictionary):
				errors.append("%s.elite_profile must be an object." % path)
				continue
			for field in ["hp_multiplier", "armor_multiplier", "spawn_warning_ms", "first_dash_delay_ms", "windup_ms", "dash_ms", "recover_ms", "cooldown_ms", "dash_distance", "dash_half_width", "expectation_wave_divisor", "erosion_bonus_full_at", "quota_cap"]:
				if not profile.has(field) or not (profile[field] is int or profile[field] is float) or float(profile[field]) <= 0.0:
					errors.append("%s.elite_profile.%s must be positive." % [path, field])
			if not profile.has("erosion_bonus_max_percent"):
				errors.append("%s.elite_profile.erosion_bonus_max_percent is required." % path)
			_validate_non_negative_int(profile, "erosion_bonus_max_percent", "%s.elite_profile" % path)
			_validate_non_negative_int(profile, "quota_cap", "%s.elite_profile" % path)
			if profile.has("minimum_quota"):
				_validate_non_negative_int(profile, "minimum_quota", "%s.elite_profile" % path)
				if (profile.minimum_quota is int or profile.minimum_quota is float) and (float(profile.minimum_quota) < 1.0 or float(profile.minimum_quota) > float(profile.get("quota_cap", 3))):
					errors.append("%s.elite_profile.minimum_quota must be between 1 and quota_cap." % path)
			if float(profile.get("spawn_window_percent", 50)) <= 0.0 or float(profile.get("spawn_window_percent", 50)) > 50.0:
				errors.append("%s.elite_profile.spawn_window_percent must be in (0, 50]." % path)


func _validate_wolf_profile(value: Variant, path: String) -> void:
	if not (value is Dictionary):
		errors.append("%s must be an object." % path)
		return
	var profile: Dictionary = value
	for field in ["spawn_warning_ms", "breath_range", "breath_cone_degrees", "breath_tick_ms", "breath_charge_ms", "breath_duration_ms", "breath_recover_ms", "breath_cooldown_ms", "breath_knockback_speed", "breath_knockback_ms", "leap_min_range", "leap_max_range", "leap_radius", "leap_charge_ms", "leap_duration_ms", "landing_ms", "leap_recover_ms", "leap_cooldown_ms", "leap_knockback_speed", "leap_knockback_ms", "control_duration_percent"]:
		var number: Variant = profile.get(field)
		if not (number is int or number is float) or not is_finite(float(number)) or float(number) <= 0:
			errors.append("%s.%s must be positive and finite." % [path, field])
			return
	_validate_non_negative_int(profile, "breath_max_hits", path)
	if not (profile.get("breath_max_hits") is int or profile.get("breath_max_hits") is float): return
	if float(profile.breath_max_hits) < 1 or float(profile.breath_max_hits) > 3:
		errors.append("%s.breath_max_hits must be between 1 and 3." % path)
	if float(profile.breath_cone_degrees) >= 180 or float(profile.control_duration_percent) > 100:
		errors.append("%s cone or control resistance is out of range." % path)
	if float(profile.leap_max_range) < float(profile.leap_min_range):
		errors.append("%s leap maximum must cover the minimum range." % path)
	if (float(profile.breath_max_hits)-1)*float(profile.breath_tick_ms) >= float(profile.breath_duration_ms):
		errors.append("%s flame duration must cover every configured pulse." % path)


func _validate_erosion_pressure_records(records: Array) -> void:
	var found := false
	for record in records:
		if not (record is Dictionary):
			continue
		var path := "erosion_pressure_rules[%s]" % str(record.get("id", ""))
		found = found or str(record.get("id", "")) == "erosion_enemy_stats"
		for field in ["erosion_full_at", "max_hp_bonus_percent", "damage_bonus_percent", "armor_bonus_percent"]:
			_validate_non_negative_int(record, field, path)
		if (record.get("erosion_full_at") is int or record.get("erosion_full_at") is float) and float(record.erosion_full_at) <= 0.0:
			errors.append("%s.erosion_full_at must be positive." % path)
		if not (record.get("growth_steps") is Array):
			errors.append("%s.growth_steps must be an array." % path)
			continue
		var previous := 0.0
		for step in record.growth_steps:
			if not (step is Dictionary):
				errors.append("%s.growth_steps must contain objects." % path)
				continue
			_validate_required_fields(step, ["erosion", "max_hp_bonus_percent", "damage_bonus_percent"], path + ".growth_steps")
			for field in ["erosion", "max_hp_bonus_percent", "damage_bonus_percent"]:
				_validate_non_negative_int(step, field, path + ".growth_steps")
			if step.get("erosion") is int or step.get("erosion") is float:
				if float(step.erosion) <= previous:
					errors.append("%s growth thresholds must be positive and strictly increasing." % path)
				previous = float(step.erosion)
	if not found:
		errors.append("Missing erosion_pressure_rules.erosion_enemy_stats record.")


func _validate_enemy_adaptation_records(records: Array) -> void:
	var found := false
	for record in records:
		if not (record is Dictionary): continue
		var path := "enemy_adaptation_rules[%s]" % str(record.get("id", ""))
		found = found or str(record.get("id", "")) == "kill_speed_hp"
		_validate_required_fields(record, TABLE_REQUIRED_FIELDS.enemy_adaptation_rules, path)
		for field in ["first_effective_wave", "fast_kill_ms", "minimum_observed_seconds", "fast_ratio_percent", "slow_ratio_percent", "slow_waves_to_relax"]:
			_validate_non_negative_int(record, field, path)
			if record.get(field) is int or record.get(field) is float:
				if float(record[field]) <= 0.0:
					errors.append("%s.%s must be positive." % [path, field])
		for field in ["fast_ratio_percent", "slow_ratio_percent"]:
			if (record.get(field) is int or record.get(field) is float) and float(record[field]) > 100.0:
				errors.append("%s.%s cannot exceed 100." % [path, field])
		if (record.get("slow_ratio_percent") is int or record.get("slow_ratio_percent") is float) and (record.get("fast_ratio_percent") is int or record.get("fast_ratio_percent") is float):
			if float(record.slow_ratio_percent) >= float(record.fast_ratio_percent):
				errors.append("%s requires slow_ratio_percent < fast_ratio_percent." % path)
		for kind in ["normal", "elite"]:
			if not (record.get(kind) is Dictionary):
				errors.append("%s.%s must be an object." % [path, kind])
				continue
			_validate_required_fields(record[kind], ["minimum_samples", "step_percent", "max_percent"], path + "." + kind)
			for field in ["minimum_samples", "step_percent", "max_percent"]:
				_validate_non_negative_int(record[kind], field, path + "." + kind)
				if (record[kind].get(field) is int or record[kind].get(field) is float) and float(record[kind][field]) <= 0.0:
					errors.append("%s.%s.%s must be positive." % [path, kind, field])
	if not found:
		errors.append("Missing enemy_adaptation_rules.kill_speed_hp record.")


func _validate_camp_building_records(records: Array, records_by_id: Dictionary) -> void:
	# 营地建筑既包含等级效果，也包含局外升级项，需分开校验。
	var upgrade_stats: Dictionary = {}
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "camp_buildings[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_bool(record, "initial_unlocked", path)
		_validate_reference(record, "unlock_condition.building", "camp_buildings", records_by_id, path)
		_validate_camp_unlock_condition(record.get("unlock_condition", {}), path)
		_validate_camp_levels(record.get("levels", {}), path)
		var upgrade_options: Variant = record.get("upgrade_options", [])
		if not (upgrade_options is Array):
			errors.append("%s.upgrade_options must be an array." % path)
			continue
		for option_index in upgrade_options.size():
			var option: Variant = upgrade_options[option_index]
			if not (option is Dictionary):
				errors.append("%s.upgrade_options[%d] must be an object." % [path, option_index])
				continue
			_validate_required_fields(option, ["id", "stat", "currency", "cost", "max_level", "value_per_level"], "%s.upgrade_options[%d]" % [path, option_index])
			_validate_camp_currency_field(option, "%s.upgrade_options[%d]" % [path, option_index])
			var stat_id := str(option.get("stat", ""))
			var option_path := "%s.upgrade_options[%d]" % [path, option_index]
			if not stat_id.is_empty():
				if upgrade_stats.has(stat_id):
					errors.append("%s duplicates upgrade stat '%s' already defined at %s." % [option_path, stat_id, upgrade_stats[stat_id]])
				else:
					upgrade_stats[stat_id] = option_path
			if option.has("required_building_level") and int(option["required_building_level"]) < 1:
				errors.append("%s.upgrade_options[%d].required_building_level must be at least 1." % [path, option_index])


func _validate_camp_levels(levels: Variant, path: String) -> void:
	# levels 的 key 是等级，value 是该等级的效果列表。
	if not (levels is Dictionary):
		errors.append("%s.levels must be an object." % path)
		return
	for level_key in levels.keys():
		var level_value := int(str(level_key))
		if level_value < 1:
			errors.append("%s.levels contains invalid level key: %s" % [path, str(level_key)])
		var level_effects: Variant = levels[level_key]
		if not (level_effects is Array):
			errors.append("%s.levels.%s must be an array." % [path, str(level_key)])
			continue
		for effect_index in level_effects.size():
			var effect: Variant = level_effects[effect_index]
			var effect_path := "%s.levels.%s[%d]" % [path, str(level_key), effect_index]
			if not (effect is Dictionary):
				errors.append("%s must be an object." % effect_path)
				continue
			_validate_camp_level_effect(effect, effect_path)


func _validate_camp_level_effect(effect: Dictionary, path: String) -> void:
	# 建筑等级效果只允许写入已注册的解锁项、阶段标记或属性项。
	if effect.has("unlock"):
		var unlock_id := str(effect["unlock"])
		if not UnlockRegistry.has_unlock(unlock_id):
			errors.append("Unknown camp unlock in %s: %s" % [path, unlock_id])
	if effect.has("stage"):
		var stage_id := str(effect["stage"])
		if not UnlockRegistry.has_stage(stage_id):
			warnings.append("Unknown camp stage in %s: %s" % [path, stage_id])
	if effect.has("stat") and not StatDefinitions.has_stat(str(effect["stat"])):
		errors.append("Unknown stat in %s: %s" % [path, str(effect["stat"])])


func _validate_camp_unlock_condition(condition: Variant, path: String) -> void:
	if not (condition is Dictionary):
		errors.append("%s.unlock_condition must be an object." % path)
		return
	if condition.has("currency") and str(condition.get("currency", "")) != "camp_currency":
		errors.append("%s.unlock_condition.currency must be camp_currency." % path)
	if condition.has("currency") and not condition.has("cost"):
		errors.append("%s.unlock_condition.cost is required when currency is set." % path)
	if condition.has("cost") and not condition.has("currency"):
		errors.append("%s.unlock_condition.currency is required when cost is set." % path)
	if condition.has("cost") and int(condition.get("cost", 0)) < 0:
		errors.append("%s.unlock_condition.cost must be greater than or equal to 0." % path)


func _validate_camp_currency_field(record: Dictionary, path: String) -> void:
	if record.has("currency") and str(record.get("currency", "")) != "camp_currency":
		errors.append("%s.currency must be camp_currency." % path)
	if record.has("cost") and int(record.get("cost", 0)) < 0:
		errors.append("%s.cost must be greater than or equal to 0." % path)


func _validate_wave_records(records: Array, records_by_id: Dictionary) -> void:
	# 波次只校验单波时长和刷怪引用，不关心具体战斗实现。
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "waves[%d:%s]" % [record_index, str(record.get("id", ""))]
		if int(record.get("duration_seconds", 0)) <= 0:
			errors.append("%s.duration_seconds must be greater than 0." % path)
		var spawn_groups: Variant = record.get("spawn_groups", [])
		if not (spawn_groups is Array):
			errors.append("%s.spawn_groups must be an array." % path)
			continue
		for group_index in spawn_groups.size():
			var group: Variant = spawn_groups[group_index]
			var group_path := "%s.spawn_groups[%d]" % [path, group_index]
			if not (group is Dictionary):
				errors.append("%s must be an object." % group_path)
				continue
			_validate_required_fields(group, ["enemy_id", "spawn_interval_ms", "count_per_spawn"], group_path)
			_validate_reference(group, "enemy_id", "enemies", records_by_id, group_path)
			if int(group.get("spawn_interval_ms", 0)) <= 0:
				errors.append("%s.spawn_interval_ms must be greater than 0." % group_path)
			if int(group.get("count_per_spawn", 0)) <= 0:
				errors.append("%s.count_per_spawn must be greater than 0." % group_path)


func _validate_augmentation_records(records: Array) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "augmentations[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_rarity(record, path)
		if record.has("enchantment_type") and not record.enchantment_type in ["buff", "spell", "element"]:
			errors.append("%s.enchantment_type must be buff, spell or element." % path)
		var weapon_bonuses: Variant = record.get("weapon_bonuses", {})
		if not (weapon_bonuses is Dictionary):
			errors.append("%s.weapon_bonuses must be an object." % path)
		else:
			for key in weapon_bonuses:
				var amount: Variant = weapon_bonuses[key]
				if not str(key) in WeaponInstance.ATTACHMENT_BONUS_KEYS:
					errors.append("Unknown weapon-only bonus in %s: %s" % [path, key])
				elif not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0 or float(amount) != floorf(float(amount)):
					errors.append("%s.weapon_bonuses.%s must be a nonnegative integer." % [path, key])
		if record.has("effect_ids") and not (record["effect_ids"] is Array):
			errors.append("%s.effect_ids must be an array." % path)
		var effect_parameters: Variant = record.get("effect_parameters", {})
		if not (effect_parameters is Dictionary):
			errors.append("%s.effect_parameters must be an object." % path)
		var instance_parameter_ranges: Variant = record.get("instance_parameter_ranges", [])
		if not (instance_parameter_ranges is Array):
			errors.append("%s.instance_parameter_ranges must be an array." % path)
		else:
			_validate_instance_parameter_ranges(instance_parameter_ranges, path)
		var modifiers: Variant = record.get("modifiers", [])
		if not (modifiers is Array):
			errors.append("%s.modifiers must be an array." % path)
			continue
		for modifier_index in modifiers.size():
			var modifier: Variant = modifiers[modifier_index]
			if not (modifier is Dictionary):
				errors.append("%s.modifiers[%d] must be an object." % [path, modifier_index])
				continue
			if str(modifier.get("channel", "")).is_empty():
				errors.append("%s.modifiers[%d].channel cannot be empty." % [path, modifier_index])


func _validate_instance_parameter_ranges(ranges: Array, path: String) -> void:
	for range_index in ranges.size():
		var range_data: Variant = ranges[range_index]
		var range_path := "%s.instance_parameter_ranges[%d]" % [path, range_index]
		if not (range_data is Dictionary):
			errors.append("%s must be an object." % range_path)
			continue
		_validate_required_fields(range_data, ["channel", "min", "max", "step"], range_path)
		if str(range_data.get("channel", "")).strip_edges().is_empty():
			errors.append("%s.channel cannot be empty." % range_path)
		var has_valid_numbers := true
		for field_name in ["min", "max", "step"]:
			if not range_data.has(field_name):
				continue
			var field_value: Variant = range_data[field_name]
			if not (field_value is int or field_value is float):
				errors.append("%s.%s must be a number." % [range_path, field_name])
				has_valid_numbers = false
		if not has_valid_numbers:
			continue
		var minimum := float(range_data["min"])
		var maximum := float(range_data["max"])
		var step := float(range_data["step"])
		if minimum > maximum:
			errors.append("%s.min must be less than or equal to max." % range_path)
		if step <= 0.0:
			errors.append("%s.step must be greater than 0." % range_path)


func _validate_drop_table_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "drop_tables[%d:%s]" % [record_index, str(record.get("id", ""))]
		if record.has("augmentation_chance_percent"):
			var chance: Variant = record.augmentation_chance_percent
			if not (chance is int or chance is float) or not is_finite(float(chance)) or float(chance) < 0.0 or float(chance) > 100.0:
				errors.append("%s.augmentation_chance_percent must be between 0 and 100." % path)
			var rarity_weights: Variant = record.get("augmentation_rarity_weights", {})
			if not (rarity_weights is Dictionary) or rarity_weights.is_empty():
				errors.append("%s.augmentation_rarity_weights must be a nonempty object." % path)
			else:
				var total_weight := 0.0
				for rarity in rarity_weights:
					var weight: Variant = rarity_weights[rarity]
					if not VALID_RARITIES.has(str(rarity)) or not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight) < 0.0:
						errors.append("%s.augmentation_rarity_weights requires valid rarities and finite nonnegative weights." % path)
					else:
						total_weight += float(weight)
				if total_weight <= 0.0:
					errors.append("%s.augmentation_rarity_weights must contain a positive weight." % path)
		if record.has("elite_relic_decay_percent"):
			var decay: Variant = record["elite_relic_decay_percent"]
			if not (decay is int or decay is float) or not is_finite(float(decay)) or float(decay) < 0.0 or float(decay) > 100.0 or float(decay) != floorf(float(decay)):
				errors.append("%s.elite_relic_decay_percent must be an integer between 0 and 100." % path)
		var entries: Variant = record.get("entries", [])
		if not (entries is Array):
			errors.append("%s.entries must be an array." % path)
			continue
		for entry_index in entries.size():
			var entry: Variant = entries[entry_index]
			var entry_path := "%s.entries[%d]" % [path, entry_index]
			if not (entry is Dictionary):
				errors.append("%s must be an object." % entry_path)
				continue
			var is_augmentation := str(entry.get("type", "")) == "augmentation"
			_validate_required_fields(entry, ["type", "amount", "weight"] if is_augmentation else ["type", "amount", "chance_percent"], entry_path)
			if entry.has("type") and not VALID_DROP_TYPES.has(str(entry["type"])):
				warnings.append("Unknown drop type in %s: %s" % [entry_path, str(entry["type"])])
			if int(entry.get("chance_percent", 0)) < 0 or int(entry.get("chance_percent", 0)) > 100:
				errors.append("%s.chance_percent must be between 0 and 100." % entry_path)
			if str(entry.get("type", "")) == "augmentation":
				var weight: Variant = entry.get("weight", 0)
				if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight) <= 0.0:
					errors.append("%s.weight must be positive." % entry_path)
				if int(entry.get("amount", 0)) != 1 or not record.has("augmentation_chance_percent"):
					errors.append("%s requires amount=1 and a table-level augmentation_chance_percent." % entry_path)
				var item_id := str(entry.get("item_id", entry.get("augmentation_id", "")))
				if item_id.is_empty():
					errors.append("%s requires item_id for augmentation drops." % entry_path)
				elif not records_by_id.get("augmentations", {}).has(item_id):
					errors.append("Unknown augmentation reference in %s: %s" % [entry_path, item_id])


func _validate_stat_dictionary(stats: Variant, path: String) -> void:
	if not (stats is Dictionary):
		errors.append("%s must be an object." % path)
		return
	for stat_id in stats.keys():
		if not StatDefinitions.has_stat(str(stat_id)):
			errors.append("Unknown stat key in %s: %s" % [path, str(stat_id)])


func _validate_rarity(record: Dictionary, path: String) -> void:
	if record.has("rarity") and not VALID_RARITIES.has(str(record["rarity"])):
		warnings.append("Unknown rarity in %s: %s" % [path, str(record["rarity"])])


func _validate_reference(record: Dictionary, field_name: String, target_table: String, records_by_id: Dictionary, path: String) -> void:
	# 统一处理单字段跨表引用，减少重复校验代码。
	var field_data := _get_field_path_value(record, field_name)
	if not bool(field_data["found"]):
		return
	_validate_id_reference(str(field_data["value"]), target_table, records_by_id, "%s.%s" % [path, field_name])


func _get_field_path_value(record: Dictionary, field_path: String) -> Dictionary:
	# 支持 a.b.c 形式的嵌套字段读取。
	var current_value: Variant = record
	for field_part in field_path.split("."):
		if not (current_value is Dictionary):
			return {"found": false, "value": null}
		var current_dict: Dictionary = current_value
		if not current_dict.has(field_part):
			return {"found": false, "value": null}
		current_value = current_dict[field_part]
	return {"found": true, "value": current_value}


func _validate_id_reference(record_id: String, target_table: String, records_by_id: Dictionary, path: String) -> void:
	if record_id.strip_edges().is_empty():
		errors.append("%s cannot be empty." % path)
		return
	if not records_by_id.has(target_table) or not records_by_id[target_table].has(record_id):
		errors.append("Invalid reference in %s: %s not found in %s" % [path, record_id, target_table])
