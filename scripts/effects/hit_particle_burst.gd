extends Node
class_name HitParticleBurst


static func spawn(
	parent: Node,
	hit_position: Vector2,
	burst_direction: Vector2 = Vector2.ZERO,
	color_override: Color = Color.TRANSPARENT
) -> ParticleWorld:
	return ParticleWorld.emit_profile(parent, "impact_green", hit_position, burst_direction, 1.0, color_override)
