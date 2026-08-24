extends Node
class_name HitParticleBurst

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")

static func spawn(
	parent: Node,
	hit_position: Vector2,
	burst_direction: Vector2 = Vector2.ZERO,
	color_override: Color = Color.TRANSPARENT
) -> Node2D:
	return PARTICLE_WORLD_SCRIPT.emit_profile(parent, "impact_green", hit_position, burst_direction, 1.0, color_override)
