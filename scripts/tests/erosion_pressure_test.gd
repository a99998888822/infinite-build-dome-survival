extends Node

class RecordingPlayer extends PlayerController:
	var received_damage: int = 0
	func take_damage(raw_damage: int, _source_id: String = "") -> int:
		received_damage = raw_damage
		return raw_damage

var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", label)

func _ready() -> void:
	_run.call_deferred()

func _make_player(erosion: float) -> RecordingPlayer:
	var player := RecordingPlayer.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.modifier_stack.set_base_stat("divinity", erosion)
	return player

func _make_manager(player: PlayerController) -> WaveManager:
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager.current_wave_index = 13
	manager.start_next_wave()
	return manager

func _spawn(manager: WaveManager, id: String) -> EnemyController:
	var enemy := manager.spawn_enemy(id, Vector2.ZERO)
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	check(DataRegistry.get_load_errors().is_empty(), "configuration loads with common erosion rules")
	ZoneProgression.reset_state()
	var player := _make_player(0.0)
	var manager := _make_manager(player)
	for row in [[-100, 1.0, 1.0, 1.0], [0, 1.0, 1.0, 1.0], [1, 1.018, 1.009, 1.0135], [10, 1.18, 1.09, 1.135], [50, 1.9, 1.45, 1.675], [100, 2.8, 1.9, 2.35], [150, 3.7, 2.35, 3.025], [200, 4.6, 2.8, 3.7], [1000000, 18001.0, 9001.0, 13501.0]]:
		var pressure := manager.calculate_enemy_erosion_pressure(row[0])
		check(is_equal_approx(pressure.max_hp_multiplier, row[1]) and is_equal_approx(pressure.damage_multiplier, row[2]) and is_equal_approx(pressure.armor_multiplier, row[3]), "uncapped stat pressure at erosion %s" % row[0])
	check(manager.calculate_miniboss_expected_count(10, 0) == 1.0 and manager.calculate_miniboss_expected_count(20, 0) == 2.0, "zero erosion count anchors remain 1 and 2")
	check(manager.calculate_miniboss_expected_count(10, 50) == 1.5 and manager.calculate_miniboss_expected_count(10, 100) == 2.0, "erosion count bonus doubles")
	check(manager.calculate_miniboss_expected_count(20, 100) == 3.0, "three miniboss hard cap still applies")
	check(manager._build_erosion_enemy_modifiers().is_empty(), "zero erosion does not modify baseline enemies")
	manager.free()
	player.free()
	_test_spawns_and_damage()
	_test_wave_start_snapshot()
	_test_rules_validation()
	await get_tree().process_frame
	await get_tree().process_frame
	print("EROSION_PRESSURE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_spawns_and_damage() -> void:
	# Keep a nonzero region pressure to catch accidental additive stacking.
	ZoneProgression.current_zone_id = str(DataRegistry.get_table("zones")[0].id)
	ZoneProgression.streak_count = 3
	var cold_player := _make_player(0.0)
	var hot_player := _make_player(100.0)
	var extreme_player := _make_player(200.0)
	var cold_manager := _make_manager(cold_player)
	var hot_manager := _make_manager(hot_player)
	var extreme_manager := _make_manager(extreme_player)
	var hot_enemies: Array[EnemyController] = []
	for id in ["enemy_mutated_grub", "enemy_elite_rusher"]:
		var cold := _spawn(cold_manager, id)
		var hot := _spawn(hot_manager, id)
		var extreme := _spawn(extreme_manager, id)
		hot_enemies.append(hot)
		# Wave 15: 10 * 1.4^14 * 1.2 (region) * 2.8 (erosion), rounded once.
		# Elite rank applies after rounding the same-wave normal HP.
		var hp_rank := 20 if hot is EliteRusher else 1
		check(cold.get_stat("max_hp") == 1333 * hp_rank and hot.get_stat("max_hp") == 3734 * hp_rank, "%s HP combines wave, region and erosion once" % id)
		check(absf(hot.get_stat("armor") - cold.get_stat("armor") * 2.35) <= 1.0, "%s armor combines rank and erosion once" % id)
		check(hot.current_hp == int(hot.get_stat("max_hp")), "%s spawns with full scaled health" % id)
		check(extreme.get_stat("max_hp") > hot.get_stat("max_hp") and extreme.current_hp == int(extreme.get_stat("max_hp")), "%s erosion 200 spawns at full increased health" % id)
		check(extreme.get_stat("armor") > hot.get_stat("armor") and absf(extreme.get_stat("armor") - cold.get_stat("armor") * 3.7) <= 1.0, "%s erosion 200 armor continues scaling" % id)
		for stat in ["ranged_damage", "element_damage"]:
			cold.modifier_stack.set_base_stat(stat, 100.0)
			hot.modifier_stack.set_base_stat(stat, 100.0)
			extreme.modifier_stack.set_base_stat(stat, 100.0)
			check(hot.get_stat(stat) == 190.0 and cold.get_stat(stat) == 100.0, "%s also scales %s" % [id, stat])
			check(extreme.get_stat(stat) == 280.0, "%s erosion 200 continues scaling %s" % [id, stat])
		if hot is EliteRusher:
			cold._process_special_behavior(0.75)
			hot._process_special_behavior(0.75)
			extreme._process_special_behavior(0.75)
			cold.start_dash()
			hot.start_dash()
			extreme.start_dash()
			cold._try_dash_damage(0.0, 20.0)
			hot._try_dash_damage(0.0, 20.0)
			extreme._try_dash_damage(0.0, 20.0)
		else:
			cold._process_contact_damage()
			hot._process_contact_damage()
			extreme._process_contact_damage()
		check(hot_player.received_damage > cold_player.received_damage, "%s actual attack hits harder" % id)
		check(extreme_player.received_damage > hot_player.received_damage, "%s erosion 200 actual attack exceeds erosion 100" % id)
		check(hot.take_damage(100) < cold.take_damage(100), "%s actual incoming damage uses increased armor" % id)
	var normal := hot_enemies[0]
	var elite := hot_enemies[1]
	check(elite.get_stat("max_hp") == normal.get_stat("max_hp") * 20.0, "erosion preserves elite 20x normal HP")
	var frozen := hot_manager.get_enemy_erosion_snapshot()
	var original_hp := normal.current_hp
	hot_player.modifier_stack.set_base_stat("divinity", 0.0)
	var later := _spawn(hot_manager, "enemy_mutated_grub")
	check(later.get_stat("max_hp") == normal.get_stat("max_hp") and normal.current_hp == original_hp, "mid-wave erosion change affects neither existing nor later enemies")
	check(hot_manager.get_enemy_erosion_snapshot() == frozen, "pressure snapshot remains frozen")
	var exposed := hot_manager.get_enemy_erosion_snapshot()
	exposed.max_hp_multiplier = 99.0
	check(hot_manager.get_enemy_erosion_snapshot() == frozen, "external reads cannot mutate pressure snapshot")
	hot_manager.start_next_wave()
	check(hot_manager.get_enemy_erosion_snapshot().max_hp_multiplier == 1.0 and hot_manager._build_erosion_enemy_modifiers().is_empty(), "next wave adopts changed erosion")
	hot_manager.initialize(hot_player)
	check(hot_manager.get_enemy_erosion_snapshot().erosion == 0.0, "new run clears pressure snapshot")
	check(DataRegistry.get_record("enemies", "enemy_mutated_grub").base_stats.max_hp == 10, "shared enemy configuration is unchanged")
	cold_manager.free()
	hot_manager.free()
	extreme_manager.free()
	cold_player.free()
	hot_player.free()
	extreme_player.free()
	ZoneProgression.reset_state()

func _test_wave_start_snapshot() -> void:
	var player := _make_player(49.0)
	player.add_relic("relic_divine_fusion")
	var manager := _make_manager(player)
	check(player.get_stat("divinity") == 50.0, "wave-start relic adds erosion once")
	check(manager.get_enemy_erosion_snapshot().erosion == 50.0 and manager.get_miniboss_spawn_snapshot().erosion == 50.0, "enemy stats and miniboss count share post-relic erosion")
	check(is_equal_approx(manager.get_enemy_erosion_snapshot().max_hp_multiplier, 1.9), "wave-start relic is included in stat pressure")
	manager.free()
	player.free()

func _test_rules_validation() -> void:
	for field in ["erosion_full_at", "max_hp_bonus_percent", "damage_bonus_percent", "armor_bonus_percent"]:
		for invalid in [-1, 0.5, "invalid"]:
			var rules := DataRegistry.get_record("erosion_pressure_rules", "erosion_enemy_stats")
			rules[field] = invalid
			var validator := DataValidator.new()
			validator._validate_erosion_pressure_records([rules])
			check(not validator.errors.is_empty(), "reject invalid pressure field %s=%s" % [field, invalid])
	var rules := DataRegistry.get_record("erosion_pressure_rules", "erosion_enemy_stats")
	rules.erosion_full_at = 0
	var validator := DataValidator.new()
	validator._validate_erosion_pressure_records([rules])
	check(not validator.errors.is_empty(), "reject zero erosion divisor")
