extends Node2D
## Directional counterpart to pixel_fire.gdshader; contains no damage logic.

const SHADER = preload("res://shaders/effects/copper_lamp_flame.gdshader")
static var flow_texture: Texture2D
static var visual_count := 0
var reach := 120.0
var half_angle := PI / 6.0
var flame_material: ShaderMaterial


func _enter_tree() -> void:
	visual_count += 1


func _exit_tree() -> void:
	visual_count -= 1
	if visual_count == 0:
		flow_texture = null


func _init() -> void:
	if flow_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 4102026
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		flow_texture = ImageTexture.create_from_image(noise.get_seamless_image(128, 128))
	flame_material = ShaderMaterial.new()
	flame_material.shader = SHADER
	flame_material.set_shader_parameter("flow_noise", flow_texture)
	material = flame_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(direction: Vector2, distance: float, degrees: float, elapsed: float, child: bool) -> void:
	rotation = direction.angle()
	half_angle = deg_to_rad(degrees) * 0.5
	if not is_equal_approx(reach, distance):
		reach = distance
		queue_redraw()
	flame_material.set_shader_parameter("reach", reach)
	flame_material.set_shader_parameter("half_angle", half_angle)
	flame_material.set_shader_parameter("flame_time", elapsed)
	flame_material.set_shader_parameter("opacity", 0.55 if child else 0.88)


func _draw() -> void:
	draw_rect(Rect2(0, -reach, reach, reach * 2), Color.WHITE)
