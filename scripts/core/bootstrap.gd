extends Node

const RUN_DATA_SELF_TEST: bool = true
const TABLE_NAMES: Array[String] = [
	"weapons",
	"relics",
	"bonds",
	"characters",
	"enemies",
	"camp_buildings",
	"waves",
	"drop_tables",
]


func _ready() -> void:
	if RUN_DATA_SELF_TEST:
		run_data_self_test()


func run_data_self_test() -> void:
	print("[Bootstrap] data self-test started")
	var load_success := DataRegistry.reload_all()
	_print_table_counts()
	_print_lookup_checks()
	_print_formula_checks()
	_print_validation_messages()
	if load_success:
		print("[Bootstrap] data self-test passed")
	else:
		push_error("[Bootstrap] data self-test failed with %d errors" % DataRegistry.get_load_errors().size())


func _print_table_counts() -> void:
	print("[Bootstrap] config table counts")
	for table_name in TABLE_NAMES:
		print("[Bootstrap] - %s: %d" % [table_name, DataRegistry.get_record_count(table_name)])


func _print_lookup_checks() -> void:
	print("[Bootstrap] lookup checks")
	_print_lookup_result("weapons", "weapon_void_blade")
	_print_lookup_result("relics", "relic_flying_teeth")
	_print_lookup_result("bonds", "bond_mighty")
	_print_lookup_result("characters", "character_void_hunter")
	_print_lookup_result("enemies", "enemy_mutated_grub")
	_print_lookup_result("drop_tables", "drop_basic_enemy")
	_print_lookup_result("waves", "wave_stage_01")


func _print_lookup_result(table_name: String, record_id: String) -> void:
	if DataRegistry.has_record(table_name, record_id):
		print("[Bootstrap] - found %s.%s" % [table_name, record_id])
	else:
		push_error("[Bootstrap] - missing %s.%s" % [table_name, record_id])


func _print_formula_checks() -> void:
	var attack_interval := StatDefinitions.calculate_attack_interval(1.0, 100)
	var cooldown := StatDefinitions.calculate_cooldown(10.0, 40)
	var damage_taken_percent := StatDefinitions.calculate_damage_taken_from_armor(100)
	print("[Bootstrap] formula checks")
	print("[Bootstrap] - attack_speed=100: 1.00s -> %.2fs" % attack_interval)
	print("[Bootstrap] - cooldown_reduction=40: 10.00s -> %.2fs" % cooldown)
	print("[Bootstrap] - armor=100: damage_taken_percent=%d" % int(damage_taken_percent))


func _print_validation_messages() -> void:
	var warnings := DataRegistry.get_load_warnings()
	var errors := DataRegistry.get_load_errors()
	print("[Bootstrap] validation warnings: %d" % warnings.size())
	for warning in warnings:
		push_warning("[Bootstrap] %s" % warning)
	print("[Bootstrap] validation errors: %d" % errors.size())
	for error in errors:
		push_error("[Bootstrap] %s" % error)
