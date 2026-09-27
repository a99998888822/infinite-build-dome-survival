extends Node2D

## Screen-space distant scenery, separated from the traversable ground.
const PILLAR = preload("res://assets/sprites/background/background-stone-piller2.png")
const BROKEN = preload("res://assets/sprites/background/wetland/ruin_broken_pillar.png")
const WALL_A = preload("res://assets/sprites/background/wetland/ruin_low_wall_01.png")
const WALL_B = preload("res://assets/sprites/background/wetland/ruin_low_wall_02.png")

var _camera_x := 0.0
var _horizon_y := 0.0
var _content_rects: Dictionary = {}
var _placements: Array[Dictionary] = []


func _ready() -> void:
	for texture in [PILLAR, BROKEN, WALL_A, WALL_B]:
		_content_rects[texture] = Rect2(texture.get_image().get_used_rect())


func configure_view(horizon: float, size: Vector2, camera_x: float) -> void:
	_camera_x = camera_x
	_horizon_y = horizon
	_placements.clear()
	# The sky coordinator supplies one horizon for both stones and water.
	for layer in range(2):
		var drift := _camera_x * (0.05 if layer == 0 else 0.11)
		var spacing := 810.0 if layer == 0 else 690.0
		var start := floori(drift / spacing) - 1
		for segment in range(start, start + ceili(size.x / spacing) + 3):
			var x := float(segment) * spacing - drift + (340.0 if layer == 0 else 36.0)
			var tint := Color(0.24, 0.31, 0.29, 0.72) if layer == 0 else Color(0.42, 0.51, 0.45, 0.9)
			var base_y := horizon + (10.0 if layer == 0 else 20.0)
			var scale_factor := 0.45 if layer == 0 else 0.65
			_add_placement(WALL_A if posmod(segment, 2) == 0 else WALL_B, Vector2(x + 82, base_y), scale_factor, tint)
			_add_placement(PILLAR if posmod(segment, 3) == 0 else BROKEN, Vector2(x + 40, base_y), scale_factor, tint)
			if layer == 1 and posmod(segment, 2) == 0:
				_add_placement(BROKEN, Vector2(x + 235, base_y + 8), scale_factor * 0.8, tint)
	queue_redraw()


func get_placements() -> Array[Dictionary]:
	return _placements


func _add_placement(texture: Texture2D, base: Vector2, scale_factor: float, tint: Color) -> void:
	var source: Rect2 = _content_rects.get(texture, Rect2(Vector2.ZERO, texture.get_size()))
	var destination := get_ruin_rect(texture, base, scale_factor)
	# This canvas is above the world water: explicitly omit submerged pixels
	# instead of drawing the sprite's complete base and an airborne oval shadow.
	var submerged := clampf(destination.size.y * 0.24, 6.0, 16.0)
	var waterline := maxf(roundf(base.y - submerged), _horizon_y + 2.0)
	var exposed := destination
	exposed.size.y = maxf(0.0, waterline - destination.position.y)
	var exposed_source := source
	exposed_source.size.y *= exposed.size.y / maxf(destination.size.y, 1.0)
	_placements.append({"texture": texture, "source": exposed_source, "rect": exposed,
		"base": Vector2(base.x, waterline), "waterline": waterline, "tint": tint})


func _draw() -> void:
	for placement in _placements:
		var destination: Rect2 = placement.rect
		var tint: Color = placement.tint
		draw_texture_rect_region(placement.texture, destination, placement.source, tint)
		# A short damp band softens the exposed stone at the same reflection edge.
		var wet_rect := Rect2(destination.position.x, destination.end.y - 3.0, destination.size.x, 3.0)
		var source: Rect2 = placement.source
		var sample_height := source.size.y * 3.0 / maxf(destination.size.y, 1.0)
		var wet_source := Rect2(source.position.x, source.end.y - sample_height, source.size.x, sample_height)
		draw_texture_rect_region(placement.texture, wet_rect, wet_source, Color(0.08, 0.17, 0.15, tint.a * 0.6))


func get_ruin_rect(texture: Texture2D, base: Vector2, scale_factor: float) -> Rect2:
	var source: Rect2 = _content_rects.get(texture, Rect2(Vector2.ZERO, texture.get_size()))
	# Keep the upper silhouette inside the sky even on a narrow window.
	var visible_scale := minf(scale_factor, maxf(base.y - 60.0, 1.0) / maxf(source.size.y, 1.0))
	var draw_size := (source.size * visible_scale).round()
	return Rect2(base.round() - Vector2(0, draw_size.y), draw_size)
