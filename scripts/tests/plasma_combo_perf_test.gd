extends "res://scripts/tests/weapon_trio_test.gd"
## Repro for the reported plasma combo: 电浆炮 + 多投 + 分裂 + 电火花, with
## fire/water enchantments on a second weapon.
##
## Casting goes through the real loadout tick (active-combat path), so split
## children, per-tick enchantment fan-out and element reactions all run exactly
## as they do in battle. Simulation CPU only; the cost of every effect script is
## attributed separately, and each spawned node is counted once.
##
## Run headless:
##   godot --headless --path . --scene scenes/tests/plasma_combo_perf_test.tscn -- --enemies=12

const PLASMA_ID := "weapon_plasma_cannon"
const BOW_ID := "weapon_void_blade"
const HIT_RENDER_WARMUP = preload("res://scripts/effects/combat_hit_render_warmup.gd")
const WEAPON_RENDER_WARMUP = preload("res://scripts/effects/weapon_render_warmup.gd")
const ENCHANT_WARMUP = preload("res://scripts/effects/enchantment_render_warmup.gd")
const WARMUP_BOLT = preload("res://scripts/effects/lightning_pixel_bolt.gd")
const WARMUP_BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")

var seen_ids: Dictionary = {}


func _run() -> void:
	print("BENCH_BOOT")
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	var count := 12
	var total_frames := 300
	var only := ""
	var live := false
	var live_seconds := 6.0
	var capture_tag := ""
	var capture_frames := 180
	var capture_stride := 3
	for arg in OS.get_cmdline_user_args():
		if arg == "--live": live = true
		if arg.begins_with("--seconds="): live_seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--capture="): capture_tag = arg.trim_prefix("--capture=")
		if arg.begins_with("--frames="): total_frames = int(arg.trim_prefix("--frames="))
		if arg.begins_with("--stride="): capture_stride = int(arg.trim_prefix("--stride="))
		if arg.begins_with("--enemies="): count = int(arg.trim_prefix("--enemies="))
		if arg.begins_with("--capture-frames="): capture_frames = int(arg.trim_prefix("--capture-frames="))
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	CampProgression.begin_transient_session()
	Engine.max_fps = 0
	if not capture_tag.is_empty():
		await run_capture(count, only, capture_tag, capture_frames, capture_stride)
		return
	if live:
		await run_live(count, only, live_seconds)
		return
	# Callbacks are pumped manually so the measurement never depends on wall time.
	EffectScheduler.set_process(false)
	var rows: Array = []
	for scenario in scenarios():
		if not only.is_empty() and str(scenario.name) != only:
			continue
		print("BENCH_START ", scenario.name)
		rows.append(await benchmark(scenario, count, total_frames))
		print("BENCH_STOP ", scenario.name)
	for row: Dictionary in rows:
		print("PLASMA_COMBO_ROW ", JSON.stringify({
			"scenario": row.scenario,
			"enemies": row.enemies,
			"cpu": row.cpu,
			"total_spawned": row.total_spawned,
			"peak_children": row.peak_children,
			"damage": row.damage,
			"top": row.top,
		}))
	if is_instance_valid(host): host.queue_free()
	await frames()
	EffectScheduler.set_process(true)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("PLASMA_COMBO_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func scenarios() -> Array:
	return [
		{"name": "01_plasma_only", "weapons": [_weapon(PLASMA_ID, [])]},
		{"name": "02_plasma_multishot", "weapons": [_weapon(PLASMA_ID, ["scroll_multishot"])]},
		{"name": "03_plasma_multishot_split", "weapons": [_weapon(PLASMA_ID, ["scroll_multishot", "scroll_split"])]},
		{"name": "04_plasma_multishot_split_lightning", "weapons": [_weapon(PLASMA_ID, ["scroll_multishot", "scroll_split", "scroll_lightning"])]},
		{"name": "05_plasma_multishot_split_fire", "weapons": [_weapon(PLASMA_ID, ["scroll_multishot", "scroll_split", "scroll_fire"])]},
		{"name": "06_plasma_multishot_split_water", "weapons": [_weapon(PLASMA_ID, ["scroll_multishot", "scroll_split", "scroll_water"])]},
		{"name": "07_full_combo", "weapons": [
			_weapon(PLASMA_ID, ["scroll_multishot", "scroll_split", "scroll_lightning"]),
			_weapon(BOW_ID, ["scroll_fire", "scroll_water"]),
		]},
		{"name": "08_control_fire_water_only", "weapons": [_weapon(BOW_ID, ["scroll_fire", "scroll_water"])]},
	]


func _weapon(id: String, attachments: Array) -> Dictionary:
	return {"id": id, "attachments": attachments}


func benchmark(scenario: Dictionary, count: int, total_frames: int) -> Dictionary:
	var positions: Array = []
	for i in count:
		positions.append(Vector2(70 + (i % 6) * 22, (i / 6 - count / 12.0) * 20))
	await assemble(positions, scenario.weapons)
	seed(741)
	seen_ids.clear()
	var cpu: Array[float] = []
	var costs: Dictionary = {}
	var spawns: Dictionary = {}
	var peak_children := 0
	for frame in total_frames:
		var start := Time.get_ticks_usec()
		# The live attack path: same entry point battle_root calls every tick.
		loadout.tick(1.0 / 60.0)
		for child in host.get_children():
			if child is EnemyController or child == player or child == loadout: continue
			child.set_process(false)
			child.set_physics_process(false)
			if child.is_queued_for_deletion(): continue
			var key := _script_key(child)
			if not seen_ids.has(child.get_instance_id()):
				seen_ids[child.get_instance_id()] = key
				spawns[key] = int(spawns.get(key, 0)) + 1
			var tick_start := Time.get_ticks_usec()
			if child.has_method("_physics_process"): child._physics_process(1.0 / 60.0)
			if child.has_method("_process"): child._process(1.0 / 60.0)
			costs[key] = float(costs.get(key, 0.0)) + (Time.get_ticks_usec() - tick_start) / 1000.0
		var scheduled_start := Time.get_ticks_usec()
		EffectScheduler._process(1.0 / 60.0)
		costs["EffectScheduler"] = float(costs.get("EffectScheduler", 0.0)) + (Time.get_ticks_usec() - scheduled_start) / 1000.0
		cpu.append((Time.get_ticks_usec() - start) / 1000.0)
		freeze_tree(host)
		peak_children = maxi(peak_children, host.get_child_count())
		await get_tree().process_frame
	var damage := 0
	for enemy in enemies: damage += 10000000 - enemy.current_hp
	var total_spawned := 0
	for key in spawns.keys(): total_spawned += int(spawns[key])
	return {
		"scenario": str(scenario.name),
		"enemies": count,
		"cpu": stats(cpu),
		"damage": damage,
		"peak_children": peak_children,
		"total_spawned": total_spawned,
		"spawns": spawns,
		"top": _top(costs, spawns),
	}


func _script_key(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null: return node.get_class()
	return script.resource_path.get_file()


func _top(costs: Dictionary, spawns: Dictionary) -> Array:
	var rows: Array = []
	for key in costs.keys():
		rows.append({
			"script": key,
			"total_ms": snappedf(float(costs[key]), 0.01),
			"spawned": int(spawns.get(key, 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return a.total_ms > b.total_ms)
	var limited: Array = []
	for i in mini(rows.size(), 10): limited.append(rows[i])
	return limited


func assemble(positions: Array, weapons: Array) -> void:
	await setup(positions)
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	loadout = WeaponLoadout.new()
	host.add_child(loadout)
	loadout.initialize(player)
	player.add_runtime_modifier({"id": "benchmark_capacity", "source_id": "benchmark", "source_type": "test", "stat": "load_capacity", "operation": "override", "value": 1000, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
	for spec: Dictionary in weapons:
		var id := str(spec.id)
		check(loadout.equip_weapon(id), "equip " + id)
		for attempt in 12:
			var current := loadout.get_weapon_instance(id)
			if current == null or current.level >= 5: break
			if not loadout.upgrade_weapon(id): break
		var weapon_instance := loadout.get_weapon_instance(id)
		check(weapon_instance != null, "weapon instance available: " + id)
		if weapon_instance == null: continue
		weapon_instance.runtime_stats.crit_chance = 0
		for item_id in spec.attachments:
			var item := player.item_inventory.add_item_from_base(str(item_id), "plasma_combo_bench")
			check(loadout.attach_item_to_weapon(id, item.item_instance_id), "attach " + str(item_id) + " to " + id)
		check(weapon_instance.level == 5 or weapon_instance.level > 1, "weapon upgraded for slots: " + id + " level=" + str(weapon_instance.level))
		check(weapon_instance.get_attachment_slot_count() >= spec.attachments.size(), "slots fit attachments: " + id + " slots=" + str(weapon_instance.get_attachment_slot_count()))
	# Real battle uses the active-combat caster; keep that path for fidelity.
	loadout.set_active_combat_enabled(true)
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_WAVE_COMBAT)
	loadout.set_process(false)
	loadout.set_physics_process(false)
	for enemy in enemies: enemy.current_hp = 10000000
	# battle_root pre-builds the damage-number pool; without it every measured
	# first burst pays for 160 label allocations instead of gameplay cost.
	EnemyController.prepare_damage_number_pool(host)
	await frames()


## Deterministic GPU capture: the same simulation steps as the headless bench,
## rendered on a private desktop, so before/after frames line up frame for frame.
func run_capture(count: int, only: String, tag: String, frames: int, stride: int) -> void:
	get_window().size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var output := "res://artifacts/previews/plasma_combo/" + tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var scenario: Dictionary = scenarios()[6] if only.is_empty() else {}
	for entry in scenarios():
		if str(entry.name) == only: scenario = entry
	check(not scenario.is_empty(), "capture scenario resolved: " + only)
	if scenario.is_empty(): get_tree().quit(2); return
	var positions: Array = []
	for i in count:
		positions.append(Vector2(70 + (i % 6) * 22, (i / 6 - count / 12.0) * 20))
	await assemble(positions, scenario.weapons)
	host.position = Vector2(640, 360)
	player._invincibility_timer = 100000.0
	# A fixed capture camera keeps before/after frames aligned and readable.
	player.set_process(false)
	if player.camera_2d != null:
		player.camera_2d.enabled = false
	var camera := Camera2D.new()
	add_child(camera)
	camera.zoom = Vector2(3.0, 3.0)
	camera.global_position = host.position + Vector2(110, -10)
	camera.make_current()
	player.position = Vector2.ZERO
	seed(741)
	var saved := 0
	for frame in frames:
		loadout.tick(1.0 / 60.0)
		for child in host.get_children():
			if child is EnemyController or child == player or child == loadout: continue
			child.set_process(false)
			child.set_physics_process(false)
			if child.is_queued_for_deletion(): continue
			if child.has_method("_physics_process"): child._physics_process(1.0 / 60.0)
			if child.has_method("_process"): child._process(1.0 / 60.0)
		EffectScheduler._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		if frame % stride == 0:
			var image := get_viewport().get_texture().get_image()
			if image != null:
				image.save_png(output.path_join("frame_%03d.png" % saved))
				saved += 1
		await get_tree().process_frame
	print("PLASMA_COMBO_CAPTURE tag=", tag, " frames=", saved, " scenario=", scenario.name)
	if is_instance_valid(host): host.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("PLASMA_COMBO_CAPTURE_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func run_live(count: int, only: String, seconds: float) -> void:
	get_window().size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var output := "res://artifacts/reports/plasma_combo_live.json"
	var warm := not "--no-warmup" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var reports: Array = []
	for scenario in scenarios():
		if not only.is_empty() and str(scenario.name) != only: continue
		var positions: Array = []
		for i in count:
			positions.append(Vector2(70 + (i % 6) * 22, (i / 6 - count / 12.0) * 20))
		await assemble(positions, scenario.weapons)
		host.position = Vector2(420, 380)
		player._invincibility_timer = 100000.0
		# Mirror the entry loading screen before measuring: first-use shader and
		# material variants then belong to loading, not to combat frames.
		if warm:
			await warm_render_paths()
		# Let shaders, atlases and material bindings warm up before measuring.
		for i in 30:
			loadout.tick(1.0 / 60.0)
			await get_tree().process_frame
		var wall: Array[float] = []
		var process_times: Array[float] = []
		var peak_draws := 0
		var peak_nodes := 0
		var max_scale_drops := 0
		var spike_log: Array = []
		var live_seen: Dictionary = {}
		var start := Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
			loadout.tick(1.0 / 60.0)
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			var frame_ms := (now - previous) / 1000.0
			wall.append(frame_ms)
			previous = now
			process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			peak_nodes = maxi(peak_nodes, host.get_child_count())
			if Engine.time_scale < 0.99: max_scale_drops += 1
			# Attribute a spike to the effect scripts born in the same frame.
			var born: Array = []
			for child in host.get_children():
				var id := child.get_instance_id()
				if live_seen.has(id): continue
				live_seen[id] = true
				born.append(_script_key(child))
			if frame_ms > 16.667:
				spike_log.append({"frame": wall.size(), "ms": snappedf(frame_ms, 0.01), "born": born})
			await get_tree().process_frame
		var over := 0
		for value in wall:
			if value > 16.667: over += 1
		var report: Dictionary = {
			"scenario": str(scenario.name),
			"enemies": count,
			"warmed": warm,
			"samples": wall.size(),
			"wall": stats(wall),
			"engine_process": stats(process_times),
			"over_16_67_percent": snappedf(100.0 * over / maxf(wall.size(), 1.0), 0.1),
			"peak_draw_calls": peak_draws,
			"peak_children": peak_nodes,
			"adapter": RenderingServer.get_video_adapter_name(),
			"time_scale_drops": max_scale_drops,
			"spikes": spike_log.slice(0, 12),
		}
		reports.append(report)
		print("PLASMA_COMBO_LIVE ", JSON.stringify(report))
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"reports": reports}, "  "))
	if is_instance_valid(host): host.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("PLASMA_COMBO_LIVE_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


## Same sample families the dungeon loading screen presents before combat.
func warm_render_paths() -> void:
	var samples := Node2D.new()
	samples.name = "BenchRenderWarmup"
	add_child(samples)
	samples.global_position = host.global_position
	HIT_RENDER_WARMUP.prepare(samples, loadout.weapon_instances, player.sprite.texture if player.sprite != null else null)
	if not "--no-enchant-warmup" in OS.get_cmdline_user_args():
		ENCHANT_WARMUP.prepare(samples)
	var bolt := WARMUP_BOLT.new()
	samples.add_child(bolt)
	bolt.points = PackedVector2Array([Vector2.ZERO, Vector2(20, -12), Vector2(50, 0)])
	bolt.rim_enabled = false
	bolt.build(true)
	WARMUP_BURST.spawn(samples, host.global_position, Vector2.RIGHT, 1.0, {"visual_cap": 2, "skip_lights": true})
	for kind in WEAPON_RENDER_WARMUP.KINDS:
		WEAPON_RENDER_WARMUP.prepare(samples, kind)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	samples.queue_free()
	await get_tree().process_frame


func freeze_tree(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze_tree(child)


func stats(values: Array[float]) -> Dictionary:
	var total := 0.0
	for value in values: total += value
	values.sort()
	return {"mean_ms": snappedf(total / values.size(), 0.001), "p95_ms": snappedf(values[int(values.size() * 0.95)], 0.001), "max_ms": snappedf(values.back(), 0.001)}
