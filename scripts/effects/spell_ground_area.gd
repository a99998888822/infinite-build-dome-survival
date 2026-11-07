extends Node2D
## Essential ground coverage survives decoration LOD. No damage or timing here.
const SHADER = preload("res://shaders/effects/spell_ground_area.gdshader")
var terminal_axes := Vector2.ONE
var growth := 1.0
var opacity := 1.0
var _fill := Color.TRANSPARENT
var _edge := Color.TRANSPARENT
var _initialized := false

func _init() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	CombatRenderWorld.set_effect_layer(self, -7)

func setup(dimensions: Vector2, fill: Color, edge: Color, expansion := 1.0, alpha := 1.0) -> void:
	var dimensions_changed := not _initialized or terminal_axes != dimensions
	if not terminal_axes.is_equal_approx(dimensions):
		terminal_axes = dimensions
		queue_redraw()
	var next_growth := clampf(expansion, 0.0, 1.0)
	var next_opacity := clampf(alpha, 0.0, 1.0)
	# Pre-strike warnings hold all five uniforms constant for half a second.
	if dimensions_changed: material.set_shader_parameter("axes", terminal_axes)
	if not _initialized or fill != _fill: material.set_shader_parameter("fill_color", fill)
	if not _initialized or edge != _edge: material.set_shader_parameter("edge_color", edge)
	if not _initialized or next_growth != growth: material.set_shader_parameter("growth", next_growth)
	if not _initialized or next_opacity != opacity: material.set_shader_parameter("opacity", next_opacity)
	growth = next_growth
	opacity = next_opacity
	_fill = fill
	_edge = edge
	_initialized = true

func _draw() -> void:
	draw_rect(Rect2(-terminal_axes - Vector2.ONE * 2.0, terminal_axes * 2.0 + Vector2.ONE * 4.0), Color.WHITE)
