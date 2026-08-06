extends Node
class_name ObjectPool

signal pool_registered(pool_id: String)
signal pool_spawned(pool_id: String, node: Node)
signal pool_released(pool_id: String, node: Node)

const POOL_ROOT_NAME: String = "_ObjectPoolRoot"

var _prefabs: Dictionary = {}
var _free_nodes: Dictionary = {}
var _active_nodes: Dictionary = {}
var _pool_root: Node = null


func _ready() -> void:
	_ensure_pool_root()


func register_prefab(pool_id: String, prefab: PackedScene, warmup_count: int = 0) -> void:
	# 注册池化模板，可选预热对象数量。
	var sanitized_pool_id := pool_id.strip_edges()
	if sanitized_pool_id.is_empty() or prefab == null:
		return
	_prefabs[sanitized_pool_id] = prefab
	_ensure_pool_collections(sanitized_pool_id)
	emit_signal("pool_registered", sanitized_pool_id)
	if warmup_count > 0:
		warmup(sanitized_pool_id, warmup_count)


func is_registered(pool_id: String) -> bool:
	return _prefabs.has(pool_id.strip_edges())


func warmup(pool_id: String, count: int, parent: Node = null) -> void:
	var sanitized_pool_id := pool_id.strip_edges()
	if not is_registered(sanitized_pool_id) or count <= 0:
		return
	for _index in count:
		var instance := _create_instance(sanitized_pool_id)
		if instance != null:
			_release_instance(sanitized_pool_id, instance, parent)


func spawn(pool_id: String, parent: Node = null) -> Node:
	# 优先复用空闲对象，避免高频实体反复实例化。
	var sanitized_pool_id := pool_id.strip_edges()
	if not is_registered(sanitized_pool_id):
		push_error("[ObjectPool] pool not registered: %s" % sanitized_pool_id)
		return null

	_ensure_pool_collections(sanitized_pool_id)
	var node: Node = null
	if _free_nodes[sanitized_pool_id].size() > 0:
		node = _free_nodes[sanitized_pool_id].pop_back()
	else:
		node = _create_instance(sanitized_pool_id)

	if node == null:
		return null

	var target_parent := parent
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent == null:
		target_parent = self

	if node.get_parent() != null and node.get_parent() != target_parent:
		node.reparent(target_parent)
	elif node.get_parent() == null:
		target_parent.add_child(node)

	_active_nodes[sanitized_pool_id][node.get_instance_id()] = node
	if node.has_method("on_pooled_spawned"):
		node.call("on_pooled_spawned", sanitized_pool_id)
	emit_signal("pool_spawned", sanitized_pool_id, node)
	return node


func despawn(node: Node) -> void:
	# 回收对象时只处理来自对象池的实例。
	if node == null:
		return
	var pool_id := str(node.get_meta("pool_id", ""))
	if pool_id.strip_edges().is_empty() or not _active_nodes.has(pool_id):
		return
	_release_node(pool_id, node)


func release(node: Node) -> void:
	despawn(node)


func clear(pool_id: String) -> void:
	# 场景切换或重开时清空单个池。
	var sanitized_pool_id := pool_id.strip_edges()
	if not _free_nodes.has(sanitized_pool_id):
		return
	for node in _free_nodes[sanitized_pool_id]:
		if is_instance_valid(node):
			node.queue_free()
	_free_nodes[sanitized_pool_id].clear()
	for node_id in _active_nodes.get(sanitized_pool_id, {}).keys():
		var active_node: Node = _active_nodes[sanitized_pool_id][node_id]
		if is_instance_valid(active_node):
			active_node.queue_free()
	_active_nodes[sanitized_pool_id].clear()


func clear_all() -> void:
	for pool_id in _prefabs.keys():
		clear(str(pool_id))


func get_pool_counts(pool_id: String) -> Dictionary:
	var sanitized_pool_id := pool_id.strip_edges()
	_ensure_pool_collections(sanitized_pool_id)
	return {
		"free": _free_nodes[sanitized_pool_id].size(),
		"active": _active_nodes[sanitized_pool_id].size(),
	}


func _ensure_pool_root() -> void:
	if _pool_root != null and is_instance_valid(_pool_root):
		return
	_pool_root = Node.new()
	_pool_root.name = POOL_ROOT_NAME
	add_child(_pool_root)


func _ensure_pool_collections(pool_id: String) -> void:
	if not _free_nodes.has(pool_id):
		_free_nodes[pool_id] = []
	if not _active_nodes.has(pool_id):
		_active_nodes[pool_id] = {}


func _create_instance(pool_id: String) -> Node:
	var prefab: PackedScene = _prefabs.get(pool_id, null)
	if prefab == null:
		return null
	var instance := prefab.instantiate()
	if instance == null:
		return null
	if instance is Node:
		var node_instance: Node = instance
		node_instance.set_meta("pool_id", pool_id)
		return node_instance
	return null


func _release_instance(pool_id: String, node: Node, parent: Node = null) -> void:
	if node == null:
		return
	_ensure_pool_collections(pool_id)
	var target_parent := _pool_root
	if parent != null and is_instance_valid(parent):
		target_parent = parent
	if node.has_method("on_pooled_released"):
		node.call("on_pooled_released", pool_id)
	if node.get_parent() != null and node.get_parent() != target_parent:
		node.reparent(target_parent)
	elif node.get_parent() == null:
		target_parent.add_child(node)
	_active_nodes[pool_id].erase(node.get_instance_id())
	_free_nodes[pool_id].append(node)
	emit_signal("pool_released", pool_id, node)


func _release_node(pool_id: String, node: Node) -> void:
	_release_instance(pool_id, node)
