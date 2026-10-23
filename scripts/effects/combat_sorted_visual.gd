extends Node2D
## A render-only sibling in the production actor sorting tree. Physics ownership
## stays with source; detaching a weapon must never detach its collision logic.
var source: Node2D

static func attach(subject: Node2D) -> Node2D:
	var proxy := new()
	proxy.source = subject
	proxy.name = "SortedCombatVisual"
	var host: Node = null
	for candidate in subject.get_tree().get_nodes_in_group("combat_actor_sort_root"):
		if candidate.get_viewport() == subject.get_viewport() and not candidate.is_queued_for_deletion():
			host = candidate
			break
	if host == null:
		for candidate in subject.get_viewport().find_children("EnemyRoot", "Node2D", true, false):
			host = candidate
			break
	if host == null: host = subject.get_parent()
	CombatRenderWorld.set_world_layer(proxy, 0)
	host.add_child(proxy)
	proxy.process_priority = 90
	subject.tree_exiting.connect(proxy.retire, CONNECT_ONE_SHOT)
	proxy.sync()
	return proxy

func sync() -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		retire()
		return
	global_transform = source.global_transform
	visible = source.is_visible_in_tree()
	modulate = source.modulate

func _process(_delta: float) -> void:
	sync()

func retire() -> void:
	hide()
	queue_free()
