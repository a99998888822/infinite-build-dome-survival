extends Node2D
class_name NightwatchSpear

signal target_hit(target_id: int, damage: int, thrust_index: int)
signal shard_launched(shard: ProjectileInstance)

const SPEAR := preload("res://assets/sprites/weapons/weapon_nightwatch_spear.png")
const EFFECTS := preload("res://scripts/effects/combat_effect_world.gd")
const SOURCE_RECT := Rect2(4, 0, 238, 28)

var weapon: WeaponInstance
var cancelled := false
var age := 0.0
var aim := Vector2.RIGHT
var time_scale := 1.0
var windup := 0.1
var extend := 0.12
var recover := 0.16
var thrusts: Array[Dictionary] = []
var primary_hits: Dictionary = {}
var split_profiles: Array[Dictionary] = []
var split_spawned := false
var diagnostic := false
var _shape := RectangleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	weapon = source
	aim = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	global_position = weapon.get_attack_origin()
	time_scale = weapon.get_actual_attack_interval_seconds() / maxf(float(weapon.attack_interval_ms) / 1000.0, 0.001)
	windup = float(weapon.weapon_data.get("spear_windup_ms", 100)) / 1000.0
	extend = float(weapon.weapon_data.get("spear_extend_ms", 120)) / 1000.0
	recover = float(weapon.weapon_data.get("spear_recover_ms", 160)) / 1000.0
	split_profiles = weapon.get_split_profiles()
	var count := maxi(1, int(weapon.get_stat("projectile_count")))
	for index in count:
		thrusts.append({"start": 0.18 * index / maxf(count - 1, 1), "hits": {}, "contacts": [], "event": weapon.calculate_damage_events()[0]})
	_query.shape = _shape
	_query.collision_mask = 2
	_query.collide_with_areas = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 50
	add_to_group("nightwatch_spears")
	add_to_group("weapon_runtime_effects")
	queue_redraw()


func is_attacking() -> bool:
	return not cancelled and age < float(thrusts[-1].start) + windup + extend + recover


func tip_distance(local_time: float) -> float:
	var reach := weapon.get_attack_range()
	if local_time < windup:
		return lerpf(172.0 / 220.0, 156.0 / 220.0, clampf(local_time / windup, 0, 1)) * reach
	if local_time < windup + extend:
		return lerpf(156.0 / 220.0, 1.0, ease((local_time - windup) / extend, 0.6)) * reach
	return lerpf(1.0, 172.0 / 220.0, clampf((local_time - windup - extend) / recover, 0, 1)) * reach


func _physics_process(delta: float) -> void:
	if cancelled:
		return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	var previous := age
	var old_origin := global_position
	age += delta / maxf(time_scale, 0.001)
	global_position = weapon.get_attack_origin()
	for index in thrusts.size():
		var thrust := thrusts[index]
		var begin := float(thrust.start) + windup
		var end := begin + extend
		if age < begin or previous >= end:
			continue
		var first := maxf(previous, begin)
		var last := minf(age, end)
		# Subdivide movement and extension so a long frame cannot skip a victim.
		var steps := maxi(1, maxi(ceili((last - first) / (extend / 16.0)), ceili(old_origin.distance_to(global_position) / maxf(weapon.get_hit_radius(), 1.0))))
		for step in range(steps + 1):
			var at := lerpf(first, last, float(step) / steps)
			var origin := old_origin.lerp(global_position, clampf((at - previous) / maxf(age - previous, 0.0001), 0, 1))
			_contact(thrust, index, origin, tip_distance(at - float(thrust.start)))
	if not split_spawned and age >= float(thrusts[-1].start) + windup + extend:
		split_spawned = true
		_spawn_shards()
	if not is_attacking():
		cancel()
	queue_redraw()


func _contact(thrust: Dictionary, index: int, origin: Vector2, length: float) -> void:
	_shape.size = Vector2(maxf(length, 1), maxf(weapon.get_hit_radius() * 2.0, 1))
	_query.transform = Transform2D(aim.angle(), origin + aim * length * 0.5)
	var contacts := get_world_2d().direct_space_state.intersect_shape(_query, maxi(32, EnemyRegistry.get_registered_enemies().size()))
	AudioManager.begin_combat_audio()
	for contact in contacts:
		var enemy := contact.collider as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive() or thrust.hits.has(enemy.get_instance_id()):
			continue
		if (enemy.global_position - origin).dot(aim) < 0:
			continue
		var ray := PhysicsRayQueryParameters2D.create(origin, enemy.global_position, 4)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var id := enemy.get_instance_id()
		thrust.hits[id] = true
		primary_hits[id] = true
		var event: DamageEvent = thrust.event.duplicate_event()
		event.hit_position = enemy.global_position
		thrust.contacts.append({"position": enemy.global_position, "event": event})
		EFFECTS.trigger_weapon_impact(get_parent(), weapon, event, event.hit_position, aim, enemy)
		enemy.take_damage(event.damage, event.source_weapon_id, event.is_critical, aim)
		weapon.play_attack_hit_sfx()
		target_hit.emit(id, event.damage, index)
	AudioManager.end_combat_audio()


func _spawn_shards() -> void:
	for thrust in thrusts:
		var reserved := primary_hits.duplicate()
		var plans: Array[Dictionary] = []
		for contact in thrust.contacts:
			var origin: Vector2 = contact.position
			for profile in split_profiles:
				for index in int(profile.child_count):
					var nearest: EnemyController
					var distance := weapon.get_attack_range() * weapon.get_attack_range()
					for enemy in EnemyRegistry.get_registered_enemies():
						if not enemy.is_alive() or not enemy.is_inside_tree() or reserved.has(enemy.get_instance_id()):
							continue
						var relative: Vector2 = enemy.global_position - origin
						if relative.dot(aim) > 0 and relative.length_squared() < distance:
							nearest = enemy
							distance = relative.length_squared()
					var spread := float(profile.spread_angle)
					var direction := aim.rotated(deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(index) / maxf(int(profile.child_count) - 1, 1))))
					var target_id := 0
					if nearest != null:
						direction = origin.direction_to(nearest.global_position)
						target_id = nearest.get_instance_id()
						reserved[target_id] = true
					var event: DamageEvent = contact.event.continue_after_split(profile)
					event.damage = maxi(1, roundi(event.damage * float(profile.damage_multiplier)))
					event.elemental_damage_scale *= float(profile.damage_multiplier)
					plans.append({"origin": origin, "direction": direction, "target": target_id, "event": event})
		for plan in plans:
			var ignored := reserved.duplicate()
			ignored.erase(plan.target)
			var shard := NightwatchSpearShard.new()
			get_parent().add_child(shard)
			shard.initialize(weapon, plan.event, "spear_%d_%d" % [weapon.volley_index, shard.get_instance_id()], plan.origin + plan.direction * 8,
				plan.direction, weapon.get_attack_range(), null, 1.0, Callable(), ignored, 1)
			shard._hit_shape.radius = StatDefinitions.calculate_damage_area_radius(6.0, weapon.get_stat("damage_area_size"))
			shard_launched.emit(shard)


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	if cancelled or weapon == null:
		return
	var tint := Color("a9bfba")
	if weapon.has_effect("fire"): tint = Color("ffad60")
	elif weapon.has_effect("ice"): tint = Color("82d9f0")
	elif weapon.has_effect("lightning"): tint = Color("c6b9ff")
	draw_set_transform(Vector2.ZERO, aim.angle())
	for thrust in thrusts:
		var local_time := age - float(thrust.start)
		if local_time < 0 or local_time >= windup + extend + recover:
			continue
		var tip := tip_distance(local_time)
		var length := weapon.get_attack_range() * 144.0 / 220.0
		var half_width := weapon.get_hit_radius()
		if diagnostic:
			draw_rect(Rect2(0, -half_width, tip, half_width * 2.0), Color(0.34, 0.73, 0.65, 0.2))
		if local_time >= windup and local_time < windup + extend + 0.08:
			for index in 16:
				var x := tip - index * 7.0
				if x > 15:
					draw_rect(Rect2(roundf(x), -half_width + index % 3 * 2, 3, 2), Color(tint, 0.5 * (1.0 - float(index) / 16)))
		draw_texture_rect_region(SPEAR, Rect2(roundf(tip - length), -half_width, length, half_width * 2.0), SOURCE_RECT)
	draw_set_transform(Vector2.ZERO)
