extends RefCounted
## Terminal ground dimensions, shared by collision and presentation.
const ATTACK = preload("res://scripts/battle/attack_footprint.gd")
const GROUND_FLATTEN := ATTACK.ELLIPSE_RATIO
const WATER_FLATTEN := 0.66
const ICE_FLATTEN := 0.55
const WIND_RADIUS := 72.0

static func axes(radius: float, flatten: float = GROUND_FLATTEN) -> Vector2:
	return Vector2(radius, radius * flatten)

static func shape(dimensions: Vector2) -> ConvexPolygonShape2D:
	return ATTACK.ellipse_shape(dimensions)

static func contains(dimensions: Vector2, offset: Vector2) -> bool:
	return (offset / dimensions.max(Vector2.ONE * 0.001)).length_squared() <= 1.0
