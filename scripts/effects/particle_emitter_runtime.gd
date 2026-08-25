extends Node2D
class_name ParticleEmitterRuntime

const PARTICLE_EVENT_SCRIPT = preload("res://scripts/effects/particle_event.gd")
const PARTICLE_MOTION_BEHAVIOR_SCRIPT = preload("res://scripts/effects/particle_motion_behavior.gd")

var _world: Node2D = null
var _profile_id: String = ""
var _context: Variant = null
var _options: Dictionary = {}
var _direction: Vector2 = Vector2.RIGHT
var _anchor_node: Node2D = null
var _motion_state: Dictionary = {}
var _emission_accumulator: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false


func configure(
	world: Node2D,
	profile_id: String,
	context: Variant = null,
	options: Dictionary = {}
) -> void:
	_world = world
	_profile_id = profile_id
	_context = context
	_options = options.duplicate(true)
	_direction = _options.get("direction", Vector2.RIGHT)
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	else:
		_direction = _direction.normalized()
	_anchor_node = _options.get("anchor_node") as Node2D
	_motion_state = PARTICLE_MOTION_BEHAVIOR_SCRIPT.create_state(global_position, _direction, _options)
	_elapsed = 0.0
	_emission_accumulator = 0.0
	_active = _world != null and not _profile_id.is_empty()


func set_anchor_node(anchor_node: Node2D) -> void:
	_anchor_node = anchor_node


func set_direction(next_direction: Vector2) -> void:
	if next_direction.is_zero_approx():
		return
	_direction = next_direction.normalized()
	_motion_state["direction"] = _direction


func set_parameter(channel: String, value: Variant) -> void:
	if _context != null and _context.has_method("set_parameter"):
		_context.set_parameter(channel, value)
	else:
		_options[channel] = value


func set_color_override(color: Color) -> void:
	if _context != null and _context.has_method("set_color_override"):
		_context.set_color_override(color)
	else:
		_options["color_override"] = color


func stop() -> void:
	_active = false


func _process(delta: float) -> void:
	if not _active or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	var motion_type := str(_options.get("motion_type", "attached"))
	if motion_type != "attached":
		_motion_state = PARTICLE_MOTION_BEHAVIOR_SCRIPT.advance(_motion_state, delta, _get_anchor_position())
		global_position = _motion_state.get("position", global_position)
		_direction = _motion_state.get("direction", _direction)
	var particle_rate := maxf(_get_parameter("particle_rate", float(_options.get("particle_rate", 0.0))), 0.0)
	_emission_accumulator += particle_rate * delta
	var emission_count := mini(int(floor(_emission_accumulator)), int(_options.get("max_emissions_per_frame", 8)))
	if emission_count > 0:
		_emission_accumulator -= float(emission_count)
		for index in emission_count:
			_emit_particle()
	var lifetime := float(_options.get("lifetime", 0.0))
	if lifetime > 0.0 and _elapsed >= lifetime:
		queue_free()


func _emit_particle() -> void:
	if _world == null:
		return
	var color_override := Color.TRANSPARENT
	if _context != null and _context.has_method("get_resolved_color"):
		color_override = _context.get_resolved_color(Color.TRANSPARENT)
	if color_override.a <= 0.0:
		color_override = _options.get("color_override", Color.TRANSPARENT)
	var event := PARTICLE_EVENT_SCRIPT.create({
		"profile_id": _profile_id,
		"global_position": global_position,
		"direction": _direction,
		"intensity": _get_parameter("intensity_multiplier", 1.0),
		"color_override": color_override,
		"source_id": _get_source_id(),
		"tags": _get_tags(),
		"parameters": {
			"count_multiplier": _get_parameter("count_multiplier", 1.0),
			"speed_multiplier": _get_parameter("speed_multiplier", 1.0),
			"size_multiplier": _get_parameter("size_multiplier", 1.0),
			"lifetime_multiplier": _get_parameter("lifetime_multiplier", 1.0),
			"gravity_multiplier": _get_parameter("gravity_multiplier", 1.0),
			"drag_multiplier": _get_parameter("drag_multiplier", 1.0),
			"alpha_multiplier": _get_parameter("alpha_multiplier", 1.0),
			"glow_multiplier": _get_parameter("glow_multiplier", 1.0),
		},
	})
	_world.call("emit_event", event)


func _get_parameter(channel: String, fallback: float) -> float:
	if _context != null and _context.has_method("get_resolved_parameter"):
		return float(_context.get_resolved_parameter(channel, fallback))
	return float(_options.get(channel, fallback))


func _get_source_id() -> String:
	var effect_context: EffectContext = _context as EffectContext
	if effect_context != null:
		return effect_context.source_weapon_id
	return ""


func _get_tags() -> Array[String]:
	var result: Array[String] = []
	var effect_context: EffectContext = _context as EffectContext
	if effect_context != null:
		for tag in effect_context.tags:
			result.append(tag)
	return result


func _get_anchor_position() -> Vector2:
	if _anchor_node != null and is_instance_valid(_anchor_node):
		return _anchor_node.global_position
	return global_position
