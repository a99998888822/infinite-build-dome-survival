extends Node

class NoDrops extends DropRewardSystem:
	func build_drop_actions(_table: String, _player: PlayerController = null) -> Array[Dictionary]:
		return []

var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func feed(system: EnemyWavePressure, kind: String, fast: int, total: int, offset: int = 0) -> void:
	for n in total: system.record_damage(offset + n + 1, kind)
	system.advance(0.5)
	for n in fast: system.record_kill(offset + n + 1)
	system.advance(1.0)
	for n in range(fast, total): system.record_kill(offset + n + 1)


func finish(system: EnemyWavePressure, struggling := false) -> Dictionary:
	system.advance(15.0)
	return system.finish_wave({"struggling": struggling})


func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	ZoneProgression.reset_state()
	check(DataRegistry.get_load_errors().is_empty(), "formal pressure configs validate")
	_test_decisions()
	_test_timing_and_survivors()
	_test_validation()
	await _test_live_waves()
	_export_curves()
	await get_tree().process_frame
	await get_tree().process_frame
	print("ENEMY_ADAPTATION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_decisions() -> void:
	var system := EnemyWavePressure.new()
	system.reset()
	for wave in [1, 2]:
		system.begin_wave(wave)
		feed(system, "normal", 20, 20)
		finish(system)
		check(system.next_bonus.normal == 0, "opening waves do not increase HP")
	system.begin_wave(3)
	feed(system, "normal", 16, 20)
	var summary := finish(system)
	check(system.next_bonus.normal == 10 and system.next_bonus.elite == 0, "80 percent triggers only the observed type")
	check(system.wave_bonus.normal == 0, "current wave HP remains frozen after decision")
	check(system.finish_wave({}) == summary and system.next_bonus.normal == 10, "finish is idempotent")
	summary.types.normal.next_bonus_percent = 999
	check(system.snapshot().last_wave.types.normal.next_bonus_percent == 10, "summary read is isolated")
	for wave in range(4, 13):
		system.begin_wave(wave)
		feed(system, "normal", 20, 20)
		feed(system, "elite", 1, 1, 100)
		finish(system)
	check(system.next_bonus.normal == 60 and system.next_bonus.elite == 30, "both types reach bounded independent caps")
	system.begin_wave(13)
	feed(system, "normal", 20, 20)
	finish(system, true)
	check(system.next_bonus.normal == 50 and system.next_bonus.elite == 25, "struggling overrides fast kills and relaxes one step")
	for wave in [14, 15]:
		system.begin_wave(wave)
		feed(system, "normal", 9, 20)
		finish(system)
		check(system.next_bonus.normal == (50 if wave == 14 else 40), "two consecutive slow waves relax one step")
	check(system.next_bonus.elite == 25, "no elite sample preserves elite bonus")
	system.begin_wave(16)
	feed(system, "normal", 10, 20)
	finish(system)
	check(system.next_bonus.normal == 40, "50 percent is in the hold band")
	system.begin_wave(17)
	feed(system, "normal", 19, 19)
	finish(system)
	check(system.next_bonus.normal == 40, "nineteen ordinary samples cannot increase bonus")
	system.begin_wave(18)
	feed(system, "normal", 15, 20)
	finish(system)
	check(system.next_bonus.normal == 40, "below eighty percent does not increase bonus")
	system.begin_wave(19)
	feed(system, "normal", 20, 20)
	system.finish_wave({})
	check(system.next_bonus.normal == 40, "short observation cannot change bonus")
	system.reset()
	check(system.next_bonus.normal == 0 and system.wave_bonus.elite == 0 and system.last_summary.is_empty(), "new run clears adaptive history")
	for wave in range(3, 7):
		system.begin_wave(wave)
		finish(system, true)
	check(system.next_bonus.normal == 0 and system.next_bonus.elite == 0, "relaxation cannot reduce base HP")


func _test_timing_and_survivors() -> void:
	var system := EnemyWavePressure.new()
	system.begin_wave(3)
	system.record_damage(1, "elite")
	system.advance(1.0)
	system.record_kill(1)
	system.record_kill(1)
	var summary := finish(system)
	check(summary.types.elite.fast_kills == 1 and summary.types.elite.samples == 1, "one-second boundary and duplicate death")
	system.begin_wave(4)
	system.advance(100.0)
	system.record_damage(1, "elite")
	system.record_kill(1)
	check(finish(system).types.elite.fast_kills == 1, "travel time before first hit does not affect fast kill")
	system.begin_wave(5)
	system.record_damage(1, "elite")
	system.advance(0.9)
	system.record_damage(1, "elite")
	system.advance(0.101)
	system.record_kill(1)
	check(finish(system).types.elite.fast_kills == 0, "repeated hits do not restart timing")
	system.begin_wave(6)
	feed(system, "normal", 16, 16)
	for n in 10: system.record_damage(100 + n, "normal")
	var before: int = system.next_bonus.normal
	summary = finish(system)
	check(summary.types.normal.samples == 26 and system.next_bonus.normal == before, "long-lived engaged survivors prevent death-only bias")
	system.begin_wave(7)
	system.advance(15.0)
	system.record_damage(1, "elite")
	system.record_damage(2, "summoned")
	system.advance(0.2)
	summary = system.finish_wave({})
	check(summary.types.elite.samples == 0, "unfinished short encounter is excluded")
	check(summary.types.normal.samples == 0, "unsupported enemy types are excluded")


func _test_validation() -> void:
	for field in ["first_effective_wave", "fast_kill_ms", "minimum_observed_seconds", "slow_waves_to_relax", "fast_ratio_percent"]:
		for bad in [-1, 0, 0.5, "bad"]:
			var config := DataRegistry.get_record("enemy_adaptation_rules", "kill_speed_hp")
			config[field] = bad
			var validator := DataValidator.new()
			validator._validate_enemy_adaptation_records([config])
			check(not validator.errors.is_empty(), "invalid adaptive numeric field is rejected")
	for bad in [101, 80]:
		var config := DataRegistry.get_record("enemy_adaptation_rules", "kill_speed_hp")
		config.slow_ratio_percent = bad
		var validator := DataValidator.new()
		validator._validate_enemy_adaptation_records([config])
		check(not validator.errors.is_empty(), "invalid ratio band is rejected")


func _test_live_waves() -> void:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var manager := WaveManager.new()
	manager.drop_reward_system = NoDrops.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	player.modifier_stack.set_base_stat("divinity", 50)
	manager.current_wave_index = 0
	manager.start_next_wave()
	var stale := manager.spawn_enemy("enemy_mutated_grub", Vector2(1000, 0))
	stale.set_physics_process(false)
	manager.start_next_wave()
	manager.spawn_timers_ms.fill(1000000000.0)
	manager._elite_spawn_schedule.clear()
	stale.take_damage(1)
	check(manager.enemy_pressure._engaged.is_empty(), "old wave damage cannot enter new wave samples")
	stale.free()
	var enemy := manager.spawn_enemy("enemy_mutated_grub", Vector2(1000, 0))
	enemy.set_physics_process(false)
	enemy.take_damage(0)
	check(manager.enemy_pressure._engaged.is_empty(), "zero damage is excluded")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	manager._process(20.0)
	enemy.take_damage(1)
	check(manager.enemy_pressure.elapsed == 0.0 and manager.enemy_pressure._engaged.is_empty(), "pause freezes both clock and hit sampling")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	enemy.set_meta("exclude_reward_progress", true)
	enemy.take_damage(1)
	check(manager.enemy_pressure._engaged.is_empty(), "noncombat reward-excluded entities are excluded")
	enemy.free()
	for id in ["enemy_mutated_grub", "enemy_elite_rusher"]:
		for n in (20 if id == "enemy_mutated_grub" else 1):
			enemy = manager.spawn_enemy(id, Vector2(1000, 0))
			enemy.set_physics_process(false)
			if enemy is EliteRusher:
				check(enemy.take_damage(1000000) == 0, "spawn warning cannot generate a damage sample")
				enemy._process_special_behavior(0.75)
			enemy.take_damage(1000000, "burn_tick")
	manager._process(15.0)
	manager.finish_current_wave()
	check(manager.enemy_pressure.next_bonus.normal == 10 and manager.enemy_pressure.next_bonus.elite == 5, "real damage and death signals drive next-wave decisions")
	check(manager.enemy_pressure.last_summary.types.normal.fast_kills == 20, "overkill and nonweapon sources each count one fast kill")
	await get_tree().create_timer(0.4).timeout
	check(manager.start_next_wave(), "next wave starts after real settlement")
	check(manager.enemy_pressure.wave_bonus.normal == 10 and manager.enemy_pressure.wave_bonus.elite == 5, "next wave adopts adaptive snapshot")
	for id in ["enemy_mutated_grub", "enemy_elite_rusher"]:
		enemy = manager.spawn_enemy(id, Vector2(1000, 0))
		enemy.set_physics_process(false)
		var is_elite: bool = id == "enemy_elite_rusher"
		var base := 160.0 * pow(1.24, 3) if is_elite else 24.0 + 200.0 * 3.0 / 19.0
		check(enemy.current_hp == roundi(base * 2.26 * (1.05 if is_elite else 1.1)), "full spawn HP applies wave, erosion and adaptation exactly once")
		check(enemy.get_stat("move_speed") == (104 if is_elite else 52), "adaptation does not change movement speed")
		check(enemy.get_stat("melee_damage") == roundi((6.21 if is_elite else 4.05) * 1.045 * 1.51), "adaptation does not change damage")
		enemy.free()
	var exposed := manager.enemy_pressure.snapshot()
	exposed.wave_bonus_percent.normal = 999
	check(manager.enemy_pressure.wave_bonus.normal == 10, "readers cannot mutate current wave bonus")
	manager.initialize(player)
	check(manager.enemy_pressure.next_bonus.normal == 0, "manager initialization resets pressure")
	manager.free()
	player.free()


func _export_curves() -> void:
	var curves: Array = []
	for erosion in range(201):
		curves.append(EnemyWavePressure.calculate_erosion(float(erosion)))
	var adaptive: Array = [{"qualifying_waves": 0, "normal": 0, "elite": 0}]
	var system := EnemyWavePressure.new()
	for n in 10:
		system.begin_wave(n + 3)
		feed(system, "normal", 20, 20)
		feed(system, "elite", 1, 1, 100)
		finish(system)
		adaptive.append({"qualifying_waves": n + 1, "normal": system.next_bonus.normal, "elite": system.next_bonus.elite})
	var output_dir := "res://artifacts/reviews/enemy_pressure_2026-10-07"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir + "/runtime_curves.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"erosion": curves, "adaptation": adaptive}, "\t"))
	file.close()
