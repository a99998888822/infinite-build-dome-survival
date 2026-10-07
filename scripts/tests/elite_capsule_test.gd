extends Node2D

var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func _run() -> void:
	var player := preload("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	add_child(player)
	player.set_physics_process(false)
	var boss := preload("res://scenes/enemy/elite_rusher.tscn").instantiate() as EliteRusher
	add_child(boss)
	boss.initialize("enemy_elite_rusher", player)
	boss.set_physics_process(false)
	var body := boss.get_node("CollisionShape2D") as CollisionShape2D
	check(body.shape is CapsuleShape2D, "boss uses a native physics capsule")
	var body_bounds := body.transform * body.shape.get_rect()
	for animation in EliteRusher.FRAMES.get_animation_names():
		for index in EliteRusher.FRAMES.get_frame_count(animation):
			var texture := EliteRusher.FRAMES.get_frame_texture(animation, index)
			var used := texture.get_image().get_used_rect()
			var art_bounds := Rect2((Vector2(used.position) - texture.get_size() * 0.5) * boss.sprite.scale + boss.sprite.position, Vector2(used.size) * boss.sprite.scale)
			check(art_bounds.encloses(body_bounds.grow(1)), "capsule stays inside visible sprite bounds with margin: %s/%d" % [animation, index])
	for offset in [Vector2(27,0), Vector2(-27,0), Vector2(0,65), Vector2(0,-65)]:
		player.global_position = body.global_position + offset
		check(boss._is_touching_player(), "capsule contact registers at body edge " + str(offset))
	for offset in [Vector2(31,0), Vector2(-31,0), Vector2(0,69), Vector2(0,-69)]:
		player.global_position = body.global_position + offset
		check(not boss._is_touching_player(), "capsule contact misses outside actual body " + str(offset))
	var coin := CoinProjectile.new()
	coin._sweep_shape.radius = 2
	var start := body.global_position - Vector2(100,0)
	var distance := coin._body_contact_distance(boss, start, 200, 2)
	check(distance >= 79 and distance <= 81, "projectile sweep hits the offset capsule at its true edge")
	check(is_inf(coin._body_contact_distance(boss, start + Vector2(0,45), 200, 2)), "projectile below the capsule cannot hit empty space")
	body.disabled = true
	player.global_position = body.global_position
	check(not boss._is_touching_player() and is_inf(coin._body_contact_distance(boss, start, 200, 2)), "disabled capsule blocks neither contact nor projectile checks")
	coin.free()
	body.disabled = false
	boss._process_special_behavior(0.75)
	await _check_auto_aim(player, boss, body)
	boss.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("ELITE_CAPSULE_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check_auto_aim(player: PlayerController, boss: EliteRusher, body: CollisionShape2D) -> void:
	var loadout := WeaponLoadout.new()
	add_child(loadout)
	loadout.owner_player = player
	loadout.set_active_combat_enabled(true)
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", player)
	weapon.use_active_range_rules = true
	loadout.weapon_instances.append(weapon)
	for offset in [Vector2(-120, 0), Vector2(120, 0), Vector2(0, -140), Vector2(0, 120)]:
		player.global_position = boss.global_position + offset
		loadout.active_casting.states.clear()
		loadout.active_casting.auto_attack()
		var shots := get_tree().get_nodes_in_group("weapon_runtime_effects")
		check(shots.size() == 1, "automatic cast creates a projectile from " + str(offset))
		for shot in shots:
			var projectile := shot as ProjectileInstance
			if projectile != null:
				# A narrow shot must cross the body, not graze the old foot anchor.
				var probe := CircleShape2D.new()
				probe.radius = 2
				check(probe.collide_with_motion(Transform2D(0, projectile.global_position), projectile.direction * 280, body.shape, body.global_transform, Vector2.ZERO), "automatic flight crosses the actual capsule from " + str(offset))
			shot.free()
	for id in ["weapon_iron_grenade_cannon", "weapon_kunyu_ritual_tome"]:
		var ground_weapon := WeaponInstance.new()
		ground_weapon.initialize(id, player)
		check(ground_weapon.get_auto_target_position(boss) == boss.global_position, "ground attack keeps its ground target: " + id)
	loadout.queue_free()
