extends "res://scripts/tests/enchantment_stacking_test.gd"
const REACTION = preload("res://scripts/effects/element_reaction_resolver.gd")

func _run() -> void:
	CampProgression.begin_transient_session()
	var result := {}
	await setup([Vector2.ZERO, Vector2(70, 0)])
	var body := enemies[0].get_node("CollisionShape2D") as CollisionShape2D
	var bounds: Rect2 = body.transform * body.shape.get_rect()
	result.body = {"kind": body.shape.get_class(), "bounds": str(bounds), "offset": str(body.position)}
	IceFieldEffect.spawn(host, Vector2.ZERO, weapon, event)
	result.ice_at_70 = enemies[1].current_hp
	await setup([Vector2.ZERO, Vector2(50, 0), Vector2(80, 0)])
	REACTION.apply_element(enemies[0], "fire", {"parent": host, "original_damage": 100, "damage_event": event})
	enemies[0].current_hp = 1
	LightningParticleEffect.spawn_ground_strike(host, Vector2.ZERO, weapon, event)
	await frames()
	result.lethal_spark_hp = [enemies[0].current_hp, enemies[1].current_hp, enemies[2].current_hp]
	await frames()
	result.lethal_spark_settled_hp = [enemies[0].current_hp, enemies[1].current_hp, enemies[2].current_hp]
	await setup([Vector2.ZERO, Vector2(55, 0)])
	var context := PARAMS.build_weapon_context(weapon, "fire", {"original_damage": 100.0, "burn_duration": 3.0})
	var patch := FirePatch.spawn(host, Vector2.ZERO, context)
	patch.set_physics_process(false)
	await frames()
	patch._apply_tick_damage()
	result.fire_at_55 = {"radius": patch._radius, "burning": enemies[1].has_status("burning")}
	await fixture(BOW, [Vector2(15.5, 0)], ["scroll_domain", "scroll_wind"])
	WindBladeEffect.spawn(host, Vector2.ZERO, Vector2.RIGHT, 480, 0.46, weapon, weapon.calculate_damage_events()[0], 0, Callable(), str(weapon.get_effect_instances("wind")[0].item_instance_id))
	for child in host.get_children():
		if child is WindBladeEffect:
			result.wind = {"radius": child._hit_radius, "base_weapon_radius": weapon.weapon_data.hit_radius, "area_size": weapon.get_stat("area_size"), "area_scale": child._area_scale, "speed": child._speed, "lifetime": child._lifetime}
	FileAccess.open("res://artifacts/reports/reaction_failure_audit.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("REACTION_FAILURE_AUDIT ", JSON.stringify(result))
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	get_tree().quit()
