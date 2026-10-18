extends Control
class_name TalentTreeCanvas
var edges: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	for edge in edges:
		_pixel_line(edge.from, edge.to, Color("151319"), 4.0)
		_pixel_line(edge.from, edge.to, Color("a88c56") if edge.lit else Color("48424b"), 2.0)

func _pixel_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	# Fixed two-pixel staircase. Overlapping blocks keep diagonal strokes connected.
	var a := Vector2i((from / 2.0).round())
	var b := Vector2i((to / 2.0).round())
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var error := dx + dy
	while true:
		draw_rect(Rect2(Vector2(a) * 2.0 - Vector2.ONE * (width - 2.0) / 2.0, Vector2.ONE * width), color)
		if a == b: break
		var twice := 2 * error
		if twice >= dy:
			error += dy
			a.x += sx
		if twice <= dx:
			# Fill the corner before moving vertically; no diagonal gaps at any zoom.
			if twice >= dy:
				draw_rect(Rect2(Vector2(a) * 2.0 - Vector2.ONE * (width - 2.0) / 2.0, Vector2.ONE * width), color)
			error += dx
			a.y += sy
