extends MultiMeshInstance2D
## PNG orientation frames share one instanced batch for all 24 warning particles.
const ATLAS = preload("res://assets/effects/electric_spark_warning/warning_masks.png")
const SHADER = preload("res://assets/shaders/electric_spark_warning_png.gdshader")
const PARTICLE_COUNT := 24
static var _quad: QuadMesh
static var _buffer := PackedFloat32Array()
var _last_radius := -1.0

func _init() -> void:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(8,8)
		_buffer.resize(PARTICLE_COUNT * 16)
		for index in PARTICLE_COUNT:
			var first := index * 16
			_buffer[first] = 1.0
			_buffer[first+5] = 1.0
			_buffer[first+8] = 1.0
			_buffer[first+9] = 1.0
			_buffer[first+10] = 1.0
			_buffer[first+11] = 1.0
			_buffer[first+12] = float(index / 8)
			_buffer[first+13] = float(index % 8) / 8.0
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = PARTICLE_COUNT
	multimesh.buffer = _buffer
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("shape_frames", ATLAS)
	material = shader_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sync(0.0,1.0,1.0)

func sync(time: float, radius: float, opacity: float) -> void:
	material.set_shader_parameter("elapsed",time)
	material.set_shader_parameter("fade",opacity)
	if not is_equal_approx(_last_radius,radius):
		_last_radius = radius
		material.set_shader_parameter("radius_scale",radius)
		# The shader moves centers only; particle size stays fixed at all radii.
		var extent := Vector2(25.8,15.26) * absf(radius) + Vector2(5,5)
		multimesh.custom_aabb = AABB(Vector3(-extent.x,-extent.y,-1),Vector3(extent.x*2,extent.y*2,2))
