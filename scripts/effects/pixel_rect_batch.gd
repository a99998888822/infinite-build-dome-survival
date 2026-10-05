extends RefCounted
## Cached pixel rasterization through the established CanvasItem renderer.
## Preserve rectangle order, pixel coverage and alpha accumulation exactly.
const GRID := 2.0
const MAX_LINE_CACHE := 8192
static var line_cache: Dictionary = {}
var canvas: CanvasItem
var count := 0

func setup(parent: Node2D) -> void:
	canvas = parent

func begin() -> void:
	count = 0

func finish() -> void:
	pass

func rect(origin: Vector2, size: Vector2, color: Color) -> void:
	_write_rect(origin, size, color)

func _write_rect(origin: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(origin, size), color)
	count += 1

func block(point: Vector2, size: Vector2, color: Color) -> void:
	if color.a <= 0.0: return
	var dimensions := (size / GRID).ceil() * GRID
	var origin := (point / GRID).round() * GRID - (dimensions / (GRID * 2.0)).floor() * GRID
	rect(origin, dimensions, color)

func line(start: Vector2, end: Vector2, color: Color, width: float = GRID) -> void:
	if color.a <= 0.0: return
	var a := (start / GRID).round()
	var b := (end / GRID).round()
	var key := Vector4i(int(a.x), int(a.y), int(b.x), int(b.y))
	var points: PackedVector2Array
	if line_cache.has(key):
		points = line_cache[key]
	else:
		var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
		var previous := Vector2(INF, INF)
		for index in range(steps + 1):
			var point := a.lerp(b, float(index) / float(steps)).round() * GRID
			if point != previous:
				points.append(point)
				previous = point
		if line_cache.size() < MAX_LINE_CACHE and steps <= 16:
			line_cache[key] = points
	# All centers are already snapped. Shared line footprints keep duplicates
	# at adjacent segment joins, including their original alpha accumulation.
	var dimensions := (Vector2.ONE * width / GRID).ceil() * GRID
	var offset := (dimensions / (GRID * 2.0)).floor() * GRID
	for point in points: _write_rect(point - offset, dimensions, color)

func path(points: PackedVector2Array, color: Color, width: float = GRID) -> void:
	for index in range(1, points.size()):
		line(points[index - 1], points[index], color, width)

func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3: return
	var top := points[0].y
	var bottom := top
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var first_row := int(floor(top / GRID))
	var last_row := int(ceil(bottom / GRID))
	var buckets: Array = []
	buckets.resize(last_row - first_row)
	for i in buckets.size(): buckets[i] = []
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		if a.y == b.y: continue
		var low := maxi(first_row, int(ceil(minf(a.y, b.y) / GRID - 0.5)))
		var high := mini(last_row, int(ceil(maxf(a.y, b.y) / GRID - 0.5)))
		for row in range(low, high):
			var y := (float(row) + 0.5) * GRID
			buckets[row - first_row].append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y))
	for row in range(first_row, last_row):
		var intersections: Array = buckets[row - first_row]
		intersections.sort()
		for index in range(0, intersections.size() - 1, 2):
			var left := roundf(intersections[index] / GRID) * GRID
			var right := roundf(intersections[index + 1] / GRID) * GRID
			if right > left:
				rect(Vector2(left, row * GRID), Vector2(right - left, GRID), color)


func layered_line(start: Vector2, end: Vector2, widths: PackedFloat32Array, colors: PackedColorArray) -> void:
	# The layers share pixel centers, but retain their complete painter order.
	# Keep overlapping squares: merging them changes translucent accumulation.
	var a := (start / GRID).round()
	var b := (end / GRID).round()
	var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	var previous := Vector2(INF, INF)
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var point := a.lerp(b, float(index) / float(steps)).round() * GRID
		if point != previous:
			points.append(point)
			previous = point
	for layer in widths.size():
		var dimensions := (Vector2.ONE * widths[layer] / GRID).ceil() * GRID
		var offset := (dimensions / (GRID * 2.0)).floor() * GRID
		var color := colors[layer]
		if color.a <= 0.0: continue
		for point in points: _write_rect(point - offset, dimensions, color)
