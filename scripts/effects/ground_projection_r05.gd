extends RefCounted
## Production ground projection. The old flag remains readable by historical reviews.
const FOOTPRINT = preload("res://scripts/battle/attack_footprint.gd")
const FLAG := "ground_projection_r05_enabled"

static func enabled() -> bool:
	return bool(GameGlobal.get_runtime_flag(FLAG, false))

static func axes() -> Vector2:
	return projected_axes()

static func projected_axes() -> Vector2:
	return Vector2(1.0, FOOTPRINT.ELLIPSE_RATIO)

static func arc_points(center: Vector2, radius: float, start: float, end: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var dimensions := projected_axes() * radius
	for i in maxi(2, count):
		points.append(center + Vector2.from_angle(lerpf(start, end, float(i) / float(maxi(2, count) - 1))) * dimensions)
	return points

static func disk(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := arc_points(center, radius, 0.0, TAU, 97)
	points.remove_at(points.size() - 1)
	canvas.draw_colored_polygon(points, color)

static func arc(canvas: CanvasItem, center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float, antialiased: bool = false) -> void:
	if is_equal_approx(start, end): return
	# Project positions rather than the canvas: centers and stroke width stay intact.
	canvas.draw_polyline(arc_points(center, radius, start, end, count), color, width, antialiased)
