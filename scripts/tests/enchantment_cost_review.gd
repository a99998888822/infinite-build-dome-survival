extends "res://scripts/tests/element_interaction_review.gd"
## Diagnostic only: equal impact rate, production spell logic, no GPU readback.
const COST_CASES := {
	"baseline": [], "fire": [["fire"]], "water": [["water"]],
	"ice": [["ice"]], "lightning": [["lightning"]],
	"electric_spark": [["electric_spark"]], "wind": [["wind"]],
	"light_sword": [["light_sword"]], "black_hole": [["black_hole"]],
	"explosion": [["explosion"]], "fire_chain": [["fire"], ["lightning"]],
	"fire_spark": [["fire"], ["electric_spark"]],
	"water_chain": [["water"], ["lightning"]],
	"water_spark": [["water"], ["electric_spark"]],
	"freeze": [["water"], ["ice"]], "wind_ice": [["ice"], ["wind"]],
	"reflection": [["water"], ["ice"], ["light_sword"]],
	"holy": [["fire"], ["light_sword"]], "dark": [["fire"], ["black_hole"]],
	"wind_water": [["water"], ["wind"]], "steam": [["fire"], ["water"]]
}
var cost_rows: Array = []

func _run() -> void:
	if output.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	for repeat in 2:
		var keys := COST_CASES.keys()
		if repeat == 1: keys.reverse()
		for key in keys:
			if not only.is_empty() and only != key: continue
			await _cost_case(str(key), repeat)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("COST_REVIEW_COMPLETE rows=", cost_rows.size())
	get_tree().quit()

func _cost_case(key: String, repeat: int) -> void:
	await _setup({"title": "Diagnostic: " + key})
	for i in range(enemies.size(), 120):
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(TARGET)
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemies.append(enemy)
	for i in enemies.size():
		enemies[i].current_hp = 1000000
		enemies[i].global_position = center + Vector2((i % 12 - 5.5) * 24, (i / 12 - 4.5) * 22)
	observations = {}
	var stages: Array = COST_CASES[key]
	var stage_index := 0
	var next_cast := 0.0
	var times: Array[float] = []
	var samples: Array = []
	var start := Time.get_ticks_usec()
	var previous := start
	var next_sample := 2.0
	var casts := 0
	while Time.get_ticks_usec() - start < 7000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - start) / 1e6
		if elapsed >= 3.0: times.append(float(now - previous) / 1000.0)
		previous = now
		if not stages.is_empty() and elapsed >= next_cast:
			var stage := stage_index % stages.size()
			_cast({"spells": stages[stage], "target": 54, "label": key})
			stage_index += 1
			casts += 1
			# Two repeated sequences per second. Every single spell also casts twice/s.
			next_cast += 0.10 if stage + 1 < stages.size() else 0.5 - 0.1 * (stages.size() - 1)
		if elapsed >= 3.0 and elapsed >= next_sample:
			next_sample = elapsed + 0.25
			var particles := 0
			var instances := 0
			for node in get_tree().get_nodes_in_group("particle_worlds"):
				particles += node.get_active_particle_count()
				instances += node._batch.multimesh.visible_instance_count
			var kinds := {}
			for node in get_tree().get_nodes_in_group("pixel_combat_effects"):
				var kind := str(node.get_meta("pixel_effect_kind", "unknown"))
				kinds[kind] = int(kinds.get(kind, 0)) + 1
			samples.append({"time": elapsed, "particles": particles, "particle_instances": instances,
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				"damage_numbers": EnemyController.active_damage_numbers,
				"kinds": kinds, "cues": get_tree().get_nodes_in_group("element_reaction_cues").size()})
	var total := 0.0
	for value in times: total += value
	times.sort()
	var row := {"id": key, "repeat": repeat, "frames": times.size(), "mean_ms": total / times.size(),
		"p50_ms": times[times.size() / 2], "p95_ms": times[int(times.size() * 0.95)],
		"p99_ms": times[int(times.size() * 0.99)], "casts": casts, "samples": samples,
		"method": "120 stationary live targets; 2 sequences/s; 3s warmup + 4s measurement; uncapped 1152x648; no readback"}
	cost_rows.append(row)
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(cost_rows, "\t"))
	print("COST_MEASURE ", key, " repeat=", repeat, " mean_ms=", row.mean_ms, " p95=", row.p95_ms)
	await _cleanup()
