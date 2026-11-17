extends RefCounted
class_name WeaponContactQuery
## Per-owner geometry only; enemy bodies and transforms are read at each contact.

var shape: Shape2D
var _kind := ""
var _dimensions := Vector3.ZERO
var _direction := Vector2.ZERO
var _local_bounds := Rect2()
var _world_bounds := Rect2()
var _transform := Transform2D.IDENTITY
var _inverse_transform := Transform2D.IDENTITY
var _interior_polygon := PackedVector2Array()
var _interior_radius_squared := -1.0


func configure_targeting(source: WeaponInstance, radius: float = -1.0) -> void:
	var dimensions := AttackFootprint.targeting_dimensions(source)
	if radius >= 0.0 and not is_equal_approx(radius, source.get_attack_range()):
		dimensions = Vector3(radius, radius, 1.0)
	if _kind == "target" and dimensions == _dimensions:
		return
	_kind = "target"
	_dimensions = dimensions
	shape = AttackFootprint.shape_for_targeting_dimensions(dimensions)
	_local_bounds = shape.get_rect()
	_capture_interior()


func configure_lamp(direction: Vector2, reach: float, degrees: float) -> void:
	var dimensions := Vector3(reach, degrees, 0.0)
	if _kind == "lamp" and dimensions == _dimensions and direction == _direction:
		return
	_kind = "lamp"
	_dimensions = dimensions
	_direction = direction
	shape = AttackFootprint.lamp_shape(direction, reach, degrees)
	_local_bounds = shape.get_rect()
	_capture_interior()


func place(transform: Transform2D) -> void:
	_transform = transform
	_inverse_transform = transform.affine_inverse() if not is_zero_approx(transform.determinant()) else Transform2D.IDENTITY
	# Conservative padding retains touching contacts despite floating-point noise.
	_world_bounds = (transform * _local_bounds).grow(0.01)


func overlaps(enemy: EnemyController) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_alive():
		return false
	var body := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null or body.disabled or body.shape == null or (enemy.collision_layer & 2) == 0:
		return false
	var pose := body.global_transform
	if not _world_bounds.intersects(pose * body.shape.get_rect(), true):
		return false
	# A centered primitive contains its local origin. If that actual body point
	# lies inside the attack, contact is already proven; no convex GJK is needed.
	# Bodies whose centers lie outside still use the original exact shape test,
	# preserving grazing contacts, offsets, rotation, scale and edge hits.
	if not is_zero_approx(_transform.determinant()) and (body.shape is CircleShape2D or body.shape is CapsuleShape2D or body.shape is RectangleShape2D):
		var center := _inverse_transform * pose.origin
		if _interior_radius_squared > 0.0 and center.length_squared() < _interior_radius_squared:
			return true
		if not _interior_polygon.is_empty() and Geometry2D.is_point_in_polygon(center, _interior_polygon):
			return true
	return shape.collide(_transform, body.shape, pose)


func _capture_interior() -> void:
	_invalidate_interior()
	if shape is ConvexPolygonShape2D:
		_interior_polygon = shape.points
	elif shape is CircleShape2D:
		_interior_radius_squared = shape.radius * shape.radius
	# Public scratch shapes can be resized by callers. Such changes invalidate
	# only this shortcut; exact collision remains authoritative until reconfigured.
	var owner: WeakRef = weakref(self)
	shape.changed.connect(func():
		var query: RefCounted = owner.get_ref()
		if query != null: query._invalidate_interior())


func _invalidate_interior() -> void:
	_interior_polygon = PackedVector2Array()
	_interior_radius_squared = -1.0
