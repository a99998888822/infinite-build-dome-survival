extends RefCounted
## Shared presentation only. Range calculations and combat timing stay in their owners.
const GRID := 2.0
const FILL := Color(0.44, 0.57, 0.59, 0.12)
const EDGE := Color(0.64, 0.78, 0.80, 1.0)
const LOCKED_FILL := Color(0.44, 0.57, 0.59, 0.12)
const LOCKED_EDGE := Color(0.64, 0.78, 0.80, 0.82)
const INK := Color(0.14, 0.19, 0.20, 0.90)
const LOCKED_INK := Color(0.14, 0.19, 0.20, 0.65)
const CLEARANCE_SHADER = preload("res://shaders/ui/attack_indicator_clearance.gdshader")
var _paths: Dictionary = {}


static func make_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = CLEARANCE_SHADER
	return result


static func sync_material(canvas: Node2D, clearance: float, available: bool) -> void:
	if canvas.material is ShaderMaterial:
		canvas.material.set_shader_parameter("cast_origin", canvas.global_position)
		canvas.material.set_shader_parameter("clearance", clearance)
		canvas.material.set_shader_parameter("cast_available", available)


static func fill_color(available: bool) -> Color:
	return FILL if available else LOCKED_FILL


func outline(canvas: Node2D, points: PackedVector2Array, available: bool, closed: bool = false, opacity: float = 1.0) -> void:
	if points.size() < 2:
		return
	var key := [points, closed, available]
	if not _paths.has(key):
		if _paths.size() >= 24: _paths.clear()
		_paths[key] = _pixel_segments(points, closed, available)
	var segments: PackedVector2Array = _paths[key]
	if segments.is_empty(): return
	var ink := INK if available else LOCKED_INK
	var edge := EDGE if available else LOCKED_EDGE
	# Two batched passes, not one draw call per pixel. Horizontal 2x2 cells stay
	# square even when aiming diagonally; points arrive already transformed.
	canvas.draw_multiline(segments, Color(ink, ink.a * opacity), 4.0, false)
	canvas.draw_multiline(segments, Color(edge, edge.a * opacity), GRID, false)


func _pixel_segments(points: PackedVector2Array, closed: bool, available: bool) -> PackedVector2Array:
	var cells: Dictionary = {}
	var segments := PackedVector2Array()
	var count := points.size() if closed else points.size() - 1
	var phase := 0
	for index in count:
		var first := Vector2i((points[index] / GRID).floor())
		var last := Vector2i((points[(index + 1) % points.size()] / GRID).floor())
		var distance := Vector2i(absi(last.x - first.x), absi(last.y - first.y))
		var step := Vector2i(1 if first.x < last.x else -1, 1 if first.y < last.y else -1)
		var error := distance.x - distance.y
		while true:
			if not cells.has(first):
				cells[first] = true
				# Missing edge clusters and diagonal fill hatching distinguish cooldown
				# without relying on hue alone. The ready silhouette stays continuous.
				if available or phase % 8 < 5:
					var corner := Vector2(first) * GRID
					segments.append(corner + Vector2(0, GRID * 0.5))
					segments.append(corner + Vector2(GRID, GRID * 0.5))
				phase += 1
			if first == last: break
			var twice := error * 2
			if twice > -distance.y:
				error -= distance.y
				first.x += step.x
			if twice < distance.x:
				error += distance.x
				first.y += step.y
	return segments
