extends Node

## Lightweight scheduler for short-lived combat-effect callbacks.
##
## It intentionally follows SceneTree.create_timer()'s default behavior:
## idle-time processing, process-always semantics, and insertion-order expiry.
## Keeping the callbacks here avoids creating one SceneTreeTimer object per
## lightning-chain hop or display echo.

var _remaining: PackedFloat32Array = PackedFloat32Array()
var _owner_ids: PackedInt64Array = PackedInt64Array()
var _task_ids: PackedInt64Array = PackedInt64Array()
var _active: PackedByteArray = PackedByteArray()
var _callbacks: Array[Callable] = []
var _free_slots: Array[int] = []
var _order: Array[int] = []
var _next_task_id: int = 1


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func schedule(delay: float, callback: Callable, owner: Object = null) -> int:
	if not callback.is_valid():
		return 0
	var slot := -1
	if not _free_slots.is_empty():
		slot = _free_slots.pop_back()
	else:
		slot = _remaining.size()
		_remaining.append(0.0)
		_owner_ids.append(0)
		_task_ids.append(0)
		_active.append(0)
		_callbacks.append(Callable())
	var task_id := _next_task_id
	_next_task_id += 1
	if _next_task_id <= 0:
		_next_task_id = 1
	_remaining[slot] = maxf(delay, 0.0)
	_owner_ids[slot] = owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
	_task_ids[slot] = task_id
	_active[slot] = 1
	_callbacks[slot] = callback
	_order.append(slot)
	return task_id


func cancel(task_id: int) -> void:
	if task_id <= 0:
		return
	for slot in _task_ids.size():
		if _active[slot] != 0 and _task_ids[slot] == task_id:
			_release_slot(slot)
			return


func cancel_owner(owner: Object) -> void:
	if owner == null:
		return
	var owner_id := owner.get_instance_id()
	for slot in _task_ids.size():
		if _active[slot] != 0 and _owner_ids[slot] == owner_id:
			_release_slot(slot)


func _process(delta: float) -> void:
	# Tasks scheduled from an expiring callback are deferred to the next
	# scheduler tick, matching a newly-created SceneTreeTimer's frame boundary.
	var task_id_upper_bound := _next_task_id
	var order_index := 0
	while order_index < _order.size():
		var slot := _order[order_index]
		if _active[slot] == 0 or _task_ids[slot] >= task_id_upper_bound:
			order_index += 1
			continue
		var owner_id := int(_owner_ids[slot])
		var owner := instance_from_id(owner_id) if owner_id != 0 else null
		if owner_id != 0 and (not is_instance_valid(owner) or (owner is Node and (owner as Node).is_queued_for_deletion())):
			_release_slot(slot)
			continue
		_remaining[slot] -= delta
		if _remaining[slot] > 0.0:
			order_index += 1
			continue
		var callback := _callbacks[slot]
		_release_slot(slot)
		if callback.is_valid():
			callback.call()


func _remove_from_order(slot: int) -> void:
	var order_index := _order.find(slot)
	if order_index >= 0:
		_order.remove_at(order_index)


func _release_slot(slot: int) -> void:
	if slot < 0 or slot >= _active.size() or _active[slot] == 0:
		return
	_active[slot] = 0
	_remaining[slot] = 0.0
	_owner_ids[slot] = 0
	_task_ids[slot] = 0
	_callbacks[slot] = Callable()
	_remove_from_order(slot)
	_free_slots.append(slot)
