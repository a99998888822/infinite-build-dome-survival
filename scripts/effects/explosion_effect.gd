extends Node2D
class_name ExplosionEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const DESTRUCTIBLE_TEST_AREA_SCRIPT = preload("res://scripts/terrain/destructible_test_area.gd")

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _hit_position: Vector2 = Vector2.ZERO


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := ExplosionEffect.new()
	parent.add_child(effect)
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._hit_position = hit_position
	effect.call_deferred("_detonate")


func _detonate() -> void:
	if _weapon == null or _damage_event == null:
		queue_free()
		return
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(_weapon, "explosion", {
		"damage": maxf(float(_damage_event.damage) * 0.8, 1.0),
		"radius": 48.0,
	})
	var radius := maxf(context.get_resolved_parameter("radius", 48.0) * context.get_resolved_parameter("area_size_multiplier", 1.0), 12.0)
	var damage := maxi(1, int(roundi(context.get_resolved_parameter("damage", 1.0))))
	var flash_color := context.get_tinted_color(Color(1.0, 0.74, 0.25, 1.0))
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_flash", _hit_position, Vector2.ZERO, 1.0, flash_color, {
		"count_multiplier": context.get_resolved_parameter("count_multiplier", 1.0),
		"speed_multiplier": context.get_resolved_parameter("speed_multiplier", 1.0),
		"size_multiplier": context.get_resolved_parameter("size_multiplier", 1.0) * context.get_resolved_parameter("area_size_multiplier", 1.0),
		"lifetime_multiplier": context.get_resolved_parameter("lifetime_multiplier", 1.0),
		"alpha_multiplier": context.get_resolved_parameter("alpha_multiplier", 1.0),
		"glow_multiplier": context.get_resolved_parameter("glow_multiplier", 1.0),
	})
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_debris", _hit_position, Vector2.ZERO, 1.0)
	_damage_enemies(radius, damage)
	_damage_terrain(radius)
	queue_free()


func _damage_enemies(radius: float, damage: int) -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _hit_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := space_state.intersect_shape(query, 64)
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive():
			continue
		var distance_ratio := clampf(enemy.global_position.distance_to(_hit_position) / radius, 0.0, 1.0)
		var scaled_damage := maxi(1, int(roundi(float(damage) * (1.0 - distance_ratio * 0.65))))
		enemy.take_damage(scaled_damage, _damage_event.source_weapon_id, false, enemy.global_position.direction_to(_hit_position))


func _damage_terrain(radius: float) -> void:
	var root := get_tree().current_scene if get_tree() != null else null
	if root == null:
		return
	var terrain := root.find_child("DestructibleTestArea", true, false)
	if terrain != null and terrain.get_script() == DESTRUCTIBLE_TEST_AREA_SCRIPT and terrain.has_method("destroy_radius"):
		terrain.call("destroy_radius", _hit_position, radius)
