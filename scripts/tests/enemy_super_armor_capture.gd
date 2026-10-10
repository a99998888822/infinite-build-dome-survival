extends "res://scripts/tests/iron_knight_live_capture.gd"


func _run() -> void:
	if capture_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		get_tree().quit(2)
		return
	seed(1010)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	var manager: WaveManager = battle.wave_manager
	manager.set_process(false)
	var player: PlayerController = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 100
	for unit in EnemyRegistry.get_registered_enemies().duplicate(): unit.free()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"): runtime.queue_free()
	await frames(2)
	var origin := player.global_position
	var knight := manager.spawn_enemy("enemy_elite_rusher", origin + Vector2(-190, 45)) as EliteRusher
	var wolf := manager.spawn_enemy("enemy_underworld_wolf", origin + Vector2(190, 45)) as UnderworldWolf
	knight.set_physics_process(false)
	wolf.set_physics_process(false)
	knight.skill_state = "chase"
	wolf.state = "chase"
	knight.sprite.show()
	wolf.sprite.show()
	wolf.sprite.flip_h = true
	knight._set_animation(&"idle")
	wolf.set_animation(&"idle")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(4)
	# Controlled real battle: only placement and time are scripted for review.
	# The visual is triggered through production knockback resistance.
	knight.apply_knockback(Vector2.LEFT, 450.0, 0.3, 0.0)
	wolf.apply_knockback(Vector2.RIGHT, 450.0, 0.3, 0.0)
	for unit in [knight, wolf]: unit._super_armor_visual.set_process(false)
	var samples: Array = []
	for index in 49:
		var elapsed := index / 20.0
		knight._animate(0.05)
		wolf.animate(0.05)
		for unit in [knight, wolf]: unit._super_armor_visual._process(0.05 if index > 0 else 0.0)
		if index == 24:
			knight.sprite.flip_h = true
			wolf.sprite.flip_h = false
		for unit in [knight, wolf]: unit._super_armor_visual._sync()
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%03d.png" % index))
		samples.append({"time": elapsed, "knight_visible": knight._super_armor_visual.visible,
			"wolf_visible": wolf._super_armor_visual.visible, "knight_frame": str(knight.sprite.texture.resource_path),
			"wolf_frame": str(wolf.sprite.texture.resource_path)})
	var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"production_scene": "res://scenes/core/game_root.tscn",
		"scripted_review": true, "trigger": "apply_knockback(direction, 450.0, 0.3, 0.0)", "fps": 20, "samples": samples}, "\t"))
	print("SUPER_ARMOR_CAPTURE_COMPLETE samples=", samples.size())
	manager.clear_battle_entities()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(8)
	get_tree().quit()
