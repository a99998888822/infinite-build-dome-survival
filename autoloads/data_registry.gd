extends Node

signal data_ready(load_success: bool)

const PRINT_BOOT_SUMMARY: bool = true

const CONFIG_PATHS: Dictionary = {
	"weapons": "res://data_config/weapons.json",
	"relics": "res://data_config/relics.json",
	"bonds": "res://data_config/bonds.json",
	"characters": "res://data_config/characters.json",
	"enemies": "res://data_config/enemies.json",
	"camp_buildings": "res://data_config/camp_buildings.json",
	"waves": "res://data_config/waves.json",
	"drop_tables": "res://data_config/drop_tables.json",
}

var tables: Dictionary = {}
var records_by_id: Dictionary = {}
var load_errors: Array[String] = []
var load_warnings: Array[String] = []


func _ready() -> void:
	reload_all()
	if PRINT_BOOT_SUMMARY:
		print_boot_summary()


func reload_all() -> bool:
	# 重新加载全部配置，并同步触发一次完整校验。
	tables.clear()
	records_by_id.clear()
	load_errors.clear()
	load_warnings.clear()

	for table_name in CONFIG_PATHS.keys():
		_load_table(str(table_name), str(CONFIG_PATHS[table_name]))

	_validate_all_tables()
	var load_success := load_errors.is_empty()
	data_ready.emit(load_success)
	return load_success


func has_table(table_name: String) -> bool:
	return tables.has(table_name)


func get_table(table_name: String) -> Array:
	if not tables.has(table_name):
		return []
	return tables[table_name].duplicate(true)


func get_record(table_name: String, record_id: String) -> Dictionary:
	if not records_by_id.has(table_name):
		return {}
	return records_by_id[table_name].get(record_id, {}).duplicate(true)


func get_records_by_tag(table_name: String, tag: String) -> Array:
	var query_tags: Array[String] = [tag]
	return get_records_by_any_tag(table_name, query_tags)


func get_records_by_any_tag(table_name: String, query_tags: Array[String]) -> Array:
	var result: Array = []
	for record in get_table(table_name):
		if _record_has_any_tag(record, query_tags):
			result.append(record)
	return result


func get_records_by_all_tags(table_name: String, query_tags: Array[String]) -> Array:
	var result: Array = []
	for record in get_table(table_name):
		if _record_has_all_tags(record, query_tags):
			result.append(record)
	return result


func has_record(table_name: String, record_id: String) -> bool:
	return records_by_id.has(table_name) and records_by_id[table_name].has(record_id)


func get_record_count(table_name: String) -> int:
	if not tables.has(table_name):
		return 0
	return tables[table_name].size()


func get_load_errors() -> Array[String]:
	return load_errors.duplicate()


func get_load_warnings() -> Array[String]:
	return load_warnings.duplicate()


func print_boot_summary() -> void:
	# 启动期输出最小可见诊断信息，便于快速定位配置问题。
	print("[DataRegistry] config load summary")
	for table_name in CONFIG_PATHS.keys():
		print("[DataRegistry] - %s: %d records" % [table_name, get_record_count(str(table_name))])

	var attack_interval := StatDefinitions.calculate_attack_interval(1.0, 100)
	var cooldown := StatDefinitions.calculate_cooldown(10.0, 40)
	var armor_damage_taken := StatDefinitions.calculate_damage_taken_from_armor(100)
	var attack_radius := StatDefinitions.calculate_attack_radius(100, 40)
	var finance_interest := StatDefinitions.calculate_finance_interest_gain(101, 5)
	print("[DataRegistry] stat check: attack_speed=100 => interval %.2fs from 1.00s" % attack_interval)
	print("[DataRegistry] stat check: cooldown_reduction=40 => cooldown %.2fs from 10.00s" % cooldown)
	print("[DataRegistry] stat check: armor=100 => damage_taken_percent %d" % int(armor_damage_taken))
	print("[DataRegistry] stat check: area_size=40 => radius %d from 100" % int(attack_radius))
	print("[DataRegistry] stat check: finance=101 interest_rate=5 => gain %d" % finance_interest)

	for warning in load_warnings:
		push_warning("[DataRegistry] %s" % warning)
	for error in load_errors:
		push_error("[DataRegistry] %s" % error)

	if load_errors.is_empty():
		print("[DataRegistry] load completed without errors")
	else:
		print("[DataRegistry] load completed with %d errors" % load_errors.size())


func _load_table(table_name: String, path: String) -> void:
	# 单表加载只负责文件读取与 JSON 解析，不混入跨表逻辑。
	if not FileAccess.file_exists(path):
		load_errors.append("Missing config file: %s" % path)
		tables[table_name] = []
		records_by_id[table_name] = {}
		return

	var raw_text := FileAccess.get_file_as_string(path)
	var parsed_data: Variant = JSON.parse_string(raw_text)
	if parsed_data == null:
		load_errors.append("Invalid JSON: %s" % path)
		tables[table_name] = []
		records_by_id[table_name] = {}
		return

	if not (parsed_data is Array):
		load_errors.append("Config root must be an array: %s" % path)
		tables[table_name] = []
		records_by_id[table_name] = {}
		return

	tables[table_name] = parsed_data
	records_by_id[table_name] = _build_id_index(table_name, parsed_data)


func _build_id_index(table_name: String, records: Array) -> Dictionary:
	# 按 id 建立快速索引，供后续跨表查询与校验使用。
	var index := {}
	for record_index in records.size():
		var record: Variant = records[record_index]
		if not (record is Dictionary):
			load_errors.append("%s[%d] must be an object." % [table_name, record_index])
			continue

		var record_id := str(record.get("id", ""))
		if record_id.strip_edges().is_empty():
			load_warnings.append("%s[%d] has no id, so it cannot be queried by id." % [table_name, record_index])
			continue
		if index.has(record_id):
			load_errors.append("Duplicate id in %s: %s" % [table_name, record_id])
			continue
		index[record_id] = record
	return index


func _validate_all_tables() -> void:
	var validator := DataValidator.new()
	validator.validate_all(tables, records_by_id)
	load_warnings.append_array(validator.get_warnings())
	load_errors.append_array(validator.get_errors())


func _record_has_any_tag(record: Variant, query_tags: Array[String]) -> bool:
	if not (record is Dictionary) or query_tags.is_empty():
		return false
	var record_tags: Variant = record.get("tags", [])
	if not (record_tags is Array):
		return false
	for tag in query_tags:
		if record_tags.has(tag):
			return true
	return false


func _record_has_all_tags(record: Variant, query_tags: Array[String]) -> bool:
	if not (record is Dictionary) or query_tags.is_empty():
		return false
	var record_tags: Variant = record.get("tags", [])
	if not (record_tags is Array):
		return false
	for tag in query_tags:
		if not record_tags.has(tag):
			return false
	return true
