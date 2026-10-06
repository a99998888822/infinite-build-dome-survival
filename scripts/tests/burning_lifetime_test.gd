extends "res://scripts/tests/pixel_combat_effect_test.gd"
## Simulate elapsed combat time with no further weapon hits.

const PARAMS = preload("res://scripts/effects/effect_parameter_resolver.gd")


func _run() -> void:
	for kind in ["normal", "holy", "dark"]:
		await setup([Vector2.ZERO])
		var enemy := enemies[0]
		ElementReactionResolver.apply_element(enemy, "fire", {"original_damage": 100, "source_id": "lifetime"})
		if kind == "holy": enemy.apply_light()
		if kind == "dark": enemy.apply_blind()
		var duration := 10.0 if kind == "dark" else 3.0
		var visual := enemy.get_node("EnemyStatusVisual")
		var visible_while_active := true
		for step in int((duration + 1.0) * 60):
			enemy._physics_process(1.0 / 60.0)
			visual._process(1.0 / 60.0)
			if enemy.has_status("burning"):
				visible_while_active = visible_while_active and is_instance_valid(visual._flame_visual)
		check(visible_while_active, kind + " burn retains its flame until damage ends")
		check(not enemy.has_status("burning") and enemy._burn_sources.is_empty(), kind + " burn expires without new hits")
		check(not is_instance_valid(visual._flame_visual), kind + " expired burn removes its visual")
		var hp := enemy.current_hp
		for step in 1200: enemy._physics_process(1.0 / 60.0)
		check(enemy.current_hp == hp, kind + " burn deals no damage for 20 seconds after expiry")
		check(hp < 10000, kind + " burn dealt damage while active")

	await setup([Vector2.ZERO])
	var victim := enemies[0]
	victim.apply_burning(3, 10, "first")
	victim.apply_burning(3, 20, "second")
	victim._physics_process(0.5)
	ElementReactionResolver.apply_element(victim, "water", {"original_damage": 100})
	var cleansed_hp := victim.current_hp
	for step in 600: victim._physics_process(1.0 / 60.0)
	check(victim.current_hp == cleansed_hp and victim._burn_sources.is_empty(), "water extinguishes all burn sources without residual damage")

	await setup([Vector2.ZERO])
	victim = enemies[0]
	weapon._attached_item_instances[0]["effect_ids"] = ["fire"]
	var context := PARAMS.build_weapon_context(weapon, "fire", {"original_damage": 100, "patch_duration": 3, "burn_duration": 3})
	var patch := FirePatch.spawn(host, Vector2.ZERO, context)
	patch.set_physics_process(false)
	await frames()
	patch._apply_tick_damage()
	check(victim.has_status("burning"), "standing in a fire pool ignites the enemy")
	victim.position = Vector2(300, 0)
	await frames()
	await frames()
	check(patch.get_overlapping_bodies().is_empty(), "physics overlap list updates after leaving the pool")
	for step in 120:
		patch._physics_process(1.0 / 60.0)
		victim._physics_process(1.0 / 60.0)
	check(victim._burning_remaining < 1.1, "leaving the pool stops refreshing burn duration")
	patch._physics_process(1.1)
	check(patch.is_queued_for_deletion(), "unrefreshed fire pool expires after three seconds")
	await frames()
	for step in 120: victim._physics_process(1.0 / 60.0)
	var expired_hp := victim.current_hp
	for step in 1200: victim._physics_process(1.0 / 60.0)
	check(not victim.has_status("burning") and victim.current_hp == expired_hp, "leaving a pool ends both burning and damage")
	await _test_live_fire_tail()
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	print("BURNING_LIFETIME_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_live_fire_tail(effect_ids: Array = ["fire"], delayed_water_frame: int = -1) -> void:
	await setup([Vector2.ZERO])
	var victim := enemies[0]
	victim.set_physics_process(true)
	weapon._attached_item_instances.clear()
	for index in effect_ids.size():
		var attachment := DataRegistry.get_record("augmentations", "scroll_" + str(effect_ids[index])).duplicate(true)
		attachment["item_instance_id"] = "lifetime_%d" % index
		weapon._attached_item_instances.append(attachment)
	weapon._rebuild_attachment_effects()
	var state := {"hits": 0, "late_hits": 0, "frame": 0, "last_hit": -1}
	victim.damage_received.connect(func(_source: String, _damage: int):
		state.hits += 1
		state.last_hit = state.frame
		# Dark fire can start after the initial impact and lasts ten seconds.
		if state.frame > 720: state.late_hits += 1
	)
	CombatEffectWorld.trigger_weapon_impact(host, weapon, event, victim.global_position, Vector2.RIGHT, victim)
	for step in 1200:
		state.frame = step
		if step == 60: victim.position = Vector2(300, 0)
		if step == delayed_water_frame: WaterWaveEffect.spawn(host, victim.global_position, weapon, event)
		await get_tree().physics_frame
		if step == 120 and effect_ids == ["fire"] and delayed_water_frame < 0:
			check(victim.has_status("burning"), "real fire hit still burns briefly after leaving the pool")
	check(state.hits > 0 and state.late_hits == 0, "single real fire impact never emits damage events after twelve seconds")
	check(not victim.has_status("burning") and victim._burn_sources.is_empty(), "real fire impact clears all status and damage sources")
	check(get_tree().get_nodes_in_group("fire_patches").is_empty(), "real fire seeds leave no permanent fire pools")
	var visible_numbers := 0
	for child in host.get_children():
		if child is Label and child.visible: visible_numbers += 1
	check(visible_numbers == 0 and EnemyController.active_damage_numbers == 0, "damage numbers recycle completely after fire expires")
	print("LIVE_FIRE_TAIL effects=%s water_frame=%d hits=%d last_hit_frame=%d late_hits=%d visible_numbers=%d hp=%d" % [str(effect_ids), delayed_water_frame, state.hits, state.last_hit, state.late_hits, visible_numbers, victim.current_hp])
