extends Node2D

const PARTICLE_EVENT_SCRIPT = preload("res://scripts/effects/particle_event.gd")
const PARTICLE_EMITTER_RUNTIME_SCRIPT = preload("res://scripts/effects/particle_emitter_runtime.gd")
const PARTICLE_WORLD_PATH: String = "res://scripts/effects/particle_world.gd"
const PARTICLE_LIGHT_FIELD_PATH: String = "res://scripts/effects/particle_light_field.gd"

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

	"fire_flame": {
		"count": 5,
		"speed": Vector2(18.0, 76.0),
		"gravity": Vector2(0.0, -1.0),
		"gravity_strength": Vector2(24.0, 68.0),
		"drag": Vector2(12.0, 34.0),
		"size_min": Vector2(3.0, 4.0),
		"size_max": Vector2(7.0, 11.0),
		"lifetime": Vector2(0.18, 0.42),
		"spread_radians": PI,
		"initial_radius": 12.0,
		"alpha": 0.90,
		"shape": "circle",
		"glow": 1.4,
		"light_color": Color(1.0, 0.22, 0.04, 1.0),
		"light_energy": 0.42,
		"light_radius": 52.0,
		"colors": [Color(1.0, 0.22, 0.02, 1.0), Color(1.0, 0.55, 0.04, 1.0), Color(1.0, 0.88, 0.20, 1.0)],
	},
	"fire_pool_flame": {
		"count": 4,
		"speed": Vector2(12.0, 58.0),
		"gravity": Vector2(0.0, -1.0),
		"gravity_strength": Vector2(18.0, 56.0),
		"drag": Vector2(10.0, 28.0),
		"size_min": Vector2(3.0, 4.0),
		"size_max": Vector2(8.0, 12.0),
		"lifetime": Vector2(0.22, 0.48),
		"spread_radians": PI * 0.35,
		"initial_radius": 5.0,
		"alpha": 0.94,
		"shape": "circle",
		"glow": 1.55,
		"light_color": Color(1.0, 0.24, 0.04, 1.0),
		"light_energy": 0.34,
		"light_radius": 42.0,
		"colors": [Color(1.0, 0.18, 0.01, 1.0), Color(1.0, 0.48, 0.02, 1.0), Color(1.0, 0.82, 0.14, 1.0)],
	},
	"fire_pool_ember": {
		"count": 3,
		"speed": Vector2(8.0, 32.0),
		"gravity": Vector2(0.0, -1.0),
		"gravity_strength": Vector2(6.0, 24.0),
		"drag": Vector2(16.0, 38.0),
		"size_min": Vector2(1.0, 1.0),
		"size_max": Vector2(3.0, 4.0),
		"lifetime": Vector2(0.18, 0.38),
		"spread_radians": PI * 0.8,
		"initial_radius": 3.0,
		"alpha": 0.96,
		"shape": "circle",
		"glow": 1.2,
		"colors": [Color(1.0, 0.92, 0.34, 1.0), Color(1.0, 0.58, 0.06, 1.0)],
	},
	"fire_spark": {
		"count": 7,
		"speed": Vector2(36.0, 110.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(30.0, 90.0),
		"drag": Vector2(24.0, 56.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(4.0, 4.0),
		"lifetime": Vector2(0.16, 0.34),
		"spread_radians": TAU,
		"initial_radius": 7.0,
		"alpha": 0.95,
		"shape": "circle",
		"glow": 1.8,
		"colors": [Color(1.0, 0.78, 0.22, 1.0), Color(1.0, 0.45, 0.06, 1.0)],
	},
	"explosion_flash": {
		"count": 22,
		"speed": Vector2(18.0, 46.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(42.0, 80.0),
		"size_min": Vector2(5.0, 5.0),
		"size_max": Vector2(13.0, 13.0),
		"lifetime": Vector2(0.12, 0.24),
		"spread_radians": TAU,
		"initial_radius": 8.0,
		"alpha": 0.92,
		"shape": "circle",
		"glow": 2.8,
		"light_color": Color(1.0, 0.74, 0.25, 1.0),
		"light_energy": 1.2,
		"light_radius": 120.0,
		"colors": [Color.WHITE, Color(1.0, 0.84, 0.36, 1.0), Color(1.0, 0.38, 0.08, 1.0)],
	},
	"explosion_hot_flash": {
		"count": 8,
		"speed": Vector2(2.0, 12.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(46.0, 90.0),
		"size_min": Vector2(5.0, 5.0),
		"size_max": Vector2(11.0, 11.0),
		"lifetime": Vector2(0.16, 0.30),
		"spread_radians": TAU,
		"initial_radius": 3.0,
		"alpha": 1.0,
		"shape": "circle",
		"glow": 3.2,
		"light_color": Color(1.0, 0.78, 0.32, 1.0),
		"light_energy": 1.15,
		"light_radius": 104.0,
		"colors": [Color(1.0, 0.96, 0.76, 1.0), Color(1.0, 0.82, 0.34, 1.0)],
	},
	"explosion_wave": {
		"count": 30,
		"speed": Vector2(0.0, 0.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(0.0, 0.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(5.0, 5.0),
		"lifetime": Vector2(0.16, 0.28),
		"travel_distance": Vector2(60.0, 96.0),
		"spread_radians": TAU,
		"initial_radius": 3.0,
		"alpha": 0.95,
		"shape": "circle",
		"glow": 2.2,
		"light_color": Color(1.0, 0.78, 0.32, 1.0),
		"light_energy": 0.42,
		"light_radius": 92.0,
		"colors": [Color.WHITE, Color(1.0, 0.88, 0.42, 1.0), Color(1.0, 0.48, 0.08, 1.0)],
	},
	"explosion_spark": {
		"count": 34,
		"speed": Vector2(0.0, 0.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(8.0, 38.0),
		"drag": Vector2(0.0, 0.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(5.0, 6.0),
		"lifetime": Vector2(0.18, 0.38),
		"travel_distance": Vector2(72.0, 128.0),
		"spread_radians": TAU,
		"initial_radius": 4.0,
		"alpha": 1.0,
		"shape": "square",
		"glow": 1.25,
		"light_color": Color(1.0, 0.74, 0.26, 1.0),
		"light_energy": 0.72,
		"light_radius": 192.0,
		"colors": [Color(1.0, 0.94, 0.68, 1.0), Color(1.0, 0.76, 0.24, 1.0), Color(1.0, 0.44, 0.08, 1.0)],
	},
	"explosion_debris": {
		"count": 42,
		"speed": Vector2(70.0, 190.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(120.0, 240.0),
		"drag": Vector2(20.0, 64.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(7.0, 7.0),
		"lifetime": Vector2(0.25, 0.58),
		"spread_radians": TAU,
		"initial_radius": 9.0,
		"alpha": 0.9,
		"shape": "square",
		"glow": 0.8,
		"colors": [Color(0.34, 0.24, 0.16, 1.0), Color(0.68, 0.40, 0.16, 1.0), Color(0.92, 0.66, 0.28, 1.0)],
	},
	"explosion_soil_debris": {
		"count": 6,
		"speed": Vector2(54.0, 168.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(110.0, 220.0),
		"drag": Vector2(18.0, 58.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(6.0, 6.0),
		"lifetime": Vector2(0.24, 0.52),
		"spread_radians": TAU,
		"initial_radius": 4.0,
		"alpha": 0.9,
		"shape": "square",
		"glow": 0.45,
		"colors": [Color(0.42, 0.27, 0.15, 1.0), Color(0.62, 0.40, 0.21, 1.0)],
	},
	"explosion_wood_debris": {
		"count": 5,
		"speed": Vector2(72.0, 190.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(90.0, 190.0),
		"drag": Vector2(14.0, 46.0),
		"size_min": Vector2(2.0, 1.0),
		"size_max": Vector2(8.0, 3.0),
		"lifetime": Vector2(0.22, 0.48),
		"spread_radians": TAU,
		"initial_radius": 4.0,
		"alpha": 0.92,
		"shape": "square",
		"glow": 0.35,
		"colors": [Color(0.50, 0.28, 0.12, 1.0), Color(0.78, 0.48, 0.22, 1.0)],
	},
	"explosion_stone_debris": {
		"count": 4,
		"speed": Vector2(42.0, 132.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(130.0, 250.0),
		"drag": Vector2(28.0, 72.0),
		"size_min": Vector2(3.0, 3.0),
		"size_max": Vector2(8.0, 8.0),
		"lifetime": Vector2(0.28, 0.62),
		"spread_radians": TAU,
		"initial_radius": 4.0,
		"alpha": 0.9,
		"shape": "square",
		"glow": 0.25,
		"colors": [Color(0.38, 0.41, 0.40, 1.0), Color(0.62, 0.66, 0.63, 1.0)],
	},
	"lightning_core": {
		"count": 3,
		"speed": Vector2(24.0, 72.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(36.0, 72.0),
		"size_min": Vector2(2.0, 4.0),
		"size_max": Vector2(4.0, 10.0),
		"lifetime": Vector2(0.20, 0.36),
		"spread_radians": TAU,
		"initial_radius": 2.0,
		"alpha": 1.0,
		"shape": "square",
		"glow": 0.9,
		"colors": [Color.WHITE, Color(0.90, 0.96, 1.0, 1.0)],
	},
	"lightning_blue": {
		"count": 2,
		"speed": Vector2(30.0, 110.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(40.0, 84.0),
		"size_min": Vector2(2.0, 5.0),
		"size_max": Vector2(4.0, 12.0),
		"lifetime": Vector2(0.24, 0.42),
		"spread_radians": TAU,
		"initial_radius": 3.0,
		"alpha": 0.86,
		"shape": "square",
		"glow": 0.7,
		"colors": [Color(0.12, 0.50, 1.0, 1.0), Color(0.34, 0.76, 1.0, 1.0), Color(0.16, 0.32, 0.92, 1.0)],
	},
	"lightning_spark": {
		"count": 2,
		"speed": Vector2(55.0, 180.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(10.0, 40.0),
		"drag": Vector2(30.0, 70.0),
		"size_min": Vector2(2.0, 3.0),
		"size_max": Vector2(3.0, 8.0),
		"lifetime": Vector2(0.28, 0.52),
		"spread_radians": TAU,
		"initial_radius": 4.0,
		"alpha": 1.0,
		"shape": "square",
		"glow": 0.5,
		"colors": [Color.WHITE, Color(0.82, 0.94, 1.0, 1.0), Color(0.58, 0.78, 1.0, 1.0)],
	},
	"lightning_filament": {
		"count": 1,
		"speed": Vector2(0.0, 1.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(80.0, 140.0),
		"size_min": Vector2(3.0, 1.0),
		"size_max": Vector2(6.0, 1.0),
		"lifetime": Vector2(0.34, 0.56),
		"spread_radians": 0.0,
		"initial_radius": 0.0,
		"alpha": 1.0,
		"shape": "square",
		"align_to_direction": true,
		"rotation_jitter": 0.22,
		"glow": 0.8,
		"glow_shape": "streak",
		"light_color": Color(0.74, 0.90, 1.0, 1.0),
		"light_energy": 0.05,
		"light_radius": 22.0,
		"colors": [Color.WHITE, Color(0.88, 0.96, 1.0, 1.0)],
	},
	"lightning_filament_core": {
		"count": 1,
		"speed": Vector2(0.0, 1.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(80.0, 140.0),
		"size_min": Vector2(5.0, 1.0),
		"size_max": Vector2(10.0, 2.0),
		"lifetime": Vector2(0.30, 0.50),
		"spread_radians": 0.0,
		"initial_radius": 0.0,
		"alpha": 1.0,
		"shape": "square",
		"align_to_direction": true,
		"rotation_jitter": 0.12,
		"glow": 0.65,
		"glow_shape": "streak",
		"light_color": Color(0.86, 0.96, 1.0, 1.0),
		"light_energy": 0.03,
		"light_radius": 20.0,
		"colors": [Color.WHITE, Color(0.94, 0.99, 1.0, 1.0)],
	},
	"lightning_flash": {
		"count": 5,
		"speed": Vector2(2.0, 10.0),
		"gravity": Vector2.ZERO,
		"gravity_strength": Vector2.ZERO,
		"drag": Vector2(46.0, 90.0),
		"size_min": Vector2(4.0, 4.0),
		"size_max": Vector2(9.0, 9.0),
		"lifetime": Vector2(0.18, 0.32),
		"spread_radians": TAU,
		"initial_radius": 2.0,
		"alpha": 1.0,
		"shape": "circle",
		"glow": 2.4,
		"light_color": Color.WHITE,
		"light_energy": 1.0,
		"light_radius": 86.0,
		"colors": [Color.WHITE, Color(0.88, 0.97, 1.0, 1.0)],
	},
	"lightning_impact": {
		"count": 30,
		"speed": Vector2(0.0, 0.0),
		"gravity": Vector2(0.0, 1.0),
		"gravity_strength": Vector2(10.0, 55.0),
		"drag": Vector2(0.0, 0.0),
		"size_min": Vector2(2.0, 2.0),
		"size_max": Vector2(5.0, 6.0),
		"lifetime": Vector2(0.18, 0.38),
		"travel_distance": Vector2(120.0, 240.0),
		"spread_radians": TAU,
		"initial_radius": 4.0,
		"alpha": 1.0,
		"shape": "square",
		"glow": 1.15,
		"light_color": Color(0.76, 0.92, 1.0, 1.0),
		"light_energy": 0.65,
		"light_radius": 200.0,
		"colors": [Color.WHITE, Color(0.94, 0.99, 1.0, 1.0), Color(0.52, 0.78, 1.0, 1.0)],
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
	color_override: Color = Color.TRANSPARENT,
	parameters: Dictionary = {}
) -> Node2D:
	var event: Variant = PARTICLE_EVENT_SCRIPT.create({
		"profile_id": profile_id,
		"global_position": global_position,
		"direction": direction,
		"intensity": intensity,
		"color_override": color_override,
		"parameters": parameters.duplicate(true),
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


static func create_emitter(
	parent: Node,
	profile_id: String,
	context: Variant = null,
	options: Dictionary = {}
) -> Node2D:
	if parent == null:
		return null
	var world: Node2D = _find_world(parent)
	if world == null:
		var world_script: Script = load(PARTICLE_WORLD_PATH)
		world = world_script.new() as Node2D
		world.name = "ParticleWorld"
		world.z_index = 80
		parent.add_child(world)
	var emitter := PARTICLE_EMITTER_RUNTIME_SCRIPT.new() as Node2D
	if emitter == null:
		return null
	parent.add_child(emitter)
	emitter.call("configure", world, profile_id, context, options)
	return emitter


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
	var parameters: Dictionary = event.get("parameters", {})
	var count_multiplier := maxf(float(parameters.get("count_multiplier", 1.0)), 0.0)
	var count := maxi(1, int(roundi(float(profile["count"]) * intensity * count_multiplier)))
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
		var speed_multiplier := maxf(float(parameters.get("speed_multiplier", 1.0)), 0.0)
		var size_multiplier := maxf(float(parameters.get("size_multiplier", 1.0)), 0.0)
		var lifetime_multiplier := maxf(float(parameters.get("lifetime_multiplier", 1.0)), 0.01)
		var gravity_multiplier := maxf(float(parameters.get("gravity_multiplier", 1.0)), 0.0)
		var drag_multiplier := maxf(float(parameters.get("drag_multiplier", 1.0)), 0.0)
		var alpha_multiplier := maxf(float(parameters.get("alpha_multiplier", 1.0)), 0.0)
		var glow_multiplier := maxf(float(parameters.get("glow_multiplier", 1.0)), 0.0)
		var size := Vector2(
			float(_random.randi_range(int(size_min.x), int(size_max.x))),
			float(_random.randi_range(int(size_min.y), int(size_max.y)))
		) * size_multiplier
		var particle_lifetime := _random.randf_range(lifetime_range.x, lifetime_range.y) * lifetime_multiplier
		var particle_speed := _random.randf_range(speed_range.x, speed_range.y) * speed_multiplier
		var travel_distance: Vector2 = profile.get("travel_distance", Vector2.ZERO)
		if travel_distance.x > 0.0 or travel_distance.y > 0.0:
			var distance_multiplier := maxf(float(parameters.get("distance_multiplier", 1.0)), 0.0)
			var desired_distance := _random.randf_range(travel_distance.x, travel_distance.y) * distance_multiplier * speed_multiplier
			particle_speed = desired_distance / maxf(particle_lifetime, 0.01)
		var event_color: Color = event.get("color_override")
		var particle_color := _resolve_color(profile, event_color)
		var rotation_jitter := float(profile.get("rotation_jitter", 0.35))
		var particle_rotation := _random.randf_range(-rotation_jitter, rotation_jitter)
		if bool(profile.get("align_to_direction", false)) and not base_direction.is_zero_approx():
			particle_rotation = base_direction.angle() + _random.randf_range(-rotation_jitter, rotation_jitter)
		_particles.append({
			"position": position + direction * _random.randf_range(0.0, float(profile["initial_radius"])),
			"velocity": direction * particle_speed,
			"gravity": Vector2(profile["gravity"].x, profile["gravity"].y * _random.randf_range(gravity_range.x, gravity_range.y) * gravity_multiplier),
			"drag": _random.randf_range(drag_range.x, drag_range.y) * drag_multiplier,
			"rotation": particle_rotation,
			"spin": _random.randf_range(-5.0, 5.0),
			"size": size,
			"color": particle_color,
			"lifetime": particle_lifetime,
			"alpha_multiplier": alpha_multiplier,
			"glow": float(profile.get("glow", 0.0)) * glow_multiplier,
			"glow_shape": str(profile.get("glow_shape", "circle")),
			"shape": str(profile.get("shape", "square")),
		})
	_emit_profile_light(profile, event_position, intensity)
	queue_redraw()


func _emit_profile_light(profile: Dictionary, event_position: Vector2, intensity: float) -> void:
	var light_energy := float(profile.get("light_energy", 0.0)) * intensity
	if light_energy <= 0.0:
		return
	var field := _find_light_field()
	if field != null:
		field.call("add_light", event_position, profile.get("light_color", Color.WHITE), light_energy, float(profile.get("light_radius", 64.0)))


func _find_light_field() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	var direct := parent.get_node_or_null("ParticleLightField")
	if direct != null and direct.has_method("add_light"):
		return direct
	var root := get_tree().current_scene if get_tree() != null else null
	if root != null:
		var found := root.find_child("ParticleLightField", true, false)
		if found != null and found.has_method("add_light"):
			return found
	return null


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
		color.a *= fade * fade * float(particle.get("alpha_multiplier", 1.0))
		var position: Vector2 = particle["position"]
		var size: Vector2 = particle["size"]
		var glow := float(particle.get("glow", 0.0))
		draw_set_transform(position.round(), float(particle["rotation"]), Vector2.ONE)
		if glow > 0.0:
			var glow_color := Color(color.r, color.g, color.b, color.a * 0.12)
			if str(particle.get("glow_shape", "circle")) == "streak":
				var glow_size := Vector2(size.x * (0.9 + glow * 0.25), maxf(size.y, 1.0) * (1.1 + glow * 0.35))
				draw_rect(Rect2(-glow_size * 0.5, glow_size), glow_color)
			else:
				draw_circle(Vector2.ZERO, maxf(size.x, size.y) * (1.5 + glow * 0.35), glow_color)
		if str(particle.get("shape", "square")) == "circle":
			draw_circle(Vector2.ZERO, maxf(size.x, size.y) * 0.5, color)
		else:
			draw_rect(Rect2(-size * 0.5, size), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
