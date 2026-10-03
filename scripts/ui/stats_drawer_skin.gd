extends Control
## Approved 128x256 parchment. Keep the clip and corners intact as height changes.

const PANEL: Texture2D = preload("res://assets/ui/stats_drawer/stats_parchment_panel.png")
const DISPLAY_WIDTH := 256.0
const TOP_ROWS := 64.0
const BOTTOM_ROWS := 40.0


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
	# Two-times pixel art at the ends; only the mostly blank middle adapts.
	var top_height := minf(TOP_ROWS * 2.0, floorf(height * 0.55))
	var bottom_height := minf(BOTTOM_ROWS * 2.0, floorf(height * 0.35))
	var middle_height := height - top_height - bottom_height
	draw_texture_rect_region(PANEL, Rect2(origin, Vector2(DISPLAY_WIDTH, top_height)),
		Rect2(0.0, 0.0, 128.0, TOP_ROWS))
	draw_texture_rect_region(PANEL, Rect2(origin + Vector2(0.0, top_height), Vector2(DISPLAY_WIDTH, middle_height)),
		Rect2(0.0, TOP_ROWS, 128.0, 256.0 - TOP_ROWS - BOTTOM_ROWS))
	draw_texture_rect_region(PANEL, Rect2(origin + Vector2(0.0, height - bottom_height), Vector2(DISPLAY_WIDTH, bottom_height)),
		Rect2(0.0, 256.0 - BOTTOM_ROWS, 128.0, BOTTOM_ROWS))
