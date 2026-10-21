extends Node2D
class_name BlackHoleEffect
const BLOCK_VFX = preload("res://scripts/effects/enchantment_block_vfx.gd")

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

const DEFAULT_RADIUS: float = 90.0
const DEFAULT_DURATION: float = 0.85
const DEFAULT_PULL_SPEED: float = 150.0
const DEFAULT_DARK_DURATION: float = 2.0
const SPHERE_FRACTION := 0.35
const DAMAGE_TO_SPHERE_RATIO := 3.0

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _visual_reach := DEFAULT_RADIUS
var _sphere_radius := DEFAULT_RADIUS * SPHERE_FRACTION
var _duration: float = DEFAULT_DURATION
var _pull_speed: float = DEFAULT_PULL_SPEED
var _dark_duration: float = DEFAULT_DARK_DURATION
var _elapsed: float = 0.0
var _targets: Array[EnemyController] = []
var _visual_detail: int = 2
var _audio_impact: RefCounted = null
var _vortex_back: Node2D
var _vortex_front: Node2D


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
		"damage_multiplier": 0.45,
		"radius": DEFAULT_RADIUS,
		"duration": DEFAULT_DURATION,
		"pull_speed": DEFAULT_PULL_SPEED,
		"dark_duration": DEFAULT_DARK_DURATION,
	}, attachment_item_id)
	effect._visual_reach = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 24.0)
	effect._sphere_radius = effect._visual_reach * SPHERE_FRACTION
	effect._radius = effect._sphere_radius * DAMAGE_TO_SPHERE_RATIO
	effect._duration = StatDefinitions.calculate_control_duration(maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.1), effect._context.get_resolved_parameter("control_power", 0.0))
	effect._pull_speed = maxf(effect._context.get_resolved_parameter("pull_speed", DEFAULT_PULL_SPEED), 1.0)
	effect._dark_duration = maxf(effect._context.get_resolved_parameter("dark_duration", DEFAULT_DARK_DURATION), 0.1)
	effect.call_deferred("_arm")


func _ready() -> void:
	z_index = 79
	_vortex_back = PIXEL.layer(self, 78, _draw_vortex.bind(false))
	_vortex_front = PIXEL.layer(self, 80, _draw_vortex.bind(true))
	queue_redraw()


func _arm() -> void:
	AudioManager.begin_combat_audio(_audio_impact)
	AudioManager.play_enchantment_sfx("black_hole")
	_collect_targets()
	FirePatch.tint_nearby_fields(get_tree(), global_position, _radius, 2, ELEMENT_REACTION_RESOLVER_SCRIPT.DARK_FLAME_DURATION)
	AudioManager.end_combat_audio()
	_audio_impact = null


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	for enemy in _targets:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if delta > 0.0 and _pull_speed > 0.0 and not enemy.is_movement_locked() and not enemy.global_position.is_equal_approx(global_position) and enemy.can_receive_control():
			enemy.global_position = enemy.global_position.move_toward(global_position, _pull_speed * delta * enemy.get_control_multiplier())
	if _elapsed >= _duration:
		queue_free()
		return
	queue_redraw()
	_vortex_back.queue_redraw()
	_vortex_front.queue_redraw()


func _collect_targets() -> void:
	if _context == null or _damage_event == null:
		return
	var damage := _damage_event.get_elemental_damage(_context.get_resolved_parameter("damage_multiplier", 0.45))
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
				"damage_event": _damage_event,
			})
		enemy.take_attack_damage(damage, _damage_event, false, global_position.direction_to(enemy.global_position))
		if not had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
				"damage_event": _damage_event,
			})


func _draw() -> void:
	BLOCK_VFX.paint(self,2,Rect2(-_visual_reach,-_visual_reach,_visual_reach*2,_visual_reach*2),_visual_reach,_elapsed,_elapsed/_duration,_visual_detail)
	material.set_shader_parameter("sphere_radius", _sphere_radius)


func _draw_vortex(front: bool) -> void:
	var canvas := _vortex_front if front else _vortex_back
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var opening := minf(1.0, progress * 7.0) * (1.0 - smoothstep(0.78, 1.0, progress) * 0.4)
	var fade := (1.0 - smoothstep(0.80, 1.0, progress)) * minf(1.0, progress * 9.0)
	if opening <= 0.0 or fade <= 0.0:
		return
	# Independent curved streamlines arrive from every direction. Each short
	# line moves inward along its own fixed path, then disappears at the sphere.
	var count := 12 if _visual_detail > 0 else 6
	var clock := floorf(_elapsed * 18.0) / 18.0
	var center := Vector2(0.0, -_visual_reach * 0.22)
	for index in count:
		var base_angle := float(index) / count * TAU + 0.17
		if (sin(base_angle) >= 0.0) != front:
			continue
		var life := fposmod(clock / 0.50 + float(index) * 0.618, 1.0)
		var head := 0.20 + life * 1.15
		var start := maxf(0.0, head - 0.50)
		var end := minf(1.0, head)
		if end - start < 0.10:
			continue
		var points := PackedVector2Array()
		var outer_radius := _visual_reach * (1.02 + sin(float(index) * 2.4) * 0.08)
		for step in 25:
			var ratio := lerpf(start, end, float(step) / 24.0)
			var angle := base_angle + ratio * 1.15
			var distance := lerpf(outer_radius, _sphere_radius, ratio) * opening
			var point := (center + Vector2(cos(angle), sin(angle) * 0.85) * distance).round()
			if points.is_empty() or points[-1] != point:
				points.append(point)
		if points.size() < 2:
			continue
		var alpha := fade * minf(1.0, life * 7.0) * (1.0 - smoothstep(0.85, 1.0, life))
		var color := Color(0.63, 0.47, 0.82, alpha) if front else Color(0.45, 0.32, 0.64, alpha)
		canvas.draw_polyline(points, color, 1.0, false)
