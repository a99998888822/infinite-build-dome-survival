extends Node

var failures := 0
var checks := 0
var spawned := 0
# Measured immediately before the 2026-10-09 density increase.
const PREVIOUS_SPAWNS := {
	"1": {1: 10, 5: 19, 10: 34, 15: 42, 20: 68},
	"2": {1: 19, 5: 26, 10: 54, 15: 76, 20: 101},
	"3": {1: 26, 5: 39, 10: 71, 15: 104, 20: 158},
}

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	_test_cluster_spawning()
	var rows: Array = []
	var previous_tier: Array = []
	for tier in BattleDifficulty.IDS:
		var p := PlayerController.new()
		p.auto_initialize_on_ready = false
		add_child(p)
		p.initialize_from_character("character_void_hunter")
		p.set_physics_process(false)
		var manager := WaveManager.new()
		add_child(manager)
		manager.set_process(false)
		manager.initialize(p, tier)
		manager.child_entered_tree.connect(func(node):
			if node is EnemyController: spawned += 1)
		var tier_rows: Array = []
		var last_hp := 0
		var last_rate := 0.0
		for wave in range(1, 21):
			manager.current_wave_index = wave - 2
			manager.start_next_wave()
			var sample := manager.spawn_enemy("enemy_mutated_grub", Vector2(900, 0))
			var hp := sample.current_hp
			var damage := sample.get_stat("melee_damage")
			sample.free()
			var rate := 0.0
			for group: Dictionary in manager.current_wave.spawn_groups:
				rate += manager.calculate_enemy_spawn_count(int(group.count_per_spawn)) * 1000.0 / manager.calculate_spawn_interval(float(group.spawn_interval_ms))
			check(hp > last_hp, "HP increases every wave: tier %s wave %d" % [tier, wave])
			check(hp == roundi((24.0 + 200.0 * float(wave - 1) / 19.0) * float(manager._difficulty.stat_multiplier)), "ordinary HP follows linear growth in tier %s wave %d" % [tier, wave])
			check(rate > last_rate, "density increases every wave: tier %s wave %d" % [tier, wave])
			check(damage >= 4 and damage <= 8, "contact damage rises while retaining player survivability: tier %s wave %d" % [tier, wave])
			last_hp = hp
			last_rate = rate
			spawned = 0
			# Exercise real timer scheduling. Remove spawned enemies without rewards
			# so the count measures supply rather than the live safety cap.
			for frame in 1200:
				manager._process(1.0 / 60.0)
				for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
			var row := {"difficulty": tier, "wave": wave, "hp": hp, "damage": damage, "spawned_20s": spawned, "rate": snappedf(rate, 0.01), "cap": manager._difficulty.enemy_limit}
			tier_rows.append(row)
			if not previous_tier.is_empty():
				check(spawned > previous_tier[wave - 1].spawned_20s, "higher tier has more actual spawns at wave " + str(wave))
			if PREVIOUS_SPAWNS[tier].has(wave):
				var ratio := float(spawned) / float(PREVIOUS_SPAWNS[tier][wave])
				# Short windows are sensitive to complete batches and opening delay.
				# Full-wave doubling/+20% acceptance lives in spawn_density_test.
				check(ratio > 1.0, "twenty-second supply increases: tier %s wave %d" % [tier, wave])
				rows.append(row)
		check(tier_rows[19].hp == roundi(224.0 * float(manager._difficulty.stat_multiplier)), "ordinary HP reaches the wave twenty target")
		check(tier_rows[19].spawned_20s > tier_rows[0].spawned_20s * 3, "late density exceeds three times opening density")
		previous_tier = tier_rows
		manager.free()
		p.free()
	print("WAVE_PRESSURE_ROWS ", JSON.stringify(rows))
	print("WAVE_PRESSURE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_cluster_spawning() -> void:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager.current_wave_index = 9
	manager.current_wave = {"id": "cluster_test", "duration_seconds": 60, "spawn_groups": [
		{"enemy_id": "enemy_mutated_grub", "spawn_interval_ms": 1000, "count_per_spawn": 12},
		{"enemy_id": "enemy_mutated_grub", "spawn_interval_ms": 1000, "count_per_spawn": 8},
	]}
	var directions: Array[float] = []
	for batch in 24:
		player.global_position = Vector2(1700 + batch * 320, -2100 - batch * 175)
		manager.wave_time_left = 60.0
		manager.spawn_timers_ms.assign([0.0, 0.0])
		manager._elite_spawn_deadline = 30.0
		manager._elite_spawn_schedule.assign([0.0])
		manager._elite_spawned_count = 0
		manager._challenge_elite_schedule.assign([0.0, 0.0])
		manager._challenge_elite_planned = 2
		manager._challenge_elite_spawned = 0
		manager._process_spawn_timers(0.0)
		var enemies := EnemyRegistry.get_registered_enemies().duplicate()
		check(enemies.size() == 7 and manager._elite_spawned_count == 1 and manager._challenge_elite_spawned == 2, "batch includes both ordinary groups, elite replacement and two challenge elites")
		var angle: float = (enemies[0].global_position - player.global_position).angle()
		directions.append(angle)
		var in_annulus := true
		var in_cluster := true
		var elites := 0
		for enemy in enemies:
			var offset: Vector2 = enemy.global_position - player.global_position
			in_annulus = in_annulus and offset.length() >= 399.99 and offset.length() <= 500.01
			in_cluster = in_cluster and absf(angle_difference(angle, offset.angle())) <= deg_to_rad(8.01)
			if str(enemy.enemy_data.get("enemy_type", "")) == "elite":
				elites += 1
				var base_hp := float(enemy.enemy_data.base_stats.max_hp)
				check(enemy.current_hp == roundi(base_hp * 0.8 * pow(1.24, 9)), "each elite retains its independent base HP and compounded growth")
		check(in_annulus and in_cluster and elites == 3, "translated player anchors every spawn inside the 400-500 annulus and shared sixteen-degree sector")
		for enemy in enemies: enemy.free()
	var changing_direction := false
	for angle in directions:
		changing_direction = changing_direction or absf(angle_difference(directions[0], angle)) > deg_to_rad(30.0)
	check(changing_direction, "successive batches choose fresh directions")
	# Fill one sector so every candidate must use the best-clearance fallback.
	var blockers := Node2D.new()
	add_child(blockers)
	for radius in range(400, 501, 20):
		for degrees in range(-8, 9, 2):
			var blocker := Node2D.new()
			blockers.add_child(blocker)
			blocker.global_position = player.global_position + Vector2.RIGHT.rotated(deg_to_rad(float(degrees))) * float(radius)
			blocker.add_to_group("enemies")
	for sample in 24:
		var position := manager.get_random_spawn_position(0.0)
		var offset := position - player.global_position
		check(offset.length() >= 399.99 and offset.length() <= 500.01 and absf(offset.angle()) <= deg_to_rad(8.01), "crowded fallback preserves radius and cluster")
	blockers.free()
	manager.free()
	player.free()
