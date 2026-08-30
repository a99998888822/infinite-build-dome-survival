extends Node2D
class_name ElectricSparkEffect

const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/effects/lightning_particle_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")

const ACTIVATION_DELAY_SECONDS: float = 0.5
const RING_FADE_SECONDS: float = 0.28
const DEFAULT_RADIUS: float = 20.0
const DEFAULT_STRIKE_HEIGHT: float = 260.0
const RING_DASH_COUNT: int = 18
const RING_DASH_RATIO: float = 0.52
const RING_ROTATION_SPEED: float = 3.2
const RING_LINE_WIDTH: float = 2.0

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _hit_position: Vector2 = Vector2.ZERO
var _attachment_item_id: String = ""
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _elapsed: float = 0.0
var _struck: bool = false


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := ElectricSparkEffect.new()
	parent.add_child(effect)
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._hit_position = hit_position
	effect._attachment_item_id = attachment_item_id
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "electric_spark", {
		"damage": maxf(float(damage_event.damage) * 0.72, 1.0),
		"radius": DEFAULT_RADIUS,
		"strike_height": DEFAULT_STRIKE_HEIGHT,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("area_size_multiplier", 1.0), 18.0)
	effect.global_position = hit_position
	effect.call_deferred("_arm")


func _arm() -> void:
	if _context == null:
		queue_free()
		return
	queue_redraw()


func _ready() -> void:
	z_index = 81
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	rotation = _elapsed * RING_ROTATION_SPEED
	if not _struck and _elapsed >= ACTIVATION_DELAY_SECONDS:
		_struck = true
		_trigger_strike()
	if _struck and _elapsed >= ACTIVATION_DELAY_SECONDS + RING_FADE_SECONDS:
		queue_free()
		return
	queue_redraw()


func _trigger_strike() -> void:
	if _context == null or _weapon == null or _damage_event == null:
		return
	var strike_height := maxf(_context.get_resolved_parameter("strike_height", DEFAULT_STRIKE_HEIGHT), 96.0)
	LIGHTNING_EFFECT_SCRIPT.spawn_ground_strike(get_parent(), _hit_position, _weapon, _damage_event, _attachment_item_id, strike_height)
	_damage_enemies()


func _damage_enemies() -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _hit_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := space_state.intersect_shape(query, 64)
	var damaged_ids: Dictionary = {}
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or damaged_ids.has(enemy.get_instance_id()):
			continue
		damaged_ids[enemy.get_instance_id()] = true
		var hit_direction := _hit_position.direction_to(enemy.global_position)
		if hit_direction.is_zero_approx():
			hit_direction = Vector2.DOWN
		enemy.take_damage(damage, _damage_event.source_weapon_id, _damage_event.is_critical, hit_direction)


func _draw() -> void:
	var ring_alpha := 1.0
	if _struck:
		ring_alpha = 1.0 - clampf((_elapsed - ACTIVATION_DELAY_SECONDS) / RING_FADE_SECONDS, 0.0, 1.0)
	var pulse := 1.0 + sin(_elapsed * 11.0) * 0.04
	var radius := _radius * pulse
	var dash_angle := TAU / float(RING_DASH_COUNT)
	for dash_index in RING_DASH_COUNT:
		var start_angle := float(dash_index) * dash_angle
		var end_angle := start_angle + dash_angle * RING_DASH_RATIO
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 3, Color(1.0, 0.48, 0.04, ring_alpha * 0.22), RING_LINE_WIDTH * 3.0, false)
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 3, Color(1.0, 0.84, 0.16, ring_alpha * 0.95), RING_LINE_WIDTH, false)
	draw_rect(Rect2(Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), Color(1.0, 0.92, 0.34, ring_alpha * 0.82))
