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
	var modifier_success := _run_modifier_stack_checks()
	_print_table_counts()
	_print_lookup_checks()
	_print_formula_checks()
	_print_validation_messages()
	if load_success and modifier_success:
		print("[Bootstrap] data self-test passed")
	else:
		push_error("[Bootstrap] data self-test failed with %d data errors" % DataRegistry.get_load_errors().size())


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


func _run_modifier_stack_checks() -> bool:
	print("[Bootstrap] modifier stack checks")
	var passed := true
	var stack := ModifierStack.new()
	stack.set_base_stats({
		"max_hp": 100,
		"move_speed": 180,
		"melee_damage": 10,
		"armor": 100,
	})

	stack.add_modifier_from_dictionary({
		"id": "mod_test_melee_flat",
		"source_type": "test",
		"source_id": "flat_bonus",
		"target_scope": "player",
		"stat": "melee_damage",
		"operation": "add_flat",
		"value": 5,
		"duration": -1,
		"stack_rule": "unique",
	})
	stack.add_modifier_from_dictionary({
		"id": "mod_test_melee_percent",
		"source_type": "test",
		"source_id": "percent_bonus",
		"target_scope": "player",
		"stat": "melee_damage",
		"operation": "add_percent",
		"value": 50,
		"duration": -1,
		"stack_rule": "unique",
	})
	passed = _print_check_result("melee_damage add_flat/add_percent", is_equal_approx(stack.get_stat("melee_damage"), 23.0)) and passed

	stack.add_modifier_from_dictionary({
		"id": "mod_test_move_speed_1",
		"source_type": "camp",
		"source_id": "camp_test_training",
		"target_scope": "player",
		"stat": "move_speed",
		"operation": "add_flat",
		"value": 10,
		"duration": -1,
		"stack_rule": "replace_same_source",
	})
	stack.add_modifier_from_dictionary({
		"id": "mod_test_move_speed_2",
		"source_type": "camp",
		"source_id": "camp_test_training",
		"target_scope": "player",
		"stat": "move_speed",
		"operation": "add_flat",
		"value": 20,
		"duration": -1,
		"stack_rule": "replace_same_source",
	})
	passed = _print_check_result("replace_same_source", is_equal_approx(stack.get_stat("move_speed"), 200.0) and stack.get_modifier_count("move_speed") == 1) and passed

	stack.add_modifier_from_dictionary({
		"id": "mod_test_temporary_hp",
		"source_type": "temporary_buff",
		"source_id": "test_buff",
		"target_scope": "player",
		"stat": "max_hp",
		"operation": "add_flat",
		"value": 25,
		"duration": 0.5,
		"stack_rule": "unique",
	})
	var temporary_applied := is_equal_approx(stack.get_stat("max_hp"), 125.0)
	stack.tick(1.0)
	var temporary_expired := is_equal_approx(stack.get_stat("max_hp"), 100.0) and not stack.has_modifier("mod_test_temporary_hp")
	passed = _print_check_result("temporary modifier tick expiry", temporary_applied and temporary_expired) and passed

	var damage_taken_debug := stack.debug_stat("damage_taken_percent")
	var melee_debug := stack.debug_stat("melee_damage")
	var debug_ok := int(melee_debug.get("modifiers", []).size()) == 2 and int(damage_taken_debug.get("armor_damage_taken_rate", 0)) == 50
	passed = _print_check_result("debug_stat source chain", debug_ok) and passed
	print("[Bootstrap] - melee_damage final: %s" % str(melee_debug.get("final_value", 0)))
	print("[Bootstrap] - melee_damage modifier sources: %d" % int(melee_debug.get("modifiers", []).size()))
	print("[Bootstrap] - damage_taken_percent armor rate: %s" % str(damage_taken_debug.get("armor_damage_taken_rate", 0)))
	return passed


func _print_check_result(check_name: String, passed: bool) -> bool:
	if passed:
		print("[Bootstrap] - %s: passed" % check_name)
	else:
		push_error("[Bootstrap] - %s: failed" % check_name)
	return passed


func _print_validation_messages() -> void:
	var warnings := DataRegistry.get_load_warnings()
	var errors := DataRegistry.get_load_errors()
	print("[Bootstrap] validation warnings: %d" % warnings.size())
	for warning in warnings:
		push_warning("[Bootstrap] %s" % warning)
	print("[Bootstrap] validation errors: %d" % errors.size())
	for error in errors:
		push_error("[Bootstrap] %s" % error)
