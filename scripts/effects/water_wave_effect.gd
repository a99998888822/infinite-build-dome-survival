extends Node2D
class_name WaterWaveEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")

const DEFAULT_RADIUS: float = 92.0
const DEFAULT_DURATION: float = 0.42
const DEFAULT_DAMAGE_MULTIPLIER: float = 0.55
const WAVE_SEGMENTS: int = 48

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _elapsed: float = 0.0
var _damage_applied: bool = false
var _phase: float = 0.0


static func spawn(
	parent: Node,
	hit_position: Vector2,
	weapon: WeaponInstance,
	damage_event: DamageEvent,
	attachment_item_id: String = ""
) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := WaterWaveEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "water", {
		"radius": DEFAULT_RADIUS,
		"duration": DEFAULT_DURATION,
		"damage_multiplier": DEFAULT_DAMAGE_MULTIPLIER,
		"wet_duration": 3.0,
		"wet_slow_multiplier": 0.8,
	}, attachment_item_id)
	effect._radius = maxf(
		effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS)
			* effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0),
		32.0,
	)
	effect._duration = maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.12)
	effect._phase = randf_range(0.0, TAU)
	effect.call_deferred("_apply_wave")


func _ready() -> void:
	z_index = 80
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func _apply_wave() -> void:
	if _damage_applied or _context == null or _damage_event == null:
		return
	_damage_applied = true
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := get_world_2d().direct_space_state.intersect_shape(query, 64)
	var damage := maxi(1, int(roundi(float(_damage_event.original_damage) * _context.get_resolved_parameter("damage_multiplier", DEFAULT_DAMAGE_MULTIPLIER))))
	var wet_duration: float = _context.get_resolved_parameter("wet_duration", 3.0)
	var wet_slow_multiplier: float = _context.get_resolved_parameter("wet_slow_multiplier", 0.8)
	var handled: Dictionary = {}
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or handled.has(enemy.get_instance_id()):
			continue
		handled[enemy.get_instance_id()] = true
		ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "water", {
			"parent": get_parent(),
			"hit_position": enemy.global_position,
			"source_id": _damage_event.source_weapon_id,
			"wet_duration": wet_duration,
			"wet_slow_multiplier": wet_slow_multiplier,
		})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))


func _draw() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var expansion := smoothstep(0.0, 1.0, progress)
	var radius := maxf(_radius * expansion, 1.0)
	var fade := 1.0 - progress * 0.72
	for wave_index in range(3):
		var wave_radius := radius * (0.82 + float(wave_index) * 0.09)
		var wave_phase := _phase + float(wave_index) * 1.7 + progress * (2.4 + float(wave_index) * 0.8)
		var points := _build_wave_points(wave_radius, wave_phase, wave_index)
		var blue_alpha := fade * (0.68 if wave_index != 1 else 0.42)
		var white_alpha := fade * (0.82 if wave_index == 1 else 0.52)
		draw_polyline(points, Color(0.18, 0.62, 1.0, blue_alpha), 3.0 if wave_index == 1 else 2.0, true)
		draw_polyline(points, Color(0.84, 0.96, 1.0, white_alpha), 1.1, true)
	if progress < 0.48:
		draw_circle(Vector2.ZERO, radius * 0.12, Color(0.55, 0.88, 1.0, fade * 0.24))


func _build_wave_points(radius: float, phase: float, wave_index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(WAVE_SEGMENTS + 1):
		var ratio := float(index) / float(WAVE_SEGMENTS)
		var angle := ratio * TAU
		var ripple := sin(angle * (3.0 + wave_index) + phase) * (2.0 + wave_index * 1.2)
		var point_radius := radius + ripple
		points.append(Vector2.from_angle(angle) * point_radius)
	return points
