extends Control
## Approved r03 art: native hardware over continuous horizontal wood.

const TOP: Texture2D = preload("res://assets/ui/stats_drawer/stats_board_top.png")
const BOTTOM: Texture2D = preload("res://assets/ui/stats_drawer/stats_board_bottom.png")
const WOOD: Texture2D = preload("res://assets/ui/stats_drawer/stats_wood_tile.png")
const LEFT_RAIL: Texture2D = preload("res://assets/ui/stats_drawer/stats_rail_left.png")
const RIGHT_RAIL: Texture2D = preload("res://assets/ui/stats_drawer/stats_rail_right.png")
const NATIVE_WIDTH := 288.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(floorf((size.x - NATIVE_WIDTH) / 2.0), 0.0)
	var height := floorf(size.y)
	if height <= 0.0:
		return
	# Crop only the plain middle when short; repeat rails when tall. Never scale
	# the rivets or straps. At 520px this reconstructs the reviewed image exactly.
	var top_height := minf(TOP.get_height(), floorf(height / 2.0))
	var bottom_height := minf(BOTTOM.get_height(), height - top_height)
	_tile(WOOD, Rect2(origin + Vector2(17.0, 18.0), Vector2(248.0, height - 38.0)))
	var middle := maxf(height - top_height - bottom_height, 0.0)
	_tile(LEFT_RAIL, Rect2(origin + Vector2(0.0, top_height), Vector2(18.0, middle)))
	_tile(RIGHT_RAIL, Rect2(origin + Vector2(264.0, top_height), Vector2(24.0, middle)))
	draw_texture_rect_region(TOP, Rect2(origin, Vector2(NATIVE_WIDTH, top_height)),
		Rect2(0.0, 0.0, NATIVE_WIDTH, top_height))
	draw_texture_rect_region(BOTTOM, Rect2(origin + Vector2(0.0, height - bottom_height), Vector2(NATIVE_WIDTH, bottom_height)),
		Rect2(0.0, BOTTOM.get_height() - bottom_height, NATIVE_WIDTH, bottom_height))


func _tile(texture: Texture2D, area: Rect2) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var tile_size := texture.get_size()
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var piece := Vector2(minf(tile_size.x, area.end.x - x), minf(tile_size.y, area.end.y - y))
			draw_texture_rect_region(texture, Rect2(Vector2(x, y), piece), Rect2(Vector2.ZERO, piece))
			x += tile_size.x
		y += tile_size.y
