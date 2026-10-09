extends Node

var checks := 0
var failures := 0
var spawned := 0
var normals := 0
var elites := 0
# Previous full-wave counts measured with this production scheduler. Early
# anchors use the unreplaced supply (the conservative upper bound for normals).
const PREVIOUS_EARLY_SUPPLY := {"1": [15, 18, 35, 40, 48], "2": [27, 32, 40, 56, 66], "3": [40, 46, 73, 83, 96]}
const PREVIOUS_FINAL_NORMALS := {"1": 211, "2": 302, "3": 499}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _count_spawn(node: Node) -> void:
	if not node is EnemyController: return
	spawned += 1


func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var output := "res://artifacts/reviews/spawn_density_20261009/after.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--density-output="): output = arg.trim_prefix("--density-output=")
	var rows: Array = []
	for tier in BattleDifficulty.IDS:
		var player := PlayerController.new()
		player.auto_initialize_on_ready = false
		add_child(player)
		player.initialize_from_character("character_void_hunter")
		player.set_physics_process(false)
		var manager := WaveManager.new()
		add_child(manager)
		manager.set_process(false)
		manager.initialize(player, tier)
		manager.child_entered_tree.connect(_count_spawn)
		manager._elite_quota_rng.seed = 20261009
		for wave in range(1, 21):
			manager.current_wave_index = wave - 2
			manager.start_next_wave()
			var groups: Array = []
			var rate := 0.0
			for group: Dictionary in manager.current_wave.spawn_groups:
				var count := manager.calculate_enemy_spawn_count(int(group.count_per_spawn))
				var interval := manager.calculate_spawn_interval(float(group.spawn_interval_ms))
				rate += float(count) * 1000.0 / interval
				groups.append({"count": count, "interval_ms": interval})
			var expected := manager._elite_expected_count
			var planned := manager._elite_planned_count
			check(planned == 0 if wave == 1 else planned >= 1, "first-wave exclusion and guaranteed later elites")
			spawned = 0
			normals = 0
			elites = 0
			var first_elite_time := -1.0
			var duration := float(manager.current_wave.duration_seconds)
			# Run the production timer at 60 Hz. Remove enemies immediately so
			# supply is measured independently of player DPS and the crowd cap.
			for frame in int(duration * 60.0):
				manager.wave_time_left = duration - float(frame + 1) / 60.0
				manager._process_spawn_timers(1.0 / 60.0)
				for enemy in EnemyRegistry.get_registered_enemies().duplicate():
					if str(enemy.enemy_data.get("enemy_type", "")) == "elite": elites += 1
					else: normals += 1
					enemy.free()
				if elites > 0 and first_elite_time < 0.0: first_elite_time = float(frame + 1) / 60.0
			check(elites == planned, "all scheduled elites appear: tier %s wave %d" % [tier, wave])
			check(first_elite_time < duration * 0.5, "elites appear in first half")
			if wave <= 5:
				check(normals >= 2 * int(PREVIOUS_EARLY_SUPPLY[tier][wave - 1]), "full-wave ordinary enemies at least double: tier %s wave %d" % [tier, wave])
			if wave == 20:
				var ratio := float(normals) / float(PREVIOUS_FINAL_NORMALS[tier])
				check(ratio >= 1.15 and ratio <= 1.25, "last-wave ordinary supply increases by about twenty percent")
			rows.append({"difficulty": tier, "wave": wave, "duration_seconds": duration,
				"groups": groups, "rate": rate, "cap": manager._difficulty.enemy_limit,
				"spawned": spawned, "normal_spawned": normals, "elite_spawned": elites,
				"elite_expected": expected, "first_elite_seconds": first_elite_time})
		# Re-run the opening without kills. Early elites must still appear
		# in a crowded arena and normal spawns must respect the raised cap.
		for wave in range(2, 6):
			manager.current_wave_index = wave - 2
			manager.start_next_wave()
			var duration := float(manager.current_wave.duration_seconds)
			for frame in int(duration * 30.0):
				manager.wave_time_left = duration - float(frame + 1) / 60.0
				manager._process_spawn_timers(1.0 / 60.0)
			check(manager._elite_spawned_count == manager._elite_planned_count and manager._elite_spawned_count >= 1, "early boss guarantee survives no-kill play: tier %s wave %d" % [tier, wave])
			check(EnemyRegistry.get_registered_enemies().size() <= int(manager._difficulty.enemy_limit), "raised crowd cap is enforced")
			for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
		manager.free()
		player.free()
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	check(file != null, "density output is writable")
	if file != null:
		file.store_string(JSON.stringify({"sample_hz": 60, "erosion": 0, "enemy_spawn_bonus": 0,
			"method": "Production spawn timer; enemies removed after each frame; no crowd-cap truncation.", "rows": rows}, "\t"))
		file.close()
	print("SPAWN_DENSITY_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
