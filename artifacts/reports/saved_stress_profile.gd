extends Node

var session: RecordingSession
var graphical := false
var config: Dictionary


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	if graphical and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	var presets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://recording_studio/presets.json"))
	for name in presets:
		if str(name) == "电浆炮压力测试": config = presets[name].duplicate(true)
	if config.is_empty():
		print("PRESET_NOT_FOUND")
		get_tree().quit(2)
		return
	config.countdown = 0
	config.entry = "combat"
	CampProgression.begin_transient_session()
	session = RecordingSession.new()
	add_child(session)
	if graphical:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 120
	var rows: Array = []
	var variants := ["full", "no_lightning", "no_fire", "no_water", "no_split", "no_multishot"]
	if graphical: variants = ["full"]
	for variant in variants:
		var data := config.duplicate(true)
		var removed := {"no_lightning": "scroll_lightning", "no_fire": "scroll_fire", "no_water": "scroll_water", "no_split": "scroll_split", "no_multishot": "scroll_multishot"}
		if removed.has(variant):
			for weapon in data.weapons: weapon.attachments.erase(removed[variant])
		seed(741)
		var error := await session.prepare(data)
		if not error.is_empty():
			print("PREPARE_FAILED ", error)
			get_tree().quit(2)
			return
		session.battle.player._invincibility_timer = 1000000.0
		if not session.begin():
			print("BEGIN_FAILED")
			get_tree().quit(2)
			return
		var frame_times: Array[float] = []
		var snapshots: Array = []
		var born: Dictionary = {}
		var seen: Dictionary = {}
		var spikes: Array = []
		var previous := Time.get_ticks_usec()
		for frame in 900:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - previous) / 1000.0
			previous = now
			frame_times.append(ms)
			# Sample only once per 30 frames, avoiding instrumentation on every node.
			if frame % 30 == 0:
				var counts: Dictionary = {}
				var new_nodes: Dictionary = {}
				var world := session.battle.loadout._get_visual_root()
				for child in world.get_children():
					var script := child.get_script() as Script
					var key := script.resource_path.get_file() if script != null else str(child.get_class())
					counts[key] = int(counts.get(key, 0)) + 1
					if not seen.has(child.get_instance_id()):
						seen[child.get_instance_id()] = true
						born[key] = int(born.get(key, 0)) + 1
						new_nodes[key] = int(new_nodes.get(key, 0)) + 1
				var snapshot := {"frame": frame, "nodes": counts, "new_nodes": new_nodes,
					"enemies": EnemyRegistry.get_registered_enemies().size(),
					"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
					"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
					"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					"objects": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
				snapshots.append(snapshot)
			if ms > 25 and spikes.size() < 30: spikes.append({"frame": frame, "ms": ms})
		var total := 0.0
		var over := 0
		for value in frame_times:
			total += value
			if value > 16.667: over += 1
		frame_times.sort()
		var row := {"variant": variant, "frames": frame_times.size(), "mean_ms": total / frame_times.size(),
			"p95_ms": frame_times[int(frame_times.size() * 0.95)], "max_ms": frame_times.back(),
			"over_16_ms": over, "snapshots": snapshots, "observed_new_nodes": born, "spikes": spikes}
		rows.append(row)
		print("SAVED_STRESS ", JSON.stringify({"variant": variant, "mean_ms": row.mean_ms, "p95_ms": row.p95_ms, "max_ms": row.max_ms}))
		await session.dispose()
	var output := "res://artifacts/reports/saved_stress_gpu.json" if graphical else "res://artifacts/reports/saved_stress_cpu.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"config": config, "graphical": graphical, "rows": rows}, "  "))
	CampProgression.end_transient_session()
	get_tree().quit()
