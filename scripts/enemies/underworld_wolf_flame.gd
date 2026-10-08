extends Node2D
## Ghost-fire variant of the copper lamp's stepped pixel flame.
const SHADER := preload("res://assets/sprites/enemies/underworld_wolf/ghost_flame.gdshader")
var flame_material: ShaderMaterial
var reach := 240.0
static var noise_texture: Texture2D


func _init() -> void:
	if noise_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 4102026
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise_texture = ImageTexture.create_from_image(noise.get_seamless_image(128,128))
	flame_material = ShaderMaterial.new()
	flame_material.shader = SHADER
	flame_material.set_shader_parameter("flow_noise",noise_texture)
	material = flame_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Keep the player silhouette and each knockback visible inside the fire.
	z_index = -1


func configure(direction: Vector2, distance: float, degrees: float, time: float) -> void:
	rotation = direction.angle()
	reach = distance
	flame_material.set_shader_parameter("reach",reach)
	flame_material.set_shader_parameter("half_angle",deg_to_rad(degrees)*0.5)
	flame_material.set_shader_parameter("flame_time",time)
	flame_material.set_shader_parameter("opacity",minf(1.0,(1.5-time)/0.15))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0,-reach,reach,reach*2),Color.WHITE)
