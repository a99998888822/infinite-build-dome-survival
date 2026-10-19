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
	return ellipse_shape(Vector2(radius, radius * ELLIPSE_RATIO))


static func ellipse_shape(axes: Vector2) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for i in 96:
		points.append(Vector2.from_angle(TAU * i / 96.0) * axes)
	shape.points = points
	return shape


static func body_overlaps(shape: Shape2D, transform: Transform2D, enemy: EnemyController, motion := Vector2.ZERO) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_alive():
		return false
	var body := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null or body.disabled or body.shape == null or (enemy.collision_layer & 2) == 0:
		return false
	if motion.is_zero_approx():
		return shape.collide(transform, body.shape, body.global_transform)
	return shape.collide_with_motion(transform, motion, body.shape, body.global_transform, Vector2.ZERO)


static func lamp_shape(direction: Vector2, reach: float, degrees: float) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	var pose := ground_transform(direction)
	var muzzle := Vector2(16, 0)
	var points := PackedVector2Array([pose * muzzle])
	var half_angle := deg_to_rad(degrees) * 0.5
	for i in 49:
		var ray := Vector2.from_angle(lerpf(-half_angle, half_angle, i / 48.0))
		var along := muzzle.dot(ray)
		var distance := -along + sqrt(maxf(0, along * along + reach * reach - muzzle.length_squared()))
		points.append(pose * (muzzle + ray * maxf(0.01, distance)))
	shape.points = points
	return shape


static func body_entry_fraction(shape: Shape2D, transform: Transform2D, motion: Vector2, enemy: EnemyController) -> float:
	if body_overlaps(shape, transform, enemy): return 0.0
	if not body_overlaps(shape, transform, enemy, motion): return INF
	var low := 0.0
	var high := 1.0
	for i in 14:
		var middle := (low + high) * 0.5
		if body_overlaps(shape, transform, enemy, motion * middle): high = middle
		else: low = middle
	return high


static func targeting_shape(source: WeaponInstance) -> Shape2D:
	var reach := source.get_attack_range()
	if source.is_ritual_tome(): return ellipse_shape(source.get_domain_axes())
	if source.is_grenade(): return ellipse_shape(grenade_range_axes(source))
	if source.is_copper_lamp() or source.is_camp_dagger(): return projected_disk(reach)
	if source.is_meteor_flail():
		return ellipse_shape(Vector2(reach, reach * ELLIPSE_RATIO) + Vector2.ONE * source.get_hit_radius())
	var circle := CircleShape2D.new()
	circle.radius = reach
	if source.has_combat_tag(L10n.text("stat.category.projectiles")):
		circle.radius += source.get_hit_radius()
	return circle


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
