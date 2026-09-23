extends Node2D
class_name LightSwordEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

const DEFAULT_RADIUS: float = 78.0
const DEFAULT_DELAY: float = 0.5
const DEFAULT_FALL_SECONDS: float = 0.22
const DEFAULT_DISSOLVE_SECONDS: float = 0.75
const DEFAULT_LIGHT_DURATION: float = 5.0

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _delay: float = DEFAULT_DELAY
var _fall_seconds: float = DEFAULT_FALL_SECONDS
var _dissolve_seconds: float = DEFAULT_DISSOLVE_SECONDS
var _light_duration: float = DEFAULT_LIGHT_DURATION
var _elapsed: float = 0.0
var _strike_started: bool = false
var _landed: bool = false
var _visual_detail: int = 2
var _ground_layer: Node2D
var _ground_cracks: Array[PackedVector2Array] = []


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := LightSwordEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._visual_detail = PIXEL.register(effect, "light_sword")
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "light_sword", {
		"damage_multiplier": 0.9,
		"radius": DEFAULT_RADIUS,
		"delay": DEFAULT_DELAY,
		"fall_seconds": DEFAULT_FALL_SECONDS,
		"dissolve_seconds": DEFAULT_DISSOLVE_SECONDS,
		"light_duration": DEFAULT_LIGHT_DURATION,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 20.0)
	effect._delay = maxf(effect._context.get_resolved_parameter("delay", DEFAULT_DELAY), 0.05)
	effect._fall_seconds = maxf(effect._context.get_resolved_parameter("fall_seconds", DEFAULT_FALL_SECONDS), 0.05)
	effect._dissolve_seconds = maxf(effect._context.get_resolved_parameter("dissolve_seconds", DEFAULT_DISSOLVE_SECONDS), 0.2)
	effect._light_duration = maxf(effect._context.get_resolved_parameter("light_duration", DEFAULT_LIGHT_DURATION), 0.1)
	effect.call_deferred("_arm")


func _ready() -> void:
	z_index = 82
	_ground_layer = PIXEL.layer(self, -7, _draw_ground)
	queue_redraw()


func _arm() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	if not _strike_started and _elapsed >= _delay:
		_strike_started = true
	if _strike_started and not _landed and _elapsed >= _delay + _fall_seconds:
		_land()
	if _landed and _elapsed >= _delay + _fall_seconds + _dissolve_seconds:
		queue_free()
		return
	queue_redraw()
	_ground_layer.queue_redraw()


func _land() -> void:
	if _landed or _context == null or _damage_event == null:
		return
	_landed = true
	AudioManager.begin_combat_audio()
	AudioManager.play_enchantment_sfx("light_sword")
	_build_ground_cracks()
	var damage := _damage_event.get_elemental_damage(_context.get_resolved_parameter("damage_multiplier", 0.9))
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var handled: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, maxi(64, EnemyRegistry.get_registered_enemies().size())):
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or handled.has(enemy.get_instance_id()):
			continue
		handled[enemy.get_instance_id()] = true
		var had_dark := enemy.has_status("dark")
		if had_dark:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "light", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"light_duration": _light_duration,
				"damage_event": _damage_event,
			})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
		if not had_dark:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "light", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"light_duration": _light_duration,
				"damage_event": _damage_event,
			})
	AudioManager.end_combat_audio()


func _draw() -> void:
	var sword_y := -190.0
	if _strike_started:
		var fall := clampf((_elapsed - _delay) / _fall_seconds, 0.0, 1.0)
		sword_y = lerpf(-190.0, -88.0, fall)
	var dissolve := 0.0
	if _landed:
		var landed_age := _elapsed - _delay - _fall_seconds
		# Continue moving into the ground instead of instantly replacing the sword.
		sword_y = lerpf(-88.0, -38.0, clampf(landed_age / 0.09, 0.0, 1.0))
		dissolve = clampf(landed_age / _dissolve_seconds, 0.0, 1.0)
	elif _strike_started and _visual_detail > 0:
		for index in range(3):
			var tail_y := sword_y - 30.0 - float(index) * 10.0
			PIXEL.block(self, Vector2(0, tail_y), Vector2(2, 6 - index * 2), Color(0.6, 0.77, 0.8, 0.6 - index * 0.15))
	_draw_pixel_sword(sword_y, dissolve)
	if _landed and _visual_detail > 0:
		_draw_impact(dissolve)


func _draw_pixel_sword(top: float, dissolve: float) -> void:
	var outline := Color(0.22, 0.33, 0.39, 1.0)
	var shade := Color(0.48, 0.65, 0.7, 1.0)
	var ivory := Color(0.88, 0.93, 0.84, 1.0)
	var light := Color(1.0, 1.0, 0.96, 1.0)
	for row in range(-12, 44):
		var local_y := float(row) * 2.0
		var y := roundf((top + local_y) / 2.0) * 2.0
		if _landed and y >= 0.0:
			continue
		var threshold := 0.16 + (1.0 - float(row + 12) / 56.0) * 0.65 + float(posmod(row * 7, 5)) * 0.028
		if dissolve > threshold:
			continue
		var half_width := 6.0
		if local_y < -18.0:
			half_width = 4.0
		elif local_y < -4.0:
			half_width = 2.0
		elif local_y <= 2.0:
			half_width = 14.0 if local_y >= -2.0 else 10.0
		elif local_y > 62.0:
			half_width = maxf(2.0, ceil((88.0 - local_y) / 8.0) * 2.0)
		PIXEL.block(self, Vector2(0, y), Vector2(half_width * 2.0 + 4.0, 2), outline)
		PIXEL.block(self, Vector2(0, y), Vector2(half_width * 2.0, 2), shade)
		if local_y > 2.0:
			PIXEL.block(self, Vector2(-2, y), Vector2(minf(half_width * 2.0, 6.0), 2), ivory)
			PIXEL.block(self, Vector2(half_width - 2.0, y), Vector2(2, 2), light)
		elif local_y >= -4.0 or local_y < -18.0:
			PIXEL.block(self, Vector2(0, y), Vector2(half_width, 2), ivory)
	if _landed and _visual_detail > 0:
		for index in range(8 if _visual_detail == 2 else 4):
			var start := 0.12 + float(index) * 0.07
			var age := dissolve - start
			if age < 0.0 or age > 0.28:
				continue
			var side := -1.0 if index % 2 == 0 else 1.0
			var point := Vector2(side * (5.0 + age * 30.0), -8.0 - float(index) * 7.0 - age * 24.0)
			PIXEL.block(self, point, Vector2(2, 4), Color(0.82, 0.9, 0.82, 1.0 - age / 0.28))


func _draw_impact(dissolve: float) -> void:
	var age := _elapsed - _delay - _fall_seconds
	if age < 0.1:
		var size := 1.0 - age / 0.1
		PIXEL.line(self, Vector2(-22, 0) * size, Vector2(22, 0) * size, Color(0.94, 1.0, 0.88, size), 4)
		PIXEL.line(self, Vector2(0, -18) * size, Vector2(0, 8) * size, Color(0.94, 1.0, 0.88, size), 2)
	if dissolve < 0.5:
		for side in [-1.0, 1.0]:
			var point := Vector2(side * (6.0 + dissolve * 40.0), -sin(dissolve * PI * 2.0) * 5.0)
			PIXEL.block(self, point, Vector2(2, 2), Color(0.85, 0.93, 0.85, (1.0 - dissolve * 2.0) * 0.7))


func _draw_ground() -> void:
	if _visual_detail == 0:
		return
	if not _landed:
		var anticipation := clampf(_elapsed / _delay, 0.0, 1.0)
		var color := Color(0.48, 0.63, 0.6, 0.25 + anticipation * 0.3)
		for index in range(4):
			PIXEL.arc(_ground_layer, 10.0, float(index) * PI * 0.5 + 0.15, float(index) * PI * 0.5 + 0.85, color)
		PIXEL.block(_ground_layer, Vector2.ZERO, Vector2(2, 2), color)
		return
	var progress := clampf((_elapsed - _delay - _fall_seconds) / _dissolve_seconds, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.25, 1.0, progress)
	for crack in _ground_cracks:
		PIXEL.path(_ground_layer, crack, Color(0.035, 0.065, 0.06, 0.62 * fade), 2)


func _build_ground_cracks() -> void:
	_ground_cracks.clear()
	# Two short, shallow horizontal cracks; no radial branches or extra RNG.
	_ground_cracks.append(PackedVector2Array([
		Vector2(-4, 0), Vector2(-12, 2), Vector2(-20, 0), Vector2(-28, 2),
	]))
	_ground_cracks.append(PackedVector2Array([
		Vector2(4, 0), Vector2(14, -2), Vector2(22, 0), Vector2(32, -2),
	]))
