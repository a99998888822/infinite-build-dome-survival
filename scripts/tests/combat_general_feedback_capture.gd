extends "res://scripts/tests/iron_knight_live_capture.gd"
## Actual production GPU viewport; scripted contacts and placement for visual QA.
var samples: Array[Dictionary] = []
var failures := 0


func _run() -> void:
	if capture_dir.is_empty() or not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	seed(1016)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.set_process(false)
	var manager := battle.wave_manager
	manager.set_process(false)
	var player := battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 1000
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"): runtime.queue_free()
	await frames(4)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var label_layer := CanvasLayer.new()
	label_layer.layer = 100
	add_child(label_layer)
	var label := Label.new()
	label.position = Vector2(330, 52)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_constant_override("outline_size", 5)
	label_layer.add_child(label)
	var units: Array[EnemyController] = []
	var origin := player.global_position
	# A normal and two real small bosses show the white exception clearly.
	for row in [["enemy_mutated_grub", Vector2(-360, 100)], ["enemy_elite_rusher", Vector2(0, 170)], ["enemy_underworld_wolf", Vector2(360, 170)]]:
		var unit := manager.spawn_enemy(row[0], origin + row[1])
		unit.set_physics_process(false)
		unit.current_hp = 100000
		unit.sprite.show()
		if unit is EliteRusher: unit.skill_state = "chase"
		if unit is UnderworldWolf: unit.state = "chase"
		units.append(unit)
	label.text = "Normal: white + shake  |  Small bosses: shake only"
	await frames(8)
	await _save("normal_boss_before")
	for unit in units:
		unit.take_damage(1, "review")
		unit._hit_visual.set_process(false)
	await _save("normal_boss_contact")
	for index in 14:
		for unit in units: unit._hit_visual._process(1.0 / 60.0)
		await _save("body_%02d" % index)
	for unit in units: unit.free()
	units.clear()
	CombatHitFeedback.clear()
	for index in 12:
		var at := origin + Vector2(230 + (index % 4) * 92, 60 + (index / 4) * 76)
		var unit := manager.spawn_enemy("enemy_mutated_grub", at)
		unit.set_physics_process(false)
		unit.current_hp = 100000
		units.append(unit)
	battle.active_controller._has_pointer_position = true
	battle.active_controller._pointer_position = Vector2(700, 420)
	var aim := battle.active_controller.pointer_world()
	var canvas := player.get_viewport().get_canvas_transform()
	var cases := [[3, "3 nearby: 1 px + 50 ms hitstop"], [6, "6 nearby: 2 px + 50 ms hitstop"], [12, "12 nearby: 6 px + 50 ms hitstop"]]
	for row in cases:
		CombatHitFeedback.clear()
		for unit in units:
			if unit._hit_visual != null: unit._hit_visual.reset()
		label.text = row[1]
		await frames(8)
		var count: int = row[0]
		# 12 contacts must fit in one local radius around a hit enemy.
		var event := DamageEvent.create({"damage": 1, "source_weapon_id": "review"})
		for index in count: units[index].take_attack_damage(1, event)
		for index in 32:
			await _save("tier_%02d_%02d" % [count, index])
			var offset := CombatHitFeedback.screen_offset
			samples.append({"case": count, "frame": index, "time_usec": Time.get_ticks_usec(),
				"tier": CombatHitFeedback.tier, "local_count": CombatHitFeedback.last_local_count,
				"paused": get_tree().paused, "screen_offset": [offset.x, offset.y],
				"world_updates": (player.get_viewport() as SubViewport).render_target_update_mode})
			if not battle.active_controller.pointer_world().is_equal_approx(aim) or player.get_viewport().get_canvas_transform() != canvas:
				failures += 1
		print("GENERAL_FEEDBACK_CAPTURE tier=", count, " count=", CombatHitFeedback.last_local_count)
	CombatHitFeedback.clear()
	var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scripted_review": true, "production_scene": "res://scenes/core/game_root.tscn", "failures": failures, "samples": samples}, "\t"))
	manager.clear_battle_entities()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("GENERAL_FEEDBACK_CAPTURE_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png"))
