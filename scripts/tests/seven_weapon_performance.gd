extends "res://scripts/tests/weapon_contact_regression_test.gd"
## Fixed-step throughput probe: production casts, static high-HP bodies, no AI.
## This is not a phone FPS test. Compare receipts before interpreting timings.
const DIAG = preload("res://scripts/battle/combat_diagnostics.gd")
var output := "res://artifacts/reports/seven_weapon_baseline.json"
var sample_count := 360
var profile := false
var enchantments := false
var random_seed := 741
var category_usec: Dictionary = {}
var category_calls: Dictionary = {}
var live_running := false
var legacy_lamp_range := false
const STRESS_SPELLS := {
	"weapon_void_blade": ["scroll_split", "scroll_pierce", "scroll_lightning"],
	"weapon_earth_hammer": ["scroll_explosion", "scroll_fire", "scroll_lightning"],
	"weapon_camp_dagger": ["scroll_split", "scroll_wind", "scroll_fire"],
	"weapon_copper_lamp": ["scroll_water", "scroll_lightning", "scroll_fire"],
	"weapon_plasma_cannon": ["scroll_multishot", "scroll_split", "scroll_electric_spark"],
	"weapon_nightwatch_spear": ["scroll_radial", "scroll_split", "scroll_ice"],
	"weapon_rentier_purse": ["scroll_multishot", "scroll_split", "scroll_explosion"],
}

func _physics_process(delta: float) -> void:
	if live_running: loadout.tick(delta)

func _run() -> void:
	var graphical := DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	if graphical and not "--background-capture" in args:
		get_tree().quit(2)
		return
	for arg in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--frames="): sample_count = int(arg.trim_prefix("--frames="))
		if arg.begins_with("--seed="): random_seed = int(arg.trim_prefix("--seed="))
	profile = "--profile" in args
	legacy_lamp_range = "--legacy-lamp-range" in args
	enchantments = "--enchanted" in args
	if graphical:
		get_window().unfocusable = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	CampProgression.begin_transient_session()
	EffectScheduler.set_process(false)
	var positions: Array = []
	for i in 48:
		positions.append(Vector2(100 + (i % 12) * 42, (i / 12 - 1.5) * 56))
	await prepare(BOW, positions)
	player.modifier_stack.set_base_stat("load_capacity", 1000)
	for id in [HAMMER, DAGGER, LAMP, PLASMA, SPEAR, COIN]:
		check(loadout.equip_weapon(id), "seven-weapon equip " + id)
	for w: WeaponInstance in loadout.weapon_instances:
		while w.level < 5: loadout.upgrade_weapon(w.weapon_id)
		if enchantments:
			for item_id in ["scroll_split", "scroll_fire", "scroll_lightning"]:
				var item := player.item_inventory.add_item_from_base(item_id, "seven_weapon_probe")
				check(loadout.attach_item_to_weapon(w.weapon_id, str(item.item_instance_id)), "probe attach " + item_id)
		weapon = w
		for pair in [["projectile_count", 7.0], ["area_size", 227.0], ["damage_area_size", 230.0], ["attack_speed", 39.0], ["crit_chance", 100.0], ["crit_damage", 590.0]]:
			total(pair[0], pair[1])
		# Review-only ablation: emulate old reach through a base offset, keeping
		# the final production formula and both raw player scores untouched.
		if legacy_lamp_range and w.is_copper_lamp():
			w.bonus_attack_range = w.get_base_attack_range() * (3.285 / 2.1425 - 1.0)
	loadout.set_process(false)
	loadout.set_physics_process(false)
	for enemy in enemies: enemy.current_hp = 100000000
	# Production resolves effect roots by group. Provide it here too, otherwise
	# every impact falls back to recursively searching the entire fixture tree.
	host.add_to_group("combat_render_world")
	host.position = Vector2(960, 540)
	for camera in player.find_children("*", "Camera2D", true, false):
		camera.enabled = false
	var camera := Camera2D.new()
	add_child(camera)
	camera.position = Vector2(960, 540)
	camera.make_current()
	_freeze(host)
	await frames()
	_thaw(host)
	seed(random_seed)
	DIAG.enabled = profile
	DIAG.reset()
	if "--live" in args:
		await _run_live(graphical)
		return
	var cpu: Array[float] = []
	var wall_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var peak_nodes := 0
	for frame in sample_count:
		var started := Time.get_ticks_usec()
		_thaw(host)
		loadout.active_casting.tick(1.0 / 60.0)
		loadout.active_casting.auto_attack()
		var ticking: Array[Node] = []
		_collect_ticks(host, ticking)
		for node in ticking:
			if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
			var before := Time.get_ticks_usec() if profile else 0
			if node.is_physics_processing() and node.has_method("_physics_process"): node.call("_physics_process", 1.0 / 60.0)
			if node.is_processing() and node.has_method("_process"): node.call("_process", 1.0 / 60.0)
			if profile:
				var path: String = node.get_script().resource_path
				category_usec[path] = int(category_usec.get(path, 0)) + Time.get_ticks_usec() - before
				category_calls[path] = int(category_calls.get(path, 0)) + 1
		EffectScheduler._process(1.0 / 60.0)
		_freeze(host)
		cpu.append((Time.get_ticks_usec() - started) / 1000.0)
		peak_nodes = maxi(peak_nodes, host.get_child_count())
		if graphical: await RenderingServer.frame_post_draw
		await get_tree().process_frame
		wall_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var hp: Array = []
	for enemy in enemies: hp.append(enemy.current_hp)
	var report := {"fixed_step": true, "static_enemies": 48, "ai": false, "phone_fps_claim": false,
		"graphical": graphical, "seed": random_seed, "enchanted": enchantments, "frames": sample_count,
		"cpu": _stats(cpu), "wall": _stats(wall_ms), "draw_calls": _stats(draw_calls),
		"hp_receipt": hp, "peak_host_children": peak_nodes, "category_usec": category_usec,
		"category_calls": category_calls, "diagnostics": DIAG.snapshot(), "failures": failures}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("SEVEN_WEAPON_PROBE ", JSON.stringify(report))
	DIAG.enabled = false
	host.queue_free()
	await frames()
	EffectScheduler.set_process(true)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)

func _collect_ticks(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child == player or child == loadout: continue
		if not child is EnemyController and child.get_script() != null and (child.is_physics_processing() or child.is_processing()):
			result.append(child)
		_collect_ticks(child, result)

func _freeze(node: Node) -> void:
	node.set_meta(&"probe_processing", Vector2i(int(node.is_processing()), int(node.is_physics_processing())))
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): _freeze(child)

func _thaw(node: Node) -> void:
	if node.has_meta(&"probe_processing"):
		var flags: Vector2i = node.get_meta(&"probe_processing")
		node.set_process(flags.x != 0)
		node.set_physics_process(flags.y != 0)
	for child in node.get_children(): _thaw(child)

func _stats(values: Array[float]) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var sum := 0.0
	var slow := 0
	for value in values:
		sum += value
		if value > 33.333: slow += 1
	return {"mean": sum / values.size(), "p95": ordered[int(ordered.size() * 0.95)],
		"p99": ordered[int(ordered.size() * 0.99)], "max": ordered.back(), "over_33ms": slow}

func _run_live(graphical: bool) -> void:
	Engine.max_fps = 60
	EffectScheduler.set_process(true)
	player._invincibility_timer = 100000
	for enemy in enemies:
		enemy.set_target_player(player)
		enemy.set_physics_process(true)
	for w: WeaponInstance in loadout.weapon_instances:
		CombatSettings.set_weapon_auto_cast(w.weapon_id, true, false)
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_WAVE_COMBAT)
	live_running = true
	var samples: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draws: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec() - started < 12000000:
		if graphical: await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		# Exclude the first two seconds of setup/first casts from frame statistics.
		if now - started >= 2000000:
			samples.append((now - previous) / 1000.0)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		previous = now
	live_running = false
	var report := {"live": true, "graphical": graphical, "seed": random_seed, "enchanted": enchantments,
		"legacy_lamp_range": legacy_lamp_range,
		"moving_high_hp_enemies": 48, "real_wave": false, "phone_fps_claim": false,
		"fps": 1000.0 / float(_stats(samples).mean), "wall_ms": _stats(samples),
		"engine_process_ms": _stats(process_ms), "engine_physics_ms": _stats(physics_ms),
		"draw_calls": _stats(draws), "diagnostics": DIAG.snapshot(), "failures": failures}
	if graphical:
		get_viewport().get_texture().get_image().save_png(output.get_basename() + ".png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("SEVEN_WEAPON_LIVE ", JSON.stringify(report))
	DIAG.enabled = false
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)
