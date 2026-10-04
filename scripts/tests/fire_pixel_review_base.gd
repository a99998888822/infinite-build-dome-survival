extends Node
## Production weapons/effects. GPU measurement and frame readback are separate phases.

const SPELLS := ["baseline", "fire", "water", "ice", "lightning", "electric_spark", "wind", "light_sword", "black_hole", "explosion", "mixed"]
var output := ""
var only := ""
var tier := "all"
var record_video := true
var results: Array = []
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var foes: Array[EnemyController] = []
var launches := 0
var failures := 0
var motion_time := 0.0
var moving := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg.begins_with("--tier="): tier = arg.trim_prefix("--tier=")
		if arg == "--no-capture": record_video = false
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func _physics_process(delta: float) -> void:
	if moving and is_instance_valid(player) and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		motion_time += delta
		player.set_mobile_move_direction(Vector2.from_angle(motion_time * 1.4))


func _run() -> void:
	if output.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	for count in [30, 120]:
		if tier != "all" and tier.to_int() != count: continue
		for spell in SPELLS:
			if not only.is_empty() and spell != only: continue
			if spell == "mixed" and count != 120: continue
			await run_case(spell, count)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("ELEMENT_REVIEW_COMPLETE cases=%d failures=%d" % [results.size(), failures])
	get_tree().quit(1 if failures else 0)


func setup(spell: String, count: int) -> Dictionary:
	seed(10042026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection():
		push_error("ELEMENT_REVIEW_START_FAILED")
		get_tree().quit(3)
		return {}
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(6)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player = battle.player
	loadout = battle.loadout
	player.set_physics_process(true)
	player._invincibility_timer = 9999
	player.modifier_stack.set_base_stat("load_capacity", 200)
	player.camera_2d.offset = Vector2(65, 0)
	var weapons := {"void_blade": [] if spell == "baseline" else [spell]}
	if spell == "mixed":
		weapons = {"void_blade": ["water", "ice"], "copper_lamp": ["fire", "wind"],
			"earth_hammer": ["electric_spark", "lightning"], "meteor_flail": ["black_hole", "light_sword"],
			"mutant_tentacle": ["explosion", "fire"]}
	var weapon_stats := {}
	for key in weapons:
		var id := "weapon_" + str(key)
		if loadout.get_weapon_instance(id) == null: loadout.equip_weapon(id)
		var weapon := loadout.get_weapon_instance(id)
		for item in weapon.get_attached_item_instances():
			loadout.detach_item_from_weapon(id, item.item_instance_id)
		while weapon.get_attachment_slot_count() < weapons[key].size():
			if not loadout.upgrade_weapon(id): break
		for effect in weapons[key]:
			var item := player.item_inventory.add_item_from_base("scroll_" + str(effect), "element_review")
			if not loadout.attach_item_to_weapon(id, item.item_instance_id):
				push_error("ELEMENT_REVIEW_ATTACH_FAILED " + str(effect))
				failures += 1
		weapon.runtime_stats.crit_chance = 0
		weapon.attack_timer = 0.25
		weapon_stats[id] = {"level": weapon.level, "interval": weapon.get_actual_attack_interval_seconds(),
			"base_damage": weapon.get_base_attack_damage(), "enchantments": weapons[key]}
	launches = 0
	loadout.weapon_fired.connect(func(_id: String, n: int): launches += n)
	foes.clear()
	for i in count:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2.from_angle(i * 2.399963) * (130 + sqrt(float(i)) * 14))
		enemy.current_hp = 100000
		foes.append(enemy)
	var hud := battle.hud as BattleHud
	hud._set_drawer_open(false, false)
	hud._performance_line.add_theme_font_size_override("font_size", 14)
	hud._performance_line.add_theme_color_override("font_color", Color.WHITE)
	var caption := CanvasLayer.new()
	caption.layer = 60
	game.add_child(caption)
	var label := Label.new()
	caption.add_child(label)
	label.position = Vector2(360, 82)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var title := "无附魔基准" if spell == "baseline" else ("五武器 · 九法术混合" if spell == "mixed" else str(DataRegistry.get_record("augmentations", "scroll_" + spell).display_name))
	label.text = "%s  |  %d只移动高生命小怪\n正式武器与附魔逻辑 · 自动绕行、角色无敌" % [title, count]
	motion_time = 0.0
	moving = true
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	battle.set_process(true)
	return weapon_stats


func sample_metrics() -> Dictionary:
	var hud := battle.hud as BattleHud
	hud._performance_line.refresh()
	var value: Dictionary = hud._performance_line.sample.duplicate()
	value.runtimes = get_tree().get_nodes_in_group("weapon_runtime_effects").size()
	value.damage_numbers = EnemyController.active_damage_numbers
	value.pixel_effects = get_tree().get_nodes_in_group("pixel_combat_effects").size()
	var kinds := {}
	for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
		var kind := str(effect.get_meta("pixel_effect_kind", "unknown"))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	value.pixel_effect_kinds = kinds
	value.fire_fields = get_tree().get_nodes_in_group("fire_patches").size()
	value.ice_fields = get_tree().get_nodes_in_group("ice_fields").size()
	var statuses := {}
	for status in ["burning", "wet", "frozen", "stunned", "light", "dark"]:
		statuses[status] = foes.filter(func(e): return is_instance_valid(e) and e.has_status(status)).size()
	value.statuses = statuses
	return value


func run_case(spell: String, count: int) -> void:
	var stats := await setup(spell, count)
	await get_tree().create_timer(3.0).timeout
	var times: Array[float] = []
	var samples: Array = []
	var start := Time.get_ticks_usec()
	var previous := start
	var last_sample := start
	battle.wave_manager.weapon_damage_this_wave.clear()
	launches = 0
	while Time.get_ticks_usec() - start < 6000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
		if now - last_sample >= 100000:
			last_sample = now
			var value := sample_metrics()
			value.time = (now - start) / 1e6
			samples.append(value)
	var duration := (Time.get_ticks_usec() - start) / 1e6
	times.sort()
	var record := {"id": spell, "enemies": count, "weapons": stats, "samples": samples, "seconds": duration,
		"avg_fps": times.size() / duration, "p50_ms": times[times.size() / 2],
		"p95_ms": times[int(times.size() * 0.95)], "p99_ms": times[int(times.size() * 0.99)], "max_ms": times.back(),
		"launches": launches, "damage": battle.wave_manager.weapon_damage_this_wave.duplicate(),
		"measurement": "uncapped GPU, no screenshots, 3s warmup then 6s sampling", "capture": {}}
	if launches <= 0 or record.damage.is_empty():
		failures += 1
		push_error("ELEMENT_REVIEW_NO_ATTACKS " + spell)
	print("ELEMENT_MEASURE ", spell, " enemies=", count, " fps=", record.avg_fps, " p95=", record.p95_ms)
	await cleanup()
	if record_video and (count == 30 or spell == "mixed"):
		await setup(spell, count)
		await get_tree().create_timer(2.0).timeout
		if DisplayServer.get_name() != "headless": record.capture = await capture(spell, count)
		await cleanup()
	results.append(record)
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))


func capture(spell: String, count: int) -> Dictionary:
	var directory := output.path_join("%s_%d" % [spell, count])
	DirAccess.make_dir_recursive_absolute(directory)
	var images: Array[Image] = []
	var samples: Array = []
	var stamps: Array[float] = []
	var start := Time.get_ticks_usec()
	var next := 0.0
	while Time.get_ticks_usec() - start < 6000000:
		await RenderingServer.frame_post_draw
		var seconds := (Time.get_ticks_usec() - start) / 1e6
		if seconds < next: continue
		next = seconds + 1.0 / 15.0
		stamps.append(seconds)
		images.append(get_tree().root.get_texture().get_image())
		if images.size() % 4 == 0:
			var value := sample_metrics()
			value.time = seconds
			samples.append(value)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	battle.set_process(false)
	# Store uncompressed pixels after recording; the packaging tool encodes media.
	# This avoids spending most of the review run on per-frame PNG compression.
	var raw := FileAccess.open(directory.path_join("frames.rgb"), FileAccess.WRITE)
	for i in images.size():
		images[i].convert(Image.FORMAT_RGB8)
		raw.store_buffer(images[i].get_data())
	raw.close()
	images[images.size() / 2].save_png(directory.path_join("poster.png"))
	var report := {"frames": images.size(), "timestamps": stamps, "samples": samples, "seconds": 6,
		"note": "Live uncapped FPS shown in HUD; GPU readback may lower FPS. PNG encoding happens after capture."}
	FileAccess.open(directory.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ELEMENT_CAPTURE ", spell, " frames=", images.size())
	return report


func cleanup() -> void:
	moving = false
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	battle.set_process(false)
	foes.clear()
	game.queue_free()
	await frames(12)
