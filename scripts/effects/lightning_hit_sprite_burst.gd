extends Node2D
## Compatible hits born in one frame share two instanced batches. Movement and frame
## selection run on the GPU; live hits never compete with ParticleWorld slots.

const WORLD = preload("res://scripts/effects/particle_world.gd")
const VISUAL_BUDGET = preload("res://scripts/effects/effect_visual_budget.gd")
const DATA = preload("res://scripts/effects/lightning_hit_frame_data.gd")
const SHADER = preload("res://assets/shaders/lightning_hit_png.gdshader")
const FLASH_CORE = preload("res://assets/effects/lightning_hit_png/flash_core.png")
const FLASH_GLOW = preload("res://assets/effects/lightning_hit_png/flash_glow.png")
const IMPACT_CORE = preload("res://assets/effects/lightning_hit_png/impact_core.png")
const IMPACT_GLOW = preload("res://assets/effects/lightning_hit_png/impact_glow.png")

static var _random := RandomNumberGenerator.new()
static var _random_ready := false
const POOL_META := &"lightning_hit_batch_pool"
const MAX_IDLE_BATCHES := 8
static var _quad: QuadMesh
var age := 0.0
var duration := 0.0
var flash_count := 0
var impact_count := 0
var batches: Array[MultiMeshInstance2D] = []
var _lifetimes := PackedFloat32Array()
var _buffers: Array[PackedFloat32Array] = []
var _extents: Array[float] = []
var _parameters: Dictionary = {}
var _birth_frame := -1
var _active := false
var _upload_pending := false

static func claim_tier(parent: Node, point: Vector2) -> int:
	if parent == null or not is_instance_valid(parent):
		return VISUAL_BUDGET.Tier.SUPPRESSED
	return VISUAL_BUDGET.claim_visual(parent, "lightning_hit", point)

static func spawn(parent: Node, point: Vector2, direction: Vector2, intensity: float, parameters: Dictionary) -> Node2D:
	return spawn_admitted(parent, point, direction, intensity, parameters, claim_tier(parent, point))

## Consumes an already claimed tier. Never claims again: callers can avoid
## building visual parameters for suppressed hits without changing density.
static func spawn_admitted(parent: Node, point: Vector2, direction: Vector2, intensity: float, parameters: Dictionary, tier: int) -> Node2D:
	if tier == VISUAL_BUDGET.Tier.SUPPRESSED or not is_instance_valid(parent): return null
	if tier > 0:
		parameters = parameters.duplicate()
		parameters.count_multiplier = float(parameters.get("count_multiplier", 1.0)) * 0.5
		parameters.glow_multiplier = float(parameters.get("glow_multiplier", 1.0)) * 0.5
		if tier == 2:
			parameters["visual_cap"] = 2
			parameters.glow_multiplier = 0.0
			parameters["skip_lights"] = true
	if not _random_ready:
		_random.randomize()
		_random_ready = true
	var pool: Array = parent.get_meta(POOL_META, [])
	var effect: Node2D
	var idle: Node2D
	for candidate in pool:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): continue
		if not candidate._active:
			idle = candidate
		elif candidate._birth_frame == Engine.get_process_frames() and candidate.age == 0.0 and candidate._parameters == parameters:
			effect = candidate
			break
	if effect == null:
		effect = idle
		if effect == null:
			effect = new() as Node2D
			parent.add_child(effect)
			pool.append(effect)
			parent.set_meta(POOL_META, pool)
		effect.global_position = point
		effect._activate(parameters)
	effect._configure(direction, maxf(intensity, 0.05), parameters, effect.to_local(point), point)
	return effect

func _ready() -> void:
	z_index = 80
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)

func _activate(parameters: Dictionary) -> void:
	age = 0.0
	duration = 0.0
	flash_count = 0
	impact_count = 0
	_lifetimes.clear()
	_parameters = parameters.duplicate(true)
	_birth_frame = Engine.get_process_frames()
	_active = true
	for index in _buffers.size():
		_buffers[index] = PackedFloat32Array()
		_extents[index] = 0.0
		batches[index].multimesh.visible_instance_count = 0
		batches[index].material.set_shader_parameter("elapsed", 0.0)
	add_to_group("lightning_hit_sprite_bursts")
	add_to_group("combat_particle_counters")
	show()
	set_process(true)

func _configure(direction: Vector2, intensity: float, parameters: Dictionary, offset := Vector2.ZERO, point := Vector2.ZERO) -> void:
	flash_count += _create_batch("lightning_flash", direction, intensity, parameters, offset)
	impact_count += _create_batch("lightning_impact", direction, intensity, parameters, offset)
	if not _upload_pending:
		_upload_pending = true
		_flush_batches.call_deferred()
	# These are the same two impact lights and radius multipliers as before.
	var field := WORLD.find_light_field(self)
	if field != null and not bool(parameters.get("skip_lights", false)):
		for profile_id in ["lightning_flash", "lightning_impact"]:
			var profile: Dictionary = WORLD.PROFILE_DEFINITIONS[profile_id]
			field.call("add_light", point, profile.light_color, float(profile.light_energy) * intensity,
				float(profile.light_radius) * maxf(float(parameters.get("glow_radius_multiplier", 1.0)), 0.0))

func _create_batch(profile_id: String, direction: Vector2, intensity: float, parameters: Dictionary, offset: Vector2) -> int:
	var profile: Dictionary = WORLD.PROFILE_DEFINITIONS[profile_id]
	var count := maxi(1, roundi(float(profile["count"]) * intensity * maxf(float(parameters.get("count_multiplier", 1.0)), 0.0)))
	if parameters.has("visual_cap"): count = mini(count, int(parameters.visual_cap))
	var is_flash := profile_id == "lightning_flash"
	var variants: Array[Dictionary] = DATA.FLASH if is_flash else DATA.IMPACT
	var lifetime_multiplier := maxf(float(parameters.get("lifetime_multiplier", 1.0)), 0.01)
	var speed_multiplier := maxf(float(parameters.get("speed_multiplier", 1.0)), 0.0)
	var distance_multiplier := maxf(float(parameters.get("distance_multiplier", 1.0)), 0.0)
	var size_multiplier := maxf(float(parameters.get("size_multiplier", 1.0)), 0.0)
	var batch_index := 0 if is_flash else 1
	if batches.size() <= batch_index:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_2D
		instances.use_colors = true
		instances.use_custom_data = true
		if _quad == null:
			_quad = QuadMesh.new()
			_quad.size = Vector2.ONE * DATA.CELL
		instances.mesh = _quad
		var batch := MultiMeshInstance2D.new()
		batch.multimesh = instances
		var shared_material := ShaderMaterial.new()
		shared_material.shader = SHADER
		batch.material = shared_material
		add_child(batch)
		batches.append(batch)
		_buffers.append(PackedFloat32Array())
		_extents.append(0.0)
	var buffer := _buffers[batch_index]
	var start := buffer.size()
	buffer.resize(start + count * 16)
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
		var initial := offset + heading * _random.randf_range(0.0, float(profile.initial_radius))
		var velocity := heading * speed
		var gravity_range: Vector2 = profile.gravity_strength
		var gravity := _random.randf_range(gravity_range.x, gravity_range.y)
		var drag_range: Vector2 = profile.drag
		var drag := _random.randf_range(drag_range.x, drag_range.y)
		var first := start + index * 16
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
	_buffers[batch_index] = buffer
	_extents[batch_index] = maxf(_extents[batch_index], extent + offset.length())
	# A cohort has identical visual parameters and one clock/material per atlas.
	if start > 0: return count
	var material := batches[batch_index].material as ShaderMaterial
	material.set_shader_parameter("core_frames", FLASH_CORE if is_flash else IMPACT_CORE)
	material.set_shader_parameter("glow_frames", FLASH_GLOW if is_flash else IMPACT_GLOW)
	material.set_shader_parameter("size_multiplier", size_multiplier)
	var glow := float(profile.glow)
	var glow_multiplier := maxf(float(parameters.get("glow_multiplier", 1.0)), 0.0)
	var radius_multiplier := maxf(float(parameters.get("glow_radius_multiplier", 1.0)), 0.0)
	material.set_shader_parameter("glow_scale", radius_multiplier * (1.5 + glow * glow_multiplier * 0.35) / (1.5 + glow * 0.35) if glow_multiplier > 0.0 else 0.0)
	material.set_shader_parameter("alpha_multiplier", maxf(float(parameters.get("alpha_multiplier", 1.0)), 0.0))
	return count

func _flush_batches() -> void:
	if not _upload_pending: return
	_upload_pending = false
	if not _active: return
	for index in batches.size():
		var instances := batches[index].multimesh
		var count := _buffers[index].size() / 16
		# Retain allocation across uses; upload only once for all hits in a frame.
		if instances.instance_count < count:
			instances.instance_count = maxi(count, instances.instance_count * 2)
		var buffer := _buffers[index]
		buffer.resize(instances.instance_count * 16)
		instances.buffer = buffer
		instances.visible_instance_count = count
		var extent := _extents[index]
		instances.custom_aabb = AABB(Vector3(-extent, -extent, -1), Vector3(extent * 2.0, extent * 2.0, 2))

func _process(delta: float) -> void:
	_flush_batches()
	if not _active: return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	age += delta
	if age >= duration:
		_retire()
		return
	for batch in batches:
		batch.material.set_shader_parameter("elapsed", age)

func _retire() -> void:
	_active = false
	hide()
	set_process(false)
	remove_from_group("lightning_hit_sprite_bursts")
	remove_from_group("combat_particle_counters")
	var idle := 0
	for candidate in get_parent().get_meta(POOL_META, []):
		if is_instance_valid(candidate) and not candidate._active: idle += 1
	if idle > MAX_IDLE_BATCHES: queue_free()

func _exit_tree() -> void:
	var parent := get_parent()
	if parent != null and parent.has_meta(POOL_META):
		var pool: Array = parent.get_meta(POOL_META)
		pool.erase(self)

func get_active_particle_count() -> int:
	if not _active: return 0
	var active := 0
	for lifetime in _lifetimes:
		if age < lifetime:
			active += 1
	return active
