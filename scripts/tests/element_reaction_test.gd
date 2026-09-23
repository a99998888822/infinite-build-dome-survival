extends "res://scripts/tests/pixel_combat_effect_test.gd"

const R = preload("res://scripts/effects/element_reaction_resolver.gd")
const PARAMS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const CUE = preload("res://scripts/effects/element_reaction_visual.gd")


func element(enemy: EnemyController, id: String) -> Dictionary:
	return R.apply_element(enemy, id, {"parent": host, "hit_position": enemy.global_position,
		"original_damage": 100, "source_id": "reaction_test", "damage_event": event,
		"detonate_burning": 1.0})


func equip(ids: Array) -> void:
	weapon._attached_item_instances.clear()
	for id in ids:
		var item: Dictionary = DataRegistry.get_record("augmentations", id).duplicate(true)
		item["item_instance_id"] = "test_" + str(id)
		weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()


func count_reflections() -> int:
	var count := 0
	for child in host.get_children():
		if child is LightReflectionEffect: count += 1
	return count


func _run() -> void:
	await setup([Vector2.ZERO])
	for ids in [["scroll_water", "scroll_black_hole"], ["scroll_black_hole", "scroll_water"]]:
		equip(ids)
		var water := PARAMS.build_weapon_context(weapon, "water")
		var hole := PARAMS.build_weapon_context(weapon, "black_hole")
		check(water.get_resolved_parameter("radius", 0) == 132 and is_equal_approx(water.get_resolved_parameter("duration", 0), 0.52), "water parameters isolated in " + str(ids))
		check(hole.get_resolved_parameter("radius", 0) == 100 and is_equal_approx(hole.get_resolved_parameter("duration", 0), 0.85), "black hole parameters isolated in " + str(ids))
	weapon._attached_item_instances[0]["rolled_parameters"] = {"radius": 99.0}
	var water := PARAMS.build_weapon_context(weapon, "water")
	check(water.get_resolved_parameter("radius", 0) == 132, "foreign rolled parameter does not leak")
	weapon.effect_modifiers.append({"effect_id": "*", "channel": "duration", "operation": "multiply", "value": 2.0})
	water = PARAMS.build_weapon_context(weapon, "water")
	check(is_equal_approx(water.get_resolved_parameter("duration", 0), 1.04), "explicit global modifier still works")

	for pair in [["water", "fire"], ["fire", "water"]]:
		await setup([Vector2.ZERO])
		element(enemies[0], pair[0])
		element(enemies[0], pair[1])
		check(enemies[0].current_hp == 9850 and not enemies[0].has_status("wet") and not enemies[0].has_status("burning"), "steam both orders " + str(pair))
	for pair in [["water", "ice"], ["ice", "water"]]:
		await setup([Vector2.ZERO])
		element(enemies[0], pair[0])
		element(enemies[0], pair[1])
		check(enemies[0].has_status("frozen") and not enemies[0].has_status("wet"), "freeze both orders " + str(pair))
		enemies[0]._process_freeze(1.1)
		check(enemies[0].has_status("wet") and not enemies[0].has_status("frozen") and not enemies[0].has_status("slowed"), "thaw restores wet without immediate refreeze")
	for pair in [["dark", "fire"], ["fire", "dark"]]:
		await setup([Vector2.ZERO])
		element(enemies[0], pair[0])
		element(enemies[0], pair[1])
		check(enemies[0].has_status("dark_flame") and enemies[0]._burning_remaining == 10.0, "dark flame both orders " + str(pair))
		element(enemies[0], "water")
		check(enemies[0].has_status("dark_flame") and enemies[0].current_hp == 9850, "water steams but preserves dark flame")
	for pair in [["light", "fire"], ["fire", "light"]]:
		await setup([Vector2.ZERO])
		element(enemies[0], pair[0])
		element(enemies[0], pair[1])
		enemies[0]._process_burning(0.5)
		check(enemies[0].current_hp == 9980 and enemies[0].has_status("light"), "holy tick is 2x and preserves light " + str(pair))
		enemies[0].take_damage(10)
		check(enemies[0].current_hp == 9960, "holy does not remove the separate light bonus for direct hits")
	for pair in [["dark", "light"], ["light", "dark"]]:
		await setup([Vector2.ZERO])
		element(enemies[0], pair[0])
		element(enemies[0], pair[1])
		check(not enemies[0].has_status("light") and not enemies[0].has_status("dark"), "opposite light/dark cancel " + str(pair))
		check(get_tree().get_nodes_in_group("element_reaction_cues").any(func(cue): return cue.kind == "cancel"), "cancellation has visible cue")

	await setup([Vector2.ZERO])
	equip(["scroll_water", "scroll_ice"])
	CombatEffectWorld.trigger_weapon_impact(host, weapon, event, Vector2.ZERO, Vector2.RIGHT, enemies[0])
	check(enemies[0].has_status("frozen"), "same impact water and ice freeze synchronously")
	await setup([Vector2.ZERO, Vector2(85, 0)])
	IceFieldEffect.spawn(host, Vector2.ZERO, weapon, event)
	var ice: IceFieldEffect
	for child in host.get_children():
		if child is IceFieldEffect: ice = child
	ice.set_process(false)
	var prior := enemies[0].current_hp
	check(enemies[1].current_hp == 10000, "outer ice target initially outside")
	ice.expand_from_wind(1.35)
	check(enemies[1].current_hp == 9965 and enemies[1].has_status("slowed"), "wind ice expansion affects new coverage")
	check(enemies[0].current_hp == prior, "wind ice does not double hit old coverage")
	ice.expand_from_wind(1.35)
	check(enemies[1].current_hp == 9965, "repeated wind cannot rehit previous ice victim")
	ice._radius = 180
	ice.expand_from_wind(1.35)
	check(ice._radius >= 180, "wind cannot shrink a large ice field")
	await setup([Vector2.ZERO, Vector2(160, 0)])
	IceFieldEffect.spawn(host, Vector2.ZERO, weapon, event)
	enemies[1].position = Vector2(35, 0)
	await frames()
	for child in host.get_children():
		if child is IceFieldEffect: child._process(0.13)
	check(enemies[1].has_status("slowed"), "entering a live ice field applies its first contact")

	await setup([Vector2.ZERO, Vector2(55, 0)])
	element(enemies[0], "water")
	element(enemies[1], "fire")
	CombatEffectWorld._apply_wind(host, enemies[0], weapon, event, Vector2.ZERO, Vector2.RIGHT, "")
	check(not enemies[1].has_status("burning") and not enemies[1].has_status("wet") and enemies[1].current_hp == 9850, "wind water propagation triggers steam")
	await setup([Vector2.ZERO, Vector2(55, 0)])
	weapon._attached_item_instances = [{"effect_ids": ["wind"], "effect_parameters": {"wet_propagation_limit": 0}}]
	element(enemies[0], "water")
	CombatEffectWorld._apply_wind(host, enemies[0], weapon, event, Vector2.ZERO, Vector2.RIGHT, "")
	check(not enemies[1].has_status("wet"), "zero wet propagation limit spreads to nobody")

	for ground in [false, true]:
		await setup([Vector2.ZERO])
		element(enemies[0], "water")
		if ground: LightningParticleEffect.spawn_ground_strike(host, Vector2.ZERO, weapon, event)
		else: LightningParticleEffect.spawn(host, Vector2.ZERO, enemies[0], weapon, event, Vector2.RIGHT)
		await frames()
		check(enemies[0].current_hp == (9856 if ground else 9890) and not enemies[0].has_status("wet"), "wet electric is same-target extra hit ground=" + str(ground))
	await setup([Vector2.ZERO])
	element(enemies[0], "fire")
	LightningParticleEffect.spawn(host, Vector2.ZERO, enemies[0], weapon, event, Vector2.RIGHT)
	await frames()
	check(enemies[0].current_hp == 9765 and not enemies[0].has_status("burning"), "electric fire detonates for 55 plus 180")
	await setup([Vector2.ZERO, Vector2(50, 0)])
	element(enemies[0], "fire")
	enemies[0].current_hp = 1
	LightningParticleEffect.spawn_ground_strike(host, Vector2.ZERO, weapon, event)
	await frames()
	check(enemies[1].current_hp == 9820, "lethal electric spark still detonates burning into nearby targets")
	await setup([Vector2.ZERO, Vector2(55, 0)])
	var fire_context := PARAMS.build_weapon_context(weapon, "fire", {"original_damage": 100.0, "burn_duration": 3.0})
	var patch := FirePatch.spawn(host, Vector2.ZERO, fire_context)
	patch.set_physics_process(false)
	await frames()
	patch._apply_tick_damage()
	check(not enemies[1].has_status("burning"), "fire target starts beyond field")
	patch.expand_from_wind(1.35)
	await frames()
	patch._apply_tick_damage()
	check(enemies[1].has_status("burning"), "wind fire expansion affects newly covered target")
	patch.expand_from_wind(2.0)
	var expanded_radius := patch._radius
	patch._absorb_seed(Vector2.ZERO, fire_context, 1.0)
	check(patch._radius >= expanded_radius, "new fire seed does not shrink wind-expanded fire field")

	for mastery in [false, true]:
		await setup([Vector2.ZERO, Vector2(30, 0), Vector2(60, 0), Vector2(90, 0), Vector2(120, 0)])
		equip(["scroll_lightning", "wizard_scroll_chain_mastery"] if mastery else ["scroll_lightning"])
		LightningParticleEffect.spawn(host, Vector2.ZERO, enemies[0], weapon, event, Vector2.RIGHT)
		await get_tree().create_timer(0.65).timeout
		var damaged := 0
		var correct_damage := true
		for enemy in enemies:
			if enemy.current_hp < 10000:
				damaged += 1
				correct_damage = correct_damage and enemy.current_hp == (9934 if mastery else 9945)
		check(damaged == (3 if mastery else 2) and correct_damage, "chain target count and damage mastery=" + str(mastery))

	await setup([Vector2.ZERO, Vector2(35, 0)])
	LightningParticleEffect.spawn(host, Vector2.ZERO, enemies[0], weapon, event, Vector2.RIGHT)
	await frames()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var visual := enemies[0]._lightning_visual
	var remaining: float = visual.get("_remaining")
	var ui_state := {"called": false}
	EffectScheduler.schedule(0.02, func(): ui_state.called = true, self, true)
	await get_tree().create_timer(0.25).timeout
	check(enemies[1].current_hp == 10000, "paused chain does not hit second victim")
	check(is_equal_approx(remaining, visual.get("_remaining")), "paused stun cue retains lifetime")
	check(ui_state.called, "UI opt-in scheduler continues during battle pause")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await get_tree().create_timer(0.25).timeout
	check(enemies[1].current_hp == 9945, "chain resumes exactly once")

	for order in [["light", "water", "ice"], ["water", "ice", "light"], ["ice", "light", "water"]]:
		await setup([Vector2.ZERO])
		for id in order: element(enemies[0], id)
		check(count_reflections() == 1, "reflection all contact orders " + str(order))
		element(enemies[0], "ice")
		check(count_reflections() == 1, "refreshing frozen state does not duplicate reflection")
	await setup([Vector2.ZERO])
	equip(["scroll_light_sword"])
	CombatEffectWorld.trigger_weapon_impact(host, weapon, event, Vector2.ZERO, Vector2.RIGHT, enemies[0])
	check(not enemies[0].has_status("light"), "sword does not apply light before landing")
	for child in host.get_children():
		if child is LightSwordEffect:
			child.set_process(false)
			child._process(0.73)
	check(enemies[0].has_status("light"), "sword landing leaves light for the next attack")

	var positions: Array = []
	for index in range(100): positions.append(Vector2(index % 10 * 3, index / 10 * 3))
	await setup(positions)
	IceFieldEffect.spawn(host, Vector2.ZERO, weapon, event)
	check(enemies.all(func(enemy): return enemy.has_status("slowed")), "dense ice query covers more than 64 enemies")
	var hp := enemies[0].current_hp
	for index in range(120): CUE.spawn(host, "cancel", Vector2(index * 10, 0))
	element(enemies[0], "water")
	check(enemies[0].has_status("frozen") and enemies[0].current_hp == hp, "visual saturation does not skip reaction logic")
	check(get_tree().get_nodes_in_group("element_reaction_cues").size() <= CUE.MAX_CUES, "reaction cue budget is bounded")
	host.queue_free()
	await frames()
	print("REACTION_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
