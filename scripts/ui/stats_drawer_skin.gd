extends Control
## Approved A+ 288x516 panel. Extend only the plain center; preserve hardware.

const PANEL: Texture2D = preload("res://assets/ui/stats_drawer/stats_parchment_panel.png")
const DISPLAY_WIDTH := 416.0
const TOP_ROWS := 216.0
const BOTTOM_ROWS := 284.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(floorf((size.x - DISPLAY_WIDTH) / 2.0), 0.0)
	var height := floorf(size.y)
	if height <= 0.0:
		return
	var source_size := PANEL.get_size()
	var art_scale := minf(DISPLAY_WIDTH / source_size.x, height / (TOP_ROWS + BOTTOM_ROWS))
	var top_height := floorf(TOP_ROWS * art_scale)
	var bottom_height := floorf(BOTTOM_ROWS * art_scale)
	var middle_height := height - top_height - bottom_height
	draw_texture_rect_region(PANEL, Rect2(origin, Vector2(DISPLAY_WIDTH, top_height)),
		Rect2(0.0, 0.0, source_size.x, TOP_ROWS))
	draw_texture_rect_region(PANEL, Rect2(origin + Vector2(0.0, top_height), Vector2(DISPLAY_WIDTH, middle_height)),
		Rect2(0.0, TOP_ROWS, source_size.x, source_size.y - TOP_ROWS - BOTTOM_ROWS))
	draw_texture_rect_region(PANEL, Rect2(origin + Vector2(0.0, height - bottom_height), Vector2(DISPLAY_WIDTH, bottom_height)),
		Rect2(0.0, source_size.y - BOTTOM_ROWS, source_size.x, BOTTOM_ROWS))
