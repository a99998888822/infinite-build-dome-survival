extends "res://scripts/tests/active_attack_revision_test.gd"


func _run() -> void:
	CampProgression.begin_transient_session()
	await _test_bonus_snapshots()
	for id in ["weapon_void_blade", "weapon_rentier_purse", "weapon_plasma_cannon", "weapon_earth_hammer", "weapon_nightwatch_spear", "weapon_mutant_tentacle"]:
		await fixture(id, [])
		weapon.use_active_range_rules = true
		var guide := WeaponAttackIndicator.new()
		host.add_child(guide)
		guide.configure(weapon, Vector2.RIGHT * 500)
		var before := guide.arrow_points(weapon.get_attack_range(), guide.get_arrow_width_parameter())
		var width := guide.get_arrow_width_parameter()
		check(before[0].y == before[1].y and before[-1].y == before[-2].y, "shaft boundaries are exact straight segments")
		check(is_equal_approx(before[-1].y - before[0].y, width * 0.62 * 2 * 0.8), "shaft is 80 percent of the old width")
		var base_range := weapon.get_attack_range()
		var base_radius := weapon.get_hit_radius()
		weapon.runtime_stats.damage_area_size = 100
		guide.configure(weapon, Vector2.RIGHT * 500)
		if weapon.is_mutant_tentacle():
			check(is_equal_approx(guide.get_arrow_width_parameter(), width * 1.5), "area-tagged tentacle guide applies half bonus")
			check(is_equal_approx(weapon.get_hit_radius(), base_radius * 1.5), "tentacle native width agrees")
		else:
			check(guide.arrow_points(weapon.get_attack_range(), guide.get_arrow_width_parameter()) == before, "area does not change non-area arrow geometry " + id)
			check(weapon.get_hit_radius() == base_radius, "area does not enlarge non-area native hit shape " + id)
		check(weapon.get_attack_range() == base_range, "area does not extend linear attack reach")
		if weapon.has_combat_tag("投射物"):
			check(weapon.get_projectile_visual_scale() == 1.5, "projectile sprite grows independently")
		weapon.runtime_stats.area_size = 100
		check(weapon.get_attack_range() == base_range * 1.5, "distance still extends each linear attack")

	await fixture("weapon_plasma_cannon", [Vector2(100, 0), Vector2(100, 80)])
	weapon.use_active_range_rules = true
	weapon.runtime_stats.damage_area_size = 100
	var orb := ProjectileInstance.new()
	host.add_child(orb)
	check(orb.initialize(weapon, weapon.calculate_damage_events()[0], "range_orb", Vector2(100, 0), Vector2.RIGHT, 240, null, 1), "real plasma runtime initializes")
	orb.set_physics_process(false)
	orb._plasma_visual.advance(0)
	check(orb._hit_shape.radius == 12 and orb._plasma_visual.core_radius == 18, "plasma visual gets half bonus but real contact radius stays fixed")
	orb._physics_process(0.01)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000, "larger orb only damages its fixed contact shape")

	await fixture("weapon_mutant_tentacle", [Vector2(90, 0)])
	weapon.use_active_range_rules = true
	var tentacle := MutantTentacle.new()
	host.add_child(tentacle)
	tentacle.initialize(weapon)
	tentacle.set_physics_process(false)
	tentacle.try_attack(Vector2.RIGHT)
	check(is_equal_approx(tentacle.motion_duration, 0.33) and is_equal_approx(tentacle.hit_time, 0.15), "tentacle action and contact retime together by 1.5")
	tentacle._physics_process(0.14)
	check(enemies[0].current_hp == 10000, "retimed tentacle does not hit before the new impact frame")
	tentacle._physics_process(0.02)
	check(enemies[0].current_hp < 10000 and tentacle.attacking, "retimed tentacle contacts during its animation")
	tentacle._physics_process(0.18)
	check(not tentacle.attacking, "retimed tentacle ends after 0.33 seconds")

	await fixture("weapon_copper_lamp", [Vector2(180, 0), Vector2(110, 110), Vector2(260, 0)])
	weapon.use_active_range_rules = true
	weapon.runtime_stats.damage_area_size = 100
	var lamp := CopperLamp.new()
	host.add_child(lamp)
	lamp.initialize(weapon)
	lamp.set_physics_process(false)
	lamp.manual_control = true
	lamp.manual_direction = Vector2.RIGHT
	lamp.externally_driven = true
	lamp.burst_active = true
	lamp._physics_process(0.01)
	check(weapon.get_lamp_cone_degrees() == 60 and weapon.get_attack_range() == 180, "lamp area bonus extends distance without changing angle")
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000 and enemies[2].current_hp == 10000, "longer flame hits forward but excludes wide and out-of-range targets")
	weapon.runtime_stats.area_size = 100
	check(weapon.get_attack_range() == 240, "dual fan bonuses add instead of multiplying")

	await fixture("weapon_meteor_flail", [Vector2(210, 0), Vector2(40, 100)])
	weapon.use_active_range_rules = true
	weapon.runtime_stats.damage_area_size = 100
	var flail := MeteorFlail.new()
	host.add_child(flail)
	flail.initialize(weapon, Vector2.RIGHT)
	flail.set_physics_process(false)
	check(flail.head_radius(flail.swings[0]) == 16, "flail head sprite radius stays fixed")
	flail._physics_process(0.60)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000, "area extends the native flail fan while keeping its angular edge")
	check(is_equal_approx(flail.sequence_duration(), 0.6), "range modifiers preserve the full 0.6 second swing")

	await fixture("weapon_camp_dagger", [Vector2(135, 0)])
	weapon.use_active_range_rules = true
	var body_scale := weapon.get_dagger_body_scale()
	weapon.runtime_stats.damage_area_size = 100
	var dagger := CampDagger.new()
	host.add_child(dagger)
	dagger.initialize(weapon, Vector2.RIGHT)
	dagger.configure_continuous_combo()
	dagger.set_physics_process(false)
	check(weapon.get_dagger_body_scale() == body_scale and weapon.get_dagger_outer_radius() == 150, "dagger body stays fixed while its outer reach gains fifty percent")
	dagger._physics_process(0.3)
	check(enemies[0].current_hp < 10000, "expanded dagger arc damages the distant real target")

	await fixture("weapon_iron_grenade_cannon", [])
	weapon.use_active_range_rules = true
	weapon.runtime_stats.damage_area_size = 100
	check(weapon.get_projectile_visual_scale() == 1.5 and weapon.get_grenade_blast_radius() == 96 and weapon.get_attack_range() == 200, "grenade body, blast and cast distance remain separate")
	await fixture("weapon_kunyu_ritual_tome", [])
	weapon.use_active_range_rules = true
	check(weapon.get_combat_tags() == ["范围", "法阵"], "tome carries exactly the user-specified ritual tags")
	var axes := weapon.get_domain_axes()
	weapon.runtime_stats.damage_area_size = 100
	check(weapon.get_domain_axes() == axes, "new ritual tag preserves the existing domain stat mapping")

	host.queue_free()
	await frames()
	for sound in AudioManager.get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("ACTIVE_RANGE_RULES checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_bonus_snapshots() -> void:
	var resolver := preload("res://scripts/effects/effect_parameter_resolver.gd")
	var scores := [0, 50, 100, 200]
	for id in ["weapon_nightwatch_spear", "weapon_iron_grenade_cannon", "weapon_copper_lamp"]:
		for index in scores.size():
			await fixture(id, [])
			weapon.use_active_range_rules = true
			var score: int = scores[index]
			weapon.runtime_stats.area_size = 0 if weapon.is_grenade() else score
			weapon.runtime_stats.damage_area_size = 0 if weapon.is_nightwatch_spear() else score
			var cast := weapon.make_cast_copy()
			check(cast.get_stat("area_size") == weapon.get_stat("area_size") and cast.get_stat("damage_area_size") == weapon.get_stat("damage_area_size"), "cast preserves raw stats instead of pre-halving them")
			var expected: float = [64, 80, 96, 128][index] if weapon.is_grenade() else [120, 180, 240, 360][index] if weapon.is_copper_lamp() else [220, 275, 330, 440][index]
			var dimension := cast.get_grenade_blast_radius() if weapon.is_grenade() else cast.get_attack_range()
			check(is_equal_approx(dimension, expected), "production matches approved four-tier preview " + id)
			var context := resolver.build_weapon_context(cast, "fire")
			var expected_area: float = 1.0 if weapon.is_nightwatch_spear() else [1.0, 1.25, 1.5, 2.0][index]
			check(is_equal_approx(context.get_resolved_parameter("damage_area_size_multiplier", 1), expected_area), "enchantment uses the same bonus efficiency")
			check(is_equal_approx(cast.calculate_damage_events()[0].damage_area_scale, expected_area), "element reaction snapshots share the same area multiplier")
			weapon.runtime_stats.area_size = 999
			weapon.runtime_stats.damage_area_size = 999
			var bounce := cast.make_bounce_copy(Vector2(30, 0))
			check(is_equal_approx(bounce.get_grenade_blast_radius() if cast.is_grenade() else bounce.get_attack_range(), expected), "live equipment changes and bounce copies never double-apply efficiency")
