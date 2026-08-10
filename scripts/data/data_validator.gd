extends RefCounted
class_name DataValidator

const REQUIRED_TABLES: Array[String] = [
	"weapons",
	"relics",
	"bonds",
	"characters",
	"enemies",
	"camp_buildings",
	"waves",
	"drop_tables",
]

const TABLE_REQUIRED_FIELDS: Dictionary = {
	"weapons": ["id", "display_name", "icon", "rarity", "tags", "weapon_type", "load_cost", "max_level", "attack_interval_ms", "hit_radius", "projectile_speed", "spread_angle", "use_cooldown_reduction_only", "base_stats", "level_upgrades"],
	"relics": ["id", "display_name", "rarity", "bond_id", "tags", "effects"],
	"bonds": ["id", "name", "bond_tag", "thresholds"],
	"characters": ["id", "icon", "base_stats", "start_weapons"],
	"enemies": ["id", "base_stats", "drop_table_id"],
	"camp_buildings": ["id", "name", "levels", "upgrade_options"],
	"waves": ["id", "duration_seconds", "spawn_groups"],
	"drop_tables": ["id", "entries"],
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
	"stack_rule",
]

const VALID_DROP_TYPES: Array[String] = ["exp_orb", "relic", "health_pack"]
const VALID_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "mythic", "legendary"]

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

	_validate_weapon_records(tables.get("weapons", []))
	_validate_relic_records(tables.get("relics", []), records_by_id)
	_validate_bond_records(tables.get("bonds", []))
	_validate_character_records(tables.get("characters", []), records_by_id)
	_validate_enemy_records(tables.get("enemies", []), records_by_id)
	_validate_camp_building_records(tables.get("camp_buildings", []), records_by_id)
	_validate_wave_records(tables.get("waves", []), records_by_id)
	_validate_drop_table_records(tables.get("drop_tables", []))

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
				_validate_integer_values(value_data[key], "%s.%s" % [path, key])
		TYPE_ARRAY:
			for index in value_data.size():
				_validate_integer_values(value_data[index], "%s[%d]" % [path, index])
		TYPE_FLOAT:
			if not is_equal_approx(value_data, roundf(value_data)):
				errors.append("Numeric config value must be integer: %s = %s" % [path, value_data])
		TYPE_INT:
			pass
		_:
			pass


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


func _validate_weapon_records(records: Array) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "weapons[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_rarity(record, path)
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		_validate_weapon_runtime_fields(record, path)
		_validate_weapon_level_upgrades(record, path)


func _validate_weapon_runtime_fields(record: Dictionary, path: String) -> void:
	_validate_non_negative_int(record, "load_cost", path)
	_validate_non_negative_int(record, "attack_interval_ms", path)
	_validate_non_negative_int(record, "hit_radius", path)
	_validate_non_negative_int(record, "projectile_speed", path)
	_validate_non_negative_int(record, "spread_angle", path)
	if record.has("use_cooldown_reduction_only") and not (record["use_cooldown_reduction_only"] is bool):
		errors.append("%s.use_cooldown_reduction_only must be a boolean." % path)
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
		_validate_reference(record, "bond_id", "bonds", records_by_id, path)
		if record.has("max_stack"):
			_validate_non_negative_int(record, "max_stack", path)
		var effects: Variant = record.get("effects", [])
		if not (effects is Array):
			errors.append("%s.effects must be an array." % path)
			continue
		for effect_index in effects.size():
			_validate_modifier_record(effects[effect_index], "%s.effects[%d]" % [path, effect_index])


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
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		var start_weapons: Variant = record.get("start_weapons", [])
		if not (start_weapons is Array):
			errors.append("%s.start_weapons must be an array." % path)
			continue
		for weapon_index in start_weapons.size():
			_validate_id_reference(str(start_weapons[weapon_index]), "weapons", records_by_id, "%s.start_weapons[%d]" % [path, weapon_index])


func _validate_enemy_records(records: Array, records_by_id: Dictionary) -> void:
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			continue
		var path := "enemies[%d:%s]" % [record_index, str(record.get("id", ""))]
		_validate_stat_dictionary(record.get("base_stats", {}), "%s.base_stats" % path)
		_validate_reference(record, "drop_table_id", "drop_tables", records_by_id, path)


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


func _validate_drop_table_records(records: Array) -> void:
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
