extends Node2D
## Shared pixel fire: three field tongues, one burning-status tongue, one seed tongue.

const FIRE_SHADER = preload("res://shaders/effects/pixel_fire.gdshader")
static var shared_material: ShaderMaterial
static var clock: Node
static var visual_count := 0
var tongue_count := 0
var build_count := 0
var pixel_size := 3
var last_radius := -1.0
var parts: Array[Dictionary] = []
var layer := 42
var _batch_slot := -1
var _batch_layer := -1
var _batch_epoch := -1
var _batch_geometry := -1
var _batch_world := Transform2D.IDENTITY
var _batch_tint := Color.TRANSPARENT

class FlameClock extends Node2D:
	var elapsed := 0.0
	var target: ShaderMaterial
	var sources: Array[Node2D] = []
	var batches: Dictionary = {}
	var buffers: Dictionary = {}
	var counts: Dictionary = {}
	var epochs: Dictionary = {}
	var quad := QuadMesh.new()
	func _ready() -> void:
		quad.size = Vector2.ONE
		process_priority = 100
	func _process(delta: float) -> void:
		if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
		advance(delta)
	func advance(delta: float) -> void:
		elapsed += delta
		target.set_shader_parameter("flame_time", elapsed)
		flush()
	func flush() -> void:
		counts.clear()
		for source in sources:
			if not source.is_visible_in_tree():
				source._batch_slot = -1
				continue
			counts[source.layer] = int(counts.get(source.layer, 0)) + source.parts.size()
		for z: int in counts:
			if not batches.has(z):
				var node := MultiMeshInstance2D.new()
				node.z_index = z
				node.material = target
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_2D
				multimesh.use_colors = true
				multimesh.use_custom_data = true
				multimesh.mesh = quad
				node.multimesh = multimesh
				add_child(node)
				batches[z] = node
			var instances: MultiMesh = batches[z].multimesh
			if instances.instance_count < int(counts[z]):
				instances.instance_count = maxi(32, int(pow(2, ceil(log(float(counts[z])) / log(2.0)))))
				var buffer := PackedFloat32Array()
				buffer.resize(instances.instance_count * 16)
				buffers[z] = buffer
				epochs[z] = int(epochs.get(z, 0)) + 1
		var dirty_layers := {}
		# Packed arrays are copy-on-write: acquire once per layer, not per enemy.
		for z: int in counts:
			var index := 0
			var buffer: PackedFloat32Array = buffers[z]
			for source in sources:
				if source.layer != z or not source.is_visible_in_tree(): continue
				var world := source.global_transform
				var tint := source.modulate
				var metadata_dirty: bool = source._batch_slot != index or source._batch_layer != z or source._batch_epoch != epochs[z] or source._batch_geometry != source.build_count or source._batch_tint != tint
				if not metadata_dirty and source._batch_world == world:
					index += source.parts.size()
					continue
				dirty_layers[z] = true
				source._batch_slot = index
				source._batch_layer = z
				source._batch_epoch = epochs[z]
				source._batch_geometry = source.build_count
				source._batch_world = world
				source._batch_tint = tint
				for part: Dictionary in source.parts:
					var transform: Transform2D = world * part.transform
					var data: Color = part.data
					var first := index * 16
					buffer[first] = transform.x.x
					buffer[first+1] = transform.y.x
					buffer[first+2] = 0
					buffer[first+3] = transform.origin.x
					buffer[first+4] = transform.x.y
					buffer[first+5] = transform.y.y
					buffer[first+6] = 0
					buffer[first+7] = transform.origin.y
					if metadata_dirty:
						buffer[first+8] = tint.r
						buffer[first+9] = tint.g
						buffer[first+10] = tint.b
						buffer[first+11] = tint.a
						buffer[first+12] = data.r
						buffer[first+13] = data.g
						buffer[first+14] = data.b
						buffer[first+15] = data.a
					index += 1
			buffers[z] = buffer
		for z: int in batches:
			var instances: MultiMesh = batches[z].multimesh
			if dirty_layers.has(z): instances.buffer = buffers[z]
			instances.visible_instance_count = int(counts.get(z, 0))

static func ensure_material(viewport: Viewport) -> ShaderMaterial:
	if shared_material == null:
		var noise := FastNoiseLite.new()
		noise.seed = 4102026
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		var texture := ImageTexture.create_from_image(noise.get_seamless_image(128, 128))
		shared_material = ShaderMaterial.new()
		shared_material.shader = FIRE_SHADER
		shared_material.set_shader_parameter("flow_noise", texture)
	if clock == null or not is_instance_valid(clock):
		clock = FlameClock.new()
		clock.target = shared_material
		clock.name = "PixelFlameClock"
		# Battle renders inside a SubViewport; the batch must share its camera.
		viewport.add_child.call_deferred(clock)
	return shared_material

func _ready() -> void:
	visual_count += 1
	ensure_material(get_viewport())
	clock.sources.append(self)
	add_to_group("pixel_fire_visuals")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _exit_tree() -> void:
	if is_instance_valid(clock): clock.sources.erase(self)
	visual_count -= 1
	if visual_count == 0:
		if is_instance_valid(clock): clock.queue_free()
		clock = null
		shared_material = null

func setup_field(radius: float, tint := Color.WHITE) -> void:
	if is_equal_approx(last_radius, radius): return
	last_radius = radius
	layer = 42
	modulate = tint
	# Original narrow contour: one medium center, two narrower side tongues.
	var extent := clampf(radius / 30.0, 0.85, 1.3)
	var phase := fposmod(global_position.x * 0.017 + global_position.y * 0.013, 0.9) + 0.05
	build([
		{"point": Vector2(-radius * 0.60, 7), "size": Vector2(31, 48) * extent, "phase": phase},
		{"point": Vector2(radius * 0.60, 9), "size": Vector2(34, 52) * extent, "phase": fposmod(phase + 0.43, 0.9) + 0.05},
		{"point": Vector2(0, 7), "size": Vector2(57, 60) * extent, "phase": fposmod(phase + 0.21, 0.9) + 0.05}
	], 3)

func setup_status(radius: float) -> void:
	layer = 25
	var width := clampf(radius * 1.4, 14.0, 24.0)
	var phase := fposmod(global_position.x * 0.017 + global_position.y * 0.013, 0.83)
	build([{"point": Vector2(0, 16), "size": Vector2(width, 28), "phase": phase + 0.05}], 2)

func setup_single(size: Vector2, grid: int, phase := 0.37) -> void:
	layer = 43
	build([{"point": Vector2.ZERO, "size": size, "phase": phase}], grid)

func build(entries: Array, grid: int) -> void:
	build_count += 1
	tongue_count = entries.size()
	pixel_size = grid
	parts.clear()
	for entry: Dictionary in entries:
		var size: Vector2 = (entry.size / grid).ceil() * grid
		var point: Vector2 = (entry.point / grid).round() * grid
		var top_left := point - Vector2(size.x * 0.5, size.y * 0.94)
		top_left = (top_left / grid).round() * grid
		var data := Color(size.x / 128.0, size.y / 128.0, float(entry.phase), float(grid) / 4.0)
		parts.append({"transform": Transform2D(0.0, size, 0.0, top_left + size * 0.5), "data": data})
