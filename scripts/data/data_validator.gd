extends RefCounted
class_name DataValidator

const REQUIRED_TABLES: Array[String] = [
	"weapons",
	"relics",
	"bonds",
	"characters",
	"enemies",
	"camp_buildings",
	"zones",
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
	"camp_buildings": ["id", "name", "levels", "upgrade_options"],
	"zones": ["id", "display_name", "description", "tendency_tags", "enemy_pressure_per_streak", "player_pressure_per_streak", "fortune_gain", "reward_bias"],
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
const VALID_ZONE_TARGET_POOLS: Array[String] = ["relic", "bond", "weapon"]
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
	BattleFinanceSystem.EFFECT_CONSUME_PRINCIPAL_PERCENT_EVERY_N_WAVES,
	BattleFinanceSystem.EFFECT_REQUIRE_WAVE_START_DEPOSIT,
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
	_validate_zone_records(tables.get("zones", []), records_by_id)
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
	return (path.contains(".runtime_effects[") and (
		path.ends_with(".value") or path.ends_with(".principal_percent")
	)) or path.contains("augmentations[") and path.contains(".modifiers[") and (
		path.ends_with(".value") or path.contains(".value[")
	) or path.contains("augmentations[") and (
		path.contains(".effect_parameters.") or path.contains(".instance_parameter_ranges[")
	)


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
	_validate_non_negative_int(record, "load_cost", path)
	_validate_non_negative_int(record, "attack_interval_ms", path)
	_validate_non_negative_int(record, "attack_range", path)
	_validate_non_negative_int(record, "hit_radius", path)
	_validate_non_negative_int(record, "projectile_speed", path)
	_validate_non_negative_int(record, "spread_angle", path)
	_validate_non_negative_int(record, "attachment_slots", path)
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
	for key in ["value", "value_percent", "double_chance_percent", "zero_chance_percent", "principal_percent", "value_per_wave", "chance_percent", "gold_multiplier", "divisor", "per_unit", "amount", "minimum_deposit"]:
		if not effect_data.has(key):
			continue
		if not (effect_data[key] is int or effect_data[key] is float):
			errors.append("%s.%s must be a number." % [path, key])
			continue
		var allows_negative_value: bool = key == "value" and str(effect_data.get("effect", "")) in [
			BattleFinanceSystem.EFFECT_ADD_STAT,
			BattleFinanceSystem.EFFECT_CONDITIONAL_STAT,
		]
		if float(effect_data[key]) < 0.0 and not allows_negative_value:
			errors.append("%s.%s must be greater than or equal to 0." % [path, key])
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


func _validate_enemy_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "enemies[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		_validate_reference(record, "drop_table_id", "drop_tables", records_by_id, path)


func _validate_zone_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "zones[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_non_empty_text(record, "display_name", path)
		_validate_non_empty_text(record, "description", path)
		if record.has("max_streak"):
			errors.append("%s.max_streak is not allowed because zone streak has no hard cap." % path)
		_validate_zone_tag_list(record.get("tendency_tags", []), path)
		_validate_zone_pressure_dictionary(record.get("enemy_pressure_per_streak", {}), path, "enemy_pressure_per_streak")
		_validate_zone_pressure_dictionary(record.get("player_pressure_per_streak", {}), path, "player_pressure_per_streak")
		_validate_zone_fortune_gain(record.get("fortune_gain", {}), path)
		_validate_zone_reward_bias(record.get("reward_bias", {}), path)


func _validate_zone_tag_list(tags: Variant, path: String) -> void:
	if not (tags is Array) or (tags as Array).is_empty():
		errors.append("%s.tendency_tags must be a non-empty array." % path)
		return
	for tag_index in tags.size():
		var tag_text := str(tags[tag_index]).strip_edges()
		if tag_text.is_empty():
			errors.append("%s.tendency_tags[%d] cannot be empty." % [path, tag_index])


func _validate_zone_pressure_dictionary(pressure: Variant, path: String, field_name: String) -> void:
	if not (pressure is Dictionary):
		errors.append("%s.%s must be an object." % [path, field_name])
		return
	if pressure.is_empty():
		errors.append("%s.%s cannot be empty." % [path, field_name])
		return
	for pressure_key in pressure.keys():
		var pressure_name := str(pressure_key)
		var is_special_pressure := pressure_name in ["max_hp_percent", "move_speed_percent", "armor_flat", "spawn_interval_percent"]
		if not is_special_pressure and not StatDefinitions.has_stat(pressure_name):
			errors.append("Unknown zone pressure key in %s.%s: %s" % [path, field_name, pressure_name])
		var pressure_value := int(pressure[pressure_key])
		if pressure_value < 0:
			errors.append("%s.%s.%s must be greater than or equal to 0." % [path, field_name, pressure_name])


func _validate_zone_fortune_gain(fortune_gain: Variant, path: String) -> void:
	if not (fortune_gain is Dictionary):
		errors.append("%s.fortune_gain must be an object." % path)
		return
	_validate_required_fields(fortune_gain, ["start_streak", "base", "per_extra_streak", "wave_bonus"], "%s.fortune_gain" % path)
	if int(fortune_gain.get("start_streak", 0)) < 2:
		errors.append("%s.fortune_gain.start_streak must be at least 2." % path)
	for key_name in ["base", "per_extra_streak", "wave_bonus"]:
		if int(fortune_gain.get(key_name, 0)) < 0:
			errors.append("%s.fortune_gain.%s must be greater than or equal to 0." % [path, key_name])


func _validate_zone_reward_bias(reward_bias: Variant, path: String) -> void:
	if not (reward_bias is Dictionary):
		errors.append("%s.reward_bias must be an object." % path)
		return
	_validate_required_fields(reward_bias, ["target_pools", "tag_weight_per_streak", "rarity_bonus_per_streak"], "%s.reward_bias" % path)
	var target_pools: Variant = reward_bias.get("target_pools", [])
	if not (target_pools is Array) or (target_pools as Array).is_empty():
		errors.append("%s.reward_bias.target_pools must be a non-empty array." % path)
	else:
		for pool_index in target_pools.size():
			var pool_name := str(target_pools[pool_index])
			if not VALID_ZONE_TARGET_POOLS.has(pool_name):
				errors.append("%s.reward_bias.target_pools[%d] must be one of %s." % [path, pool_index, ", ".join(VALID_ZONE_TARGET_POOLS)])
	if int(reward_bias.get("tag_weight_per_streak", 0)) < 0:
		errors.append("%s.reward_bias.tag_weight_per_streak must be greater than or equal to 0." % path)
	if int(reward_bias.get("rarity_bonus_per_streak", 0)) < 0:
		errors.append("%s.reward_bias.rarity_bonus_per_streak must be greater than or equal to 0." % path)


func _validate_camp_building_records(records: Array, records_by_id: Dictionary) -> void:
	# 营地建筑既包含等级效果，也包含局外升级项，需分开校验。
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
			_validate_required_fields(entry, ["type", "amount", "chance_percent"], entry_path)
			if entry.has("type") and not VALID_DROP_TYPES.has(str(entry["type"])):
				warnings.append("Unknown drop type in %s: %s" % [entry_path, str(entry["type"])])
			if int(entry.get("chance_percent", 0)) < 0 or int(entry.get("chance_percent", 0)) > 100:
				errors.append("%s.chance_percent must be between 0 and 100." % entry_path)
			if str(entry.get("type", "")) == "augmentation":
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
