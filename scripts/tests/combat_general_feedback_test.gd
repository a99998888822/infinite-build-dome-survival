extends "res://scripts/tests/pixel_combat_effect_test.gd"
## Spatial/temporal grouping, real hitstop, and restoration on lifecycle changes.
var events: Array[Dictionary] = []

class ClockProbe extends Node:
	var updates := 0
	var physics_updates := 0
	func _process(_delta: float) -> void: updates += 1
	func _physics_process(_delta: float) -> void: physics_updates += 1


func settle_damage() -> void:
	var deadline := Time.get_ticks_msec() + 1000
	while (not CombatHitFeedback._batches.is_empty() or CombatHitFeedback._owns_pause) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(CombatHitFeedback._batches.is_empty(), "physics batch closes before timeout")


func active_seconds(seconds: float) -> void:
	var until := CombatHitFeedback._combat_clock + seconds
	while CombatHitFeedback._combat_clock < until: await get_tree().process_frame


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CampProgression.begin_transient_session()
	var positions: Array = []
	for index in 24: positions.append(Vector2(index * 5, 0))
	await setup(positions)
	host.process_mode = Node.PROCESS_MODE_PAUSABLE
	var world_layer := CanvasLayer.new()
	world_layer.offset = Vector2(7, 11)
	add_child(world_layer)
	var sky_layer := CanvasLayer.new()
	sky_layer.offset = Vector2(-2, 4)
	add_child(sky_layer)
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	var probe := ClockProbe.new()
	host.add_child(probe)
	CombatHitFeedback.bind_battle(get_viewport(), [world_layer, sky_layer])
	CombatHitFeedback.feedback_started.connect(func(tier: int, count: int):
		events.append({"tier": tier, "count": count, "paused": get_tree().paused, "offset": CombatHitFeedback.screen_offset}))
	for count in [1, 2, 3, 5, 6, 11, 12, 18]:
		CombatHitFeedback.clear()
		events.clear()
		for index in count: enemies[index].take_attack_damage(1, event)
		if count == 1:
			var visual := enemies[0]._hit_visual
			var displacement := enemies[0].sprite.global_transform.basis_xform(visual.applied_offset)
			check(displacement.is_equal_approx(Vector2(5,-2)), "body shake is one third of 14 pixels, rounded to whole screen pixels")
		await settle_damage()
		var expected := 3 if count >= 12 else (2 if count >= 6 else (1 if count >= 3 else 0))
		check(CombatHitFeedback.last_local_count == count, "%d unique nearby damaged enemies counted" % count)
		check(events.size() == (0 if expected == 0 else 1), "%d contacts emit one threshold at most" % count)
		if expected > 0 and not events.is_empty():
			check(events[0].tier == expected and events[0].paused, "%d contacts choose correct shake and fixed hitstop" % count)
			check(events[0].offset.x == [0, 1, 2, 6][expected], "%d contacts use reduced amplitude" % count)
		check(hud_layer.offset == Vector2.ZERO, "HUD remains stable")
		CombatHitFeedback.clear()
		check(world_layer.offset == Vector2(7, 11) and sky_layer.offset == Vector2(-2, 4), "presentation layers return to their original offsets")
	# Neither repeated hits nor distant pockets inflate the local count.
	for scenario in ["duplicate", "scattered", "two_pockets", "chain"]:
		events.clear()
		CombatHitFeedback.clear()
		for index in 12:
			var enemy := enemies[0] if scenario == "duplicate" else enemies[index]
			match scenario:
				"scattered": enemy.position = Vector2(index * 1000, 0)
				"two_pockets": enemy.position = Vector2((index / 6) * 1000 + (index % 6) * 10, 0)
				"chain": enemy.position = Vector2(index * 200, 0)
			enemy.take_attack_damage(1, event)
		await settle_damage()
		var expected := 6 if scenario == "two_pockets" else (3 if scenario == "chain" else 1)
		check(CombatHitFeedback.last_local_count == expected, scenario + " stays local and deduplicated")
	CombatHitFeedback.clear()
	events.clear()
	for index in 2:
		enemies[index].position = Vector2(index * 10, 0)
		enemies[index].take_attack_damage(1, event)
	await settle_damage()
	for index in 2: enemies[index].take_attack_damage(1, event)
	await settle_damage()
	check(events.is_empty(), "repeat hits on the same two targets across frames do not inflate count")
	# A single attack reaches milestones over time; nine adds no extra pause.
	CombatHitFeedback.clear()
	events.clear()
	for index in 24: enemies[index].position = Vector2(index * 5, 0)
	for wave in 6:
		for index in range(wave * 3, wave * 3 + 3): enemies[index].take_attack_damage(1, event)
		await settle_damage()
		await active_seconds(0.10)
	check(events.map(func(row: Dictionary): return row.count) == [3, 6, 12, 15, 18], "one attack re-triggers at 3, 6, 12, 15, 18 across frames")
	check(events.map(func(row: Dictionary): return row.tier) == [1, 2, 3, 3, 3], "later milestones repeat the reduced highest tier")
	check(CombatHitFeedback.last_local_count == 18, "chain count no longer caps at twelve")
	var same_attack := event.duplicate_event()
	check(DamageEvent.feedback_attack_id(same_attack.attack_context) == DamageEvent.feedback_attack_id(event.attack_context), "split/duplicate events share the attack identity")
	# A gap in active simulation resets the combo, while hitstop consumes no gap.
	CombatHitFeedback.clear()
	events.clear()
	for index in 2: enemies[index].take_attack_damage(1, event)
	await settle_damage()
	await active_seconds(0.22)
	for index in range(2, 4): enemies[index].take_attack_damage(1, event)
	await settle_damage()
	check(events.is_empty() and CombatHitFeedback.last_local_count == 2, "a gap over 0.2 active seconds starts a new chain")
	CombatHitFeedback.clear()
	events.clear()
	var other_attack := DamageEvent.create({"damage": 1, "source_weapon_id": "second_cast"})
	for index in 2: enemies[index].take_attack_damage(1, event)
	for index in range(2, 4): enemies[index].take_attack_damage(1, other_attack)
	await settle_damage()
	check(events.is_empty(), "different casts never add two plus two together")
	enemies[4].take_attack_damage(1, other_attack)
	await settle_damage()
	check(events.size() == 1 and events[0].count == 3, "second cast advances only its own local chain")
	CombatHitFeedback.clear()
	events.clear()
	for index in 18:
		enemies[index].apply_burning(3, 1, "burn")
		enemies[index]._process_burning(0.5)
		enemies[index].clear_burning()
	check(CombatHitFeedback._batches.is_empty() and events.is_empty(), "burn ticks only shake enemy bodies, never accumulate screen hitstop")
	# Steam keeps its explicit damage attribution while sharing the weapon chain.
	CombatHitFeedback.clear()
	events.clear()
	var sources: Array[String] = []
	var received := func(source: String, _damage: int): sources.append(source)
	enemies[2].damage_received.connect(received)
	for index in 2: enemies[index].take_attack_damage(1, event)
	await settle_damage()
	ElementReactionResolver._deal_reaction_damage(enemies[2], {"damage_event": event}, 1, "reaction_source", false, Vector2.ZERO, [])
	await settle_damage()
	check(sources == ["reaction_source"] and event.source_weapon_id == "pixel_test", "reaction preserves its damage source without mutating the weapon event")
	check(events.size() == 1 and events[0].count == 3, "reaction and native contacts share the attack chain")
	enemies[2].damage_received.disconnect(received)
	CombatHitFeedback.clear()
	enemies[0].take_damage(0)
	enemies[0].take_damage(-1)
	check(CombatHitFeedback._batches.is_empty(), "rejected damage never counts")
	check(CombatHitFeedback.local_hit_count([Vector2.ZERO, Vector2(240, 0), Vector2(-240, 0)]) == 3, "radius boundary is inclusive")
	check(CombatHitFeedback.local_hit_count([Vector2.ZERO, Vector2(241, 0), Vector2(-241, 0)]) == 1, "outside radius is excluded")
	# Capture the pause before awaiting. Both idle and physics must actually stop.
	for tier in [1, 2, 3]:
		CombatHitFeedback.clear()
		var before := probe.updates
		var physics_before := probe.physics_updates
		var started := Time.get_ticks_usec()
		CombatHitFeedback._play([0, 3, 6, 12][tier])
		check(get_tree().paused, "hitstop pauses the simulation immediately")
		await get_tree().create_timer(0.015, true, false, true).timeout
		check(probe.updates == before and probe.physics_updates == physics_before, "idle and physics clocks freeze during hitstop")
		while get_tree().paused: await get_tree().process_frame
		var duration := float(Time.get_ticks_usec() - started) / 1000000.0
		check(duration >= CombatHitFeedback.HITSTOP_SECONDS[tier] and duration < 0.18, "hitstop restores on wall time: %.4f seconds" % duration)
		await frames()
		check(probe.updates > before and probe.physics_updates > physics_before, "simulation resumes after hitstop")
	CombatHitFeedback.clear()
	get_tree().paused = true
	CombatHitFeedback._play(12)
	CombatHitFeedback.clear()
	check(get_tree().paused, "feedback never releases a preexisting scene pause")
	get_tree().paused = false
	CombatHitFeedback._play(12)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not get_tree().paused and bool(GameGlobal.get_runtime_flag("battle_runtime_paused")), "menu cancels hitstop and keeps its own pause flag")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var player := load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.set_physics_process(false)
	player.active_controls = true
	player._held_move_keys[KEY_D] = true
	var controller := ActiveCombatController.new()
	host.add_child(controller)
	controller.set_process(false)
	controller.right_held = true
	var joystick := MobileJoystick.new()
	host.add_child(joystick)
	joystick.set_mobile_input_enabled(true)
	joystick._active_touch_index = 2
	joystick._direction = Vector2.RIGHT
	CombatHitFeedback.set_input_receivers([player, controller, joystick])
	CombatHitFeedback._play(12)
	var key := InputEventKey.new()
	key.keycode = KEY_D
	CombatHitFeedback._input(key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	CombatHitFeedback._input(mouse)
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	CombatHitFeedback._input(touch)
	check(not player._held_move_keys[KEY_D] and not controller.right_held and joystick._direction == Vector2.ZERO, "keyboard, mouse and touch releases survive hitstop")
	CombatHitFeedback.clear()
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var presentation := SubViewportContainer.new()
	var original_material := CanvasItemMaterial.new()
	presentation.material = original_material
	add_child(presentation)
	CombatHitFeedback.bind_battle(viewport, [world_layer], presentation)
	CombatHitFeedback._play(12)
	check(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "contact image freezes GPU rendering after its first draw")
	check(presentation.material != original_material and presentation.position == Vector2.ZERO, "screen shader shifts presentation without changing layout or aim")
	remove_child(presentation)
	CombatHitFeedback.unbind_battle()
	check(not get_tree().paused and viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and world_layer.offset == Vector2(7, 11), "battle teardown restores pause, rendering and layer transform")
	check(presentation.material == original_material, "detached presentation restores its original material without a viewport")
	presentation.free()
	CombatHitFeedback.bind_battle(get_viewport(), [world_layer])
	for index in 3:
		enemies[index].position = Vector2(index * 10, 0)
		enemies[index].current_hp = 1
		enemies[index].take_attack_damage(10, event)
	await settle_damage()
	check(CombatHitFeedback.last_local_count == 3, "lethal contacts count using position snapshots")
	CombatHitFeedback.unbind_battle()
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("GENERAL_HIT_FEEDBACK checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
