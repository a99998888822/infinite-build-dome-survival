extends Control
## Repaired reference wood and fixed-size hardware, composed at the drawer's height.

const TOP: Texture2D = preload("res://assets/ui/stats_drawer/stats_board_top.png")
const BOTTOM: Texture2D = preload("res://assets/ui/stats_drawer/stats_board_bottom.png")
const WOOD: Texture2D = preload("res://assets/ui/stats_drawer/stats_wood_tile.png")
const LEFT_RAIL: Texture2D = preload("res://assets/ui/stats_drawer/stats_rail_left.png")
const RIGHT_RAIL: Texture2D = preload("res://assets/ui/stats_drawer/stats_rail_right.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var scale_factor := size.x / 313.0
	var top_height := TOP.get_height() * scale_factor
	var bottom_height := BOTTOM.get_height() * scale_factor
	_tile(WOOD, Rect2(20.0 * scale_factor, 30.0 * scale_factor,
		272.0 * scale_factor, size.y - 60.0 * scale_factor), scale_factor)
	var middle := maxf(size.y - top_height - bottom_height, 0.0)
	_tile(LEFT_RAIL, Rect2(0.0, top_height, 25.0 * scale_factor, middle), scale_factor)
	_tile(RIGHT_RAIL, Rect2(288.0 * scale_factor, top_height, 25.0 * scale_factor, middle), scale_factor)
	draw_texture_rect(TOP, Rect2(0.0, 0.0, size.x, top_height), false)
	draw_texture_rect(BOTTOM, Rect2(0.0, size.y - bottom_height, size.x, bottom_height), false)


func _tile(texture: Texture2D, area: Rect2, scale_factor: float) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var tile_size := texture.get_size() * scale_factor
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var piece := Vector2(minf(tile_size.x, area.end.x - x), minf(tile_size.y, area.end.y - y))
			draw_texture_rect_region(texture, Rect2(Vector2(x, y), piece), Rect2(Vector2.ZERO, piece / scale_factor))
			x += tile_size.x
		y += tile_size.y
