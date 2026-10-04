extends "res://scripts/tests/meadow_install_review.gd"
## Exercise automatic production activation, streaming, rendering and scene lifetime.
var pairs: Array = []


func verify_batch(prefix: String) -> void:
	var renderer: Node = ground.grass_batch
	check(is_instance_valid(renderer) and renderer.get_parent() == ground, "battle owns grass renderer")
	check(renderer.mode == "batch" and renderer.active_batches > 0, "production enables grass batching")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	player.camera_2d.position_smoothing_enabled = false
	var poses := [Vector2.ZERO, Vector2(260, 40), Vector2(-260, -40), Vector2(20000, -20000), Vector2(-42000, 33000), Vector2.ZERO]
	for index in poses.size():
		move_to(poses[index])
		ground._update_area()
		await frames(2)
		ground._update_area()
		renderer.update()
		var signature := ground.layout_signature()
		check(ground.cells.size() == ground.cell_rect.get_area(), "streamed cells cover view")
		check(renderer.cells.size() == ground.cells.size(), "batch registry retires old cells")
		check(renderer.groups.size() <= ground.cell_rect.size.y * 32, "depth bands stay bounded")
		var stem := "%s-%02d" % [prefix, index]
		for mode in ["original", "batch"]:
			renderer.set_mode(mode)
			await frames(2)
			await capture(stem + "-" + mode + ".png")
		check(signature == ground.layout_signature(), "batching preserves grass placement")
		pairs.append(stem)
	# Hold camera fixed while the player crosses several root depths.
	var builds: int = renderer.build_count
	var nodes: int = renderer.node_builds
	var bounds := ground.cell_rect
	for i in 24:
		player.global_position = Vector2(0, i - 12)
		ground._update_area()
		renderer.update()
	check(ground.cell_rect == bounds, "fixed camera keeps same streamed area")
	check(renderer.build_count == builds and renderer.node_builds == nodes, "player movement never rebuilds grass buffers")
	game.process_mode = Node.PROCESS_MODE_INHERIT
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	move_to(Vector2.ZERO)
	await frames(6)


func _run() -> void:
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	for id in ["character_void_hunter", "character_capitalist"]:
		await start_character(id)
		await verify_batch(id)
		await check_view_mapping()
		await verify_batch(id + "-resized")
		player.set_physics_process(true)
		battle.wave_manager.set_process(true)
		var before := battle.wave_manager.wave_time_left
		await frames(120)
		check(battle.wave_manager.wave_time_left < before, "normal combat progresses")
		var old_renderer: WeakRef = weakref(ground.grass_batch)
		var old_visual: WeakRef = weakref(player.visual_anchor)
		flow.enter_start_page()
		await frames(20)
		check(get_tree().get_nodes_in_group("battle_meadow").is_empty(), "menu releases scenery")
		check(old_renderer.get_ref() == null and old_visual.get_ref() == null, "menu releases batch renderer and player visual")
	game.queue_free()
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("verification.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "pairs": pairs, "captures": captures}, "\t"))
	print("MEADOW_GRASS_BATCH_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
