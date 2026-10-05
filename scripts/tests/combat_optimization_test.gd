extends "res://scripts/tests/pixel_combat_effect_test.gd"

const LIGHT = preload("res://scripts/effects/particle_light_field.gd")


func _run() -> void:
	CampProgression.begin_transient_session()
	test_clamping()
	test_stat_cache()
	await setup([Vector2.ZERO])
	var player := load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.set_physics_process(false)
	enemies[0].target_player = player
	test_contacts(enemies[0], player)
	test_status_visual(enemies[0])
	test_light_geometry()
	host.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("COMBAT_OPTIMIZATION_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func reference_clamp(id: String, value: float) -> float:
	if not StatDefinitions.has_stat(id): return value
	var result := clampf(value, StatDefinitions.get_min_value(id), StatDefinitions.get_max_value(id))
	return float(roundi(result)) if StatDefinitions.is_integer_stat(id) else result


func test_clamping() -> void:
	var ids := StatDefinitions.get_all_stat_ids()
	ids.append("custom_unknown")
	for id in ids:
		var equal := true
		for value in [-1e9, -9999.5, -100.0, -0.5, 0.0, 0.49, 0.5, 1.5, 99.5, 100.0, 10000.0, 1e9]:
			equal = equal and StatDefinitions.clamp_stat_value(id, value) == reference_clamp(id, value)
		check(equal, "clamp preserves bounds and rounding: " + id)


func compare_stacks(cached: ModifierStack, reference: ModifierStack, label: String) -> void:
	var same := true
	for id in StatDefinitions.get_all_stat_ids():
		same = same and is_equal_approx(cached.get_stat(id), reference.get_stat(id))
	check(same, label)


func test_stat_cache() -> void:
	var cached := ModifierStack.new()
	var reference := ModifierStack.new()
	check(not reference.cache_enabled, "existing player and preview stacks default to uncached")
	cached.cache_enabled = true
	for stack in [cached, reference]: stack.set_base_stats({"move_speed": 100, "armor": 20})
	compare_stacks(cached, reference, "initial stats")
	var operations := ["add_flat", "add_percent", "multiply", "override", "min_cap", "max_cap"]
	var rules := ["unique", "replace_same_source", "stack_add", "stack_with_limit", "refresh_duration", "exclusive_group"]
	for index in 36:
		var modifier := {"id": "test_%d" % (index % 4), "source_type": "enemy", "source_id": "source_%d" % (index % 3),
			"target_scope": "enemy", "stat": "move_speed" if index % 2 else "armor", "value": 1.2 if index % 6 == 2 else 12.0 + index,
			"operation": operations[index % 6], "duration": 0.5 if index % 3 == 0 else -1.0,
			"stack_rule": rules[index / 6], "metadata": {"max_stacks": 2, "exclusive_group": "test"}}
		for stack in [cached, reference]: stack.add_modifier_from_dictionary(modifier)
		compare_stacks(cached, reference, "modifier mutation %d" % index)
		for stack in [cached, reference]: stack.tick(0.1)
		compare_stacks(cached, reference, "duration tick %d" % index)
	for stack in [cached, reference]: stack.tick(1.0)
	compare_stacks(cached, reference, "expiry invalidates cache")
	for stack in [cached, reference]: stack.set_base_stat("armor", -25)
	compare_stacks(cached, reference, "armor changes invalidate dependent damage_taken_percent")
	for method in ["remove_modifier", "remove_by_source", "remove_by_source_type", "remove_by_target_scope", "clear_modifiers", "clear"]:
		for stack in [cached, reference]:
			match method:
				"remove_modifier": stack.remove_modifier("test_1")
				"remove_by_source": stack.remove_by_source("enemy", "source_0")
				"remove_by_source_type": stack.remove_by_source_type("enemy")
				"remove_by_target_scope": stack.remove_by_target_scope("enemy")
				"clear_modifiers": stack.clear_modifiers()
				"clear": stack.clear()
		compare_stacks(cached, reference, method)
	var extra := {"id": "extra", "source_type": "test", "source_id": "test", "target_scope": "enemy", "stat": "move_speed", "operation": "add_flat", "value": 75, "duration": -1, "stack_rule": "unique"}
	check(cached.get_stat_with_extra_modifier("move_speed", extra) == reference.get_stat_with_extra_modifier("move_speed", extra), "temporary extra modifier resolved")
	compare_stacks(cached, reference, "temporary extra modifier does not pollute cache")
	check(cached.get_stat("custom", 11) == 11 and cached.get_stat("custom", 22) == 22, "unknown stat fallback stays caller-specific")
	cached.base_stats = {"move_speed": 211.0}
	check(cached.get_stat("move_speed") == 211, "replacing base container invalidates")
	cached.modifiers = [Modifier.from_dictionary(extra)]
	check(cached.get_stat("move_speed") == 286, "replacing modifier container invalidates")


func reference_contact(enemy: EnemyController, player: PlayerController) -> bool:
	var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var target := player.get_node("CollisionShape2D") as CollisionShape2D
	if body.disabled or target.disabled or body.shape == null or target.shape == null: return false
	if body.shape is CircleShape2D:
		var probe := CircleShape2D.new()
		probe.radius = body.shape.radius + enemy.CONTACT_MARGIN
		return probe.collide(body.global_transform, target.shape, target.global_transform)
	var motion := body.global_position.direction_to(target.global_position) * enemy.CONTACT_MARGIN
	return body.shape.collide_with_motion(body.global_transform, motion, target.shape, target.global_transform, Vector2.ZERO)


func test_contacts(enemy: EnemyController, player: PlayerController) -> void:
	var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var target := player.get_node("CollisionShape2D") as CollisionShape2D
	var rng := RandomNumberGenerator.new()
	rng.seed = 7112026
	var cases := 0
	var mismatches := 0
	for rectangular in [false, true]:
		if rectangular:
			body.shape = RectangleShape2D.new()
			body.shape.size = Vector2(27, 35)
		else:
			body.shape = CircleShape2D.new()
			body.shape.radius = 17.6
		for index in 1400:
			var scale_value := rng.randf_range(0.3, 2.0)
			body.scale = Vector2(scale_value, scale_value)
			body.rotation = rng.randf_range(-PI, PI)
			body.position = Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
			target.rotation = rng.randf_range(-PI, PI)
			var player_scale := rng.randf_range(0.5, 1.8)
			target.scale = Vector2(player_scale, player_scale)
			enemy.position = Vector2(rng.randf_range(-100, 100), rng.randf_range(-100, 100))
			if enemy._is_touching_player() != reference_contact(enemy, player): mismatches += 1
			cases += 1
	check(mismatches == 0, "broad phase matches exact legacy shape queries in %d rotated/scaled/offset cases" % cases)
	body.disabled = true
	check(not enemy._is_touching_player(), "disabled collision still disables contact")
	body.disabled = false
	body.scale = Vector2.ONE
	body.rotation = 0
	target.scale = Vector2.ONE
	target.rotation = 0


func test_status_visual(enemy: EnemyController) -> void:
	var visual = enemy.get_node("EnemyStatusVisual")
	visual.set_process(false)
	visual._process(0.1)
	var frame: int = visual._draw_frame
	visual._process(1.0)
	check(visual._draw_frame == frame and visual._draw_status_mask == 0, "empty status geometry is not rebuilt")
	enemy.apply_wet(2.0)
	visual._process(0.01)
	check(visual._draw_status_mask != 0, "new status invalidates immediately")
	frame = visual._draw_frame
	var elapsed: float = visual._elapsed
	visual._process(0.2)
	check(visual._draw_frame == frame and visual._elapsed > elapsed, "static status geometry stays cached while the visual clock advances")
	enemy.clear_wet()
	visual._process(0.01)
	check(visual._draw_status_mask == 0, "status removal clears cached geometry")


func test_light_geometry() -> void:
	var light := LIGHT.new()
	host.add_child(light)
	light.set_process(false)
	var mesh: ArrayMesh = light._get_circle_mesh(Color(0.4, 0.6, 1))
	check(light._get_circle_mesh(Color(0.4, 0.6, 1)) == mesh, "light color reuses cached four-disk mesh")
	check(mesh.get_surface_count() == 1 and mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 4 * 64 * 3, "one ordered surface holds four light disks")
	light.add_light(Vector2.ZERO, Color.WHITE, 2.0, 80.0, 1.0)
	light._process(0.25)
	check(is_equal_approx(light._remainings[0], 0.75), "light lifetime unchanged")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	light._process(0.25)
	check(is_equal_approx(light._remainings[0], 0.75), "light pause unchanged")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	light._process(1.0)
	check(light._order.is_empty(), "light expires without stale geometry")
	for index in 40: light._get_circle_mesh(Color(float(index) / 40, 0.2, 0.5))
	check(light._circle_mesh_cache.size() <= 32, "arbitrary light tint cache stays bounded")
