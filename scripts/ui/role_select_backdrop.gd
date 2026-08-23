extends Control
class_name RoleSelectBackdrop

const BG_TOP := Color("#17110b")
const BG_BOTTOM := Color("#070a08")
const GOLD := Color("#d3a637")
const GREEN := Color("#182d20")

var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var size := get_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for index in range(24):
		var ratio := float(index) / 23.0
		draw_rect(Rect2(0.0, ratio * size.y, size.x, size.y / 23.0 + 1.0), BG_TOP.lerp(BG_BOTTOM, ratio))
	for y in range(0, int(size.y), 4):
		var scan_alpha := 0.024 + 0.012 * sin(_elapsed * 2.4 + float(y) * 0.12)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.0, 0.0, 0.0, scan_alpha), 1.0)
	for x in range(0, int(size.x), 8):
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.2, 0.13, 0.04, 0.012), 1.0)

	var frame := Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0)
	draw_rect(frame, Color(GOLD, 0.34), false, 1.0)

	var sweep_x := fmod(_elapsed * 26.0, maxf(size.x, 1.0))
	draw_line(Vector2(sweep_x, 0.0), Vector2(sweep_x + 42.0, size.y), Color(GREEN, 0.12), 1.0)
	_draw_corner_marks(frame)


func _draw_corner_marks(frame: Rect2) -> void:
	var mark_color := Color(GOLD, 0.76)
	var length := 18.0
	draw_line(frame.position, frame.position + Vector2(length, 0.0), mark_color, 2.0)
	draw_line(frame.position, frame.position + Vector2(0.0, length), mark_color, 2.0)
	draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x - length, frame.position.y), mark_color, 2.0)
	draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x, frame.position.y + length), mark_color, 2.0)
	draw_line(Vector2(frame.position.x, frame.end.y), Vector2(frame.position.x + length, frame.end.y), mark_color, 2.0)
	draw_line(Vector2(frame.position.x, frame.end.y), Vector2(frame.position.x, frame.end.y - length), mark_color, 2.0)
	draw_line(frame.end, frame.end - Vector2(length, 0.0), mark_color, 2.0)
	draw_line(frame.end, frame.end - Vector2(0.0, length), mark_color, 2.0)
