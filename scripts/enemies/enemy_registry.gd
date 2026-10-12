extends Node

var _registered_enemies: Array[Node] = []
var revision: int = 0
var spatial_revision: int = 0
var _built_revision := -1
var _cells: Dictionary = {}
var _parents: Dictionary = {}
var _untracked := false
const CELL_SIZE := 128.0


func invalidate_spatial() -> void:
	spatial_revision += 1


func sync_spatial_revision() -> int:
	# Local enemy transforms notify synchronously. Ancestor transforms may not;
	# compare the few shared parents explicitly before using the spatial index.
	for parent in _parents:
		if not is_instance_valid(parent) or parent.get_global_transform() != _parents[parent]:
			invalidate_spatial()
			break
	if _untracked: invalidate_spatial()
	return spatial_revision


func candidates_in_radius(origin: Vector2, radius: float) -> PackedInt32Array:
	sync_spatial_revision()
	if _built_revision != spatial_revision:
		_cells.clear()
		_parents.clear()
		_untracked = false
		for index in _registered_enemies.size():
			var enemy := _registered_enemies[index] as Node2D
			if not is_instance_valid(enemy): continue
			var ancestor := enemy.get_parent()
			while ancestor != null and not ancestor is CanvasItem and not ancestor is CanvasLayer and not ancestor is Viewport:
				ancestor = ancestor.get_parent()
			var parent := ancestor as CanvasItem
			if parent != null: _parents[parent] = parent.get_global_transform()
			if not enemy.has_method("_spatial_tracking_marker"): _untracked = true
			var cell := Vector2i(floori(enemy.global_position.x / CELL_SIZE), floori(enemy.global_position.y / CELL_SIZE))
			if not _cells.has(cell): _cells[cell] = PackedInt32Array()
			_cells[cell].append(index)
		_built_revision = spatial_revision
	var extent := Vector2.ONE * (maxf(radius, 0.0) + 0.01)
	var low := Vector2i(((origin - extent) / CELL_SIZE).floor())
	var high := Vector2i(((origin + extent) / CELL_SIZE).floor())
	var result := PackedInt32Array()
	if (high.x - low.x + 1) * (high.y - low.y + 1) > maxi(_cells.size() * 2, 64):
		for index in _registered_enemies.size(): result.append(index)
		return result
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if _cells.has(Vector2i(x, y)): result.append_array(_cells[Vector2i(x, y)])
	# Exact tests stay in the callers. Sorting preserves registry order, ties and RNG.
	result.sort()
	return result


func register_enemy(enemy: Node) -> void:
	if enemy == null or _registered_enemies.has(enemy):
		return
	_registered_enemies.append(enemy)
	revision += 1
	invalidate_spatial()


func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	_registered_enemies.erase(enemy)
	revision += 1
	invalidate_spatial()


func get_registered_enemies() -> Array[Node]:
	# Return the live backing array so hot-path queries do not allocate.
	return _registered_enemies
