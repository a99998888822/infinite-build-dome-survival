extends Node

class ControlledDrops extends DropRewardSystem:
	var roll_percent: float = 0.0
	var checked_chances: Array[float] = []
	func _roll_drop_chance(chance_percent: float) -> bool:
		checked_chances.append(chance_percent)
		return chance_percent > 0.0 and roll_percent < chance_percent

var checks: int = 0
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", label)

func make_player() -> PlayerController:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.set_physics_process(false)
	player.initialize_from_character("character_void_hunter")
	return player

func pending(drops: DropRewardSystem, player: PlayerController, id: String = "relic_finance_manager", table: String = "drop_elite_enemy") -> Dictionary:
	for action in drops.build_drop_actions(table, player):
		if action.type == "relic":
			action.relic_id = id
			return action
	return {}

func _run() -> void:
	check(DataRegistry.get_load_errors().is_empty(), "project configuration validates")
	_test_drops()
	_test_wave_end()
	_test_elite()
	await _test_collision_and_events()
	_test_config()
	await get_tree().process_frame
	await get_tree().process_frame
	print("ELITE_RELIC_DECAY_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_drops() -> void:
	var player := make_player()
	var root := Node2D.new()
	add_child(root)
	var drops := ControlledDrops.new()
	var snapshot := RewardSnapshot.new()
	var first := pending(drops, player)
	var second := pending(drops, player)
	drops.checked_chances.clear()
	drops.roll_percent = 75.0
	var pickup := drops.spawn_action(first, Vector2(800, 0), root, player, snapshot) as RelicPickup
	check(pickup != null and player.get_relic_counts().is_empty(), "ground reward is a choice token, no immediate relic")
	check(drops.get_elite_relics_dropped_this_wave() == 1, "ground token immediately consumes a decay tier")
	check(drops.spawn_action(second, Vector2.ZERO, root, player) == null and drops.checked_chances == [100.0, 50.0], "same-frame second roll already uses 50 percent")
	check(drops.spawn_action(first, Vector2.ZERO, root, player) == null, "successful action cannot replay")
	check(drops.spawn_action(second, Vector2.ZERO, root, player) == null, "failed action cannot reroll")
	check(pickup.collect() and not pickup.collect(), "token collects exactly once")
	check(snapshot.collected_relics == 1 and player.get_relic_counts().is_empty(), "collection queues a choice without auto-grant")
	check(drops.get_elite_relics_dropped_this_wave() == 1, "collection does not decay twice")
	drops.roll_percent = 0.0
	for expected in [2, 3, 4]:
		drops.spawn_action(pending(drops, player), Vector2(800, 0), root, player, snapshot)
		check(drops.get_elite_relics_dropped_this_wave() == expected, "ground token advances tier %d" % expected)
	check(is_equal_approx(drops.get_elite_relic_drop_chance(10000.0), 6.25), "bonus cap precedes decay")
	var before := drops.get_elite_relics_dropped_this_wave()
	drops.spawn_action(pending(drops, player, "", "drop_boss_enemy"), Vector2.ZERO, root, player)
	player.add_relic("relic_finance_manager")
	check(drops.get_elite_relics_dropped_this_wave() == before, "other sources do not change elite decay")
	var expected_chances := {"exp_orb": 100.0, "health_pack": 20.0, "augmentation": 5.0}
	for action in drops.build_drop_actions("drop_elite_enemy", player):
		if expected_chances.has(action.type):
			check(is_equal_approx(action.adjusted_chance_percent, expected_chances[action.type]), "non-relic probability unchanged: " + action.type)
			expected_chances.erase(action.type)
	var stale := pending(drops, player)
	var stale_pickup := drops.spawn_action(pending(drops, player), Vector2.ZERO, root, player) as RelicPickup
	drops.begin_wave()
	check(drops.get_elite_relics_dropped_this_wave() == 0 and drops.get_elite_relic_drop_chance(100.0) == 100.0, "next wave resets decay")
	check(drops.spawn_action(stale, Vector2.ZERO, root, player) == null and not stale_pickup.collect(), "old queued actions and ground tokens cannot leak into new run")
	root.free()
	player.free()

func _test_wave_end() -> void:
	var player := make_player()
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.drop_reward_system = ControlledDrops.new()
	manager.initialize(player)
	manager.start_next_wave()
	var action := pending(manager.drop_reward_system, player)
	manager._pending_reward_batches.append({"actions": [action] as Array[Dictionary], "position": Vector2(9000, 0)})
	manager.finish_current_wave()
	check(player.get_relic_counts().is_empty() and manager._pending_relic_choices.size() == 1, "wave end flushes last-frame drop into pending choice")
	check(manager.get_reward_snapshot().elite_relics_dropped == 1 and manager.reward_snapshot.collected_relics == 1, "wave snapshot separates drops and collections")
	manager.finish_current_wave()
	manager._flush_pending_reward_batches()
	check(manager._pending_relic_choices.size() == 1, "repeated finish does not duplicate choice")
	manager.initialize(player)
	check(manager._pending_relic_choices.is_empty(), "new run discards pending choices")
	manager.free()
	player.free()

func _test_elite() -> void:
	var player := make_player()
	player.global_position = Vector2(500, 0)
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager.current_wave_index = 4
	var normal := manager.spawn_enemy("enemy_mutated_grub", Vector2(-500, 0))
	var elite := manager.spawn_enemy("enemy_elite_rusher", Vector2.ZERO) as EliteRusher
	normal.set_physics_process(false)
	elite.set_physics_process(false)
	check(elite.current_hp == int(elite.get_stat("max_hp")) and is_equal_approx(elite.get_stat("max_hp"), normal.get_stat("max_hp") * 20.0), "elite has 20 times normal same-wave HP")
	check(is_equal_approx(elite.get_stat("armor"), normal.get_stat("armor") * 2.0), "wave armor doubles after growth")
	check(elite.get_stat("damage_taken_percent") < normal.get_stat("damage_taken_percent"), "armor affects actual damage reduction")
	check(elite.get_drop_table_id() == "drop_elite_enemy" and normal.get_drop_table_id() == "drop_basic_enemy", "normal enemy data remains independent")
	check(elite.take_damage(10) == 0, "spawn warning cannot be attacked")
	elite._process_special_behavior(0.75)
	check(elite.skill_state == "chase" and elite.sprite.visible, "spawn warning completes")
	elite.start_dash()
	var locked := elite._direction
	player.global_position = Vector2(0, 500)
	elite._process_special_behavior(0.4)
	check(elite.skill_state == "windup" and elite._direction == locked, "telegraph locks direction")
	elite._process_special_behavior(0.4)
	check(elite.skill_state == "dash", "800ms windup starts dash")
	elite._process_special_behavior(0.4)
	check(elite.skill_state == "recover" and elite.global_position.distance_to(Vector2(240, 0)) < 0.1, "dash travels 240 pixels in 400ms")
	elite._process_special_behavior(0.5)
	check(elite.skill_state == "chase", "recovery returns to chase")
	elite.start_dash()
	elite.apply_freeze(1.0)
	elite._physics_process(0.01)
	check(elite.skill_state == "windup" and elite._frozen_remaining < 0.1, "resisted freeze briefly pauses but preserves skill")
	elite._frozen_remaining = 0.0
	elite.start_dash()
	var clock_before := elite._state_time
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	elite._physics_process(1.0)
	check(elite._state_time == clock_before, "pause freezes skill clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var count := manager.drop_reward_system.get_elite_relics_dropped_this_wave()
	manager.clear_enemies()
	check(not elite.alive and manager.drop_reward_system.get_elite_relics_dropped_this_wave() == count, "cleanup cancels elite without rewards")
	manager.free()
	player.free()

func _test_config() -> void:
	var record := DataRegistry.get_record("drop_tables", "drop_elite_enemy")
	check(int(record.elite_relic_decay_percent) == 50, "configured decay is half per ground drop")
	for value in [0, 50, 100, -1, 101, 0.5, "invalid"]:
		var validator := DataValidator.new()
		validator._validate_drop_table_records([{"id": "test", "entries": [], "elite_relic_decay_percent": value}], {})
		var valid := value is int and int(value) >= 0 and int(value) <= 100
		check(validator.errors.is_empty() == valid, "decay config validates %s" % str(value))


func _test_collision_and_events() -> void:
	var player := make_player()
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager._elite_quota_rng.seed = 20260923
	var rng_before := manager._elite_quota_rng.state
	for row in [[1, 1000, 0.0], [2, 0, 0.2], [5, 0, 0.5], [10, 0, 1.0], [15, 0, 1.5], [20, 0, 2.0], [10, 50, 1.5], [20, 50, 3.0], [10, 100, 2.0], [20, 1000, 3.0], [3, -20, 0.3]]:
		check(is_equal_approx(manager.calculate_miniboss_expected_count(row[0], row[1]), row[2]), "expectation wave=%s erosion=%s" % [row[0], row[1]])
	check(manager._elite_quota_rng.state == rng_before, "expectation preview does not consume quota RNG")
	for expected in [0.0, 1.0, 2.0, 3.0]:
		check(manager._sample_miniboss_quota(expected) == int(expected), "integer expectation has no count variance: %s" % expected)
	check(manager._elite_quota_rng.state == rng_before, "integer quotas do not consume randomness")
	for expected in [0.2, 0.5, 1.25, 1.5, 2.5]:
		var total := 0
		var bounded := true
		for trial in 10000:
			var sampled := manager._sample_miniboss_quota(expected)
			total += sampled
			bounded = bounded and sampled >= floori(expected) and sampled <= ceili(expected)
		check(bounded and absf(float(total) / 10000.0 - expected) < 0.02, "10000 samples preserve mean and adjacent counts: %s" % expected)
	manager.current_wave_index = 18
	manager.start_next_wave()
	var snapshot := manager.get_miniboss_spawn_snapshot()
	check(snapshot.planned >= 1 and snapshot.planned <= 3 and snapshot.schedule.size() == snapshot.planned, "wave start samples and fixes total and schedule")
	var planned := int(snapshot.planned)
	var seeded_state := manager._elite_quota_rng.state
	manager.get_miniboss_spawn_snapshot()
	check(manager._elite_quota_rng.state == seeded_state, "reading schedule does not reroll quota")
	for time in snapshot.schedule:
		check(time + 0.75 < manager.wave_time_left * 0.5, "warning completes before halfway")
	var times: Array = snapshot.schedule.duplicate()
	for time in times:
		manager.wave_time_left = float(manager.current_wave.duration_seconds) - float(time) - 0.05
		for index in manager.spawn_timers_ms.size():
			manager.spawn_timers_ms[index] = 0.0
		manager._process_spawn_timers(0.0)
	check(manager.get_miniboss_spawn_snapshot().spawned == planned, "all planned minibosses appear in first half without requiring kills")
	manager.wave_time_left = float(manager.current_wave.duration_seconds) * 0.49
	for index in manager.spawn_timers_ms.size():
		manager.spawn_timers_ms[index] = 0.0
	manager._process_spawn_timers(0.0)
	check(manager.get_miniboss_spawn_snapshot().spawned == planned and manager._elite_quota_rng.state == seeded_state, "second half never creates another miniboss or rerolls quota")
	manager.clear_enemies()
	manager.current_wave_index = 9
	manager.start_next_wave()
	manager.wave_time_left = float(manager.current_wave.duration_seconds) * 0.4
	manager._process_spawn_timers(0.1)
	check(manager.get_miniboss_spawn_snapshot().spawned == 0 and manager.get_miniboss_spawn_snapshot().schedule.is_empty(), "lag crossing deadline drops expired schedule instead of late catch-up")
	manager.free()
	player.free()
	await get_tree().process_frame
