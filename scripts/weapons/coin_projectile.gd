extends Node2D
class_name CoinProjectile

signal target_hit(target_id: int, damage: int, child: bool)

const COIN = preload("res://assets/sprites/weapons/rentier_coin_spin.png")
const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
const HIT = preload("res://scripts/weapons/ritual_coin_hit.gd")

var weapon: WeaponInstance
var damage_event: DamageEvent
var direction := Vector2.RIGHT
var speed := 380.0
var remaining_distance := 280.0
var distance_travelled := 0.0
var age := 0.0
var remaining_hits := 1
var split_generation := 0
var has_split := false
var cancelled := false
# Every coin and descendant of a volley shares this ledger, by reference.
var volley_hits: Dictionary = {}


func initialize(source: WeaponInstance, event: DamageEvent, origin: Vector2, heading: Vector2,
		shared_hits: Dictionary, generation: int = 0) -> void:
	weapon = source
	damage_event = event
	global_position = origin
	direction = heading.normalized()
	speed = maxf(1.0, weapon.get_projectile_speed())
	remaining_distance = weapon.get_attack_range()
	remaining_hits = weapon.get_pierce_hit_limit()
	volley_hits = shared_hits
	split_generation = generation
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 50
	add_to_group("coin_projectiles")
	add_to_group("weapon_runtime_effects")


func _physics_process(delta: float) -> void:
	if cancelled or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	age += delta
	var start := global_position
	var step := minf(speed * delta, remaining_distance)
	var end := start + direction * step
	# Sweep terrain first, so a large frame cannot shoot through a wall or a target.
	var terrain: Dictionary = {}
	if step > 0.0:
		var ray := PhysicsRayQueryParameters2D.create(start, end, 4)
		terrain = get_world_2d().direct_space_state.intersect_ray(ray)
		if not terrain.is_empty():
			end = terrain.position
	var contacts: Array[Dictionary] = []
	var radius := maxf(1.0, weapon.get_hit_radius())
	var length := start.distance_to(end)
	for enemy in EnemyRegistry.get_registered_enemies():
		if not is_instance_valid(enemy) or not enemy.is_alive() or volley_hits.has(enemy.get_instance_id()):
			continue
		var relative: Vector2 = enemy.global_position - start
		var along: float = relative.dot(direction)
		var lateral_squared := maxf(0.0, relative.length_squared() - along * along)
		if lateral_squared > radius * radius:
			continue
		var half_chord := sqrt(maxf(0.0, radius * radius - lateral_squared))
		var entry := maxf(0.0, along - half_chord)
		if along + half_chord < 0.0 or entry > length:
			continue
		contacts.append({"enemy": enemy, "distance": entry})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for contact in contacts:
		var enemy: EnemyController = contact.enemy
		if not is_instance_valid(enemy) or not enemy.is_alive() or volley_hits.has(enemy.get_instance_id()):
			continue
		global_position = start + direction * float(contact.distance)
		_hit_enemy(enemy)
		if cancelled:
			return
	global_position = end
	distance_travelled += length
	remaining_distance -= length
	if not terrain.is_empty():
		HIT.spawn(get_parent(), weapon, end, false)
		cancel()
	elif remaining_distance <= 0.001:
		cancel()
	queue_redraw()


func _hit_enemy(enemy: EnemyController) -> void:
	var target_id := enemy.get_instance_id()
	volley_hits[target_id] = true
	var where := enemy.global_position
	var event := damage_event.duplicate_event()
	event.hit_position = where
	# Capture split origin before lethal damage, but share the volley ledger.
	if split_generation == 0 and not has_split:
		has_split = true
		_spawn_children(where)
	EFFECTS.trigger_weapon_impact(get_parent(), weapon, event, where, direction, enemy)
	enemy.take_damage(event.damage, event.source_weapon_id, event.is_critical, direction)
	HIT.spawn(get_parent(), weapon, where, false)
	weapon.play_projectile_hit_sfx(str(get_instance_id()))
	target_hit.emit(target_id, event.damage, split_generation > 0)
	remaining_hits -= 1
	if remaining_hits <= 0:
		cancel()


func _spawn_children(origin: Vector2) -> void:
	var reserved := volley_hits.duplicate()
	for profile in weapon.get_split_profiles():
		var count := int(profile.child_count)
		for index in count:
			var nearest: EnemyController
			var nearest_distance := weapon.get_attack_range() * weapon.get_attack_range()
			for candidate in EnemyRegistry.get_registered_enemies():
				if not candidate.is_alive() or reserved.has(candidate.get_instance_id()):
					continue
				var distance := origin.distance_squared_to(candidate.global_position)
				if distance < nearest_distance:
					nearest = candidate
					nearest_distance = distance
			var heading := direction.rotated(deg_to_rad(lerpf(-float(profile.spread_angle) * 0.5, float(profile.spread_angle) * 0.5, float(index) / maxf(count - 1, 1))))
			if nearest != null:
				heading = origin.direction_to(nearest.global_position)
				reserved[nearest.get_instance_id()] = true
			var event := damage_event.duplicate_event()
			var multiplier := float(profile.damage_multiplier)
			event.damage = maxi(1, roundi(event.damage * multiplier))
			event.original_damage = maxi(1, roundi(event.original_damage * multiplier))
			event.element_damage_bonus = maxi(0, roundi(event.element_damage_bonus * multiplier))
			var child := CoinProjectile.new()
			get_parent().add_child(child)
			child.initialize(weapon, event, origin, heading, volley_hits, split_generation + 1)


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	if cancelled:
		return
	for index in 3:
		if distance_travelled < 10 + index * 5:
			continue
		var point := -direction * (10 + index * 5)
		draw_rect(Rect2(point.round(), Vector2(2,2)), Color(0.81, 0.64, 0.31, 0.48 - index * 0.12))
	var frame := int(age * 18.0) % 8
	var side := 12.0 if split_generation > 0 else 16.0
	draw_texture_rect_region(COIN, Rect2(Vector2.ONE * (-side * 0.5), Vector2.ONE * side), Rect2(frame * 16, 0, 16, 16))
