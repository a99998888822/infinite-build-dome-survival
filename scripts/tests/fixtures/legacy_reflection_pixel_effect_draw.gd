extends RefCounted

## Render-only helpers. Simulation positions, hit shapes and timers stay continuous.
const GRID := 2.0
const DETAIL_GROUP := "pixel_combat_effects"


static func register(effect: Node2D, kind: String) -> int:
	var nearby := 0
	var total := 0
	for peer in effect.get_tree().get_nodes_in_group(DETAIL_GROUP):
		if not is_instance_valid(peer) or peer.is_queued_for_deletion():
			continue
		total += 1
		if peer.get_meta("pixel_effect_kind", "") == kind and effect.global_position.distance_squared_to(peer.global_position) < 25600.0:
			nearby += 1
	effect.set_meta("pixel_effect_kind", kind)
	effect.add_to_group(DETAIL_GROUP)
	# Only decoration is reduced. Even the lowest tier draws the main silhouette
	# and every effect continues applying its original damage/control logic.
	return 0 if nearby >= 4 or total >= 48 else (1 if nearby >= 2 or total >= 24 else 2)


static func layer(owner: Node2D, order: int, draw_callback: Callable) -> Node2D:
	var result := Node2D.new()
	result.z_as_relative = false
	result.z_index = order
	owner.add_child(result)
	result.draw.connect(draw_callback)
	return result


static func block(canvas: CanvasItem, point: Vector2, size: Vector2, color: Color) -> void:
	if color.a <= 0.0:
		return
	var dimensions := (size / GRID).ceil() * GRID
	var origin := (point / GRID).round() * GRID - (dimensions / (GRID * 2.0)).floor() * GRID
	canvas.draw_rect(Rect2(origin, dimensions), color)


static func line(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, width: float = GRID) -> void:
	var a := (start / GRID).round()
	var b := (end / GRID).round()
	var count := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	var previous := Vector2(INF, INF)
	for index in range(count + 1):
		var point := a.lerp(b, float(index) / float(count)).round() * GRID
		if point != previous:
			block(canvas, point, Vector2.ONE * width, color)
			previous = point


static func path(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float = GRID) -> void:
	for index in range(1, points.size()):
		line(canvas, points[index - 1], points[index], color, width)


static func arc(canvas: CanvasItem, radius: float, start: float, end: float, color: Color, width: float = GRID, flatten: Vector2 = Vector2.ONE, rotation_angle: float = 0.0) -> void:
	var count := maxi(2, int(ceil(absf(end - start) * radius / 6.0)))
	var previous := (Vector2.from_angle(start) * radius * flatten).rotated(rotation_angle)
	for index in range(1, count + 1):
		var angle := lerpf(start, end, float(index) / float(count))
		var next := (Vector2.from_angle(angle) * radius * flatten).rotated(rotation_angle)
		line(canvas, previous, next, color, width)
		previous = next


static func ellipse(canvas: CanvasItem, radius: Vector2, color: Color) -> void:
	var rows := maxi(1, int(ceil(radius.y / GRID)))
	for row in range(-rows, rows):
		var y := (float(row) + 0.5) * GRID
		var fraction := y / maxf(radius.y, GRID)
		if absf(fraction) >= 1.0:
			continue
		var half_width := maxf(GRID, floor(sqrt(1.0 - fraction * fraction) * radius.x / GRID) * GRID)
		canvas.draw_rect(Rect2(Vector2(-half_width, row * GRID), Vector2(half_width * 2.0, GRID)), color)


static func polygon(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var top := points[0].y
	var bottom := top
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	for row in range(int(floor(top / GRID)), int(ceil(bottom / GRID))):
		var y := (float(row) + 0.5) * GRID
		var intersections: Array[float] = []
		for index in points.size():
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				intersections.append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		for index in range(0, intersections.size() - 1, 2):
			var left := roundf(intersections[index] / GRID) * GRID
			var right := roundf(intersections[index + 1] / GRID) * GRID
			if right > left:
				canvas.draw_rect(Rect2(Vector2(left, row * GRID), Vector2(right - left, GRID)), color)
