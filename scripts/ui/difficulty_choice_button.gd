extends Button
class_name DifficultyChoiceButton

var accent := Color("#c8ae54")
var _selected := false
var _clock := 0.0
var _hover := 0.0
var _flash := 0.0

func set_selected(value: bool) -> void:
	if value and not _selected:
		_flash = 1.0
		_clock = 0.0
	elif not value and _selected:
		_flash = 0.0
		_hover = 0.0
		scale = Vector2.ONE
	_selected = value
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if not _selected:
		# Hover/focus on another choice must never look like a second selection.
		_hover = 0.0
		_flash = 0.0
		scale = Vector2.ONE
		return
	_clock += delta
	var previous_hover := _hover
	_hover = move_toward(_hover, 1.0 if is_hovered() or has_focus() else 0.0, delta * 8.0)
	_flash = maxf(0.0, _flash - delta * 2.8)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * (1.0 + _hover * 0.018)
	if _selected or previous_hover > 0.0 or _flash > 0.0:
		queue_redraw()

func _draw() -> void:
	# Selection effects belong only to the current choice, never hover/focus.
	if not _selected:
		# Keep keyboard navigation visible without a colored frame or animation.
		if has_focus():
			draw_line(Vector2(8, size.y - 7), Vector2(20, size.y - 7), Color("#a9a184"), 1.0)
		return
	var strength := 0.48 + sin(_clock * 2.5) * 0.18
	var edge := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var glow := Color(accent.lightened(0.3), strength)
	draw_rect(edge, glow, false, 1.0)
	# Pixel corners and two narrow traveling glints leave the text unobscured.
	for corner in [edge.position, Vector2(edge.end.x, edge.position.y), edge.end, Vector2(edge.position.x, edge.end.y)]:
		var inward := Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
		draw_line(corner, corner + Vector2(inward.x * 7, 0), glow, 2.0)
		draw_line(corner, corner + Vector2(0, inward.y * 7), glow, 2.0)
	if _selected:
		var travel := fposmod(_clock * 52.0, maxf(1.0, size.x - 26.0))
		draw_rect(Rect2(Vector2(5 + travel, 2), Vector2(16, 1)), Color(accent.lightened(0.65), 0.85))
		draw_rect(Rect2(Vector2(size.x - 21 - travel, size.y - 3), Vector2(16, 1)), Color(accent.lightened(0.45), 0.65))
	if _flash > 0.0:
		draw_rect(edge.grow(-2), Color(accent.lightened(0.8), _flash * 0.65), false, 1.0)
