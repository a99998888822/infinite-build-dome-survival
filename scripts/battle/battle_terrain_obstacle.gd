extends StaticBody2D
class_name BattleTerrainObstacle
## Streamed ground footprints shared by player collision and enemy routing.
const TERRAIN_LAYER := 3
static var active: Array[BattleTerrainObstacle] = []
var footprint := Rect2()

func _ready() -> void:
	var polygon := get_child(0) as CollisionPolygon2D
	if polygon != null and not polygon.polygon.is_empty():
		footprint = Rect2(polygon.polygon[0], Vector2.ZERO)
		for point in polygon.polygon: footprint = footprint.expand(point)
		footprint = polygon.transform * footprint
	active.append(self)

func _exit_tree() -> void:
	active.erase(self)

func routing_bounds(body: CharacterBody2D) -> Rect2:
	return _routing_bounds_for(_body_bounds(body))

static func _body_bounds(body: CharacterBody2D) -> Rect2:
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var body_bounds := Rect2(-16, -16, 32, 32)
	if shape != null and shape.shape != null:
		var basis := body.global_transform
		basis.origin = Vector2.ZERO
		body_bounds = (basis * shape.transform) * shape.shape.get_rect()
	return body_bounds

func _routing_bounds_for(body_bounds: Rect2) -> Rect2:
	var bounds := global_transform * footprint
	return Rect2(bounds.position - body_bounds.end, bounds.size + body_bounds.size).grow(8.0)

class Route:
	extends RefCounted
	var obstacle: BattleTerrainObstacle
	var bounds := Rect2()
	var target := Vector2(INF, INF)
	var points := PackedVector2Array()

	func direction(body: CharacterBody2D, destination: Vector2) -> Vector2:
		var start := body.global_position
		if BattleTerrainObstacle.active.is_empty():
			obstacle = null
			points.clear()
			return start.direction_to(destination)
		var nearest: BattleTerrainObstacle
		var next_bounds := Rect2()
		var distance := INF
		# Geometry belongs to this query, not to each obstacle. Recompute on
		# the next call so body scaling, shape edits and streaming stay live.
		var body_bounds := BattleTerrainObstacle._body_bounds(body)
		var viewport := body.get_viewport()
		# All candidates test the same segment. Prepare it once and retain the
		# exact two-axis clipping arithmetic from EvacuationBunker.crosses,
		# without a per-obstacle helper call, axis loop or indexed vectors.
		var motion := destination - start
		var parallel_x := absf(motion.x) < 0.0001
		var parallel_y := absf(motion.y) < 0.0001
		for candidate in BattleTerrainObstacle.active:
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or candidate.get_viewport() != viewport: continue
			var area := candidate._routing_bounds_for(body_bounds)
			var inside := area.grow(-0.5)
			var inside_end := inside.end
			var first := 0.0
			var last := 1.0
			if parallel_x:
				if start.x <= inside.position.x or start.x >= inside_end.x: continue
			else:
				var a := (inside.position.x - start.x) / motion.x
				var b := (inside_end.x - start.x) / motion.x
				first = maxf(first, minf(a, b))
				last = minf(last, maxf(a, b))
				if first >= last: continue
			if parallel_y:
				if start.y <= inside.position.y or start.y >= inside_end.y: continue
			else:
				var a := (inside.position.y - start.y) / motion.y
				var b := (inside_end.y - start.y) / motion.y
				first = maxf(first, minf(a, b))
				last = minf(last, maxf(a, b))
				if first >= last: continue
			var closest := start.clamp(area.position, area.end)
			var next_distance := start.distance_squared_to(closest)
			if next_distance < distance:
				distance = next_distance
				nearest = candidate
				next_bounds = area
		if nearest == null:
			obstacle = null
			points.clear()
			return start.direction_to(destination)
		if obstacle != nearest or bounds != next_bounds:
			obstacle = nearest
			bounds = next_bounds
			points.clear()
		var escape := EvacuationBunker.outside_point(bounds, start)
		if not start.is_equal_approx(escape):
			points.clear()
			return start.direction_to(escape)
		var finish := EvacuationBunker.outside_point(bounds, destination)
		if points.is_empty() or target.distance_squared_to(finish) > 32.0 * 32.0:
			target = finish
			points = EvacuationBunker.find_route(bounds, start, finish)
		while points.size() > 1 and not EvacuationBunker.crosses(bounds, start, points[1]):
			points.remove_at(0)
		return start.direction_to(points[0]) if not points.is_empty() else Vector2.ZERO
