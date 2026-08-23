extends Node

const RUN_DATA_SELF_TEST: bool = true
const RUN_PLAYER_SELF_TEST: bool = true
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player_root.tscn")
const WEAPON_LOADOUT_SCENE: PackedScene = preload("res://scenes/weapons/weapon_loadout.tscn")
const WAVE_MANAGER_SCENE: PackedScene = preload("res://scenes/waves/wave_manager.tscn")
const CAMP_SCENE: PackedScene = preload("res://scenes/camp/camp_root.tscn")
const MAIN_FLOW_COORDINATOR_SCENE: PackedScene = preload("res://scenes/core/main_flow_coordinator.tscn")
const GAME_ROOT_SCENE: PackedScene = preload("res://scenes/core/game_root.tscn")
const DEBUG_ROOT_SCENE: PackedScene = preload("res://scenes/core/debug_root.tscn")
const ZONE_UI_CONTROLLER_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_ui_controller.tscn")
const ZONE_SELECT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_select_popup.tscn")
const ZONE_SELECT_CARD_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_select_card.tscn")
const ZONE_HARVEST_RESULT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_harvest_result_popup.tscn")
const FINANCE_UI_CONTROLLER_SCENE: PackedScene = preload("res://scenes/ui/finance/finance_ui_controller.tscn")
const FINANCE_POPUP_SCENE: PackedScene = preload("res://scenes/ui/finance/finance_popup.tscn")
const INTEREST_SETTLEMENT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/finance/interest_settlement_popup.tscn")
const SHOP_POPUP_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_popup.tscn")
const SHOP_UI_CONTROLLER_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_ui_controller.tscn")
const BATTLE_ROOT_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const MAIN_MENU_UI_CONTROLLER_SCENE: PackedScene = preload("res://scenes/ui/main_menu/main_menu_ui_controller.tscn")
const CAMP_UI_CONTROLLER_SCENE: PackedScene = preload("res://scenes/ui/camp/camp_ui_controller.tscn")
const REWARD_OPTION_SCENE: PackedScene = preload("res://scenes/ui/rewards/reward_option.tscn")
const TABLE_NAMES: Array[String] = [
	"weapons",
	"relics",
	"bonds",
	"characters",
	"enemies",
	"camp_buildings",
	"zones",
	"waves",
	"drop_tables",
]


func _ready() -> void:
	if RUN_DATA_SELF_TEST:
		run_data_self_test()


func run_data_self_test() -> void:
	# 启动后只做最小自检，避免把玩法逻辑塞进入口。
	print("[Bootstrap] data self-test started")
	GameGlobal.reset_runtime_state()
	GameGlobal.set_runtime_flag("bootstrap_self_test", true)
	GameGlobal.log_debug("bootstrap runtime ready")
	var load_success := DataRegistry.reload_all()
	var modifier_success := _run_modifier_stack_checks()
	var relic_success := _run_relic_bond_checks()
	var player_success := _run_player_checks()
	var survival_relic_success := _run_survival_relic_checks()
	var weapon_success := _run_weapon_checks()
	var enemy_wave_success := _run_enemy_wave_checks()
	var summon_success := _run_summon_checks()
	var camp_success := _run_camp_meta_checks()
	var zone_success := _run_zone_state_checks()
	var zone_ui_success := _run_zone_ui_checks()
	var audio_success := _run_audio_checks()
	var ui_success := _run_ui_flow_checks()
	var finance_success := _run_finance_checks()
	var main_flow_success := _run_main_flow_checks()
	_print_table_counts()
	_print_lookup_checks()
	_print_formula_checks()
	_print_engine_checks()
	_print_validation_messages()
	if load_success and modifier_success and relic_success and player_success and survival_relic_success and weapon_success and enemy_wave_success and summon_success and camp_success and zone_success and zone_ui_success and audio_success and ui_success and finance_success and main_flow_success:
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
	_print_lookup_result("relics", "relic_finance_manager")
	_print_lookup_result("relics", "relic_piggy_bank")
	_print_lookup_result("bonds", "bond_mighty")
	_print_lookup_result("characters", "character_void_hunter")
	_print_lookup_result("enemies", "enemy_mutated_grub")
	_print_lookup_result("zones", "zone_nearstring_battlefield")
	_print_lookup_result("drop_tables", "drop_basic_enemy")
	_print_lookup_result("waves", "wave_stage_01")


func _print_lookup_result(table_name: String, record_id: String) -> void:
	if DataRegistry.has_record(table_name, record_id):
		print("[Bootstrap] - found %s.%s" % [table_name, record_id])
	else:
		push_error("[Bootstrap] - missing %s.%s" % [table_name, record_id])


func _print_formula_checks() -> void:
	var attack_interval := StatDefinitions.calculate_attack_interval(1.0, 100)
	var damage_taken_percent := StatDefinitions.calculate_damage_taken_from_armor(100)
	var attack_radius := StatDefinitions.calculate_attack_radius(100, 40)
	var finance_interest := StatDefinitions.calculate_finance_interest_gain(101, 5)
	print("[Bootstrap] formula checks")
	print("[Bootstrap] - attack_speed=100: 1.00s -> %.2fs" % attack_interval)
	print("[Bootstrap] - armor=100: damage_taken_percent=%d" % int(damage_taken_percent))
	print("[Bootstrap] - area_size=40: radius 100 -> %d" % int(attack_radius))
	print("[Bootstrap] - finance=101 interest_rate=5: gain %d" % finance_interest)


func _print_engine_checks() -> void:
	# 确认工程基础设施类 Autoload 已接入且可读取状态。
	print("[Bootstrap] engine foundation checks")
	print("[Bootstrap] - GameGlobal mode: %s" % GameGlobal.game_mode)
	print("[Bootstrap] - GameGlobal bootstrap flag: %s" % str(GameGlobal.get_runtime_flag("bootstrap_self_test", false)))
	print("[Bootstrap] - GameRoot scene ready: %s" % str(GAME_ROOT_SCENE != null))
	print("[Bootstrap] - DebugRoot scene ready: %s" % str(DEBUG_ROOT_SCENE != null))
	print("[Bootstrap] - ZoneUIController scene ready: %s" % str(ZONE_UI_CONTROLLER_SCENE != null))
	print("[Bootstrap] - ZoneSelectPopup scene ready: %s" % str(ZONE_SELECT_POPUP_SCENE != null))
	print("[Bootstrap] - ZoneSelectCard scene ready: %s" % str(ZONE_SELECT_CARD_SCENE != null))
	print("[Bootstrap] - ZoneHarvestResultPopup scene ready: %s" % str(ZONE_HARVEST_RESULT_POPUP_SCENE != null))


func _run_modifier_stack_checks() -> bool:
	# 用少量样例验证 modifier 叠加、替换、过期和调试输出。
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
	var shop_offer_count_ok := StatDefinitions.calculate_shop_offer_count(3, 2.0) == 5 and StatDefinitions.calculate_shop_offer_count(3, -999.0) == 2
	passed = _print_check_result("shop offer count bonus and minimum", shop_offer_count_ok) and passed

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


func _run_relic_bond_checks() -> bool:
	print("[Bootstrap] relic bond checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	if player == null:
		return false
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	var relic_system: RelicBondSystem = RelicBondSystem.new()
	relic_system.initialize(player)
	relic_system.set_weapon_ids(player.get_start_weapon_ids())
	passed = _print_check_result("relic system init", relic_system != null and relic_system.get_total_relic_count() == 0) and passed
	passed = _print_check_result("relic max_stack zero", int(DataRegistry.get_record("relics", "relic_piggy_bank").get("max_stack", -1)) == 0) and passed
	passed = _print_check_result("relic add modifier", relic_system.add_relic("relic_finance_manager") and int(player.get_stat("interest_rate")) == 6) and passed
	passed = _print_check_result("bond count zero without bond relic", relic_system.get_bond_count("bond_chosen") == 0) and passed
	passed = _print_check_result("bond count stays zero without bond relic", relic_system.add_relic("relic_high_yield_contract") and relic_system.get_bond_count("bond_chosen") == 0 and relic_system.get_active_bond_layers("bond_chosen") == 0) and passed
	passed = _print_check_result("bond count still zero after second relic", relic_system.add_relic("relic_goblin_central_bank_printer") and relic_system.get_bond_count("bond_chosen") == 0 and relic_system.get_active_bond_layers("bond_chosen") == 0) and passed
	passed = _print_check_result("relic stack unlimited", relic_system.can_add_relic("relic_piggy_bank")) and passed
	player.queue_free()
	return passed


func _run_player_checks() -> bool:
	if not RUN_PLAYER_SELF_TEST:
		return true

	print("[Bootstrap] player checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	passed = _print_check_result("player scene instantiate", player != null) and passed

	if player != null:
		player.auto_initialize_on_ready = false
		add_child(player)
		var initialized := player.initialize_from_character("character_void_hunter")
		passed = _print_check_result("player initialize character", initialized) and passed
		var base_stats: Dictionary = player.character_data.get("base_stats", {})
		var configured_max_hp := int(base_stats.get("max_hp", player.get_stat("max_hp")))
		var configured_move_speed := float(base_stats.get("move_speed", player.get_stat("move_speed")))
		passed = _print_check_result("player max_hp", int(player.get_stat("max_hp")) == configured_max_hp and player.current_hp == configured_max_hp) and passed
		passed = _print_check_result("player move_speed", is_equal_approx(player.get_stat("move_speed"), configured_move_speed)) and passed
		passed = _print_check_result("player start weapons", player.get_start_weapon_ids().has("weapon_void_blade")) and passed
		var pickup_radius := 0.0
		var pickup_shape := player.get_node_or_null("PickupArea/CollisionShape2D") as CollisionShape2D
		if pickup_shape != null and pickup_shape.shape is CircleShape2D:
			pickup_radius = (pickup_shape.shape as CircleShape2D).radius
		passed = _print_check_result("player pickup radius", is_equal_approx(pickup_radius, player.get_stat("pickup_radius"))) and passed

		player.add_runtime_modifier({
			"id": "mod_test_player_armor",
			"source_type": "test",
			"source_id": "bootstrap_player_check",
			"target_scope": "player",
			"stat": "armor",
			"operation": "add_flat",
			"value": 100,
			"duration": -1,
			"stack_rule": "unique",
		})
		var hp_before_damage := player.current_hp
		var shield_before_damage := player.current_shield
		var dealt_damage := player.take_damage(1, "bootstrap_test")
		var expected_shield_after_damage := maxi(shield_before_damage - dealt_damage, 0)
		var expected_hp_damage := maxi(dealt_damage - shield_before_damage, 0)
		var expected_hp_after_damage := maxi(hp_before_damage - expected_hp_damage, 0)
		passed = _print_check_result("player damage flow", player.current_hp == expected_hp_after_damage and player.current_shield == expected_shield_after_damage) and passed
		player._physics_process(1.0)
		player.add_runtime_modifier({
			"id": "mod_test_player_revive",
			"source_type": "test",
			"source_id": "bootstrap_player_check",
			"target_scope": "player",
			"stat": "revive_count",
			"operation": "add_flat",
			"value": 1,
			"duration": -1,
			"stack_rule": "unique",
		})
		player.take_damage(999, "bootstrap_revive_check")
		passed = _print_check_result("player extra revive", player.alive and player.get_remaining_revives() == 0 and player.current_hp == 5) and passed
		player.queue_free()
	return passed


func _run_survival_relic_checks() -> bool:
	if not RUN_PLAYER_SELF_TEST:
		return true

	print("[Bootstrap] survival relic checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	passed = _print_check_result("survival relic scene instantiate", player != null) and passed
	if player == null:
		return false
	player.auto_initialize_on_ready = false
	add_child(player)
	passed = _print_check_result("survival relic player initialize", player.initialize_from_character("character_void_hunter")) and passed

	var base_max_hp := int(player.get_stat("max_hp"))
	var base_armor := player.get_stat("armor")
	var base_move_speed := player.get_stat("move_speed")
	passed = _print_check_result("survival relic flat stats", player.add_relic("relic_worn_hemostatic_cloth") and int(player.get_stat("max_hp")) == base_max_hp + 3) and passed
	passed = _print_check_result("survival relic negative movement", player.add_relic("relic_load_iron_bracer") and is_equal_approx(player.get_stat("move_speed"), base_move_speed - 5.0)) and passed

	passed = _print_check_result("survival relic low hp armor", player.add_relic("relic_broken_crystal")) and passed
	player.take_damage(6, "bootstrap_relic_check")
	passed = _print_check_result("survival relic low hp condition", player.get_stat("armor") >= base_armor + 15.0) and passed
	player.heal(99)
	passed = _print_check_result("survival relic condition clears", is_equal_approx(player.get_stat("armor"), base_armor + 8.0)) and passed

	passed = _print_check_result("survival relic shield start", player.add_relic("relic_dead_shield_badge")) and passed
	player.current_shield = 0
	player.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_START)
	passed = _print_check_result("survival relic shield granted", player.current_shield == 15) and passed

	passed = _print_check_result("survival relic shield regen add", player.add_relic("relic_barrier_crystal")) and passed
	player.current_shield = 0
	player._physics_process(1.0)
	passed = _print_check_result("survival relic shield regen", player.current_shield >= 2) and passed

	passed = _print_check_result("survival relic low sanity movement", player.add_relic("relic_lost_wayfarer_greave")) and passed
	player.add_runtime_modifier({
		"id": "mod_bootstrap_low_humanity",
		"source_type": "test",
		"source_id": "survival_relic_check",
		"target_scope": "player",
		"stat": "humanity",
		"operation": "add_flat",
		"value": -50,
		"duration": -1,
		"stack_rule": "unique",
	})
	passed = _print_check_result("survival relic conditional movement", is_equal_approx(player.get_stat("move_speed"), base_move_speed + 7.0)) and passed

	passed = _print_check_result("survival relic wave end trigger", player.add_relic("relic_vitality_potion")) and passed
	player.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	passed = _print_check_result("survival relic wave end stat", player.get_stat("divinity") >= 1.0) and passed

	passed = _print_check_result("survival relic revive trigger", player.add_relic("relic_costly_seed_of_life")) and passed
	player.take_damage(999, "bootstrap_relic_revive_check")
	passed = _print_check_result("survival relic revive effect", player.alive and player.get_stat("divinity") >= 21.0) and passed

	passed = _print_check_result("survival relic derived stat", player.add_relic("relic_chain_of_hardship")) and passed
	passed = _print_check_result("survival relic derived armor", player.get_stat("armor") >= 16.0) and passed
	player.queue_free()
	return passed


func _run_enemy_wave_checks() -> bool:
	print("[Bootstrap] enemy wave checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var wave_manager := WAVE_MANAGER_SCENE.instantiate() as WaveManager
	passed = _print_check_result("enemy wave test scene instantiate", player != null and wave_manager != null) and passed
	if player == null or wave_manager == null:
		return false

	player.auto_initialize_on_ready = false
	add_child(player)
	add_child(wave_manager)
	player.initialize_from_character("character_void_hunter")
	wave_manager.enemy_root = wave_manager.get_node_or_null("EnemyRoot")
	wave_manager.pickup_root = wave_manager.get_node_or_null("PickupRoot")
	wave_manager.initialize(player)
	passed = _print_check_result("enemy config load", DataRegistry.has_record("enemies", "enemy_mutated_grub")) and passed
	passed = _print_check_result("wave config load", DataRegistry.has_record("waves", "wave_stage_01")) and passed
	passed = _print_check_result("wave duration formula", wave_manager.calculate_wave_duration(0) == 30 and wave_manager.calculate_wave_duration(6) == 60) and passed

	var enemy := wave_manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(20, 0))
	passed = _print_check_result("enemy instantiate", enemy != null and enemy.current_hp == 20) and passed
	if enemy != null:
		var previous_hp := player.current_hp
		enemy._process_contact_damage()
		passed = _print_check_result("enemy contact damage knockback", player.current_hp < previous_hp and enemy.has_contact_damaged and enemy.velocity.length() > 0.0) and passed
		player.add_runtime_modifier({
			"id": "mod_test_on_kill_heal",
			"source_type": "test",
			"source_id": "bootstrap_enemy_wave_check",
			"target_scope": "player",
			"stat": "on_kill_heal",
			"operation": "add_flat",
			"value": 2,
			"duration": -1,
			"stack_rule": "unique",
		})
		var hp_before_kill := player.current_hp
		var dealt_damage := enemy.take_damage(999, "bootstrap")
		passed = _print_check_result("enemy damage and death", dealt_damage > 0 and not enemy.alive) and passed
		passed = _print_check_result("enemy kill heal", player.current_hp == mini(int(player.get_stat("max_hp")), hp_before_kill + 2)) and passed

	player.add_runtime_modifier({
		"id": "mod_test_enemy_spawn_rate",
		"source_type": "test",
		"source_id": "bootstrap_enemy_wave_check",
		"target_scope": "player",
		"stat": "enemy_spawn_rate_percent",
		"operation": "add_flat",
		"value": 20,
		"duration": -1,
		"stack_rule": "unique",
	})
	passed = _print_check_result("enemy spawn rate", wave_manager.calculate_enemy_spawn_count(3) == 4) and passed

	var orb := wave_manager.spawn_exp_orb(4, player.global_position + Vector2(8, 0))
	passed = _print_check_result("enemy drop table link", DataRegistry.has_record("drop_tables", "drop_basic_enemy") and orb != null) and passed
	var shared_reward_shop_counter := {"count": 0}
	wave_manager.shared_reward_shop_requested.connect(func(_level: int) -> void: shared_reward_shop_counter["count"] = int(shared_reward_shop_counter.get("count", 0)) + 1)
	var expected_collected_exp := 4 + _get_guaranteed_exp_drop_amount("drop_basic_enemy")
	wave_manager.collect_all_exp_orbs()
	var expected_after_collect := _calculate_level_state_after_exp(expected_collected_exp)
	passed = _print_check_result("wave collect exp orbs", wave_manager.current_exp == int(expected_after_collect.get("current_exp", 0)) and wave_manager.current_gold == expected_collected_exp and wave_manager.player_level == int(expected_after_collect.get("player_level", 1)) and int(shared_reward_shop_counter.get("count", 0)) >= int(expected_after_collect.get("level_ups", 0))) and passed

	player.add_runtime_modifier({
		"id": "mod_test_reward_drop_rate",
		"source_type": "test",
		"source_id": "bootstrap_reward_check",
		"target_scope": "player",
		"stat": "drop_rate_percent",
		"operation": "add_flat",
		"value": 2000,
		"duration": -1,
		"stack_rule": "unique",
	})
	var reward_system := DropRewardSystem.new()
	var reward_actions := reward_system.build_drop_actions("drop_basic_enemy", player)
	var reward_action_types := {}
	for action in reward_actions:
		reward_action_types[str(action.get("type", ""))] = true
	passed = _print_check_result("reward action build", reward_action_types.has("exp_orb") and reward_action_types.has("health_pack")) and passed

	player.take_damage(10, "bootstrap_reward_check")
	var hp_before_reward := player.current_hp
	var health_pack := wave_manager.spawn_health_pack(6, player.global_position + Vector2(8, 0))
	passed = _print_check_result("health pack spawn", health_pack != null) and passed
	health_pack.collect()
	passed = _print_check_result("health pack collection", player.current_hp == hp_before_reward + 6 and int(wave_manager.get_reward_snapshot().get("health_restored", 0)) >= 6 and int(wave_manager.get_reward_snapshot().get("spawned_health_packs", 0)) >= 1) and passed

	wave_manager.add_exp_and_gold(10, 0)
	var expected_after_bonus_exp := _calculate_level_state_after_exp(expected_collected_exp + 10)
	passed = _print_check_result("level up shared reward/shop trigger", int(shared_reward_shop_counter.get("count", 0)) >= int(expected_after_bonus_exp.get("level_ups", 0)) and wave_manager.player_level == int(expected_after_bonus_exp.get("player_level", 1)) and wave_manager.current_exp == int(expected_after_bonus_exp.get("current_exp", 0))) and passed

	wave_manager.queue_free()
	player.queue_free()
	return passed


func _run_summon_checks() -> bool:
	print("[Bootstrap] summon checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var wave_manager := WAVE_MANAGER_SCENE.instantiate() as WaveManager
	passed = _print_check_result("summon test scene instantiate", player != null and wave_manager != null) and passed
	if player == null or wave_manager == null:
		return false

	player.auto_initialize_on_ready = false
	add_child(player)
	add_child(wave_manager)
	player.initialize_from_character("character_void_hunter")
	wave_manager.initialize(player)
	passed = _print_check_result("summon root initialize", wave_manager.summon_root != null and wave_manager.summon_root.owner_player == player) and passed

	player.add_runtime_modifier({
		"id": "mod_test_summon_damage",
		"source_type": "test",
		"source_id": "bootstrap_summon_check",
		"target_scope": "player",
		"stat": "summon_damage",
		"operation": "add_flat",
		"value": 6,
		"duration": -1,
		"stack_rule": "unique",
	})
	player.add_runtime_modifier({
		"id": "mod_test_summon_count",
		"source_type": "test",
		"source_id": "bootstrap_summon_check",
		"target_scope": "player",
		"stat": "summon_count",
		"operation": "add_flat",
		"value": 2,
		"duration": -1,
		"stack_rule": "unique",
	})

	var summons := wave_manager.spawn_default_summons(1)
	passed = _print_check_result("summon count bonus", summons.size() == 3 and wave_manager.summon_root.get_active_summon_count() == 3) and passed
	var summon := summons[0] if not summons.is_empty() else null
	passed = _print_check_result("summon inherited damage", summon != null and int(summon.get_stat("summon_damage")) == 10) and passed
	if summon != null:
		var enemy := wave_manager.spawn_enemy("enemy_mutated_grub", summon.global_position + Vector2(10, 0))
		var dealt_damage := summon.try_attack_target(enemy, false, true) if enemy != null else 0
		passed = _print_check_result("summon attack enemy", enemy != null and dealt_damage == 10 and enemy.current_hp == 10) and passed

	wave_manager.clear_summons()
	wave_manager.summon_root.hard_cap = 2
	var capped_summons := wave_manager.spawn_default_summons(1)
	passed = _print_check_result("summon hard cap", capped_summons.size() == 2 and wave_manager.summon_root.get_active_summon_count() == 2) and passed
	wave_manager.clear_battle_entities()
	passed = _print_check_result("summon clear battle entities", wave_manager.summon_root.get_active_summon_count() == 0) and passed

	wave_manager.queue_free()
	player.queue_free()
	return passed


func _run_camp_meta_checks() -> bool:
	print("[Bootstrap] camp meta progression checks")
	var passed := true
	CampProgression.begin_transient_session()
	passed = _print_check_result("camp config load", DataRegistry.has_record("camp_buildings", "camp_armory_workshop") and DataRegistry.get_record_count("camp_buildings") == 8) and passed
	passed = _print_check_result("camp state init", CampProgression.is_building_unlocked("camp_armory_workshop") and CampProgression.get_building_level("camp_armory_workshop") == 1) and passed
	var camp_save_state := CampProgression.get_state()
	var camp_save_schema_ok := camp_save_state.has("schema_version") and camp_save_state.has("profile_id") and camp_save_state.has("currencies") and camp_save_state.has("settings")
	camp_save_schema_ok = camp_save_schema_ok and not camp_save_state.has("unlocks") and not camp_save_state.has("records")
	camp_save_schema_ok = camp_save_schema_ok and not camp_save_state.has("selected_character_id") and not camp_save_state.has("selected_start_weapons")
	passed = _print_check_result("camp save schema", camp_save_schema_ok) and passed
	passed = _print_check_result("camp ruins state", CampProgression.get_building_display_state("camp_farstar_range") == "ruins") and passed
	var camp_root := CAMP_SCENE.instantiate() as CampRoot
	passed = _print_check_result("camp scene instantiate", camp_root != null) and passed
	if camp_root != null:
		add_child(camp_root)
		passed = _print_check_result("camp scene slot count", camp_root.get_building_slot_count() == DataRegistry.get_record_count("camp_buildings")) and passed
		passed = _print_check_result("camp scene slot lookup", camp_root.get_building_slot("camp_armory_workshop") != null and camp_root.get_building_slot("camp_farstar_range") != null) and passed
	CampProgression.add_camp_currency(400)
	var farstar_unlock_ok := CampProgression.purchase_building_unlock("camp_farstar_range")
	passed = _print_check_result("camp unlock sync", farstar_unlock_ok and CampProgression.is_building_unlocked("camp_farstar_range") and CampProgression.get_building_level("camp_farstar_range") == 1) and passed
	var building_unlock_ok := CampProgression.purchase_building_unlock("camp_council_hall")
	passed = _print_check_result("camp currency unlock", building_unlock_ok and CampProgression.is_building_unlocked("camp_council_hall") and CampProgression.get_building_level("camp_council_hall") == 1) and passed
	var purchase_ok := CampProgression.purchase_upgrade("camp_upgrade_melee_damage")
	passed = _print_check_result("camp upgrade option", purchase_ok and CampProgression.get_upgrade_option_level("camp_upgrade_melee_damage") == 1) and passed
	if camp_root != null:
		camp_root.queue_free()
	CampProgression.end_transient_session()
	return passed



func _run_zone_state_checks() -> bool:
	print("[Bootstrap] zone streak fortune checks")
	var passed := true
	if not ZoneProgression.has_zone_records():
		push_error("[Bootstrap] zone table missing")
		return false
	var zone_count := ZoneProgression.get_zone_records().size()
	passed = _print_check_result("zone table count", zone_count >= 3) and passed
	var player := PLAYER_SCENE.instantiate() as PlayerController
	passed = _print_check_result("zone test player instantiate", player != null) and passed
	if player == null:
		return false

	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	ZoneProgression.reset_state(player)

	var initial_selection := ZoneProgression.select_zone("zone_nearstring_battlefield", 1, player)
	passed = _print_check_result("zone initial select", bool(initial_selection.get("success", false)) and initial_selection.get("action", "") == "initial" and ZoneProgression.get_current_zone_id() == "zone_nearstring_battlefield" and ZoneProgression.get_current_streak_count() == 1 and ZoneProgression.get_fortune_storage() == 0) and passed

	var stay_selection := ZoneProgression.select_zone("zone_nearstring_battlefield", 2, player)
	var expected_fortune_gain := ZoneProgression.calculate_fortune_gain(2, 2)
	passed = _print_check_result("zone stay accumulation", bool(stay_selection.get("success", false)) and stay_selection.get("action", "") == "stay" and int(stay_selection.get("fortune_gain", -1)) == expected_fortune_gain and ZoneProgression.get_current_streak_count() == 2 and ZoneProgression.get_fortune_storage() == expected_fortune_gain) and passed
	passed = _print_check_result("zone pressure applied", int(player.get_stat("damage_taken_percent")) == 103) and passed

	var runtime_context := ZoneProgression.get_zone_runtime_context()
	passed = _print_check_result("zone runtime context", int(runtime_context.get("zone_streak_count", 0)) == 2 and int(runtime_context.get("zone_fortune_storage", 0)) == expected_fortune_gain) and passed
	passed = _print_check_result("zone harvest context", not ZoneProgression.build_harvest_context("zone_meteor_tower").is_empty()) and passed

	var switch_selection := ZoneProgression.select_zone("zone_meteor_tower", 3, player)
	passed = _print_check_result("zone switch harvest", bool(switch_selection.get("success", false)) and bool(switch_selection.get("harvested", false)) and not switch_selection.get("harvest_payload", {}).is_empty() and ZoneProgression.get_current_zone_id() == "zone_meteor_tower" and ZoneProgression.get_current_streak_count() == 1 and ZoneProgression.get_fortune_storage() == 0 and int(player.get_stat("damage_taken_percent")) == 100) and passed
	ZoneProgression.acknowledge_harvest_result()
	passed = _print_check_result("zone harvest acknowledge", not ZoneProgression.is_harvest_pending()) and passed

	ZoneProgression.reset_state(player)
	player.queue_free()
	return passed


func _run_zone_ui_checks() -> bool:
	print("[Bootstrap] zone ui checks")
	var passed := true
	var controller := ZONE_UI_CONTROLLER_SCENE.instantiate()
	passed = _print_check_result("zone ui controller instantiate", controller != null) and passed
	if controller != null:
		passed = _print_check_result("zone ui controller layer", controller.get_node_or_null("PopupLayer") != null and controller.get_node_or_null("DebugLayer") == null) and passed
		passed = _print_check_result("zone ui select popup", controller.get_node_or_null("PopupLayer/ZoneSelectPopup") != null) and passed
		passed = _print_check_result("zone ui harvest popup", controller.get_node_or_null("PopupLayer/ZoneHarvestResultPopup") != null) and passed
		controller.queue_free()

	var select_popup := ZONE_SELECT_POPUP_SCENE.instantiate()
	passed = _print_check_result("zone select popup instantiate", select_popup != null and select_popup.get_node_or_null("CenterContainer/MainPanel/Content/ZoneCardGrid") != null) and passed
	if select_popup != null:
		select_popup.queue_free()
	var select_card := ZONE_SELECT_CARD_SCENE.instantiate()
	passed = _print_check_result("zone select card instantiate", select_card != null and select_card.get_node_or_null("Content/SelectButton") != null) and passed
	if select_card != null:
		select_card.queue_free()
	var harvest_popup := ZONE_HARVEST_RESULT_POPUP_SCENE.instantiate()
	passed = _print_check_result("zone harvest popup instantiate", harvest_popup != null and harvest_popup.get_node_or_null("CenterContainer/MainPanel/Content/ConfirmButton") != null) and passed
	if harvest_popup != null:
		harvest_popup.queue_free()
	var game_root := GAME_ROOT_SCENE.instantiate() as GameRoot
	passed = _print_check_result("game root zone ui controller", game_root != null and game_root.get_node_or_null("UiRoot/ZoneUIController") != null) and passed
	if game_root != null:
		game_root.queue_free()
	return passed


func _run_audio_checks() -> bool:
	print("[Bootstrap] audio checks")
	var passed := true
	passed = _print_check_result("audio manager autoload", AudioManager != null) and passed
	passed = _print_check_result("audio sfx bus", AudioServer.get_bus_index(AudioManager.BUS_SFX) >= 0) and passed
	var bgm_played := AudioManager.play_bgm("menu")
	passed = _print_check_result("audio menu bgm playback", bgm_played and AudioManager.current_bgm_id == "menu") and passed
	var weapon_sfx_played := AudioManager.play_weapon_hit_sfx("weapon_void_blade", 0)
	passed = _print_check_result("weapon hit sfx missing fallback", weapon_sfx_played == false) and passed
	AudioManager.set_bus_volume(AudioManager.BUS_SFX, 90, false)
	passed = _print_check_result("audio volume set fallback", AudioServer.get_bus_index(AudioManager.BUS_SFX) >= 0) and passed
	return passed


func _run_ui_flow_checks() -> bool:
	print("[Bootstrap] ui flow checks")
	var passed := true
	var reward_option := REWARD_OPTION_SCENE.instantiate() as RewardOption
	passed = _print_check_result("reward option scene instantiate", reward_option != null) and passed
	if reward_option != null:
		var sample_offer := {
			"offer_id": "weapon_upgrade:weapon_void_blade:2",
			"offer_type": ShopOfferGenerator.OFFER_WEAPON_UPGRADE,
			"rarity": "rare",
			"target_id": "weapon_void_blade",
			"display_name": "虚空刃 升至2级",
			"load_cost": 12,
			"to_level": 2,
			"effects": [],
		}
		var free_button_text := reward_option.get_button_text_for_offer(sample_offer, RewardOption.ENTRY_FREE)
		var shop_button_text := reward_option.get_button_text_for_offer(sample_offer, RewardOption.ENTRY_SHOP, 18)
		passed = _print_check_result("reward option free button text", free_button_text == "选择") and passed
		passed = _print_check_result("reward option shop button text", shop_button_text == "18") and passed
		reward_option.queue_free()
	var interest_popup := INTEREST_SETTLEMENT_POPUP_SCENE.instantiate()
	passed = _print_check_result("interest settlement popup instantiate", interest_popup != null and interest_popup.get_node_or_null("CenterContainer/MainPanel/Content/ConfirmButton") != null) and passed
	if interest_popup != null:
		interest_popup.queue_free()
	var shop_popup := SHOP_POPUP_SCENE.instantiate()
	passed = _print_check_result("shop popup instantiate", shop_popup != null and shop_popup.get_node_or_null("CenterContainer/MainPanel/Content/OfferGrid") != null) and passed
	if shop_popup != null:
		shop_popup.queue_free()
	var shop_controller := SHOP_UI_CONTROLLER_SCENE.instantiate()
	passed = _print_check_result("shop ui controller instantiate", shop_controller != null and shop_controller.get_node_or_null("PopupLayer/ShopPopup") != null) and passed
	if shop_controller != null:
		shop_controller.queue_free()
	var battle_root := BATTLE_ROOT_SCENE.instantiate()
	passed = _print_check_result("battle root instantiate", battle_root != null and battle_root.get_node_or_null("Player") != null and battle_root.get_node_or_null("Loadout") != null and battle_root.get_node_or_null("WaveManager") != null and battle_root.get_node_or_null("HUD/PreparePanel") == null) and passed
	if battle_root != null:
		battle_root.queue_free()
	var main_menu_controller := MAIN_MENU_UI_CONTROLLER_SCENE.instantiate()
	var main_menu_has_start_nodes := main_menu_controller != null and main_menu_controller.get_node_or_null("StartPage/Background") != null and main_menu_controller.get_node_or_null("StartPage/ContentMargin/ContentColumn/TitleArea/TitleCenter/TitleStack/TitleArt") != null and main_menu_controller.get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell/StartBattleButton") != null and main_menu_controller.get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell/CampEntryButton") != null and main_menu_controller.get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/QuitButton") != null
	var main_menu_has_flow_pages := main_menu_controller != null and main_menu_controller.get_node_or_null("CharacterSelectPage") != null and main_menu_controller.get_node_or_null("BattleResultPanel") != null
	passed = _print_check_result("main menu ui controller instantiate", main_menu_has_start_nodes and main_menu_has_flow_pages) and passed
	if main_menu_controller != null:
		main_menu_controller.queue_free()
	var camp_ui_controller := CAMP_UI_CONTROLLER_SCENE.instantiate()
	passed = _print_check_result("camp ui controller instantiate", camp_ui_controller != null and camp_ui_controller.get_node_or_null("MainSplit/BuildingListPanel/BuildingList") != null and camp_ui_controller.get_node_or_null("MainSplit/DetailPanel/DetailContent/UpgradeOptionsList") != null) and passed
	if camp_ui_controller != null:
		camp_ui_controller.queue_free()
	return passed


func _run_weapon_checks() -> bool:
	print("[Bootstrap] weapon checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var loadout := WEAPON_LOADOUT_SCENE.instantiate() as WeaponLoadout
	passed = _print_check_result("weapon test scene instantiate", player != null and loadout != null) and passed
	if player == null or loadout == null:
		return false

	player.auto_initialize_on_ready = false
	add_child(player)
	add_child(loadout)
	player.initialize_from_character("character_void_hunter")
	var initialized := loadout.initialize(player)
	passed = _print_check_result("weapon loadout initialize", initialized and loadout.get_weapon_instances().size() == 1) and passed
	passed = _print_check_result("weapon load cost", loadout.get_total_load_cost() == 12 and loadout.get_load_capacity() == 100) and passed

	var weapon := loadout.get_weapon_instance("weapon_void_blade")
	passed = _print_check_result("weapon instance lookup", weapon != null) and passed
	if weapon != null:
		passed = _print_check_result("weapon config runtime fields", int(weapon.get_attack_range()) == 420 and int(weapon.get_hit_radius()) == 10 and int(weapon.get_projectile_speed()) == 500 and int(weapon.get_spread_angle()) == 12) and passed
		passed = _print_check_result("weapon area_size radius", int(StatDefinitions.calculate_attack_radius(100, 40)) == 140) and passed
		passed = _print_check_result("weapon attack interval base", is_equal_approx(weapon.get_actual_attack_interval_seconds(), 0.7)) and passed
		player.add_runtime_modifier({
			"id": "mod_test_weapon_attack_speed",
			"source_type": "test",
			"source_id": "bootstrap_weapon_check",
			"target_scope": "player",
			"stat": "attack_speed",
			"operation": "add_flat",
			"value": 100,
			"duration": -1,
			"stack_rule": "unique",
		})
		passed = _print_check_result("weapon attack_speed interval", is_equal_approx(weapon.get_actual_attack_interval_seconds(), 0.35)) and passed
		var upgraded := loadout.upgrade_weapon("weapon_void_blade")
		passed = _print_check_result("weapon upgrade", upgraded and weapon.level == 2 and int(weapon.get_weapon_stat("ranged_damage")) == 10 and weapon.attack_interval_ms == 650) and passed
		var damage_events := weapon.calculate_damage_events(false)
		var damage_ok := damage_events.size() == 1 and damage_events[0].damage_kind == "ranged" and damage_events[0].damage >= 10
		passed = _print_check_result("weapon damage event", damage_ok) and passed
		var first_projectile_sfx_request := weapon.play_projectile_hit_sfx("projectile_1")
		var second_projectile_sfx_request := weapon.play_projectile_hit_sfx("projectile_1")
		var projectile_sfx_once := weapon.get_hit_sfx_path().ends_with("sfx_weapon_void_blade_hit.ogg") and weapon.has_played_projectile_hit_sfx("projectile_1") and second_projectile_sfx_request == false and first_projectile_sfx_request
		passed = _print_check_result("weapon projectile hit sfx once", projectile_sfx_once) and passed
		var attack_target := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		if attack_target != null:
			attack_target.auto_initialize_on_ready = false
			add_child(attack_target)
			attack_target.global_position = player.global_position + Vector2(32, 0)
			attack_target.initialize("enemy_mutated_grub", player)
			var hp_before_attack := attack_target.current_hp
			loadout.tick(0.0)
			var spawned_projectile := false
			for child in get_children():
				if child is ProjectileInstance:
					spawned_projectile = true
					child.queue_free()
			passed = _print_check_result("weapon loadout runtime projectile spawn", spawned_projectile and attack_target.current_hp == hp_before_attack) and passed
			attack_target.queue_free()
		else:
			passed = _print_check_result("weapon loadout runtime projectile spawn", false) and passed

	var mixed_weapon := WeaponInstance.new()
	mixed_weapon.initialize("weapon_dome_shockwave", player)
	var mixed_events := mixed_weapon.calculate_damage_events(false)
	var mixed_ok := mixed_events.size() == 2 and mixed_events[0].damage_kind == "melee" and mixed_events[1].damage_kind == "ranged"
	passed = _print_check_result("weapon mixed damage split", mixed_ok) and passed
	var first_area_sfx_request := mixed_weapon.play_attack_hit_sfx()
	var second_area_sfx_request := mixed_weapon.play_attack_hit_sfx()
	var area_sfx_once := mixed_weapon.get_hit_sfx_path().ends_with("sfx_weapon_dome_shockwave_hit.ogg") and mixed_weapon.has_played_attack_hit_sfx() and second_area_sfx_request == false and first_area_sfx_request
	passed = _print_check_result("weapon area hit sfx once", area_sfx_once) and passed

	var duplicate_purchase_rejected := not loadout.try_buy_weapon("weapon_void_blade")
	passed = _print_check_result("weapon duplicate purchase rejected", duplicate_purchase_rejected) and passed
	var overload_success := loadout.try_buy_weapon("weapon_dome_shockwave")
	player.add_runtime_modifier({
		"id": "mod_test_weapon_load_capacity_limit",
		"source_type": "test",
		"source_id": "bootstrap_weapon_check",
		"target_scope": "player",
		"stat": "load_capacity",
		"operation": "add_flat",
		"value": -60,
		"duration": -1,
		"stack_rule": "unique",
	})
	overload_success = overload_success and not loadout.try_buy_weapon("weapon_mutated_cleaver")
	passed = _print_check_result("weapon purchase load limit", overload_success and loadout.get_total_load_cost() <= loadout.get_load_capacity()) and passed

	var shop_generator := ShopOfferGenerator.new()
	var shop_context := {
		"owned_weapon_ids": ["weapon_void_blade"],
		"equipped_weapons": [{"weapon_id": "weapon_void_blade", "level": 2}],
		"unlocked_weapon_ids": ["weapon_mutated_cleaver", "weapon_dome_shockwave"],
		"unlocked_relic_ids": ["relic_piggy_bank", "relic_finance_manager", "relic_dividend_check"],
		"owned_relic_counts": {},
		"current_load": 12,
		"load_capacity": 100,
		"weapon_upgrade_miss_count": 0,
		"shop_price_percent": 20,
	}
	var shop_candidates := shop_generator.build_shop_candidate_pool(shop_context)
	var shop_rarity_weights := shop_generator.get_shop_rarity_weights(100)
	var shop_context_with_candidates := shop_context.duplicate(true)
	shop_context_with_candidates["candidate_pool"] = shop_candidates
	var shop_type_weights := shop_generator.get_shop_type_weights(shop_context_with_candidates)
	var default_shop_offer_count := StatDefinitions.calculate_shop_offer_count(MainFlowCoordinator.BASE_SHOP_OFFER_COUNT, 0.0)
	var shop_offers := shop_generator.roll_shop_offers(shop_rarity_weights, shop_type_weights, shop_candidates, default_shop_offer_count)
	var upgrade_offer_count := 0
	var upgrade_keys := {}
	for offer in shop_offers:
		if str(offer.get("offer_type", "")) == ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
			upgrade_offer_count += 1
			upgrade_keys[offer.get("offer_id", "")] = true
	var shop_check := not shop_candidates.is_empty() and not shop_rarity_weights.is_empty() and shop_offers.size() == mini(default_shop_offer_count, shop_candidates.size()) and upgrade_offer_count <= 1
	passed = _print_check_result("shared reward/shop pool generation", shop_check) and passed
	var discounted_weapon_cost := -1
	for candidate in shop_candidates:
		if str(candidate.get("target_id", "")) == "weapon_mutated_cleaver":
			discounted_weapon_cost = int(candidate.get("shop_cost", -1))
			break
	passed = _print_check_result("shop price discount", discounted_weapon_cost == 12) and passed
	var bucket_context := shop_context.duplicate(true)
	bucket_context["owned_rarity_counts"] = {"common": 5}
	var bucket_candidates := shop_generator.build_shop_candidate_pool(bucket_context)
	var baseline_relic_cost := -1
	var bucket_relic_cost := -1
	for candidate in shop_candidates:
		if str(candidate.get("offer_type", "")) == ShopOfferGenerator.OFFER_RELIC and str(candidate.get("rarity", "")) == "common":
			baseline_relic_cost = int(candidate.get("shop_cost", -1))
			break
	for candidate in bucket_candidates:
		if str(candidate.get("offer_type", "")) == ShopOfferGenerator.OFFER_RELIC and str(candidate.get("rarity", "")) == "common":
			bucket_relic_cost = int(candidate.get("shop_cost", -1))
			break
	passed = _print_check_result("relic rarity bucket baseline", baseline_relic_cost == 12) and passed
	passed = _print_check_result("relic rarity bucket price step", bucket_relic_cost == 24) and passed

	loadout.queue_free()
	player.queue_free()
	return passed




func _run_finance_checks() -> bool:
	print("[Bootstrap] finance checks")
	var passed := true
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var wave_manager := WAVE_MANAGER_SCENE.instantiate() as WaveManager
	passed = _print_check_result("finance scene instantiate", player != null and wave_manager != null) and passed
	if player == null or wave_manager == null:
		return false
	player.auto_initialize_on_ready = false
	add_child(player)
	add_child(wave_manager)
	player.initialize_from_character("character_void_hunter")
	wave_manager.initialize(player)
	wave_manager.add_exp_and_gold(0, 100)
	var payload := wave_manager.prepare_finance_for_wave(1)
	passed = _print_check_result("finance payload build", int(payload.get("gold", 0)) == 100 and int(payload.get("principal", 0)) == 0) and passed
	var deposit_result := wave_manager.apply_finance_operation("deposit", 50)
	passed = _print_check_result("finance deposit", bool(deposit_result.get("success", false)) and wave_manager.current_gold == 50 and int(wave_manager.get_finance_snapshot().get("principal", 0)) == 50) and passed
	var over_deposit_result := wave_manager.apply_finance_operation("deposit", 999)
	passed = _print_check_result("finance reject over deposit", not bool(over_deposit_result.get("success", false)) and str(over_deposit_result.get("reason", "")) == "amount_exceeds_gold") and passed
	var settle_result := wave_manager.trigger_finance_interest("bootstrap")
	passed = _print_check_result("finance interest settle", bool(settle_result.get("success", false)) and int(wave_manager.get_finance_snapshot().get("principal", 0)) > 50) and passed
	wave_manager.add_relic("relic_piggy_bank")
	wave_manager.prepare_finance_for_wave(2)
	passed = _print_check_result("finance piggy relic", int(wave_manager.get_finance_snapshot().get("principal", 0)) >= 60) and passed
	var dividend_before := int(wave_manager.get_finance_snapshot().get("principal", 0))
	wave_manager.add_relic("relic_dividend_check")
	var dividend_settle := wave_manager.trigger_finance_interest("bootstrap_dividend")
	passed = _print_check_result("finance dividend check settle", bool(dividend_settle.get("success", false)) and int(wave_manager.get_finance_snapshot().get("principal", 0)) > dividend_before) and passed
	wave_manager.add_relic("relic_fixed_deposit_certificate")
	var fixed_deposit_result := wave_manager.apply_finance_operation("deposit", 1)
	passed = _print_check_result("finance fixed deposit deposit", bool(fixed_deposit_result.get("success", false))) and passed
	var fixed_deposit_withdraw_result := wave_manager.apply_finance_operation("withdraw", 1)
	passed = _print_check_result("finance fixed deposit withdraw", bool(fixed_deposit_withdraw_result.get("success", false))) and passed
	wave_manager.add_relic("relic_compound_interest_tome")
	var rate_before := float(wave_manager.get_finance_snapshot().get("interest_rate", 0.0))
	wave_manager.process_wave_end_settlements()
	var rate_after := float(wave_manager.get_finance_snapshot().get("interest_rate", 0.0))
	passed = _print_check_result("finance compound rate growth on wave end", rate_after > rate_before) and passed
	wave_manager.add_relic("relic_perpetual_annuity_scroll")
	var annuity_principal_before := int(wave_manager.get_finance_snapshot().get("principal", 0))
	var annuity_results := wave_manager.process_wave_end_settlements()
	passed = _print_check_result("finance annuity extra settlement", annuity_results.size() >= 2 and int(wave_manager.get_finance_snapshot().get("principal", 0)) > annuity_principal_before) and passed
	wave_manager.add_relic("relic_high_yield_contract")
	wave_manager.prepare_finance_for_wave(3)
	var blocked_settle_results := wave_manager.process_wave_end_settlements()
	var blocked_settle_result: Dictionary = blocked_settle_results[0] if not blocked_settle_results.is_empty() else {}
	passed = _print_check_result("finance high yield blocks below threshold", bool(blocked_settle_result.get("blocked", false))) and passed
	var threshold_deposit_result := wave_manager.apply_finance_operation("deposit", 50)
	passed = _print_check_result("finance high yield threshold deposit", bool(threshold_deposit_result.get("success", false))) and passed
	var threshold_settle_results := wave_manager.process_wave_end_settlements()
	var threshold_settle_result: Dictionary = threshold_settle_results[0] if not threshold_settle_results.is_empty() else {}
	passed = _print_check_result("finance high yield passes at threshold", bool(threshold_settle_result.get("success", false)) and not bool(threshold_settle_result.get("blocked", false))) and passed
	var finance_popup := FINANCE_POPUP_SCENE.instantiate()
	passed = _print_check_result("finance popup instantiate", finance_popup != null and finance_popup.get_node_or_null("MainPanel/Content/ActionRow/DepositButton") != null) and passed
	if finance_popup != null:
		finance_popup.queue_free()
	var finance_controller := FINANCE_UI_CONTROLLER_SCENE.instantiate()
	passed = _print_check_result("finance ui controller instantiate", finance_controller != null and finance_controller.get_node_or_null("PopupLayer/FinancePopup") != null and finance_controller.get_node_or_null("PopupLayer/InterestSettlementPopup") != null) and passed
	if finance_controller != null:
		finance_controller.queue_free()
	wave_manager.queue_free()
	player.queue_free()
	return passed


func _run_main_flow_checks() -> bool:
	print("[Bootstrap] main flow checks")
	var passed := true

	var flow := MAIN_FLOW_COORDINATOR_SCENE.instantiate() as MainFlowCoordinator
	passed = _print_check_result("main flow scene instantiate", flow != null) and passed
	if flow == null:
		return false

	add_child(flow)
	passed = _print_check_result("main flow start page", flow.get_current_mode() == MainFlowCoordinator.MODE_BOOT and flow.get_current_state() == MainFlowCoordinator.STATE_START_PAGE) and passed

	var player := PLAYER_SCENE.instantiate() as PlayerController
	var loadout := WEAPON_LOADOUT_SCENE.instantiate() as WeaponLoadout
	var wave_manager := WAVE_MANAGER_SCENE.instantiate() as WaveManager
	passed = _print_check_result("main flow battle context instantiate", player != null and loadout != null and wave_manager != null) and passed
	if player == null or loadout == null or wave_manager == null:
		flow.queue_free()
		return false

	player.auto_initialize_on_ready = false
	add_child(player)
	add_child(loadout)
	add_child(wave_manager)
	flow.bind_battle_context(player, loadout, wave_manager)
	flow.enter_battle_selection("character_void_hunter")
	var selection_ok := flow.confirm_character_selection()
	passed = _print_check_result("main flow character selection", selection_ok and flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT and flow.current_wave_index == 0) and passed
	passed = _print_check_result("main flow start weapon sync", player.get_start_weapon_ids().size() == 1 and player.get_start_weapon_ids()[0] == "weapon_void_blade" and loadout.get_weapon_instances().size() == 1) and passed
	passed = _print_check_result("main flow first wave auto start", flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT and flow.get_state_snapshot().get("pending_finance_payload", {}).is_empty()) and passed
	var default_shop_payload := flow._build_shop_payload("free", 1)
	var default_shop_offers: Array = default_shop_payload.get("offers", [])
	var offer_bonus_applied := player.add_runtime_modifier({
		"id": "mod_test_shop_offer_count",
		"source_type": "test",
		"source_id": "bootstrap_shop_offer_count",
		"target_scope": "player",
		"stat": "shop_offer_count_bonus",
		"operation": "add_flat",
		"value": 2,
		"duration": -1,
		"stack_rule": "unique",
	})
	var expanded_shop_payload := flow._build_shop_payload("free", 1)
	var expanded_shop_offers: Array = expanded_shop_payload.get("offers", [])
	var shop_offer_count_payload_ok := (
		offer_bonus_applied
		and int(default_shop_payload.get("offer_count", -1)) == MainFlowCoordinator.BASE_SHOP_OFFER_COUNT
		and default_shop_offers.size() == MainFlowCoordinator.BASE_SHOP_OFFER_COUNT
		and int(expanded_shop_payload.get("offer_count", -1)) == MainFlowCoordinator.BASE_SHOP_OFFER_COUNT + 2
		and expanded_shop_offers.size() == MainFlowCoordinator.BASE_SHOP_OFFER_COUNT + 2
	)
	passed = _print_check_result("main flow shop offer count bonus", shop_offer_count_payload_ok) and passed
	player.remove_runtime_modifiers_by_source("test", "bootstrap_shop_offer_count")
	wave_manager.add_exp_and_gold(10, 0)
	passed = _print_check_result("main flow shared reward/shop popup", flow.get_current_state() == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP) and passed
	passed = _print_check_result("main flow shared reward/shop dedupe", flow.get_state_snapshot().get("pending_shared_reward_shop_levels", []).is_empty()) and passed
	flow.close_shared_reward_shop_popup()
	passed = _print_check_result("main flow resume combat after popup", flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT) and passed

	flow.finish_current_wave()
	passed = _print_check_result("main flow wave end shop ready", flow.get_state_snapshot().get("wave_end_ready", false) == true and flow.get_current_state() == MainFlowCoordinator.STATE_SHOP_POPUP) and passed
	passed = _print_check_result("shop refresh cost wave1", flow.get_shop_refresh_cost() == 4) and passed
	var refresh_rejected := flow.request_shop_refresh()
	passed = _print_check_result("shop refresh reject no gold", not bool(refresh_rejected.get("success", false))) and passed
	wave_manager.apply_gold_delta(20, "bootstrap")
	var refresh_result := flow.request_shop_refresh()
	passed = _print_check_result("shop refresh pay and double cost", bool(refresh_result.get("success", false)) and wave_manager.get_current_gold() == 16 and flow.get_shop_refresh_cost() == 8) and passed
	var invalid_purchase := flow.submit_shop_purchase({}, "shop")
	passed = _print_check_result("main flow shop reject invalid offer", not bool(invalid_purchase.get("success", false))) and passed
	flow.advance_wave_end_phase()
	passed = _print_check_result("main flow shop to finance order", flow.get_current_state() == MainFlowCoordinator.STATE_FINANCE_POPUP) and passed
	var finance_result := flow.submit_finance_operation("none", 0)
	passed = _print_check_result("main flow finance submit", bool(finance_result.get("success", false))) and passed
	passed = _print_check_result("main flow second wave zone select", flow.get_current_state() == MainFlowCoordinator.STATE_ZONE_SELECT) and passed
	if flow.get_current_state() == MainFlowCoordinator.STATE_ZONE_SELECT:
		var zone_ok := flow.confirm_zone_selection("zone_nearstring_battlefield")
		passed = _print_check_result("main flow zone select after finance", zone_ok and (flow.get_current_state() == MainFlowCoordinator.STATE_ZONE_HARVEST_RESULT or flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT)) and passed
		if flow.get_current_state() == MainFlowCoordinator.STATE_ZONE_HARVEST_RESULT:
			flow.close_zone_harvest_result_popup()
			passed = _print_check_result("main flow zone harvest close", flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT) and passed
	passed = _print_check_result("main flow wave auto start after zone", flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT) and passed

	flow.present_battle_result(true, {"reason": "bootstrap"})
	passed = _print_check_result("main flow battle result", flow.get_current_state() == MainFlowCoordinator.STATE_BATTLE_RESULT and flow.current_victory) and passed
	flow.confirm_battle_result()
	passed = _print_check_result("main flow reset after result", flow.get_current_state() == MainFlowCoordinator.STATE_START_PAGE and flow.get_current_mode() == MainFlowCoordinator.MODE_BOOT) and passed

	flow.enter_camp_flow()
	passed = _print_check_result("main flow camp entry", flow.get_current_state() == MainFlowCoordinator.STATE_CAMP_ENTRY and flow.get_current_mode() == MainFlowCoordinator.MODE_CAMP) and passed

	flow.queue_free()
	loadout.queue_free()
	player.queue_free()
	wave_manager.queue_free()
	return passed


func _get_guaranteed_exp_drop_amount(drop_table_id: String) -> int:
	var drop_table := DataRegistry.get_record("drop_tables", drop_table_id)
	var total_exp := 0
	var entries: Array = drop_table.get("entries", [])
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var entry_data: Dictionary = entry
		if str(entry_data.get("type", "")) == "exp_orb" and int(entry_data.get("chance_percent", 0)) >= 100:
			total_exp += maxi(0, int(entry_data.get("amount", 0)))
	return total_exp


func _calculate_level_state_after_exp(total_exp: int) -> Dictionary:
	var level := WaveManager.DEFAULT_PLAYER_LEVEL
	var remaining_exp := maxi(total_exp, 0)
	var level_ups := 0
	while remaining_exp >= 5 + (level - 1) * 5:
		remaining_exp -= 5 + (level - 1) * 5
		level += 1
		level_ups += 1
	return {
		"player_level": level,
		"current_exp": remaining_exp,
		"level_ups": level_ups,
	}


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
