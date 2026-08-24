extends Node2D

const PARTICLE_EVENT_SCRIPT = preload("res://scripts/effects/particle_event.gd")
const PARTICLE_WORLD_PATH: String = "res://scripts/effects/particle_world.gd"

const MAX_PARTICLES: int = 900
const PROFILE_DEFINITIONS: Dictionary = {
	"impact_green": {
		"count": 26,
		"speed": Vector2(72.0, 205.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(55.0, 135.0),
		"drag": Vector2(30.0, 76.0),
		"size_min": Vector2(5.0, 5.0),
		"size_max": Vector2(9.0, 10.0),
		"lifetime": Vector2(0.36, 0.62),
		"spread_radians": PI * 0.72,
		"initial_radius": 4.5,
		"alpha": 1.0,
		"colors": [
			Color(0.17, 0.38, 0.27, 1.0),
			Color(0.22, 0.49, 0.32, 1.0),
			Color(0.28, 0.57, 0.37, 1.0),
			Color(0.35, 0.65, 0.42, 1.0),
			Color(0.43, 0.72, 0.48, 1.0),
			Color(0.25, 0.52, 0.46, 1.0),
		],
	},
	"projectile_trail": {
		"count": 1,
		"speed": Vector2(8.0, 28.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(18.0, 36.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(4.0, 4.0),
		"lifetime": Vector2(0.10, 0.20),
		"spread_radians": PI * 0.45,
		"initial_radius": 1.5,
		"alpha": 0.62,
		"colors": [Color(0.43, 0.72, 0.48, 1.0)],
	},
	"impact_terrain": {
		"count": 9,
		"speed": Vector2(28.0, 92.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(80.0, 160.0),
		"drag": Vector2(25.0, 60.0),
		"size_min": Vector2(3.0, 3.0),
		"size_max": Vector2(6.0, 6.0),
		"lifetime": Vector2(0.24, 0.44),
		"spread_radians": PI * 0.85,
		"initial_radius": 2.0,
		"alpha": 0.94,
		"colors": [
			Color(0.36, 0.25, 0.16, 1.0),
			Color(0.50, 0.36, 0.21, 1.0),
			Color(0.63, 0.48, 0.30, 1.0),
			Color(0.46, 0.46, 0.38, 1.0),
		],
	},
}

var _particles: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	queue_redraw()


static func emit_profile(
	parent: Node,
	profile_id: String,
	global_position: Vector2,
	direction: Vector2 = Vector2.ZERO,
	intensity: float = 1.0,
	color_override: Color = Color.TRANSPARENT
) -> Node2D:
	var event: Variant = PARTICLE_EVENT_SCRIPT.create({
		"profile_id": profile_id,
		"global_position": global_position,
		"direction": direction,
		"intensity": intensity,
		"color_override": color_override,
	})
	return emit(parent, event)


static func emit(parent: Node, event: Variant) -> Node2D:
	if parent == null or event == null:
		return null
	var world: Node2D = _find_world(parent)
	if world == null:
		var world_script: Script = load(PARTICLE_WORLD_PATH)
		world = world_script.new() as Node2D
		world.name = "ParticleWorld"
		world.z_index = 80
		parent.add_child(world)
	world.call("emit_event", event)
	return world


static func _find_world(parent: Node) -> Node2D:
	var current: Node = parent
	while current != null:
		if _is_particle_world(current):
			return current as Node2D
		var child := current.get_node_or_null("ParticleWorld") as Node2D
		if child != null and _is_particle_world(child):
			return child
		current = current.get_parent()
	return null


static func _is_particle_world(node: Node) -> bool:
	var script: Script = node.get_script()
	return script != null and script.resource_path == PARTICLE_WORLD_PATH


func emit_event(event: Variant) -> void:
	var profile_id: String = str(event.get("profile_id"))
	if profile_id.is_empty() or not PROFILE_DEFINITIONS.has(profile_id):
		return
	var profile: Dictionary = PROFILE_DEFINITIONS[profile_id]
	var intensity: float = maxf(float(event.get("intensity")), 0.05)
	var count := maxi(1, int(roundi(float(profile["count"]) * intensity)))
	var event_direction: Vector2 = event.get("direction")
	var base_direction: Vector2 = event_direction.normalized() if not event_direction.is_zero_approx() else Vector2.ZERO
	var event_position: Vector2 = event.get("global_position")
	var position: Vector2 = to_local(event_position)
	for index in count:
		if _particles.size() >= MAX_PARTICLES:
			break
		var direction := Vector2.from_angle(_random.randf_range(0.0, TAU))
		if not base_direction.is_zero_approx():
			direction = base_direction.rotated(_random.randf_range(-float(profile["spread_radians"]), float(profile["spread_radians"])))
		var speed_range: Vector2 = profile["speed"]
		var gravity_range: Vector2 = profile["gravity_strength"]
		var drag_range: Vector2 = profile["drag"]
		var size_min: Vector2 = profile["size_min"]
		var size_max: Vector2 = profile["size_max"]
		var lifetime_range: Vector2 = profile["lifetime"]
		var size := Vector2(
			float(_random.randi_range(int(size_min.x), int(size_max.x))),
			float(_random.randi_range(int(size_min.y), int(size_max.y)))
		)
		var particle_lifetime := _random.randf_range(lifetime_range.x, lifetime_range.y)
		var event_color: Color = event.get("color_override")
		var particle_color := _resolve_color(profile, event_color)
		_particles.append({
			"position": position + direction * _random.randf_range(0.0, float(profile["initial_radius"])),
			"velocity": direction * _random.randf_range(speed_range.x, speed_range.y),
			"gravity": Vector2(profile["gravity"].x, profile["gravity"].y * _random.randf_range(gravity_range.x, gravity_range.y)),
			"drag": _random.randf_range(drag_range.x, drag_range.y),
			"rotation": _random.randf_range(-0.35, 0.35),
			"spin": _random.randf_range(-5.0, 5.0),
			"size": size,
			"color": particle_color,
			"lifetime": particle_lifetime,
		})
	queue_redraw()


func _resolve_color(profile: Dictionary, color_override: Color) -> Color:
	var color := color_override
	if color.a <= 0.0:
		var colors: Array = profile["colors"]
		color = colors[_random.randi_range(0, colors.size() - 1)]
	else:
		var brightness := _random.randf_range(0.84, 1.16)
		color = Color(
			clampf(color.r * brightness, 0.0, 1.0),
			clampf(color.g * brightness, 0.0, 1.0),
			clampf(color.b * brightness, 0.0, 1.0),
			color.a
		)
	color.a *= float(profile["alpha"])
	return color


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		var velocity: Vector2 = particle["velocity"]
		velocity = velocity.move_toward(Vector2.ZERO, float(particle["drag"]) * delta)
		velocity += particle["gravity"] * delta
		particle["velocity"] = velocity
		particle["position"] = particle["position"] + velocity * delta
		particle["rotation"] = float(particle["rotation"]) + float(particle["spin"]) * delta
		particle["age"] = float(particle.get("age", 0.0)) + delta
		_particles[index] = particle
		if float(particle["age"]) >= float(particle["lifetime"]):
			_particles.remove_at(index)
	queue_redraw()


func _draw() -> void:
	for particle in _particles:
		var lifetime := maxf(float(particle["lifetime"]), 0.01)
		var fade := clampf(1.0 - float(particle.get("age", 0.0)) / lifetime, 0.0, 1.0)
		var color: Color = particle["color"]
		color.a *= fade * fade
		var position: Vector2 = particle["position"]
		var size: Vector2 = particle["size"]
		draw_set_transform(position.round(), float(particle["rotation"]), Vector2.ONE)
		draw_rect(Rect2(-size * 0.5, size), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
