extends "res://scripts/tests/active_attack_revision_test.gd"
## Real contacts and screen bearings for production ground projection.

func _run() -> void:
	CampProgression.begin_transient_session()
	var directions := [Vector2.RIGHT, Vector2.UP, Vector2(-0.6, 0.8)]
	for direction: Vector2 in directions:
		var transform := AttackFootprint.ground_transform(direction)
		check((transform * Vector2.RIGHT).normalized().is_equal_approx(direction), "projected fan tracks screen pointer " + str(direction))
		var round_trip := true
		for i in 32:
			var edge := transform * (Vector2.from_angle(TAU * i / 32) * 180)
			round_trip = round_trip and is_equal_approx(AttackFootprint.unproject(edge).length(), 180)
		check(round_trip and transform.determinant() > 0, "ground ellipse keeps world axes and handedness " + str(direction))
		await fixture("weapon_copper_lamp", [])
		var reach := weapon.get_attack_range()
		var inside := transform * (Vector2(16, 0) + Vector2.from_angle(deg_to_rad(29)) * 70)
		var outside := transform * (Vector2(16, 0) + Vector2.from_angle(deg_to_rad(31)) * 70)
		check(AttackFootprint.in_lamp_cone(inside, direction, reach, 60) and not AttackFootprint.in_lamp_cone(outside, direction, reach, 60), "lamp projected cone boundary " + str(direction))
		await fixture("weapon_meteor_flail", [transform * Vector2(40, 0), transform * Vector2(136, 0), transform * (Vector2.from_angle(deg_to_rad(67)) * 90)])
		var flail := MeteorFlail.new()
		host.add_child(flail)
		flail.initialize(weapon, direction)
		flail.set_physics_process(false)
		var base_damage := weapon.calculate_damage_events()[0].damage
		flail._physics_process(0.72 * flail.time_scale)
		check(enemies[0].current_hp == 10000 - base_damage and enemies[1].current_hp == 10000 - roundi(base_damage * 1.5) and enemies[2].current_hp == 10000, "real projected flail inner/outer damage and safe angular edge " + str(direction) + " hp=" + str(enemies.map(func(enemy): return enemy.current_hp)))
		await fixture("weapon_camp_dagger", [transform * Vector2(55, 0), transform * Vector2(-55, 0), transform * Vector2(0, 120)])
		var dagger := CampDagger.new()
		host.add_child(dagger)
		dagger.initialize(weapon, direction)
		dagger.set_physics_process(false)
		dagger._physics_process(0.30)
		check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000 and enemies[2].current_hp == 10000, "real projected dagger sweep follows pointer and excludes rear " + str(direction))
		await fixture("weapon_hand_cannon", [])
		weapon.use_active_range_rules = true
		var runtime := MobilityWeaponRuntime.new()
		host.add_child(runtime)
		runtime.initialize_replay(weapon, Vector2.ZERO, direction)
		runtime.set_physics_process(false)
		var endpoints_ok := true
		var duration_ok := true
		var angles := weapon.get_projectile_angles()
		var index := 0
		for child in runtime.get_children():
			if child is CannonPellet:
				child.set_physics_process(false)
				var endpoint: Vector2 = child.direction * child.remaining_distance
				var expected := transform * (Vector2.from_angle(deg_to_rad(angles[index])) * weapon.get_attack_range())
				endpoints_ok = endpoints_ok and endpoint.distance_to(expected) < 0.001
				duration_ok = duration_ok and is_equal_approx(child.remaining_distance / child.speed, weapon.get_attack_range() / weapon.get_projectile_speed())
				index += 1
		check(endpoints_ok and index == angles.size(), "all cannon endpoints match projected indicator " + str(direction))
		check(duration_ok and is_equal_approx(weapon.get_mobility_landing(direction * 500).length(), 96), "cannon flight duration and recoil distance preserved " + str(direction))
	await fixture("weapon_star_tome", [])
	var radius := weapon.get_hit_radius()
	await fixture("weapon_star_tome", [Vector2(radius * 0.6, 0), Vector2(0, radius * 0.45), Vector2(0, radius * 0.95 + 12)])
	var old_circle := CircleShape2D.new()
	old_circle.radius = radius
	var safe_body := enemies[2].get_node("CollisionShape2D") as CollisionShape2D
	check(old_circle.collide(Transform2D.IDENTITY, safe_body.shape, safe_body.global_transform) and not AttackFootprint.projected_disk(radius).collide(Transform2D.IDENTITY, safe_body.shape, safe_body.global_transform), "star safe fixture intersects old circle but not projected ellipse")
	var star := MobilityWeaponRuntime.new()
	host.add_child(star)
	star.initialize_replay(weapon, Vector2.ZERO, Vector2.RIGHT)
	star.set_physics_process(false)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp < 10000 and enemies[2].current_hp == 10000, "star impact uses projected collider and excludes old-circle-only body")
	await fixture("weapon_rentier_purse", [])
	var coin := CoinProjectile.new()
	host.add_child(coin)
	coin.initialize(weapon, weapon.calculate_damage_events()[0], Vector2.ZERO, Vector2.UP, {})
	coin.set_physics_process(false)
	check(is_equal_approx(coin.remaining_distance, weapon.get_attack_range()) and is_equal_approx(coin.speed, weapon.get_projectile_speed()), "normal purse distance and speed remain unchanged")
	await _wolf_boundaries(directions)
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("GROUND_INDICATOR_PROJECTION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _wolf_boundaries(directions: Array) -> void:
	await fixture("weapon_copper_lamp", [])
	var wolf := load("res://scenes/enemy/underworld_wolf.tscn").instantiate() as UnderworldWolf
	wolf.auto_initialize_on_ready = false
	host.add_child(wolf)
	wolf.initialize("enemy_underworld_wolf", player)
	wolf.set_physics_process(false)
	wolf.push_controller.set_physics_process(false)
	wolf.breath_origin = Vector2.ZERO
	var body := player.get_node("CollisionShape2D") as CollisionShape2D
	var body_offset := body.global_position - player.global_position
	for direction: Vector2 in directions:
		wolf.breath_direction = direction
		var transform := AttackFootprint.ground_transform(direction)
		for pair in [[Vector2(150, 0), true], [Vector2(290, 0), false], [Vector2(150, 140), false]]:
			player.global_position = transform * pair[0] - body_offset
			player.current_hp = int(player.get_stat("max_hp"))
			player.current_shield = 0
			player._invincibility_timer = 0
			wolf.breath_hits = 0
			var before := player.current_hp
			wolf.try_breath_pulse()
			check((player.current_hp < before) == pair[1], "wolf actual body against projected breath " + str(direction) + " " + str(pair[0]))
			check(wolf.breath_shape.points == wolf.projected_breath_polygon(), "wolf warning and pulse use identical polygon")
			wolf.push_controller.cancel()
	# Inside the old upward circle, fully outside the new short axis.
	wolf.breath_direction = Vector2.UP
	player.global_position = Vector2(0, -225) - body_offset
	player._invincibility_timer = 0
	wolf.breath_hits = 0
	var before := player.current_hp
	wolf.try_breath_pulse()
	check(player.current_hp == before, "wolf old-circle-only area is safe")
