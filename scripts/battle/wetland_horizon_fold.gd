extends Node2D
class_name WetlandHorizonFold

## The node's local coordinates match the outer UI viewport, but it renders
## inside the world below the stone floor, actors and projectiles.
var _placements: Array[Dictionary] = []
var _environment_time := 0.0
var _horizon_y := 128.0
var _fold_height := 44.0
var _view_size := Vector2(1152, 648)


func _ready() -> void:
	add_to_group("battle_horizon_fold")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure_view(horizon: float, height: float, ui_size: Vector2, ground: WetlandBackdrop, placements: Array[Dictionary], sky_texture: Texture2D) -> void:
	_horizon_y = horizon
	_fold_height = height
	_view_size = ui_size
	_placements = placements
	_environment_time = ground.get_environment_time()
	# SubViewportContainer can resize the world independently of UI coordinates.
	# Explicit conversion also keeps the band attached during camera movement.
	var world_size := get_viewport_rect().size
	var ui_to_viewport := Transform2D(0.0, world_size / ui_size, 0.0, Vector2.ZERO)
	var ui_to_world := get_viewport().get_canvas_transform().affine_inverse() * ui_to_viewport
	global_transform = ui_to_world
	ground.set_horizon_view(horizon, height, ui_size, Vector2(ui_to_world.x.length(), ui_to_world.y.length()), sky_texture)
	queue_redraw()


func _draw() -> void:
	for placement in _placements:
		var rect: Rect2 = placement.rect
		if rect.end.x < 0 or rect.position.x > _view_size.x:
			continue
		_draw_reflection(placement)


func _draw_reflection(placement: Dictionary) -> void:
	var rect: Rect2 = placement.rect
	var source: Rect2 = placement.source
	var base: Vector2 = placement.base
	var tint: Color = placement.tint
	var reflection_height := minf(rect.size.y * 0.32, 22.0)
	reflection_height = minf(reflection_height, _horizon_y + _fold_height - base.y)
	if reflection_height < 2.0:
		return
	for row in range(0, ceili(reflection_height), 2):
		var progress := float(row) / reflection_height
		var strip_height := minf(2.0, reflection_height - row)
		var alpha := (1.0 - progress) * (1.0 - progress) * tint.a * 0.28
		# Slightly broken mirror strips, not a moving stone base.
		var drift := sin(_environment_time * 0.9 + row * 0.7 + base.x * 0.025)
		var offset := roundf(drift) * progress
		alpha *= 0.45 if posmod(row, 6) == 2 else 1.0
		var sample_height := source.size.y * strip_height / reflection_height
		var sample_y := source.end.y - source.size.y * (row + strip_height) / reflection_height
		draw_set_transform(Vector2(rect.position.x + offset, base.y + row + strip_height), 0.0, Vector2(1, -1))
		draw_texture_rect_region(placement.texture, Rect2(0, 0, rect.size.x, strip_height),
			Rect2(source.position.x, sample_y, source.size.x, sample_height), Color(0.24, 0.32, 0.29, alpha))
	draw_set_transform(Vector2.ZERO)
