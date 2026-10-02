extends RefCounted
## One instanced draw for ordered square/circle particles, preserving their
## individual transforms, colors and alpha instead of one Canvas draw per shape.
const MATERIAL_SHADER = preload("res://assets/shaders/pixel_particle_batch.gdshader")

static func create(capacity: int) -> MultiMeshInstance2D:
	var node := MultiMeshInstance2D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = capacity
	instances.visible_instance_count = 0
	node.multimesh = instances
	var shader_material := ShaderMaterial.new()
	shader_material.shader = MATERIAL_SHADER
	node.material = shader_material
	return node

static func put(instances: MultiMesh, index: int, point: Vector2, size: Vector2, angle: float, color: Color, circle: bool = false) -> void:
	instances.set_instance_transform_2d(index, Transform2D(angle, size, 0.0, point))
	instances.set_instance_color(index, color)
	instances.set_instance_custom_data(index, Color(1.0 if circle else 0.0, 0, 0, 0))
