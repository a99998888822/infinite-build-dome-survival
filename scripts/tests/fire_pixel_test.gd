extends "res://scripts/tests/pixel_combat_effect_test.gd"

const PARAMS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const FIRE = preload("res://scripts/effects/pixel_fire_visual.gd")

func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2.ZERO, Vector2(150, 0)])
	weapon._attached_item_instances[0]["effect_ids"] = ["fire"]
	var context := PARAMS.build_weapon_context(weapon, "fire", {"original_damage": 100.0, "damage": 35.0, "patch_duration": 3.0, "tick_interval": 0.25, "burn_duration": 3.0})
	var patch := FirePatch.spawn(host, Vector2.ZERO, context)
	patch.set_physics_process(false)
	check(is_equal_approx(patch._radius, 30.0), "initial gameplay radius remains 30")
	check(is_equal_approx(patch._remaining, 3.0), "initial field lifetime remains 3 seconds")
	await frames()
	patch._apply_tick_damage()
	check(enemies[0].has_status("burning") and not enemies[1].has_status("burning"), "field applies burning only in unchanged collision range")
	var before_hp := enemies[0].current_hp
	enemies[0]._process_burning(0.5)
	check(enemies[0].current_hp < before_hp, "burning still deals periodic damage")
	var merged := FirePatch.spawn(host, Vector2(24, 0), context)
	check(merged == patch, "nearby seeds merge into the same gameplay field")
	check(is_equal_approx(patch._radius, 40.8), "merged field retains original radius rule")
	patch.expand_from_wind(1.35)
	check(is_equal_approx(patch._radius, 55.08), "wind expansion retains original radius rule")
	check(is_equal_approx((patch._collision_shape.shape as CircleShape2D).radius, patch._radius), "collision shape follows expanded gameplay radius")
	var remaining := patch._remaining
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	patch._physics_process(1.0)
	check(is_equal_approx(patch._remaining, remaining), "battle pause freezes field duration")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var visual = patch._flame_visual
	check(visual.tongue_count == 3 and visual.parts.size() == 3, "expanded field keeps one medium and two narrow tongues")
	check(visual.parts[2].data.r > visual.parts[0].data.r and visual.parts[2].data.r > visual.parts[1].data.r, "center tongue is wider than both side tongues")
	var before_parts: Array = visual.parts.duplicate(true)
	var builds: int = visual.build_count
	visual.setup_field(patch._radius)
	check(visual.parts == before_parts and visual.build_count == builds, "unchanged extent does not rebuild geometry")
	FIRE.clock.flush()
	check(FIRE.clock.batches.size() <= 3, "all fire sources share at most three draw batches")
	var clock_age: float = FIRE.clock.elapsed
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	FIRE.clock._process(1.0)
	check(is_equal_approx(FIRE.clock.elapsed, clock_age), "battle pause freezes shader animation")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var status = enemies[0].get_node("EnemyStatusVisual")
	if status != null:
		status._process(0.1)
		check(is_instance_valid(status._flame_visual), "burning status creates a small reusable flame mesh")
		check(status._flame_visual.tongue_count == 1, "each burning enemy has exactly one tongue")
		var saved_id: int = status._flame_visual.get_instance_id()
		status._process(0.1)
		check(status._flame_visual.get_instance_id() == saved_id, "burn refresh reuses existing visual")
		enemies[0].apply_burning(3.0, 1.0, "holy_test", true, false)
		status._process(0.1)
		check(not is_instance_valid(status._flame_visual), "holy flame replaces the ordinary narrow tongue")
		enemies[0]._process_burning(4.0)
		status._process(0.1)
		check(not is_instance_valid(status._flame_visual), "expired burning leaves no ordinary flame")
	var seed := FireSeed.new()
	seed.set_process(false)
	host.add_child(seed)
	seed.position = Vector2(220, 0)
	seed._parent_root = host
	seed._context = context
	seed._land_position = Vector2(240, 0)
	seed._velocity = Vector2(40, -50)
	seed._lifetime = 0.1
	check(seed.get_child(0).tongue_count == 1, "flying seed owns one narrow tongue")
	var seed_position := seed.position
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	seed._process(0.05)
	check(seed.position == seed_position, "paused seed stays at its current position")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	seed._process(0.05)
	check(seed.position != seed_position, "seed retains its ballistic movement")
	seed._process(0.06)
	check(seed.is_queued_for_deletion(), "landed seed is released")
	var landed := false
	for child in host.get_children():
		if child is FirePatch and child.global_position == Vector2(240, 0): landed = true
	check(landed, "seed landing creates a field at the original destination")
	patch._physics_process(4.0)
	check(patch.is_queued_for_deletion(), "expired gameplay field frees itself")
	host.queue_free()
	await frames()
	check(get_tree().get_nodes_in_group("pixel_fire_visuals").is_empty(), "fire meshes are released with their owners")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	add_child(viewport)
	var anchor := Node2D.new()
	viewport.add_child(anchor)
	anchor.transform = Transform2D(0.3, Vector2(1.2, 0.8), 0.0, Vector2(77, 101))
	var flame := FIRE.new()
	anchor.add_child(flame)
	flame.setup_single(Vector2(24, 36), 3)
	await frames()
	FIRE.clock.flush()
	check(FIRE.clock.get_viewport() == viewport, "shared batch stays inside the owner's battle SubViewport")
	var batch: MultiMeshInstance2D = FIRE.clock.batches[43]
	var actual := batch.multimesh.get_instance_transform_2d(0)
	var expected: Transform2D = flame.global_transform * flame.parts[0].transform
	# The dummy headless renderer returns identity for MultiMesh getters.
	# Check its submitted buffer here; the GPU run exercises native readback.
	if DisplayServer.get_name() == "headless":
		var submitted: PackedFloat32Array = FIRE.clock.buffers[43]
		actual = Transform2D(Vector2(submitted[0], submitted[4]), Vector2(submitted[1], submitted[5]), Vector2(submitted[3], submitted[7]))
	check(actual.is_equal_approx(expected), "batch preserves owner position, rotation, and scale")
	viewport.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.2).timeout
	CampProgression.end_transient_session()
	print("FIRE_PIXEL_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
