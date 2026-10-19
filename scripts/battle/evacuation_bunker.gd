extends StaticBody2D
class_name EvacuationBunker
## The doorway remains accessible to the player; enemies avoid the whole footprint.
const ENEMY_BARRIER_LAYER := 4
const FOOTPRINT := Rect2(-252, -125, 500, 150)
const ROUTE_MARGIN := 18.0
static var current: EvacuationBunker


func _ready() -> void:
	collision_layer = 1 << (ENEMY_BARRIER_LAYER - 1)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = FOOTPRINT.size
	shape.shape = box
	shape.position = FOOTPRINT.get_center()
	add_child(shape)
	current = self


func deactivate() -> void:
	if current == self: current = null
	collision_layer = 0


func _exit_tree() -> void:
	deactivate()


func routing_bounds(body: CharacterBody2D) -> Rect2:
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var body_bounds := Rect2(-16, -16, 32, 32)
	if shape != null and shape.shape != null:
		var basis := body.global_transform
		basis.origin = Vector2.ZERO
		body_bounds = (basis * shape.transform) * shape.shape.get_rect()
	var footprint := global_transform * FOOTPRINT
	# Expand asymmetrically: elite capsules sit well above their node origins.
	return Rect2(footprint.position - body_bounds.end, footprint.size + body_bounds.size).grow(ROUTE_MARGIN)


static func crosses(bounds: Rect2, start: Vector2, finish: Vector2) -> bool:
	# Open interior lets a route travel along the padded rectangle's edges.
	var inside := bounds.grow(-0.5)
	var motion := finish - start
	var first := 0.0
	var last := 1.0
	for axis in 2:
		if absf(motion[axis]) < 0.0001:
			if start[axis] <= inside.position[axis] or start[axis] >= inside.end[axis]: return false
			continue
		var a := (inside.position[axis] - start[axis]) / motion[axis]
		var b := (inside.end[axis] - start[axis]) / motion[axis]
		first = maxf(first, minf(a, b))
		last = minf(last, maxf(a, b))
		if first >= last: return false
	return true


static func outside_point(bounds: Rect2, point: Vector2) -> Vector2:
	if not bounds.has_point(point): return point
	var candidates := PackedVector2Array([
		Vector2(bounds.position.x, point.y), Vector2(bounds.end.x, point.y),
		Vector2(point.x, bounds.position.y), Vector2(point.x, bounds.end.y)])
	var nearest := candidates[0]
	for candidate in candidates:
		if point.distance_squared_to(candidate) < point.distance_squared_to(nearest): nearest = candidate
	return nearest


static func find_route(bounds: Rect2, start: Vector2, finish: Vector2) -> PackedVector2Array:
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	var best := PackedVector2Array()
	var best_length := INF
	# A rectangle's shortest detour follows one of its two perimeter directions.
	for first in 4:
		if crosses(bounds, start, corners[first]): continue
		for step in [-1, 1]:
			var route := PackedVector2Array()
			var length := start.distance_to(corners[first])
			for offset in 4:
				var index := posmod(first + offset * step, 4)
				var corner := corners[index]
				if not route.is_empty(): length += route[-1].distance_to(corner)
				route.append(corner)
				if crosses(bounds, corner, finish): continue
				length += corner.distance_to(finish)
				if length < best_length:
					best_length = length
					best = route.duplicate()
				break
	return best


class Route:
	extends RefCounted
	var bunker: EvacuationBunker
	var bounds := Rect2()
	var target := Vector2(INF, INF)
	var points := PackedVector2Array()


	func direction(body: CharacterBody2D, destination: Vector2) -> Vector2:
		var active := EvacuationBunker.current
		if not is_instance_valid(active):
			points.clear()
			return body.global_position.direction_to(destination)
		var next_bounds := active.routing_bounds(body)
		if bunker != active or bounds != next_bounds:
			bunker = active
			bounds = next_bounds
			points.clear()
		var start := body.global_position
		var escape := EvacuationBunker.outside_point(bounds, start)
		if not start.is_equal_approx(escape):
			points.clear()
			return start.direction_to(escape)
		var finish := EvacuationBunker.outside_point(bounds, destination)
		if not EvacuationBunker.crosses(bounds, start, finish):
			points.clear()
			return start.direction_to(finish)
		# Cache the chosen side until the target moves appreciably, avoiding jitter
		# and per-frame path searches for every member of a pursuing crowd.
		if points.is_empty() or target.distance_squared_to(finish) > 32.0 * 32.0:
			target = finish
			points = EvacuationBunker.find_route(bounds, start, finish)
		while points.size() > 1 and not EvacuationBunker.crosses(bounds, start, points[1]):
			points.remove_at(0)
		return start.direction_to(points[0]) if not points.is_empty() else Vector2.ZERO
