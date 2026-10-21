extends "res://scripts/tests/weapon_contact_regression_test.gd"

const ORIGINAL = preload("res://scripts/tests/fixtures/continuous_contact_original_footprint.gd")


func original_nearest(radius: float) -> EnemyController:
	var origin := weapon.get_attack_origin()
	var shape: Shape2D = ORIGINAL.targeting_shape(weapon)
	if not is_equal_approx(radius, weapon.get_attack_range()):
		shape = CircleShape2D.new()
		shape.radius = radius
	var best: EnemyController
	var distance := INF
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_alive(): continue
		if enemy is EliteRusher and enemy.skill_state == "spawn": continue
		if not ORIGINAL.body_overlaps(shape, Transform2D(0, origin), enemy): continue
		var next := origin.distance_squared_to(enemy.global_position)
		if weapon.is_copper_lamp() or weapon.is_meteor_flail() or weapon.is_camp_dagger():
			next = ORIGINAL.unproject(enemy.global_position - origin).length_squared()
		if next < distance and DirectedWeaponRuntime.clear_path(player, origin, enemy.global_position):
			best = enemy
			distance = next
	return best


func _run() -> void:
	CampProgression.begin_transient_session()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	for id in [BOW, PLASMA, GRENADE, TOME, COIN, LAMP, TENTACLE, HAMMER, DAGGER, SPEAR, FLAIL, DASH, CANNON, STAR]:
		await prepare(id, [Vector2.ZERO])
		var query := weapon.targeting_query
		var body := enemies[0].get_node("CollisionShape2D") as CollisionShape2D
		for area in [0.0, 100.0, -30.0]:
			total("area_size", area)
			total("damage_area_size", area)
			query.configure_targeting(weapon)
			var original := ORIGINAL.targeting_shape(weapon)
			check(original.get_rect().is_equal_approx(query.shape.get_rect()), "target geometry " + id + " " + str(area))
			var saved := query.shape
			query.configure_targeting(weapon)
			check(query.shape == saved, "reuse unchanged geometry " + id)
			for sample in 24:
				host.transform = Transform2D(rng.randf_range(-PI, PI), Vector2(1.2, 0.8), 0.1, Vector2(45, -27))
				enemies[0].position = Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500))
				body.position = Vector2(rng.randf_range(-220, 220), rng.randf_range(-220, 220))
				body.rotation = rng.randf_range(-PI, PI)
				body.scale = Vector2(rng.randf_range(0.3, 3.0), rng.randf_range(0.3, 3.0))
				var pose := Transform2D(0, weapon.get_attack_origin())
				query.place(pose)
				check(query.overlaps(enemies[0]) == ORIGINAL.body_overlaps(original, pose, enemies[0]), "transformed body contact " + id + " " + str(sample))
	await prepare(LAMP, [Vector2(90, 0), Vector2(-90, 0), Vector2(160, 10), Vector2(410, 0)])
	wall(Vector2(45, 0))
	await frames()
	for radius in [weapon.get_attack_range(), 50.0, 600.0]:
		check(DirectedWeaponRuntime.nearest(weapon, radius) == original_nearest(radius), "nearest respects walls, ties and radius override " + str(radius))
	var query := WeaponContactQuery.new()
	var body := enemies[0].get_node("CollisionShape2D") as CollisionShape2D
	for sample in 600:
		var direction := Vector2.from_angle(rng.randf_range(-PI, PI))
		var reach := rng.randf_range(20, 700)
		var degrees := rng.randf_range(15, 162)
		query.configure_lamp(direction, reach, degrees)
		query.place(Transform2D(0, Vector2(15, -30)))
		var original := ORIGINAL.lamp_shape(direction, reach, degrees)
		enemies[0].position = Vector2(rng.randf_range(-700, 700), rng.randf_range(-500, 500))
		body.position = Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300))
		body.rotation = rng.randf_range(-PI, PI)
		body.scale = Vector2(rng.randf_range(0.2, 4), rng.randf_range(0.2, 4))
		check(query.overlaps(enemies[0]) == ORIGINAL.body_overlaps(original, Transform2D(0, Vector2(15, -30)), enemies[0]), "lamp moving/rotating/scaled collider " + str(sample))
		var saved := query.shape
		query.configure_lamp(direction, reach, degrees)
		check(saved == query.shape, "lamp unchanged shape reuse " + str(sample))
	body.disabled = true
	check(not query.overlaps(enemies[0]), "disabled collider rejected immediately")
	body.disabled = false
	enemies[0].collision_layer = 0
	check(not query.overlaps(enemies[0]), "collision layer change rejected immediately")
	enemies[0].collision_layer = 2
	body.shape = CircleShape2D.new()
	body.shape.radius = 1000
	body.position = Vector2.ZERO
	query.configure_lamp(Vector2.RIGHT, 360, 60)
	query.place(Transform2D.IDENTITY)
	check(query.overlaps(enemies[0]) == ORIGINAL.body_overlaps(query.shape, Transform2D.IDENTITY, enemies[0]), "replacement body shape read immediately")
	enemies[0].alive = false
	check(not query.overlaps(enemies[0]), "dead target rejected immediately")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("CONTINUOUS_CONTACT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
