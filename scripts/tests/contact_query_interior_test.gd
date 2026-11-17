extends Node2D
## Native Shape2D collision is the oracle for the interior confirmation shortcut.
var failures := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var enemy := EnemyController.new()
	enemy.auto_initialize_on_ready = false
	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	enemy.add_child(body)
	add_child(enemy)
	enemy.alive = true
	enemy.current_hp = 100000
	enemy.collision_layer = 2
	enemy.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	var weapon := WeaponInstance.new()
	weapon.weapon_id = "weapon_copper_lamp"
	weapon.weapon_data = DataRegistry.get_record("weapons", weapon.weapon_id).duplicate(true)
	var query := WeaponContactQuery.new()
	var shapes: Array[Shape2D] = [CircleShape2D.new(), CapsuleShape2D.new(), RectangleShape2D.new(), ConvexPolygonShape2D.new()]
	(shapes[0] as CircleShape2D).radius = 16
	(shapes[1] as CapsuleShape2D).radius = 12
	(shapes[1] as CapsuleShape2D).height = 60
	(shapes[2] as RectangleShape2D).size = Vector2(20, 60)
	# Deliberately offset convex geometry: its local origin is not a body point.
	(shapes[3] as ConvexPolygonShape2D).points = PackedVector2Array([Vector2(30, 0), Vector2(70, 0), Vector2(50, 25)])
	for kind in 3:
		for shape in shapes:
			body.shape = shape
			for sample in 800:
				var pose := Transform2D(rng.randf_range(-PI, PI), Vector2(rng.randf_range(0.4, 2), rng.randf_range(0.4, 2)), 0.1, Vector2(20, -30))
				if kind == 0:
					query.configure_lamp(Vector2.from_angle(rng.randf_range(-PI, PI)), rng.randf_range(20, 900), rng.randf_range(15, 170))
				else:
					weapon.weapon_id = "weapon_copper_lamp" if kind == 1 else "weapon_void_blade"
					query.configure_targeting(weapon)
				query.place(pose)
				enemy.transform = Transform2D(rng.randf_range(-PI, PI), Vector2(rng.randf_range(0.3, 3), rng.randf_range(0.3, 3)), 0.2, Vector2(rng.randf_range(-950, 950), rng.randf_range(-650, 650)))
				body.position = Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
				var expected := query.shape.collide(pose, body.shape, body.global_transform)
				_check(query.overlaps(enemy) == expected, "interior/native mismatch kind=%d sample=%d" % [kind, sample])
	body.disabled = true
	_check(not query.overlaps(enemy), "disabled body rejected")
	body.disabled = false
	enemy.collision_layer = 0
	_check(not query.overlaps(enemy), "non-enemy layer rejected")
	enemy.collision_layer = 2
	enemy.alive = false
	_check(not query.overlaps(enemy), "dead body rejected")
	var order := EnemyRegistry.get_registry_order()
	_check(order.has(enemy.get_instance_id()), "registry snapshot contains registered body")
	EnemyRegistry.unregister_enemy(enemy)
	_check(not EnemyRegistry.get_registry_order().has(enemy.get_instance_id()) and order.has(enemy.get_instance_id()), "membership change replaces ordering snapshot")
	EnemyRegistry.register_enemy(enemy)
	_check(EnemyRegistry.get_registry_order().has(enemy.get_instance_id()), "re-register rebuilds ordering snapshot")
	enemy.alive = true
	enemy.transform = Transform2D.IDENTITY
	body.transform = Transform2D.IDENTITY
	body.shape = shapes[1]
	query.configure_lamp(Vector2.RIGHT, 600, 60)
	query.place(Transform2D.IDENTITY)
	enemy.position = Vector2(220, 0)
	var native_samples: Array[int] = []
	var query_samples: Array[int] = []
	for pass_index in 6:
		for variant in ([0, 1] if pass_index % 2 == 0 else [1, 0]):
			var started := Time.get_ticks_usec()
			var hit_count := 0
			for iteration in 5000:
				if variant == 0:
					if query.shape.collide(Transform2D.IDENTITY, body.shape, body.global_transform): hit_count += 1
				else:
					if query.overlaps(enemy): hit_count += 1
			var elapsed := Time.get_ticks_usec() - started
			_check(hit_count == 5000, "dense interior benchmark retains every hit")
			if variant == 0: native_samples.append(elapsed)
			else: query_samples.append(elapsed)
	print("INTERIOR_THROUGHPUT native_usec=", native_samples, " query_usec=", query_samples)
	enemy.queue_free()
	await get_tree().process_frame
	print("CONTACT_INTERIOR checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
