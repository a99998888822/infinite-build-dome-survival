extends Node2D
class_name ElectricSparkEffect

const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/effects/lightning_particle_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")

const ACTIVATION_DELAY_SECONDS: float = 0.5
const RING_FADE_SECONDS: float = 0.28
const DEFAULT_RADIUS: float = 20.0
const DEFAULT_STRIKE_HEIGHT: float = 260.0
const PARTICLE_ROWS: int = 3
const PARTICLES_PER_ROW: int = 8
const BODY_RADIUS: Vector2 = Vector2(23.0, 14.0)
const PARTICLE_SIZE: Vector2 = Vector2(3.0, 2.0)

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
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 18.0)
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
	var fade := 1.0
	if _struck:
		fade = 1.0 - clampf((_elapsed - ACTIVATION_DELAY_SECONDS) / RING_FADE_SECONDS, 0.0, 1.0)
	var radius_scale := _radius / DEFAULT_RADIUS
	for row_index in PARTICLE_ROWS:
		var row_phase := float(row_index) * 1.9
		for particle_index in PARTICLES_PER_ROW:
			var ratio := float(particle_index) / float(PARTICLES_PER_ROW)
			var orbit_angle := _elapsed * (5.0 + float(row_index) * 0.7) + ratio * TAU + row_phase
			var wave := sin(_elapsed * 13.0 + ratio * 15.0 + row_phase) * 2.8
			var particle_position := Vector2(
				cos(orbit_angle) * (BODY_RADIUS.x + wave),
				sin(orbit_angle) * (BODY_RADIUS.y + wave * 0.45),
			) * radius_scale
			var tangent := Vector2(-sin(orbit_angle), cos(orbit_angle)).angle()
			var particle_alpha := (0.55 + 0.45 * sin(_elapsed * 18.0 + ratio * TAU + row_phase)) * fade
			var yellow_color := Color(1.0, 0.62, 0.06, particle_alpha * 0.72)
			var bright_yellow_color := Color(1.0, 0.94, 0.34, particle_alpha)
			draw_set_transform(particle_position.round(), tangent, Vector2.ONE)
			draw_circle(Vector2.ZERO, 3.2, Color(1.0, 0.72, 0.08, particle_alpha * 0.12))
			draw_rect(Rect2(-PARTICLE_SIZE * 0.5, PARTICLE_SIZE), yellow_color)
			draw_rect(Rect2(-Vector2(2.0, 0.8), Vector2(4.0, 1.6)), bright_yellow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
