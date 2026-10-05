extends "res://scripts/effects/pixel_rect_batch.gd"
## Submit the same overlapping pixel squares as independent horizontal strokes.
## Each stroke has square coverage; no paths are joined and no alpha is merged.
const MAX_SEGMENT_KEYS := 1024
static var segment_cache: Dictionary = {}
var _last_key := Vector4i(2147483647, 0, 0, 0)
var _last_points := PackedVector2Array()

func _segments(start: Vector2, end: Vector2, width: float) -> PackedVector2Array:
	var a := (start / GRID).round()
	var b := (end / GRID).round()
	var key := Vector4i(int(a.x), int(a.y), int(b.x), int(b.y))
	var dimension := ceilf(width / GRID) * GRID
	if segment_cache.has(key) and segment_cache[key].has(dimension):
		return segment_cache[key][dimension]
	var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	if key != _last_key:
		_last_key = key
		_last_points.clear()
		var previous := Vector2(INF, INF)
		for index in range(steps + 1):
			var point := a.lerp(b, float(index) / float(steps)).round() * GRID
			if point != previous:
				_last_points.append(point)
				previous = point
	var segments := PackedVector2Array()
	segments.resize(_last_points.size() * 2)
	var offset := floorf(dimension / (GRID * 2.0)) * GRID
	var left := Vector2(-offset, dimension * 0.5 - offset)
	var right := left + Vector2(dimension, 0)
	for index in _last_points.size():
		segments[index * 2] = _last_points[index] + left
		segments[index * 2 + 1] = _last_points[index] + right
	if segment_cache.has(key):
		segment_cache[key][dimension] = segments
	elif segment_cache.size() < MAX_SEGMENT_KEYS and steps <= 512:
		segment_cache[key] = {dimension: segments}
	return segments

func line(start: Vector2, end: Vector2, color: Color, width: float = GRID) -> void:
	if color.a <= 0.0: return
	canvas.draw_multiline(_segments(start, end, width), color, ceilf(width / GRID) * GRID, false)

func layered_line(start: Vector2, end: Vector2, widths: PackedFloat32Array, colors: PackedColorArray) -> void:
	for layer in widths.size():
		line(start, end, colors[layer], widths[layer])
