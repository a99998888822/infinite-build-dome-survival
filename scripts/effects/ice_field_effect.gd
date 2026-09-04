extends Node2D
class_name IceFieldEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _elapsed: float = 0.0
var _radius: float = 64.0
var _lifetime: float = 1.8

static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := IceFieldEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "ice", {
		"damage": maxf(float(damage_event.damage) * 0.35, 1.0),
		"radius": 64.0,
		"duration": 1.8,
		"slow_multiplier": 0.45,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", 64.0) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 16.0)
	effect._lifetime = maxf(effect._context.get_resolved_parameter("duration", 1.8), 0.2)
	PARTICLE_WORLD_SCRIPT.emit_profile(parent, "ice_burst", hit_position, Vector2.ZERO, 1.0)
	effect._damage_enemies()

func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _lifetime:
		queue_free()

func _damage_enemies() -> void:
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := get_world_2d().direct_space_state.intersect_shape(query, 64)
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive():
			continue
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
		enemy.apply_slow(_context.get_resolved_parameter("duration", 1.8), _context.get_resolved_parameter("slow_multiplier", 0.45))

func _draw() -> void:
	var fade := 1.0 - clampf(_elapsed / _lifetime, 0.0, 1.0)
	draw_circle(Vector2.ZERO, _radius, Color(0.55, 0.86, 1.0, 0.10 * fade))
	for index in range(12):
		var angle := float(index) * TAU / 12.0 + _elapsed * (0.8 if index % 2 == 0 else -0.55)
		var distance := _radius * (0.58 + 0.14 * sin(_elapsed * 4.0 + index))
		var size := 2.0 + float(index % 3)
		var position := Vector2.from_angle(angle) * distance
		draw_rect(Rect2(position - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(0.86, 0.97, 1.0, 0.9 * fade))
