extends RefCounted
class_name ProjectileGuard
## Only native damage geometry registers shields; decoration never blocks shots.
static var surfaces: Array[Dictionary] = []
static var blocked_count := 0

static func intercept(source: Node2D, weapon: WeaponInstance, shape: Shape2D, pose: Transform2D) -> void:
	if not weapon.has_effect("guard") or not is_instance_valid(source) or not source.is_inside_tree(): return
	var frame := Engine.get_physics_frames()
	surfaces = surfaces.filter(func(s): return int(s.frame) >= frame - 1 and is_instance_valid(s.owner.get_ref()))
	# Copy mutable query shapes: native melee runtimes reuse their scratch shape.
	surfaces.append({"owner": weakref(source), "shape": shape.duplicate(), "pose": pose, "frame": frame})
	for shot in source.get_tree().get_nodes_in_group("hostile_projectiles"):
		if not is_instance_valid(shot) or shot.impacted: continue
		var end: Vector2 = shot.global_position + shot.direction * shot.speed * source.get_physics_process_delta_time()
		if _overlaps(shape, pose, shot.global_position, end, 10.0):
			shot.impact()
			blocked_count += 1

static func intercept_segment(source: Node2D, weapon: WeaponInstance, start: Vector2, end: Vector2, radius: float) -> void:
	if not weapon.has_effect("guard"): return
	var shape := CapsuleShape2D.new()
	shape.radius = maxf(radius, 1.0)
	shape.height = start.distance_to(end) + shape.radius * 2.0
	intercept(source, weapon, shape, Transform2D((end - start).angle() + PI / 2.0, (start + end) * 0.5))

static func blocks_motion(shot: Node2D, start: Vector2, end: Vector2) -> bool:
	var frame := Engine.get_physics_frames()
	surfaces = surfaces.filter(func(s): return int(s.frame) >= frame - 1 and is_instance_valid(s.owner.get_ref()))
	for surface in surfaces:
		var owner: Node2D = surface.owner.get_ref()
		if not owner.is_inside_tree() or owner.is_queued_for_deletion(): continue
		if _overlaps(surface.shape, surface.pose, start, end, 10.0):
			shot.impact()
			blocked_count += 1
			return true
	return false

static func _overlaps(shape: Shape2D, pose: Transform2D, start: Vector2, end: Vector2, radius: float) -> bool:
	var bullet := CircleShape2D.new()
	bullet.radius = radius
	return bullet.collide_with_motion(Transform2D(0, start), end - start, shape, pose, Vector2.ZERO)
