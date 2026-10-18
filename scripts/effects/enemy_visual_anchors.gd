extends RefCounted
## Stable local-space anchors; never infer body size from an animation canvas.
const PROFILES = preload("res://scripts/effects/enemy_visual_profiles.gd")

static func body_bounds(enemy: Node2D) -> Rect2:
	var collider := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape != null:
		return collider.transform * collider.shape.get_rect()
	return Rect2(-10,-20,20,20)

static func radius(enemy: Node2D) -> float:
	var size := body_bounds(enemy).size
	return maxf(4.0,minf(size.x,size.y)*0.5)

static func factor(enemy: Node2D) -> float:
	return PROFILES.body_factor(enemy)

static func foot(enemy: Node2D) -> Vector2:
	var profile: Dictionary = PROFILES.PROFILES.get(str(enemy.get("enemy_id")),{})
	var origin: Vector2 = profile.get("origin",Vector2.ZERO)
	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.flip_h: origin.x = -origin.x
	return (origin*factor(enemy)).round()

static func head(enemy: Node2D) -> Vector2:
	var fallback := Vector2(body_bounds(enemy).get_center().x,body_bounds(enemy).position.y-12)
	var profile: Dictionary = PROFILES.PROFILES.get(str(enemy.get("enemy_id")),{})
	return (Vector2(profile.get("head",fallback/factor(enemy)))*factor(enemy)).round()

static func frost_size(enemy: Node2D) -> Vector2:
	var profile: Dictionary = PROFILES.PROFILES.get(str(enemy.get("enemy_id")),{})
	var size: Vector2 = profile.get("size",Vector2(48,20))
	return ((size*factor(enemy)/3.0).round()*3.0).max(Vector2(18,12))
