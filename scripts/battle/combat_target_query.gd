extends RefCounted
## Preserve physics membership and ordering; center queries use the spatial index.
const DIAGNOSTICS = preload("res://scripts/battle/combat_diagnostics.gd")
const MAX_QUERIES := 256
static var cache_enabled := true
static var _frame := -1
static var _physics_frame := -1
static var _revision := -1
static var _spatial_revision := -1
static var _queries: Dictionary = {}

static func radius_candidates(origin: Vector2, radius: float) -> Dictionary:
	var started := DIAGNOSTICS.begin()
	DIAGNOSTICS.count(&"radius_queries")
	var spatial := EnemyRegistry.sync_spatial_revision()
	var frame := Engine.get_process_frames()
	var physics_frame := Engine.get_physics_frames()
	if frame != _frame or physics_frame != _physics_frame or _revision != EnemyRegistry.revision or spatial != _spatial_revision:
		_queries.clear()
		_frame = frame
		_physics_frame = physics_frame
		_revision = EnemyRegistry.revision
		_spatial_revision = spatial
	var key := [origin, radius]
	if cache_enabled and _queries.has(key):
		DIAGNOSTICS.count(&"radius_cache_hits")
		DIAGNOSTICS.finish(&"radius_queries", started)
		return _queries[key]
	var indices := PackedInt32Array()
	var distances := PackedFloat64Array()
	var registry := EnemyRegistry.get_registered_enemies()
	var radius_squared := radius * radius
	var candidates := EnemyRegistry.candidates_in_radius(origin, radius)
	DIAGNOSTICS.count(&"radius_candidates", candidates.size())
	for index in candidates:
		var enemy := registry[index] as EnemyController
		if not is_instance_valid(enemy): continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance > radius_squared: continue
		indices.append(index)
		distances.append(distance)
	_spatial_revision = EnemyRegistry.spatial_revision
	var result := {"indices": indices, "distances": distances}
	if cache_enabled and _queries.size() < MAX_QUERIES: _queries[key] = result
	DIAGNOSTICS.finish(&"radius_queries", started)
	return result

## Engine physics may have unflushed transforms, offset shapes or disabled bodies.
## Keep each query fresh rather than reusing stale physics hits.
static func intersect_shape(world: World2D, query: PhysicsShapeQueryParameters2D, limit: int, kind: StringName) -> Array[Dictionary]:
	var started := DIAGNOSTICS.begin()
	var results := world.direct_space_state.intersect_shape(query, limit)
	if DIAGNOSTICS.enabled:
		DIAGNOSTICS.count(&"shape_queries")
		DIAGNOSTICS.count(kind)
		DIAGNOSTICS.count(&"shape_candidates", results.size())
		DIAGNOSTICS.finish(&"shape_queries", started)
	return results
