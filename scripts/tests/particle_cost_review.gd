extends Node2D
## Particle-only microbenchmark. No enemy queries, combat, or scene duplication.
const WORLD = preload("res://scripts/tests/fixtures/profiled_particle_world.gd")
const EVENT = preload("res://scripts/effects/particle_event.gd")
var output := ""
var rows: Array = []

class WaterProbe:
	extends "res://scripts/effects/water_wave_effect.gd"
	var draw_usec := 0
	var draw_calls := 0
	func _process(delta: float) -> void:
		_elapsed = fmod(_elapsed + delta, _duration)
		queue_redraw()
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec() - start
		draw_calls += 1

class IceProbe:
	extends "res://scripts/effects/ice_field_effect.gd"
	var draw_usec := 0
	var draw_calls := 0
	func _process(delta: float) -> void:
		_elapsed = fmod(_elapsed + delta, _lifetime)
		var frame := int(_elapsed * 12.0)
		if frame != _visual_frame:
			_visual_frame = frame
			queue_redraw()
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec() - start
		draw_calls += 1

class ReflectionCostCanvas:
	extends "res://scripts/effects/light_reflection_effect.gd"
	var draw_usec := 0
	var draw_calls := 0
	func _process(delta: float) -> void:
		_elapsed = fmod(_elapsed + delta, _duration)
		queue_redraw()
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec() - start
		draw_calls += 1

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if output.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	get_tree().root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# A common 60 Hz budget makes per-frame CPU scopes comparable across loads.
	Engine.max_fps = 60
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for repeat in 2:
		for frequency in ([0, 10, 30] if repeat == 0 else [30, 10, 0]):
			await _measure(frequency, repeat)
	for kind in ["water", "ice", "reflection"]:
		for count in [1, 8]:
			await _measure_drawing(kind, count)
	print("PARTICLE_COST_COMPLETE")
	get_tree().quit()

func _measure(frequency: int, repeat: int) -> void:
	var world := WORLD.new()
	add_child(world)
	world._random.seed = 20261004
	var event = EVENT.create({"profile_id": "explosion_burst", "global_position": Vector2(576, 324),
		"direction": Vector2.ZERO, "intensity": 1.0, "color_override": Color(1, 0.65, 0.1), "parameters": {}})
	var start := Time.get_ticks_usec()
	var previous := start
	var next_emit := 0.0
	var measuring := false
	var times: Array[float] = []
	var counts: Array[int] = []
	var instance_counts: Array[int] = []
	while Time.get_ticks_usec() - start < 6000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - start) / 1e6
		if elapsed >= 2.0:
			if not measuring: world.reset_timing(); measuring = true
			times.append(float(now - previous) / 1000.0)
			counts.append(world.get_active_particle_count())
			instance_counts.append(world._batch.multimesh.visible_instance_count)
		previous = now
		if frequency > 0 and elapsed >= next_emit:
			world.emit_event(event)
			next_emit += 1.0 / frequency
	var total := 0.0
	var count_sum := 0
	var instance_sum := 0
	for value in times: total += value
	for value in counts: count_sum += value
	for value in instance_counts: instance_sum += value
	times.sort()
	var row := {"frequency": frequency, "repeat": repeat, "mean_ms": total / times.size(),
		"p95_ms": times[int(times.size() * 0.95)], "particles_mean": float(count_sum) / counts.size(),
		"instances_mean": float(instance_sum) / instance_counts.size(),
		"simulation_ms_per_frame": world.sim_usec / 1000.0 / maxi(world.sim_calls, 1),
		"draw_prepare_ms_per_frame": world.draw_usec / 1000.0 / maxi(world.sim_calls, 1),
		"spawn_ms_per_frame": world.emit_usec / 1000.0 / maxi(world.sim_calls, 1),
		"spawn_ms_per_event": world.emit_usec / 1000.0 / maxi(world.emit_calls, 1),
		"draw_calls": world.draw_calls, "sim_calls": world.sim_calls,
		"method": "60 fps cap; unchanged explosion_burst methods wrapped by CPU timers; 2s warmup + 4s measurement; no readback"}
	rows.append(row)
	FileAccess.open(output.path_join("particles.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("PARTICLE_COST ", JSON.stringify(row))
	world.queue_free()
	for i in 8: await get_tree().process_frame

func _measure_drawing(kind: String, count: int) -> void:
	var probes: Array = []
	for i in count:
		var probe: Node2D
		match kind:
			"water":
				probe = WaterProbe.new()
				probe._radius = 33.0 * 0.7 * 0.85
			"ice":
				probe = IceProbe.new()
				probe._lifetime = 3.0
			_: probe = ReflectionCostCanvas.new()
		probe.position = Vector2(220 + i % 4 * 220, 180 + i / 4 * 260)
		probe._elapsed = i * 0.037
		add_child(probe)
		probes.append(probe)
	await get_tree().create_timer(1.0).timeout
	for probe in probes: probe.draw_usec = 0; probe.draw_calls = 0
	var start := Time.get_ticks_usec()
	var previous := start
	var frame_count := 0
	var times: Array[float] = []
	while Time.get_ticks_usec() - start < 4000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
		frame_count += 1
	var usec := 0
	var calls := 0
	for probe in probes: usec += probe.draw_usec; calls += probe.draw_calls
	var total := 0.0
	for value in times: total += value
	times.sort()
	var row := {"kind": kind, "instances": count, "mean_ms": total / frame_count,
		"p95_ms": times[int(times.size() * 0.95)], "draw_cpu_ms_per_frame": usec / 1000.0 / frame_count,
		"draw_cpu_ms_per_call": usec / 1000.0 / maxi(calls, 1),
		"method": "60 fps cap; unchanged production _draw, maximum visual detail, animated clock; gameplay disabled; 1s warmup + 4s measurement"}
	rows.append(row)
	FileAccess.open(output.path_join("particles.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("DRAW_COST ", JSON.stringify(row))
	for probe in probes: probe.queue_free()
	for i in 8: await get_tree().process_frame
