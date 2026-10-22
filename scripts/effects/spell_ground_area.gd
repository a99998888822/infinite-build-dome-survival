extends Node2D
## Essential ground coverage survives decoration LOD. No damage or timing here.
const SHADER = preload("res://shaders/effects/spell_ground_area.gdshader")
var terminal_axes := Vector2.ONE
var growth := 1.0
var opacity := 1.0

func _init() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	CombatRenderWorld.set_effect_layer(self, -7)

func setup(dimensions: Vector2, fill: Color, edge: Color, expansion := 1.0, alpha := 1.0) -> void:
	if not terminal_axes.is_equal_approx(dimensions):
		terminal_axes = dimensions
		queue_redraw()
	growth = clampf(expansion, 0.0, 1.0)
	opacity = clampf(alpha, 0.0, 1.0)
	material.set_shader_parameter("axes", terminal_axes)
	material.set_shader_parameter("fill_color", fill)
	material.set_shader_parameter("edge_color", edge)
	material.set_shader_parameter("growth", growth)
	material.set_shader_parameter("opacity", opacity)

func _draw() -> void:
	draw_rect(Rect2(-terminal_axes - Vector2.ONE * 2.0, terminal_axes * 2.0 + Vector2.ONE * 4.0), Color.WHITE)
