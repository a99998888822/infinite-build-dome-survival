extends Node

const PROBE = preload("res://scripts/tests/hammer_probe.gd")
const TARGET = preload("res://scripts/tests/water_review_target.gd")
var output := ""
var variant := "original"
var capture := false
var moving := false
var seconds := 16.0
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var weapon: WeaponInstance
var enemies: Array[EnemyController] = []
var positions: Array[Vector2] = []
var label: Label
var title: Label

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg == "--capture": capture = true
		if arg == "--moving": moving = true
		if arg == "--profile": PROBE.profiling = true
		if arg == "--hide-warning-diagnostic": PROBE.hide_warning_diagnostic = true
	PROBE.remove_glow = variant in ["no_glow", "both"]
	PROBE.remove_spray = variant in ["no_spray", "both"]
	PROBE.use_warning_png = variant == "png"
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	CombatSettings.set_option("wheelchair_mode", false, false)
	seed(10062026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	assert(flow.confirm_character_selection())
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 99999
	player.modifier_stack.set_base_stat("load_capacity", 1000)
	for old: WeaponInstance in battle.loadout.weapon_instances.duplicate(): battle.loadout.remove_weapon(old.weapon_id)
	assert(battle.loadout.equip_weapon("weapon_earth_hammer"))
	weapon = battle.loadout.get_weapon_instance("weapon_earth_hammer")
	for i in 4: assert(weapon.upgrade())
	# Production has two attachment slots. Multishot only adds one stat and
	# has no dispatch action; applying its exact bonus reproduces the build.
	weapon.runtime_stats.projectile_count = float(weapon.runtime_stats.get("projectile_count", 1)) + 1.0
	var ids := ["scroll_split"]
	if variant != "native": ids.append("scroll_electric_spark")
	for id: String in ids:
		var item := DataRegistry.get_record("augmentations", id).duplicate(true)
		item.item_instance_id = "hammer_review_" + id
		item.base_item_id = id
		assert(weapon.attach_item_instance(item))
	player.camera_2d.offset = Vector2(125, -30)
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	var host := Node2D.new()
	player.get_parent().add_child(host)
	for i in 20:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		if not moving: enemy.set_script(TARGET)
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 1000000
		var pos := player.global_position + Vector2(75 + (i % 5) * 48, (i / 5 - 1.5) * 26)
		enemy.global_position = pos
		positions.append(pos)
		enemies.append(enemy)
	var layer := CanvasLayer.new()
	layer.layer = 90
	game.add_child(layer)
	var bg := ColorRect.new()
	bg.position = Vector2(12, 90)
	bg.size = Vector2(1118, 67)
	bg.color = Color(0.015, 0.025, 0.04, 0.9)
	layer.add_child(bg)
	title = Label.new()
	title.position = Vector2(20, 92)
	title.add_theme_font_size_override("font_size", 18)
	title.text = "裂地战锤 Lv5 + 分裂 + 多投等效 + 落雷 | 20 怪 | " + variant
	layer.add_child(title)
	label = Label.new()
	label.position = Vector2(20, 122)
	label.add_theme_font_size_override("font_size", 17)
	layer.add_child(label)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await get_tree().create_timer(1.0).timeout
	# One warm-up cast compiles the same shaders and allocates reusable pools.
	assert(battle.loadout.cast_weapon(weapon, player.global_position + Vector2(250, 0)))
	var warm := Time.get_ticks_usec()
	while Time.get_ticks_usec() - warm < 5000000:
		await get_tree().process_frame
		battle.loadout.tick(get_process_delta_time())
	PROBE.counters.clear()
	PROBE.costs.clear()
	for i in enemies.size():
		enemies[i].current_hp = 1000000
		enemies[i].global_position = positions[i]
	var build := {"level": weapon.level, "slots": weapon.get_attachment_slot_count(), "angles": weapon.get_projectile_angles(), "nodes": weapon.get_ground_node_count(), "range": weapon.get_attack_range(), "cooldown": weapon.get_active_cooldown_seconds(), "split": weapon.get_split_profiles(), "sequence": weapon.get_enchantment_sequence(), "projectiles": weapon.get_stat("projectile_count"), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "size": [1152, 648], "world_viewport": str(player.get_viewport().get_visible_rect().size)}
	var times: Array[float] = []
	var active_times: Array[float] = []
	var samples: Array = []
	var casts: Array[float] = []
	var frame_stamps: Array[float] = []
	var raw: FileAccess
	if capture: raw = FileAccess.open(output.path_join("frames.rgb"), FileAccess.WRITE)
	var start := Time.get_ticks_usec()
	var previous := start
	var next_sample := 0.0
	var next_capture := 0.0
	var peak_particles := 0
	var peak_reported := 0
	var peak_lights := 0
	while Time.get_ticks_usec() - start < int(seconds * 1e6):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - start) / 1e6
		var ms := float(now - previous) / 1000.0
		previous = now
		times.append(ms)
		if not casts.is_empty() and elapsed - casts[-1] >= 0.55 and elapsed - casts[-1] < 2.15: active_times.append(ms)
		battle.loadout.tick(get_process_delta_time())
		if casts.size() < 3 and battle.loadout.active_casting.can_cast(weapon):
			for i in enemies.size():
				enemies[i].global_position = positions[i]
				enemies[i].velocity = Vector2.ZERO
			if battle.loadout.cast_weapon(weapon, player.global_position + Vector2(250, 0)): casts.append(elapsed)
		var particles := 0
		var reported := 0
		var instances := 0
		var lights := 0
		var png_rings := 0
		for node in get_tree().get_nodes_in_group("particle_worlds"):
			particles += node.get_active_particle_count()
			instances += node._batch.multimesh.visible_instance_count
		for node in get_tree().get_nodes_in_group("combat_particle_counters"):
			reported += node.get_active_particle_count()
			if node is ElectricSparkEffect and node._using_warning_atlas(): png_rings += 1
		for node in get_tree().get_nodes_in_group("particle_light_field"): lights += node._order.size()
		peak_particles = maxi(peak_particles, particles)
		peak_reported = maxi(peak_reported, reported)
		peak_lights = maxi(peak_lights, lights)
		if elapsed >= next_sample:
			next_sample = elapsed + 0.05
			samples.append({"t": elapsed, "ms": ms, "particles": particles, "reported": reported, "png_rings": png_rings, "instances": instances, "lights": lights, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000})
			label.text = "FPS %3.0f | 粒子 %d（白色池 %d）| PNG 预警 %d | 第 %d 次挥锤" % [1000.0 / maxf(ms, 0.01), reported, particles, png_rings, casts.size()]
		if capture and elapsed >= next_capture:
			await RenderingServer.frame_post_draw
			var img := get_tree().root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			raw.store_buffer(img.get_data())
			frame_stamps.append(float(Time.get_ticks_usec() - start) / 1e6)
			next_capture = elapsed + 1.0 / 20.0
	if capture: raw.close()
	var damage := 0
	for enemy in enemies: damage += 1000000 - enemy.current_hp
	var row := {"variant": variant, "moving": moving, "capture": capture, "profile": PROBE.profiling, "build": build, "all": stats(times), "active": stats(active_times), "samples": samples, "casts": casts, "particles_peak": peak_particles, "reported_peak": peak_reported, "lights_peak": peak_lights, "counters": PROBE.counters, "costs": PROBE.costs, "damage": damage, "frame_stamps": frame_stamps}
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(row, "\t"))
	print("HAMMER_REVIEW ", variant, " all=", row.all, " active=", row.active, " counters=", PROBE.counters)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	get_tree().quit()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var a := values.duplicate()
	a.sort()
	var total := 0.0
	var over16 := 0
	var over33 := 0
	for v in a:
		total += v
		if v > 16.667: over16 += 1
		if v > 33.333: over33 += 1
	return {"frames": a.size(), "fps": 1000.0 * a.size() / total, "mean_ms": total / a.size(), "p50_ms": a[a.size() / 2], "p95_ms": a[int(a.size() * 0.95)], "p99_ms": a[int(a.size() * 0.99)], "max_ms": a[-1], "over16": over16, "over33": over33}
