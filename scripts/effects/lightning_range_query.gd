extends RefCounted
## Share only exact geometry. Alive/visited state and RNG stay in each chain.
const MAX_QUERIES := 256
static var _frame := -1
static var _revision := -1
static var _spatial_revision := -1
static var _queries: Dictionary = {}

static func candidates(origin: Vector2, radius: float) -> Dictionary:
	var spatial := EnemyRegistry.sync_spatial_revision()
	var frame := Engine.get_process_frames()
	if frame != _frame or _revision != EnemyRegistry.revision or spatial != _spatial_revision:
		_queries.clear()
		_frame = frame
		_revision = EnemyRegistry.revision
		_spatial_revision = spatial
	var key := [origin, radius]
	if _queries.has(key): return _queries[key]
	var indices := PackedInt32Array()
	var distances := PackedFloat64Array()
	var registry := EnemyRegistry.get_registered_enemies()
	var radius_squared := radius * radius
	for index in EnemyRegistry.candidates_in_radius(origin, radius):
		var enemy := registry[index] as EnemyController
		if not is_instance_valid(enemy): continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance > radius_squared: continue
		indices.append(index)
		distances.append(distance)
	_spatial_revision = EnemyRegistry.spatial_revision
	var result := {"indices": indices, "distances": distances}
	if _queries.size() < MAX_QUERIES: _queries[key] = result
	return result
