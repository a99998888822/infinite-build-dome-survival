extends Node2D
## Broad palette bands, shared with the lamp's pixel/noise language.
## This node is only needed for the detached, short-lived shockwave visual.
const SHADER = preload("res://shaders/effects/enchantment_blocks.gdshader")
static var _noise: Texture2D
var radius := 55.2
var elapsed := 0.0
var duration := 0.55
var detail := 2


static func paint(
	canvas: CanvasItem, kind: int, bounds: Rect2, reach: float,
	age: float, progress: float, quality := 2
) -> void:
	var shader_material: ShaderMaterial
	if not canvas.has_meta("enchantment_block_material"):
		if _noise == null:
			var noise := FastNoiseLite.new()
			noise.seed = 4102026
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.035
			noise.fractal_type = FastNoiseLite.FRACTAL_NONE
			_noise = ImageTexture.create_from_image(noise.get_seamless_image(128, 128))
		shader_material = ShaderMaterial.new()
		shader_material.shader = SHADER
		shader_material.set_shader_parameter("flow_noise", _noise)
		canvas.material = shader_material
		canvas.set_meta("enchantment_block_material", shader_material)
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		shader_material = canvas.get_meta("enchantment_block_material")
	shader_material.set_shader_parameter("kind", kind)
	shader_material.set_shader_parameter("reach", reach)
	shader_material.set_shader_parameter("effect_time", age)
	shader_material.set_shader_parameter("progress", clampf(progress, 0, 1))
	shader_material.set_shader_parameter("detail", quality)
	canvas.draw_rect(bounds, Color.WHITE)


static func spawn_shockwave(parent: Node, point: Vector2, reach: float, tier: int) -> Node2D:
	var effect := new()
	effect.radius = reach
	effect.detail = maxi(0, 2 - tier)
	effect.z_index = 78
	parent.add_child(effect)
	effect.global_position = point
	effect.add_to_group("enchantment_block_shockwaves")
	return effect


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	paint(self, 0, Rect2(-radius * 1.2, -radius, radius * 2.4, radius * 2),
		radius, elapsed, elapsed / duration, detail)
