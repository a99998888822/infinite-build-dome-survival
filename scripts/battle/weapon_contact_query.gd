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


func configure_lamp(direction: Vector2, reach: float, degrees: float) -> void:
	var dimensions := Vector3(reach, degrees, 0.0)
	if _kind == "lamp" and dimensions == _dimensions and direction == _direction:
		return
	_kind = "lamp"
	_dimensions = dimensions
	_direction = direction
	shape = AttackFootprint.lamp_shape(direction, reach, degrees)
	_local_bounds = shape.get_rect()


func place(transform: Transform2D) -> void:
	_transform = transform
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
	return shape.collide(_transform, body.shape, pose)
