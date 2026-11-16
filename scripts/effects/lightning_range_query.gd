extends RefCounted
## Compatibility facade for shared combat geometry queries.
const TARGETS = preload("res://scripts/battle/combat_target_query.gd")

static func candidates(origin: Vector2, radius: float) -> Dictionary:
	return TARGETS.radius_candidates(origin, radius)
