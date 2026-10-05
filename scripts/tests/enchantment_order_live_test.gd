extends Node
## Production GameRoot/GPU smoke and stress test. No PNG readback during sampling.
var output := ""
var only := ""
var results: Array = []
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var foes: Array[EnemyController] = []
var launches: Array = []
var label: Label
var started := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	_run.call_deferred()

func frames(n: int) -> void:
	for _i in n: await get_tree().process_frame

func _run() -> void:
	if output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var cases := [
		{"id":"chain_split", "title":"闪电链 → 分裂", "count":12, "moving":false, "weapons":{"void_blade":["lightning","split"]}},
		{"id":"split_chain", "title":"分裂 → 闪电链", "count":12, "moving":false, "weapons":{"void_blade":["split","lightning"]}},
		{"id":"hammer_lightning", "title":"战锤：分裂 → 落雷", "count":30, "moving":false, "weapons":{"earth_hammer":["split","electric_spark"]}},
		{"id":"lamp_haste", "title":"炉灯：迅捷＋燃烧", "count":30, "moving":true, "weapons":{"copper_lamp":["haste","fire"]}},
		{"id":"control", "title":"触手：结霜 → 震荡", "count":30, "moving":true, "weapons":{"mutant_tentacle":["ice","explosion"]}},
		{"id":"baseline_200", "title":"200只怪物 · 单武器基准", "count":200, "moving":true, "weapons":{"void_blade":[]}},
		{"id":"stress_200", "title":"200只怪物 · 五武器重复与范围附魔", "count":200, "moving":true, "weapons":{"meteor_flail":["split","lightning"],"copper_lamp":["fire","fire"],"earth_hammer":["split","electric_spark"],"iron_grenade_cannon":["lightning","lightning"],"mutant_tentacle":["water","ice"]}},
	]
	for config in cases:
		if not only.is_empty() and only != config.id: continue
		await run_case(config)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("ORDER_LIVE_COMPLETE cases=", results.size())
	get_tree().quit(0)

func run_case(config: Dictionary) -> void:
	seed(9302026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152,768)
	get_tree().root.content_scale_size = Vector2i(1152,768)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_" + str(config.weapons.keys()[0])])
	await frames(4)
	if not flow.confirm_character_selection():
		push_error("ORDER_LIVE_START_FAILED")
		get_tree().quit(3)
		return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(6)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player = battle.player
	loadout = battle.loadout
	player.set_physics_process(false)
	player._invincibility_timer = 9999
	player.modifier_stack.set_base_stat("load_capacity", 200)
	player.camera_2d.offset = Vector2(90,0)
	launches.clear()
	loadout.weapon_fired.connect(func(id: String, count: int): launches.append({"seconds":(Time.get_ticks_usec()-started)/1e6,"weapon":id,"count":count}))
	var levels := {}
	for key in config.weapons:
		var id := "weapon_" + str(key)
		if loadout.get_weapon_instance(id) == null: loadout.equip_weapon(id)
		var weapon := loadout.get_weapon_instance(id)
		for item in weapon.get_attached_item_instances():
			loadout.detach_item_from_weapon(id, item.item_instance_id)
		while weapon.get_attachment_slot_count() < 2:
			if not loadout.upgrade_weapon(id): break
		for enchantment in config.weapons[key]:
			var item := player.item_inventory.add_item_from_base("scroll_" + str(enchantment), "live_order_test")
			if not loadout.attach_item_to_weapon(id, item.item_instance_id): push_error("ORDER_LIVE_ATTACH_FAILED " + id)
		weapon.runtime_stats.crit_chance = 0
		weapon.attack_timer = 0.2
		levels[id] = weapon.level
	foes.clear()
	for i in int(config.count):
		var at := Vector2(70 + (i % 6) * 42, (i / 6) * 38 - (int(config.count) / 6 - 1) * 19)
		if bool(config.moving): at = Vector2.from_angle(i * 2.39996) * (100 + sqrt(float(i)) * 13)
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		player.get_parent().add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 100000
		enemy.set_physics_process(bool(config.moving))
		enemy.global_position = player.global_position + at
		enemy.damage_received.connect(battle.wave_manager._on_enemy_damage_received)
		foes.append(enemy)
	var caption := CanvasLayer.new()
	game.add_child(caption)
	label = Label.new()
	caption.add_child(label)
	label.position = Vector2(380, 70)
	label.add_theme_font_size_override("font_size", 16)
	label.text = str(config.title) + "\n正式战斗逻辑 · 高生命测试敌人"
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	battle.set_process(true)
	started = Time.get_ticks_usec()
	await get_tree().create_timer(2.0).timeout
	battle.wave_manager.weapon_damage_this_wave.clear()
	var elapsed_ms: Array[float] = []
	var metrics: Array = []
	var start := Time.get_ticks_usec()
	var previous := start
	var last_sample := start
	while Time.get_ticks_usec() - start < 6000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		elapsed_ms.append((now - previous) / 1000.0)
		previous = now
		if now - last_sample >= 100000:
			last_sample = now
			var hud := battle.hud as BattleHud
			hud._performance_line.refresh()
			var sample: Dictionary = hud._performance_line.sample.duplicate()
			sample.runtimes = get_tree().get_nodes_in_group("weapon_runtime_effects").size()
			sample.damage_numbers = EnemyController.active_damage_numbers
			sample.stunned = foes.filter(func(e): return e.has_status("stunned")).size()
			sample.frozen = foes.filter(func(e): return e.has_status("frozen")).size()
			sample.pushed = foes.filter(func(e): return e._knockback_timer > 0).size()
			metrics.append(sample)
	var duration := (Time.get_ticks_usec() - start) / 1e6
	elapsed_ms.sort()
	var record := {"id":config.id, "fixture":config, "levels":levels, "seconds":duration,
		"fps":elapsed_ms.size()/duration, "p50_ms":elapsed_ms[elapsed_ms.size()/2], "p95_ms":elapsed_ms[int(elapsed_ms.size()*.95)],
		"p99_ms":elapsed_ms[int(elapsed_ms.size()*.99)], "max_ms":elapsed_ms.back(), "samples":metrics,
		"damage":battle.wave_manager.weapon_damage_this_wave.duplicate(), "launches":launches.duplicate(true)}
	results.append(record)
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("ORDER_LIVE_CASE ", config.id, " fps=", record.fps, " p95_ms=", record.p95_ms, " damage=", record.damage)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(output.path_join(str(config.id) + ".png"))
		if config.id in ["chain_split", "split_chain"]:
			var directory := output.path_join(config.id)
			DirAccess.make_dir_recursive_absolute(directory)
			for i in 36:
				await get_tree().create_timer(1.0/12.0).timeout
				RenderingServer.force_draw()
				await RenderingServer.frame_post_draw
				get_tree().root.get_texture().get_image().save_png(directory.path_join("frame_%03d.png" % i))
		if config.id == "chain_split":
			get_tree().root.content_scale_size = Vector2i(768,512)
			get_tree().root.size = Vector2i(768,512)
			await frames(8)
			await get_tree().create_timer(2.0).timeout
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png(output.path_join("compact_hud.png"))
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	battle.set_process(false)
	game.queue_free()
	await frames(12)
