extends RefCounted
## Bind identical beam shapes once; refresh their shared results each frame or
## registry/transform edit. Damage and each beam's hit ledger remain independent.
const MAX_GEOMETRIES := 512
const MAX_FILTERS := 2048
const MAX_SWEEPS := 256

class Geometry:
	var origin: Vector2
	var radius: float
	var orientation: float
	var epoch := -1
	var geometry_epoch := -1
	var indices := PackedInt32Array()
	var directions := PackedVector2Array()
	var angles := PackedFloat64Array()
	var sweeps: Dictionary = {}
	var sweep_count := 0
	var last_start := INF
	var last_angle := INF
	var last_result: Dictionary = {}

static var _frame := -1
static var _revision := -1
static var _spatial_revision := -1
static var _epoch := 0
static var _geometry_epoch := 0
static var _queries: Dictionary = {}
static var _active_geometries: Array[Geometry] = []
static var _geometry_count := 0
static var _filter_count := 0

static func candidates(origin: Vector2, radius: float, orientation: float,
		start_angle: float, sweep_angle: float) -> Dictionary:
	return candidates_for(bind_geometry(origin, radius, orientation), start_angle, sweep_angle)


static func bind_geometry(origin: Vector2, radius: float, orientation: float) -> Geometry:
	# Exact doubles remain in the key. Beam owners retain the binding and avoid
	# allocating these keys again on every update.
	var shape_key := [radius, orientation]
	var at_origin: Dictionary = _queries.get(origin, {})
	if at_origin.has(shape_key): return at_origin[shape_key]
	if _geometry_count >= MAX_GEOMETRIES:
		_queries.clear()
		_geometry_count = 0
		at_origin = {}
	var geometry := Geometry.new()
	geometry.origin = origin
	geometry.radius = radius
	geometry.orientation = orientation
	at_origin[shape_key] = geometry
	_queries[origin] = at_origin
	_geometry_count += 1
	return geometry


static func candidates_for(geometry: Geometry, start_angle: float, sweep_angle: float) -> Dictionary:
	var spatial := EnemyRegistry.sync_spatial_revision()
	var frame := Engine.get_process_frames()
	if _revision != EnemyRegistry.revision or spatial != _spatial_revision:
		_geometry_epoch += 1
	if frame != _frame or _revision != EnemyRegistry.revision or spatial != _spatial_revision:
		# Bindings can outlive their frame, but hit-filter results must not. Drop
		# all previous-epoch results, including shapes no longer queried.
		for previous in _active_geometries:
			previous.sweeps.clear()
			previous.last_result = {}
		_active_geometries.clear()
		_epoch += 1
		_filter_count = 0
		_frame = frame
		_revision = EnemyRegistry.revision
		_spatial_revision = spatial
	if geometry.epoch != _epoch:
		# Frozen/stationary targets keep exact distances and angles across frames.
		# Local/ancestor transforms and registry edits invalidate this separately.
		if geometry.geometry_epoch != _geometry_epoch:
			var data := _build_geometry(geometry.origin, geometry.radius, geometry.orientation)
			geometry.indices = data.indices
			geometry.directions = data.directions
			geometry.angles = data.angles
			geometry.geometry_epoch = _geometry_epoch
		geometry.sweeps.clear()
		geometry.sweep_count = 0
		geometry.last_result = {}
		geometry.epoch = _epoch
		_active_geometries.append(geometry)
		_spatial_revision = EnemyRegistry.spatial_revision
	if not geometry.last_result.is_empty() and geometry.last_start == start_angle and geometry.last_angle == sweep_angle:
		return geometry.last_result
	geometry.last_start = start_angle
	geometry.last_angle = sweep_angle
	# Float keys preserve double precision without per-contact temporary arrays.
	var sweeps: Dictionary = geometry.sweeps.get(start_angle, {})
	if sweeps.has(sweep_angle):
		geometry.last_result = sweeps[sweep_angle]
		return geometry.last_result
	var indices := PackedInt32Array()
	var directions := PackedVector2Array()
	for cursor in geometry.indices.size():
		var angle: float = geometry.angles[cursor]
		if angle < start_angle or angle > sweep_angle: continue
		indices.append(geometry.indices[cursor])
		directions.append(geometry.directions[cursor])
	var result := {"indices": indices, "directions": directions, "filtered": {}}
	if geometry.sweep_count >= MAX_SWEEPS:
		geometry.sweeps.clear()
		geometry.sweep_count = 0
		sweeps = {}
	sweeps[sweep_angle] = result
	geometry.sweeps[start_angle] = sweeps
	geometry.sweep_count += 1
	geometry.last_result = result
	return result


static func excluding_hits(sweep: Dictionary, hit_mask: PackedInt64Array) -> Dictionary:
	# Masks are per-beam ledgers in registry order. Packed arrays are value keys
	# with copy-on-write, so later hits cannot mutate a retained dictionary key.
	# Only identical exclusion sets share a result; damage/alive state stay live.
	var filtered: Dictionary = sweep.filtered
	if filtered.has(hit_mask): return filtered[hit_mask]
	var indices := PackedInt32Array()
	var directions := PackedVector2Array()
	var source_indices: PackedInt32Array = sweep.indices
	var source_directions: PackedVector2Array = sweep.directions
	for cursor in source_indices.size():
		var index := source_indices[cursor]
		if (hit_mask[index >> 6] & (1 << (index & 63))) != 0: continue
		indices.append(index)
		directions.append(source_directions[cursor])
	var result := {"indices": indices, "directions": directions}
	if _filter_count < MAX_FILTERS:
		filtered[hit_mask] = result
		_filter_count += 1
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
