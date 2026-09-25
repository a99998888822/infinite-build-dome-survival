extends Node2D
class_name BlackHoleEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

const DEFAULT_RADIUS: float = 100.0
const DEFAULT_DURATION: float = 0.85
const DEFAULT_PULL_SPEED: float = 150.0
const DEFAULT_DARK_DURATION: float = 2.0

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _pull_speed: float = DEFAULT_PULL_SPEED
var _dark_duration: float = DEFAULT_DARK_DURATION
var _elapsed: float = 0.0
var _targets: Array[EnemyController] = []
var _visual_detail: int = 2
var _shadow_layer: Node2D
var _audio_impact: RefCounted = null


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := BlackHoleEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._visual_detail = PIXEL.register(effect, "black_hole")
	effect._weapon = weapon
	effect._audio_impact = AudioManager.current_combat_audio()
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "black_hole", {
		"damage_multiplier": 0.65,
		"radius": DEFAULT_RADIUS,
		"duration": DEFAULT_DURATION,
		"pull_speed": DEFAULT_PULL_SPEED,
		"dark_duration": DEFAULT_DARK_DURATION,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 24.0)
	effect._duration = maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.1)
	effect._pull_speed = maxf(effect._context.get_resolved_parameter("pull_speed", DEFAULT_PULL_SPEED), 1.0)
	effect._dark_duration = maxf(effect._context.get_resolved_parameter("dark_duration", DEFAULT_DARK_DURATION), 0.1)
	effect.call_deferred("_arm")


func _ready() -> void:
	z_index = 79
	_shadow_layer = PIXEL.layer(self, -6, _draw_shadow)
	queue_redraw()


func _arm() -> void:
	AudioManager.begin_combat_audio(_audio_impact)
	AudioManager.play_enchantment_sfx("black_hole")
	_collect_targets()
	AudioManager.end_combat_audio()
	_audio_impact = null


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	for enemy in _targets:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		enemy.global_position = enemy.global_position.move_toward(global_position, _pull_speed * delta * enemy.get_control_multiplier())
	if _elapsed >= _duration:
		queue_free()
		return
	queue_redraw()
	_shadow_layer.queue_redraw()


func _collect_targets() -> void:
	if _context == null or _damage_event == null:
		return
	var damage := _damage_event.get_elemental_damage(_context.get_resolved_parameter("damage_multiplier", 0.65))
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var handled: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or handled.has(enemy.get_instance_id()):
			continue
		handled[enemy.get_instance_id()] = true
		_targets.append(enemy)
		var had_light := enemy.has_status("light")
		if had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
			})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
		if not had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
			})


func _draw() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var collapse := 1.0 - smoothstep(0.76, 1.0, progress)
	var core_radius := _radius * 0.22 * collapse
	var fade := (1.0 - progress * 0.3) * collapse
	if collapse <= 0.0:
		return
	# Lift only the drawing; the attraction center and collision query stay on
	# the original ground point. A round body and separate shadow imply height.
	var center := Vector2(0, roundf((-_radius * 0.22 - 10.0) / 2.0) * 2.0)
	if _visual_detail > 0:
		_draw_absorbing_segments(core_radius, fade, center)
	draw_set_transform(center)
	if _visual_detail > 0:
		_draw_accretion_rings(fade, core_radius, false)
	PIXEL.ellipse(self, Vector2.ONE * (core_radius + 2.0), Color(0.18, 0.15, 0.27, collapse))
	PIXEL.ellipse(self, Vector2.ONE * core_radius, Color(0.052, 0.041, 0.091, collapse))
	# Broad, clipped color masses suggest a sphere without noisy surface detail.
	draw_set_transform(center + (Vector2(-0.14, -0.16) * core_radius / 2.0).round() * 2.0)
	PIXEL.ellipse(self, Vector2.ONE * core_radius * 0.72, Color(0.105, 0.082, 0.17, collapse))
	draw_set_transform(center + (Vector2(0.12, 0.15) * core_radius / 2.0).round() * 2.0)
	PIXEL.ellipse(self, Vector2.ONE * core_radius * 0.78, Color(0.018, 0.02, 0.041, collapse))
	draw_set_transform(center)
	PIXEL.arc(self, core_radius, 3.4, 5.15, Color(0.44, 0.37, 0.59, fade), 2)
	PIXEL.arc(self, core_radius - 4.0, 3.8, 4.6, Color(0.25, 0.21, 0.38, fade * 0.85), 2)
	if _visual_detail > 0:
		_draw_accretion_rings(fade, core_radius, true)
	draw_set_transform(Vector2.ZERO)


func _draw_shadow() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var collapse := 1.0 - smoothstep(0.76, 1.0, progress)
	if collapse > 0.0:
		PIXEL.ellipse(_shadow_layer, Vector2(_radius * 0.2, _radius * 0.06) * collapse, Color(0.01, 0.02, 0.025, 0.35 * collapse))


func _draw_accretion_rings(fade: float, core_radius: float, front: bool) -> void:
	var clock := floorf(_elapsed * 16.0) / 16.0
	for index in range(8):
		var angle := fposmod(float(index) * TAU / 8.0 + clock * 0.8, TAU)
		if (angle < PI) != front:
			continue
		var color := Color(0.34, 0.42, 0.55, fade * 0.75) if front else Color(0.23, 0.25, 0.37, fade * 0.65)
		PIXEL.arc(self, core_radius * 1.5, angle, minf(angle + 0.34, PI if front else TAU), color, 2, Vector2(1.0, 0.34), -0.2)


func _draw_absorbing_segments(core_radius: float, fade: float, center: Vector2) -> void:
	var count := 12 if _visual_detail == 2 else 6
	var clock := floorf(_elapsed * 20.0) / 20.0
	for index in range(count):
		var phase := fposmod(float(index) * 0.381 + clock * (0.9 + float(index % 3) * 0.12), 1.0)
		var angle := float(index) * 2.399 + clock * 0.25
		var radius := lerpf(_radius * 0.92, maxf(core_radius, 3.0), phase)
		var head := Vector2.from_angle(angle - phase * 0.85) * radius + center * phase
		var tail := Vector2.from_angle(angle - phase * 0.85 + 0.06) * (radius + 5.0) + center * maxf(phase - 0.05, 0.0)
		var tint := Color(0.48, 0.55, 0.66, fade * (0.9 - phase * 0.3))
		PIXEL.line(self, tail, head, tint, 2.0)
		if index % 3 == 0:
			PIXEL.block(self, head, Vector2(4, 2), Color(0.69, 0.67, 0.79, fade * 0.8))
