extends Control
## Fixed pixel-metal trim. Empty center and ignored mouse input preserve canvas interaction.

const PALETTE = preload("res://scripts/ui/hud_palette.gd")
var pixel_width := 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var pixel := pixel_width
	var margin := pixel * 4.0
	var frame := Rect2(Vector2.ONE * margin, size - Vector2.ONE * margin * 2.0)
	# Mask the outside gutter so panned nodes disappear behind the fixed trim.
	_outline(Rect2(Vector2.ZERO, size), PALETTE.BACKDROP, margin)
	_outline(frame, PALETTE.SHADOW, pixel * 2)
	_outline(frame.grow(-pixel), PALETTE.BORDER, pixel)
	_outline(frame.grow(-pixel * 2), PALETTE.NODE_FILL, pixel * 2)
	_outline(frame.grow(-pixel * 4), PALETTE.BORDER, pixel)
	_outline(frame.grow(-pixel * 5), PALETTE.SHADOW, pixel)
	var plate_size := Vector2.ONE * pixel * 10
	for point in [frame.position, Vector2(frame.end.x - plate_size.x, frame.position.y),
		Vector2(frame.position.x, frame.end.y - plate_size.y), frame.end - plate_size]:
		_corner(Rect2(point, plate_size), pixel)
	for y in [frame.position.y + pixel * 3, frame.end.y - pixel * 3]:
		var center := Vector2(roundf(size.x / 2.0 / pixel) * pixel, y)
		for direction in [-1, 1]:
			var start := center + Vector2(direction * pixel * 8, -pixel)
			if direction < 0: start.x -= pixel * 16
			draw_rect(Rect2(start, Vector2(pixel * 16, pixel * 2)), PALETTE.SHADOW)
			draw_rect(Rect2(start, Vector2(pixel * 16, pixel)), PALETTE.METAL)
		# Stepped lozenge, never smoothed diagonal strokes.
		draw_rect(Rect2(center - Vector2(pixel * 4, pixel), Vector2(pixel * 8, pixel * 2)), PALETTE.SHADOW)
		draw_rect(Rect2(center - Vector2(pixel * 2, pixel * 2), Vector2.ONE * pixel * 4), PALETTE.BORDER)
		draw_rect(Rect2(center - Vector2.ONE * pixel, Vector2.ONE * pixel * 2), Color("34383a"))


func _outline(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)), color)
	draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color)
	draw_rect(Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, rect.size.y)), color)


func _corner(rect: Rect2, pixel: float) -> void:
	draw_rect(rect.grow(pixel), PALETTE.SHADOW)
	draw_rect(rect, PALETTE.BORDER)
	draw_rect(rect.grow(-pixel), PALETTE.NODE_FILL)
	var inset := rect.position + Vector2.ONE * pixel * 2
	draw_rect(Rect2(inset, Vector2(pixel * 6, pixel)), PALETTE.METAL)
	draw_rect(Rect2(inset, Vector2(pixel, pixel * 6)), PALETTE.BORDER)
	var rivet := rect.get_center() - Vector2.ONE * pixel
	draw_rect(Rect2(rivet - Vector2.ONE * pixel, Vector2.ONE * pixel * 4), Color("121418"))
	draw_rect(Rect2(rivet, Vector2.ONE * pixel * 2), PALETTE.BORDER)
	draw_rect(Rect2(rivet, Vector2.ONE * pixel), PALETTE.METAL)
