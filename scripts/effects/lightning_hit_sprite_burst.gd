extends Node2D
## PNG particle frames share two instanced batches per hit. Movement and frame
## selection run on the GPU; live hits never compete with ParticleWorld slots.

const WORLD = preload("res://scripts/effects/particle_world.gd")
const DATA = preload("res://scripts/effects/lightning_hit_frame_data.gd")
const SHADER = preload("res://assets/shaders/lightning_hit_png.gdshader")
const FLASH_CORE = preload("res://assets/effects/lightning_hit_png/flash_core.png")
const FLASH_GLOW = preload("res://assets/effects/lightning_hit_png/flash_glow.png")
const IMPACT_CORE = preload("res://assets/effects/lightning_hit_png/impact_core.png")
const IMPACT_GLOW = preload("res://assets/effects/lightning_hit_png/impact_glow.png")

static var _random := RandomNumberGenerator.new()
static var _random_ready := false
var age := 0.0
var duration := 0.0
var flash_count := 0
var impact_count := 0
var batches: Array[MultiMeshInstance2D] = []
var _lifetimes := PackedFloat32Array()

static func spawn(parent: Node, point: Vector2, direction: Vector2, intensity: float, parameters: Dictionary) -> Node2D:
	if parent == null or not is_instance_valid(parent):
		return null
	if not _random_ready:
		_random.randomize()
		_random_ready = true
	var effect := new() as Node2D
	parent.add_child(effect)
	effect.global_position = point
	effect._configure(direction, maxf(intensity, 0.05), parameters)
	return effect

func _ready() -> void:
	z_index = 80
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("lightning_hit_sprite_bursts")
	add_to_group("combat_particle_counters")

func _configure(direction: Vector2, intensity: float, parameters: Dictionary) -> void:
	flash_count = _create_batch("lightning_flash", direction, intensity, parameters)
	impact_count = _create_batch("lightning_impact", direction, intensity, parameters)
	# These are the same two impact lights and radius multipliers as before.
	var field := WORLD.find_light_field(self)
	if field != null:
		for profile_id in ["lightning_flash", "lightning_impact"]:
			var profile: Dictionary = WORLD.PROFILE_DEFINITIONS[profile_id]
			field.call("add_light", global_position, profile.light_color, float(profile.light_energy) * intensity,
				float(profile.light_radius) * maxf(float(parameters.get("glow_radius_multiplier", 1.0)), 0.0))

func _create_batch(profile_id: String, direction: Vector2, intensity: float, parameters: Dictionary) -> int:
	var profile: Dictionary = WORLD.PROFILE_DEFINITIONS[profile_id]
	var count := maxi(1, roundi(float(profile["count"]) * intensity * maxf(float(parameters.get("count_multiplier", 1.0)), 0.0)))
	var is_flash := profile_id == "lightning_flash"
	var variants: Array[Dictionary] = DATA.FLASH if is_flash else DATA.IMPACT
	var lifetime_multiplier := maxf(float(parameters.get("lifetime_multiplier", 1.0)), 0.01)
	var speed_multiplier := maxf(float(parameters.get("speed_multiplier", 1.0)), 0.0)
	var distance_multiplier := maxf(float(parameters.get("distance_multiplier", 1.0)), 0.0)
	var size_multiplier := maxf(float(parameters.get("size_multiplier", 1.0)), 0.0)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * DATA.CELL
	instances.mesh = quad
	instances.instance_count = count
	var buffer := PackedFloat32Array()
	buffer.resize(count * 16)
	var extent := float(DATA.CELL) * size_multiplier + 8.0
	for index in count:
		var variant_index := _random.randi_range(0, DATA.VARIANT_COUNT - 1)
		var variant: Dictionary = variants[variant_index]
		var lifetime := float(variant.lifetime) * lifetime_multiplier
		_lifetimes.append(lifetime)
		duration = maxf(duration, lifetime)
		var heading := Vector2.from_angle(_random.randf_range(0.0, TAU))
		if not direction.is_zero_approx():
			heading = direction.normalized().rotated(_random.randf_range(-TAU, TAU))
		var speed_range: Vector2 = profile.speed
		var speed := _random.randf_range(speed_range.x, speed_range.y) * speed_multiplier
		if not is_flash:
			var travel: Vector2 = profile.travel_distance
			speed = _random.randf_range(travel.x, travel.y) * distance_multiplier * speed_multiplier / lifetime
		var initial := heading * _random.randf_range(0.0, float(profile.initial_radius))
		var velocity := heading * speed
		var gravity_range: Vector2 = profile.gravity_strength
		var gravity := _random.randf_range(gravity_range.x, gravity_range.y)
		var drag_range: Vector2 = profile.drag
		var drag := _random.randf_range(drag_range.x, drag_range.y)
		var first := index * 16
		buffer[first] = 1.0
		buffer[first + 3] = initial.x
		buffer[first + 5] = 1.0
		buffer[first + 7] = initial.y
		# Color channels carry normalized physics data, not visible particle tint.
		buffer[first + 8] = gravity / 100.0
		buffer[first + 9] = drag / 100.0
		buffer[first + 11] = 1.0
		buffer[first + 12] = velocity.x
		buffer[first + 13] = velocity.y
		buffer[first + 14] = lifetime
		buffer[first + 15] = float(variant_index)
		extent = maxf(extent, speed * lifetime + gravity * lifetime * lifetime + DATA.CELL * size_multiplier)
	instances.buffer = buffer
	instances.custom_aabb = AABB(Vector3(-extent, -extent, -1), Vector3(extent * 2.0, extent * 2.0, 2))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("core_frames", FLASH_CORE if is_flash else IMPACT_CORE)
	material.set_shader_parameter("glow_frames", FLASH_GLOW if is_flash else IMPACT_GLOW)
	material.set_shader_parameter("size_multiplier", size_multiplier)
	var glow := float(profile.glow)
	var glow_multiplier := maxf(float(parameters.get("glow_multiplier", 1.0)), 0.0)
	var radius_multiplier := maxf(float(parameters.get("glow_radius_multiplier", 1.0)), 0.0)
	material.set_shader_parameter("glow_scale", radius_multiplier * (1.5 + glow * glow_multiplier * 0.35) / (1.5 + glow * 0.35) if glow_multiplier > 0.0 else 0.0)
	material.set_shader_parameter("alpha_multiplier", maxf(float(parameters.get("alpha_multiplier", 1.0)), 0.0))
	var batch := MultiMeshInstance2D.new()
	batch.multimesh = instances
	batch.material = material
	add_child(batch)
	batches.append(batch)
	return count

func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	age += delta
	if age >= duration:
		queue_free()
		return
	for batch in batches:
		batch.material.set_shader_parameter("elapsed", age)

func get_active_particle_count() -> int:
	var active := 0
	for lifetime in _lifetimes:
		if age < lifetime:
			active += 1
	return active
