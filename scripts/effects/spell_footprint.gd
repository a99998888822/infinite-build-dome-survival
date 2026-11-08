extends RefCounted
## Terminal ground dimensions, shared by collision and presentation.
const ATTACK = preload("res://scripts/battle/attack_footprint.gd")
## Every spell footprint lies on the battlefield ground plane; one tilt for all.
const GROUND_FLATTEN := ATTACK.ELLIPSE_RATIO
const WIND_RADIUS := 72.0
static var _shapes: Dictionary = {}

static func axes(radius: float, flatten: float = GROUND_FLATTEN) -> Vector2:
	return Vector2(radius, radius * flatten)

static func shape(dimensions: Vector2) -> ConvexPolygonShape2D:
	# Read-only spell geometry is identical across victims and projectile copies.
	# Rebuilding 96-point convex resources for every proc also rebuilds physics
	# server geometry. Bound the cache for runs with continuously varying sizes.
	if _shapes.has(dimensions): return _shapes[dimensions]
	var result := ATTACK.ellipse_shape(dimensions)
	if _shapes.size() >= 128: _shapes.clear()
	_shapes[dimensions] = result
	return result

static func contains(dimensions: Vector2, offset: Vector2) -> bool:
	return (offset / dimensions.max(Vector2.ONE * 0.001)).length_squared() <= 1.0
