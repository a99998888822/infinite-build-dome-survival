extends Node2D
## Complementary shader passes: broad fire stays behind actors; sparse edges and
## embers cross their silhouettes. Each pixel belongs to exactly one pass.
var bounds := Rect2()

static func sync(canvas: Node2D, source: ShaderMaterial, rect: Rect2) -> void:
	var front: Node2D
	if canvas.has_meta("flame_front"):
		front = canvas.get_meta("flame_front")
	else:
		front = new()
		front.name = "FrontFlameEdges"
		front.material = source.duplicate()
		canvas.add_child(front)
		canvas.set_meta("flame_front", front)
		CombatRenderWorld.set_world_layer(canvas, CombatRenderWorld.BACK_Z)
		CombatRenderWorld.set_world_layer(front, CombatRenderWorld.BEAM_Z)
	for uniform in source.shader.get_shader_uniform_list():
		var key: StringName = uniform.name
		if key != &"render_part":
			front.material.set_shader_parameter(key, source.get_shader_parameter(key))
	source.set_shader_parameter("render_part", 1)
	front.material.set_shader_parameter("render_part", 2)
	if front.bounds != rect:
		front.bounds = rect
		front.queue_redraw()

func _draw() -> void:
	draw_rect(bounds, Color.WHITE)
