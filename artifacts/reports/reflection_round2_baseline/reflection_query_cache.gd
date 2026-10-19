extends RefCounted
## Share geometry, never damage or a beam's hit ledger. Entries live one render
## frame and are invalidated by registry/local/ancestor transform changes.
const MAX_GEOMETRIES := 512
static var _frame := -1
static var _revision := -1
static var _spatial_revision := -1
static var _queries: Dictionary = {}
static var _geometry_count := 0

static func candidates(origin: Vector2, radius: float, orientation: float,
		start_angle: float, sweep_angle: float) -> Dictionary:
	var spatial := EnemyRegistry.sync_spatial_revision()
	var frame := Engine.get_process_frames()
	if frame != _frame or _revision != EnemyRegistry.revision or spatial != _spatial_revision:
		_queries.clear()
		_geometry_count = 0
		_frame = frame
		_revision = EnemyRegistry.revision
		_spatial_revision = spatial
	# Array keys retain double precision; Vector2 would round sweep boundaries.
	var shape_key := [radius, orientation]
	var at_origin: Dictionary = _queries.get(origin, {})
	var geometry: Dictionary = at_origin.get(shape_key, {})
	if geometry.is_empty():
		geometry = _build_geometry(origin, radius, orientation)
		_spatial_revision = EnemyRegistry.spatial_revision
		if _geometry_count < MAX_GEOMETRIES:
			at_origin[shape_key] = geometry
			_queries[origin] = at_origin
			_geometry_count += 1
	var sweep_key := [start_angle, sweep_angle]
	var sweeps: Dictionary = geometry.sweeps
	if sweeps.has(sweep_key): return sweeps[sweep_key]
	var indices := PackedInt32Array()
	var directions := PackedVector2Array()
	for cursor in geometry.indices.size():
		var angle: float = geometry.angles[cursor]
		if angle < start_angle or angle > sweep_angle: continue
		indices.append(geometry.indices[cursor])
		directions.append(geometry.directions[cursor])
	var result := {"indices": indices, "directions": directions}
	sweeps[sweep_key] = result
	return result

static func _build_geometry(origin: Vector2, radius: float, orientation: float) -> Dictionary:
	var indices := PackedInt32Array()
	var directions := PackedVector2Array()
	# Angles are GDScript doubles: float32 storage would change edge contacts.
	var angles := PackedFloat64Array()
	var radius_squared := radius * radius
	var radius_with_slack := radius_squared + maxf(0.01, radius_squared * 0.000001)
	var registry := EnemyRegistry.get_registered_enemies()
	for index in EnemyRegistry.candidates_in_radius(origin, radius):
		var enemy := registry[index] as EnemyController
		if not is_instance_valid(enemy): continue
		# Keep the legacy distance/normalization/angle arithmetic exactly.
		# Alive and already-hit checks stay live in the consumer, not this cache.
		if origin.distance_squared_to(enemy.global_position) > radius_with_slack: continue
		if origin.distance_to(enemy.global_position) > radius: continue
		var direction := origin.direction_to(enemy.global_position)
		var angle := atan2(direction.y, direction.x) - orientation
		while angle > PI: angle -= TAU
		while angle < -PI: angle += TAU
		indices.append(index)
		directions.append(direction)
		angles.append(angle)
	return {"indices": indices, "directions": directions, "angles": angles, "sweeps": {}}
