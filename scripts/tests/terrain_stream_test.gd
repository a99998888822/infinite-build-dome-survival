extends "res://scripts/tests/cavern_sunlight_test.gd"
## Original planner oracle plus lifecycle checks on the production backdrop.
func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	flow.confirm_character_selection()
	await frames(16)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	player = battle.player
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	player.set_physics_process(false)
	await wait_for_stream()
	var oracle_script := load("res://scripts/tests/fixtures/terrain_original_plan.gd") as GDScript
	var oracle := oracle_script.new() as CavernSunlightBackdrop
	oracle.config = ground.config
	oracle.surface_context = ground.surface_context
	oracle.sample_offset = ground.sample_offset
	var saved_seed := ground.population_seed
	var saved_clearance := ground.shelter_clearance
	for layout_seed in [1, 20102026, 998877]:
		ground.population_seed = layout_seed
		oracle.population_seed = layout_seed
		for clearance in [Rect2(), Rect2(-200,-100,1100,700)]:
			ground.shelter_clearance = clearance
			oracle.shelter_clearance = clearance
			for y in range(-3,4):
				for x in range(-3,4):
					var key := Vector2i(x,y)
					seed(112233)
					var expected_rng := randi()
					seed(112233)
					var result := ground._plan_cell(key)
					var unchanged_rng := randi() == expected_rng
					check(result == oracle.original_plan(key) and unchanged_rng,
						"original placements and gameplay RNG seed=%d cell=%s shelter=%s" % [layout_seed,key,clearance.has_area()])
	oracle.free()
	ground.population_seed = saved_seed
	ground.shelter_clearance = saved_clearance
	verify_receivers()
	# Start a far-away stream, then cancel before it has completed.
	ground.set_process(false)
	player.global_position = Vector2(9000,9000)
	player._sync_camera()
	player.camera_2d.force_update_scroll()
	ground._update_area()
	check(not ground._pending_cells.is_empty(), "large move leaves resumable work")
	var old_keys := ground._cell_jobs.keys()
	var all_solids := true
	for key: Vector2i in ground._pending_cells:
		var expected := 0
		for entry: Dictionary in ground._solid_plan(key).entries:
			if ground._allows_solid(entry) and entry.kind=="prop": expected += 1
		var actual := 0
		for node: Node in ground.cells[key]:
			for child in node.get_children():
				if child is BattleTerrainObstacle and child.collision_layer==6: actual += 1
		all_solids = all_solids and actual==expected
	check(all_solids, "all pending cells have their solid collisions immediately")
	ground.reserve_shelter(Rect2(8500,8500,1500,1500))
	var clear := true
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			var entry: Dictionary = node.get_meta("scenery")
			if entry.kind in ["prop","rubble"]:
				clear = clear and not ground.shelter_clearance.has_point(entry.point)
	check(clear, "shelter reservation cancels pending solids and restarts the plan")
	ground.set_process(true)
	await move_to(Vector2(-9000,-9000))
	var cancelled := true
	for key: Vector2i in old_keys: cancelled = cancelled and not ground.cells.has(key) and not ground._cell_jobs.has(key)
	check(cancelled, "moving away cancels unfinished cells without reviving them")
	verify_receivers()
	ground.reserve_shelter(saved_clearance)
	await move_to(Vector2.ZERO)
	var signature := ground.layout_signature()
	await move_to(Vector2(9000,9000))
	await move_to(Vector2.ZERO)
	check(signature==ground.layout_signature(), "revisiting restores completed geometry and batch order")
	check(ground._cell_jobs.is_empty() and ground._retiring_nodes.is_empty(), "job and retirement queues drain")
	verify_receivers()
	await capture("terrain_complete")
	flow.enter_start_page()
	await frames(15)
	check(BattleTerrainObstacle.active.is_empty(), "exit releases every streamed collider")
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	print("TERRAIN_STREAM_TEST_COMPLETE checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
