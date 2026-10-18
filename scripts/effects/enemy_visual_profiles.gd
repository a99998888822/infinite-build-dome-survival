extends RefCounted
## Art anchors in the original authored body coordinates, shared by all statuses.
const PROFILES := {
	"enemy_mutated_grub": {"radius":22.0,"head":Vector2(-1,-32),"size":Vector2i(108,28),"origin":Vector2(-5,27),"alpha":Vector3(0.16,0.30,0.44),"pads":[]},
	"enemy_echo_bat": {"radius":16.0,"head":Vector2(4,-55),"size":Vector2i(68,20),"origin":Vector2(4,42),"alpha":Vector3(0.15,0.26,0.36),"pads":[]},
	"enemy_elite_rusher": {"radius":32.0,"head":Vector2(0,-164),"size":Vector2i(116,30),"origin":Vector2(0,1),"alpha":Vector3(0.16,0.29,0.40),"pads":[Rect2(-37,-4,27,9),Rect2(15,-3,27,9)]},
	"enemy_underworld_wolf": {"radius":36.8,"head":Vector2(10,-143),"size":Vector2i(164,42),"origin":Vector2(10,2),"alpha":Vector3(0.20,0.34,0.48),"pads":[Rect2(-43,-5,24,10),Rect2(22,-4,28,10)]},
}

static func body_factor(enemy: Node2D) -> float:
	var profile: Dictionary = PROFILES.get(str(enemy.get("enemy_id")),{})
	var collider := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not profile.is_empty() and collider != null and (collider.shape is CircleShape2D or collider.shape is CapsuleShape2D):
		# Includes revised base body dimensions AND challenge scaling exactly once.
		return maxf(0.1,float(collider.shape.radius)*minf(absf(collider.scale.x),absf(collider.scale.y))/float(profile.radius))
	return maxf(0.1,float(enemy.get("body_scale_multiplier")))
