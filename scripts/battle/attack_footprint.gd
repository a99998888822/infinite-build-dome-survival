extends RefCounted
class_name AttackFootprint
## Shared dimensions for active targeting and weapon contact checks.

const ELLIPSE_RATIO := 145.0 / 220.0
const FLAIL_ARC := 130.0


static func project(point: Vector2) -> Vector2:
	return point * Vector2(1.0, ELLIPSE_RATIO)


static func unproject(point: Vector2) -> Vector2:
	return point / Vector2(1.0, ELLIPSE_RATIO)


static func ground_direction(screen_direction: Vector2) -> Vector2:
	return unproject(screen_direction).normalized() if not screen_direction.is_zero_approx() else Vector2.RIGHT


static func ground_transform(screen_direction: Vector2, origin := Vector2.ZERO) -> Transform2D:
	var forward := ground_direction(screen_direction)
	# Rotate in the ground plane, then project. Screen Y stays the minor axis.
	return Transform2D(project(forward), project(Vector2(-forward.y, forward.x)), origin)


static func spread_direction(screen_direction: Vector2, radians: float) -> Vector2:
	return project(ground_direction(screen_direction).rotated(radians)).normalized()


static func projected_disk(radius: float) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for i in 96:
		points.append(project(Vector2.from_angle(TAU * i / 96.0) * radius))
	shape.points = points
	return shape


static func player_clearance(source: WeaponInstance) -> float:
	var clearance := 28.0
	if is_instance_valid(source.owner_player):
		var collider := source.owner_player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collider != null and collider.shape != null:
			var rect := collider.shape.get_rect()
			clearance = 0.0
			for corner in [rect.position, rect.end, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y)]:
				clearance = maxf(clearance, (collider.global_transform * corner - source.owner_player.global_position).length())
	return clearance + 6.0


static func grenade_range_axes(source: WeaponInstance) -> Vector2:
	return Vector2(1, ELLIPSE_RATIO) * source.get_attack_range()


static func grenade_blast_axes(source: WeaponInstance) -> Vector2:
	return Vector2(1, ELLIPSE_RATIO) * minf(source.get_grenade_blast_radius(), source.get_attack_range())


static func grenade_landings(source: WeaponInstance, pointer: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var axes := grenade_range_axes(source).max(Vector2.ONE)
	var inner := grenade_blast_axes(source)
	var center_axes := (axes - inner).max(Vector2.ZERO)
	var count := maxi(1, int(source.get_stat("projectile_count")))
	var aim := pointer.normalized() if not pointer.is_zero_approx() else Vector2.RIGHT
	var center := Vector2.ZERO
	if center_axes.x > 0 and center_axes.y > 0:
		# Clamp the aim before spreading so distant cursors cannot collapse a volley.
		center = (pointer / center_axes).limit_length(1.0) * center_axes
	for i in count:
		var spread := (i - (count - 1) * 0.5) * minf(30, inner.x * 0.65)
		var point := center + aim.orthogonal() * spread
		if center_axes.x <= 0 or center_axes.y <= 0:
			result.append(Vector2.ZERO)
		else:
			result.append((point / center_axes).limit_length(1.0) * center_axes)
	return result


static func in_lamp_cone(offset: Vector2, direction: Vector2, reach: float, degrees: float) -> bool:
	var ground := unproject(offset)
	var forward := ground_direction(direction)
	var relative := ground - forward * 16.0
	return ground.length_squared() <= reach * reach and relative.dot(forward) >= 0.0 and absf(forward.angle_to(relative)) <= deg_to_rad(degrees) * 0.5


static func in_flail_fan(offset: Vector2, direction: Vector2, reach: float) -> bool:
	var ground := unproject(offset)
	return ground.length_squared() <= reach * reach + 0.0001 and absf(ground_direction(direction).angle_to(ground)) <= deg_to_rad(FLAIL_ARC) * 0.5 + 0.00001
