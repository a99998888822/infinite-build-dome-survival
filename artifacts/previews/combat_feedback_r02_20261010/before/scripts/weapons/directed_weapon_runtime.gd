extends Node2D
class_name DirectedWeaponRuntime

signal target_hit(target_id: int, damage: int, child: bool)

const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
var weapon: WeaponInstance
var cancelled := false
var heading := Vector2.RIGHT
var age := 0.0


func bind_weapon(source: WeaponInstance, group: String) -> void:
	weapon = source
	global_position = source.get_attack_origin()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 50
	add_to_group(group)
	add_to_group("weapon_runtime_effects")


func ready_to_tick() -> bool:
	if cancelled:
		return false
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return false
	return not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))


static func clear_path(source: Node2D, from: Vector2, to: Vector2) -> bool:
	return source.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 4)).is_empty()


static func nearest(source: WeaponInstance, radius: float) -> EnemyController:
	var origin := source.get_attack_origin()
	var best: EnemyController
	var distance := radius * radius + 0.001
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_alive():
			continue
		if enemy is EliteRusher and enemy.skill_state == "spawn":
			continue
		var next := origin.distance_squared_to(enemy.global_position)
		if next < distance and clear_path(source.owner_player, origin, enemy.global_position):
			best = enemy
			distance = next
	return best


func rectangle_contacts(origin: Vector2, direction: Vector2, length: float, half_width: float) -> Array[EnemyController]:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, half_width * 2)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(direction.angle(), origin + direction * length * 0.5)
	query.collision_mask = 2
	query.collide_with_areas = false
	var result: Array[EnemyController] = []
	for contact in get_world_2d().direct_space_state.intersect_shape(query, maxi(32, EnemyRegistry.get_registered_enemies().size())):
		var enemy := contact.collider as EnemyController
		if is_instance_valid(enemy) and enemy.is_alive() and not result.has(enemy) and clear_path(self, origin, enemy.global_position):
			result.append(enemy)
	return result


func deal_hit(enemy: EnemyController, source: DamageEvent, direction: Vector2, child: bool = false, trigger_effects: bool = true) -> void:
	var event := source.duplicate_event()
	event.hit_position = enemy.global_position
	if trigger_effects:
		EFFECTS.trigger_weapon_impact(get_parent(), weapon, event, event.hit_position, direction, enemy)
	enemy.take_damage(event.damage, event.source_weapon_id, event.is_critical, direction)
	weapon.play_attack_hit_sfx()
	target_hit.emit(enemy.get_instance_id(), event.damage, child)


func speed_scale() -> float:
	if weapon.use_active_range_rules:
		return 1.0
	return weapon.get_actual_attack_interval_seconds() / maxf(float(weapon.attack_interval_ms) / 1000.0, 0.001)


func draw_atlas(texture: Texture2D, size: int, frame: int, pivot: Vector2, origin: Vector2, angle: float, dimensions: Vector2 = Vector2.ONE, alpha: float = 1.0) -> void:
	draw_set_transform(origin.round(), angle, dimensions)
	draw_texture_rect_region(texture, Rect2(-pivot, Vector2(size, size)), Rect2(frame * size, 0, size, size), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()
