extends Node2D
class_name LightningParticleEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")

const CHAIN_DISPLAY_ECHO_DELAY: float = 0.12
const CHAIN_CONTROL_POINT_SPACING: float = 24.0
const CHAIN_CONTROL_POINT_JITTER: float = 26.0
const BOLT_PULSE_LIFETIME: float = 0.38
const BOLT_CORE_PARTICLE_SIZE: Vector2 = Vector2(4.0, 2.0)
const BOLT_COMPANION_PARTICLE_SIZE: Vector2 = Vector2(3.0, 2.0)
const BOLT_GLOW_PARTICLE_SIZE: float = 5.0
const BOLT_PARTICLE_SPACING: float = 3.25
const BOLT_MICRO_JITTER: float = 2.2
const GROUND_STRIKE_ECHO_COUNT: int = 4
const GROUND_STRIKE_JITTER_MULTIPLIER: float = 1.65
const GROUND_STRIKE_SAMPLE_JITTER_MULTIPLIER: float = 1.8
const GROUND_STRIKE_PARTICLE_SPACING: float = 3.0

var _parent_root: Node = null
var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _direction: Vector2 = Vector2.RIGHT
var _attachment_item_id: String = ""
var _context: RefCounted = null
var _visited: Dictionary = {}
var _remaining_jumps: int = 0
var _jump_radius: float = 170.0
var _pending_display_echoes: int = 0
var _chain_finished: bool = false
var _bolt_pulses: Array[Dictionary] = []
var _display_echo_count: int = 2
var _control_point_jitter_multiplier: float = 1.0
var _sample_jitter_multiplier: float = 1.0
var _bolt_particle_spacing: float = BOLT_PARTICLE_SPACING
var _control_point_envelope_power: float = 1.3


static func spawn(parent: Node, hit_position: Vector2, first_body: Node, weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2, attachment_item_id: String = "") -> void:
	var first_enemy := first_body as EnemyController
	if parent == null or weapon == null or damage_event == null or first_enemy == null:
		return
	var effect := LightningParticleEffect.new()
	parent.add_child(effect)
	effect._parent_root = parent
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._attachment_item_id = attachment_item_id
	effect._direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "lightning", {
		"damage": maxf(float(damage_event.damage) * 0.55, 1.0),
		"chain_count": 3.0,
		"chain_interval": 0.10,
		"jump_radius": 170.0,
		"stun_duration": 0.7,
		"detonate_burning": 1.0,
	}, effect._attachment_item_id)
	effect._remaining_jumps = maxi(0, int(roundi(effect._context.get_resolved_parameter("chain_count", 3.0) + effect._context.get_resolved_parameter("control_power", 0.0) / 10.0)))
	effect._jump_radius = maxf(effect._context.get_resolved_parameter("jump_radius", 170.0) * effect._context.get_resolved_parameter("area_size_multiplier", 1.0), 32.0)
	effect.call_deferred("_strike_chain", first_enemy, hit_position)


static func spawn_ground_strike(parent: Node, ground_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "", strike_height: float = 260.0) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := LightningParticleEffect.new()
	parent.add_child(effect)
	effect._parent_root = parent
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._attachment_item_id = attachment_item_id
	effect._direction = Vector2.DOWN
	effect._display_echo_count = GROUND_STRIKE_ECHO_COUNT
	effect._control_point_jitter_multiplier = GROUND_STRIKE_JITTER_MULTIPLIER
	effect._sample_jitter_multiplier = GROUND_STRIKE_SAMPLE_JITTER_MULTIPLIER
	effect._bolt_particle_spacing = GROUND_STRIKE_PARTICLE_SPACING
	effect._control_point_envelope_power = 0.65
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "electric_spark", {
		"damage": maxf(float(damage_event.damage) * 0.72, 1.0),
		"strike_height": strike_height,
	}, effect._attachment_item_id)
	effect._chain_finished = true
	effect.call_deferred("_strike_ground", ground_position)


func _strike_chain(target: Node, from_position: Vector2) -> void:
	if _weapon == null or _damage_event == null:
		_finish_chain()
		return
	var current := target as EnemyController
	if current == null:
		_finish_chain()
		return
	var key := current.get_instance_id()
	if _visited.has(key):
		_schedule_next(from_position)
		return
	_visited[key] = true
	if not current.is_alive():
		_emit_hit_burst(current.global_position, from_position.direction_to(current.global_position))
		_schedule_next(current.global_position)
		return
	_emit_bolt(from_position, current.global_position)
	_emit_hit_burst(current.global_position, from_position.direction_to(current.global_position))
	current.apply_lightning_stun(_context.get_resolved_parameter("stun_duration", 0.7))
	if current.has_status("burning") and _context.get_resolved_parameter("detonate_burning", 1.0) > 0.0:
		current.clear_burning()
		for explosion_instance in _weapon.get_effect_instances("explosion"):
			EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, current.global_position, _weapon, _damage_event, str(explosion_instance.get("item_instance_id", "")))
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	current.take_damage(damage, _damage_event.source_weapon_id, false, from_position.direction_to(current.global_position))
	if _remaining_jumps <= 0:
		_finish_chain()
		return
	_remaining_jumps -= 1
	_schedule_next(current.global_position)


func _strike_ground(ground_position: Vector2) -> void:
	if _context == null:
		queue_free()
		return
	var strike_height := maxf(_context.get_resolved_parameter("strike_height", 260.0), 96.0)
	_emit_bolt(ground_position + Vector2.UP * strike_height, ground_position)
	_emit_hit_burst(ground_position, Vector2.DOWN)
	_try_finish_chain()


func _schedule_next(origin: Vector2) -> void:
	if _remaining_jumps <= 0:
		_finish_chain()
		return
	var next_target := _find_nearest_enemy(origin)
	if next_target == null:
		_finish_chain()
		return
	var chain_interval := clampf(_context.get_resolved_parameter("chain_interval", 0.10), 0.02, 0.5)
	get_tree().create_timer(chain_interval).timeout.connect(Callable(self, "_strike_chain").bind(next_target, origin))


func _find_nearest_enemy(origin: Vector2) -> EnemyController:
	var nearest: EnemyController = null
	var nearest_distance := _jump_radius * _jump_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or _visited.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _emit_hit_burst(hit_position: Vector2, burst_direction: Vector2) -> void:
	var context_parameters := {
		"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0),
		"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0),
		"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0),
		"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0),
		"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0),
		"distance_multiplier": _context.get_resolved_parameter("area_size_multiplier", 1.0),
	}
	var intensity: float = float(_context.get_resolved_parameter("area_size_multiplier", 1.0))
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, "lightning_flash", hit_position, Vector2.ZERO, intensity, Color.WHITE, context_parameters)
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, "lightning_impact", hit_position, burst_direction, intensity, Color.WHITE, context_parameters)


func _emit_bolt(start_position: Vector2, end_position: Vector2) -> void:
	_emit_bolt_pulse(start_position, end_position)
	for echo_index in range(1, _display_echo_count):
		_pending_display_echoes += 1
		get_tree().create_timer(CHAIN_DISPLAY_ECHO_DELAY * float(echo_index)).timeout.connect(Callable(self, "_emit_bolt_echo").bind(start_position, end_position))


func _emit_bolt_echo(start_position: Vector2, end_position: Vector2) -> void:
	_pending_display_echoes = maxi(_pending_display_echoes - 1, 0)
	_emit_bolt_pulse(start_position, end_position)
	_try_finish_chain()


func _emit_bolt_pulse(start_position: Vector2, end_position: Vector2) -> void:
	var distance := start_position.distance_to(end_position)
	if distance <= 1.0:
		return
	var bolt_direction := start_position.direction_to(end_position)
	var perpendicular := bolt_direction.orthogonal()
	var strand_count := clampi(int(roundi(_context.get_resolved_parameter("projectile_count", 1.0))), 1, 3)
	var size_multiplier := clampf(_context.get_resolved_parameter("size_multiplier", 1.0), 0.5, 2.0)
	var glow_multiplier := clampf(_context.get_resolved_parameter("glow_multiplier", 1.0), 0.25, 3.0)
	var lifetime_multiplier := clampf(_context.get_resolved_parameter("lifetime_multiplier", 1.0), 0.5, 2.0)
	var alpha_multiplier := clampf(_context.get_resolved_parameter("alpha_multiplier", 1.0), 0.0, 2.0)
	var control_points := _build_bolt_control_points(
		start_position,
		end_position,
		bolt_direction,
		perpendicular,
		_control_point_jitter_multiplier
	)
	for strand_index in strand_count:
		var strand_offset := (float(strand_index) - float(strand_count - 1) * 0.5) * 1.2
		var particle_points := PackedVector2Array()
		var particle_rotations := PackedFloat32Array()
		for control_index in range(control_points.size() - 1):
			var segment_start: Vector2 = control_points[control_index] + perpendicular * strand_offset
			var segment_end: Vector2 = control_points[control_index + 1] + perpendicular * strand_offset
			var sample_count := maxi(1, int(ceil(segment_start.distance_to(segment_end) / _bolt_particle_spacing)))
			for sample_index in sample_count:
				var sample_ratio := float(sample_index) / float(sample_count)
				var sample_position := segment_start.lerp(segment_end, sample_ratio)
				var segment_direction := segment_start.direction_to(segment_end)
				if not segment_direction.is_zero_approx() and sample_index > 0 and sample_index < sample_count:
					var path_ratio := (float(control_index) + sample_ratio) / float(control_points.size() - 1)
					var jitter_envelope := pow(sin(path_ratio * PI), _control_point_envelope_power)
					sample_position += segment_direction.orthogonal() * randf_range(-BOLT_MICRO_JITTER, BOLT_MICRO_JITTER) * _sample_jitter_multiplier * jitter_envelope
					sample_position += segment_direction * randf_range(-0.7, 0.7) * jitter_envelope
				var sample_point := to_local(sample_position).round()
				if particle_points.is_empty() or particle_points[particle_points.size() - 1].distance_squared_to(sample_point) > 0.25:
					particle_points.append(sample_point)
					particle_rotations.append(randf_range(-PI, PI))
			var end_point := to_local(segment_end).round()
			if particle_points.is_empty() or particle_points[particle_points.size() - 1].distance_squared_to(end_point) > 0.25:
				particle_points.append(end_point)
				particle_rotations.append(randf_range(-PI, PI))
		var strand_color := Color.WHITE
		if strand_index > 0:
			strand_color.a = 0.9
		strand_color.a *= alpha_multiplier
		_bolt_pulses.append({
			"points": particle_points,
			"rotations": particle_rotations,
			"age": 0.0,
			"lifetime": BOLT_PULSE_LIFETIME * lifetime_multiplier,
			"color": strand_color,
			"size_multiplier": size_multiplier,
			"particle_size": BOLT_CORE_PARTICLE_SIZE if strand_index == 0 else BOLT_COMPANION_PARTICLE_SIZE,
			"glow_size": BOLT_GLOW_PARTICLE_SIZE * glow_multiplier,
			"is_core": strand_index == 0,
		})
	_emit_bolt_light(start_position.lerp(end_position, 0.5), distance, glow_multiplier)
	queue_redraw()


func _emit_bolt_light(global_position: Vector2, distance: float, glow_multiplier: float) -> void:
	if _parent_root == null:
		return
	var field := _parent_root.get_node_or_null("ParticleLightField")
	if field == null and get_tree() != null and get_tree().current_scene != null:
		field = get_tree().current_scene.find_child("ParticleLightField", true, false)
	if field != null and field.has_method("add_light"):
		field.call("add_light", global_position, Color(0.74, 0.90, 1.0, 1.0), 0.18 * glow_multiplier, clampf(distance * 0.42, 36.0, 130.0), BOLT_PULSE_LIFETIME)


func _finish_chain() -> void:
	_chain_finished = true
	_try_finish_chain()


func _try_finish_chain() -> void:
	if _chain_finished and _pending_display_echoes <= 0 and _bolt_pulses.is_empty():
		queue_free()


func _build_bolt_control_points(
	start_position: Vector2,
	end_position: Vector2,
	bolt_direction: Vector2,
	perpendicular: Vector2,
	jitter_multiplier: float = 1.0
) -> Array[Vector2]:
	var distance := start_position.distance_to(end_position)
	var control_count := maxi(1, int(ceil(distance / CHAIN_CONTROL_POINT_SPACING)))
	var control_points: Array[Vector2] = [start_position]
	for control_index in range(1, control_count):
		var t := float(control_index) / float(control_count)
		var envelope := pow(sin(t * PI), _control_point_envelope_power)
		var offset := randf_range(-CHAIN_CONTROL_POINT_JITTER, CHAIN_CONTROL_POINT_JITTER) * jitter_multiplier * envelope
		control_points.append(start_position.lerp(end_position, t) + perpendicular * offset)
	control_points.append(end_position)
	return control_points


func _ready() -> void:
	z_index = 81
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for index in range(_bolt_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _bolt_pulses[index]
		pulse["age"] = float(pulse.get("age", 0.0)) + delta
		if float(pulse["age"]) >= float(pulse["lifetime"]):
			_bolt_pulses.remove_at(index)
		else:
			_bolt_pulses[index] = pulse
	queue_redraw()
	_try_finish_chain()


func _draw() -> void:
	for pulse in _bolt_pulses:
		var points: PackedVector2Array = pulse["points"]
		if points.size() < 2:
			continue
		var lifetime := maxf(float(pulse.get("lifetime", BOLT_PULSE_LIFETIME)), 0.01)
		var age_ratio := clampf(float(pulse.get("age", 0.0)) / lifetime, 0.0, 1.0)
		var fade := (1.0 - age_ratio) * (1.0 - age_ratio)
		var base_color: Color = pulse["color"]
		var alpha := base_color.a * fade
		var base_particle_size: Vector2 = pulse["particle_size"]
		var particle_size := Vector2(
			clampf(base_particle_size.x * float(pulse["size_multiplier"]), 2.0, 5.0),
			clampf(base_particle_size.y * float(pulse["size_multiplier"]), 1.5, 4.0)
		)
		var glow_size := clampf(float(pulse["glow_size"]) * float(pulse["size_multiplier"]), 3.0, 10.0)
		var rotations: PackedFloat32Array = pulse.get("rotations", PackedFloat32Array())
		for point_index in points.size():
			var point: Vector2 = points[point_index]
			var particle_rotation := float(rotations[point_index]) if point_index < rotations.size() else 0.0
			draw_set_transform(point, particle_rotation, Vector2.ONE)
			var glow_alpha := alpha * (0.12 if point_index % 3 == 1 else 0.08)
			draw_rect(Rect2(Vector2(-glow_size * 0.62, -glow_size * 0.30), Vector2(glow_size * 1.24, glow_size * 0.60)), Color(1.0, 1.0, 1.0, glow_alpha))
			var particle_alpha := alpha * (0.72 if point_index % 3 == 1 else 0.9)
			draw_rect(Rect2(-particle_size * 0.5, particle_size), Color(1.0, 1.0, 1.0, particle_alpha))
			if bool(pulse.get("is_core", false)) and point_index % 5 == 0:
				var highlight_size := Vector2(minf(particle_size.x, 2.0), minf(particle_size.y, 2.0))
				draw_rect(Rect2(-highlight_size * 0.5, highlight_size), Color(1.0, 1.0, 1.0, alpha * 0.82))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
