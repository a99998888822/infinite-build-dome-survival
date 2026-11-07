extends Node

## Lightweight scheduler for short-lived combat-effect callbacks.
##
## Combat callbacks follow battle pause. UI callers may opt into process-always.
## Keeping the callbacks here avoids creating one SceneTreeTimer object per
## lightning-chain hop or display echo.

var _remaining: PackedFloat32Array = PackedFloat32Array()
var _owner_ids: PackedInt64Array = PackedInt64Array()
var _task_ids: PackedInt64Array = PackedInt64Array()
var _active: PackedByteArray = PackedByteArray()
var _run_when_paused: PackedByteArray = PackedByteArray()
var _callbacks: Array[Callable] = []
var _free_slots: Array[int] = []
var _order: Array[int] = []
var _next_task_id: int = 1
var _task_slots: Dictionary = {}
var _owner_tasks: Dictionary = {}
var _processing := false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func schedule(delay: float, callback: Callable, owner: Object = null, run_when_paused: bool = false) -> int:
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
		_run_when_paused.append(0)
		_callbacks.append(Callable())
	var task_id := _next_task_id
	_next_task_id += 1
	if _next_task_id <= 0:
		_next_task_id = 1
	_remaining[slot] = maxf(delay, 0.0)
	_owner_ids[slot] = owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
	_task_ids[slot] = task_id
	_active[slot] = 1
	_run_when_paused[slot] = 1 if run_when_paused else 0
	_callbacks[slot] = callback
	_task_slots[task_id] = slot
	if _owner_ids[slot] != 0:
		var owner_id := int(_owner_ids[slot])
		if not _owner_tasks.has(owner_id): _owner_tasks[owner_id] = {}
		_owner_tasks[owner_id][task_id] = true
	_order.append(task_id)
	return task_id


func cancel(task_id: int) -> void:
	if task_id <= 0:
		return
	if _task_slots.has(task_id): _release_slot(int(_task_slots[task_id]))


func cancel_owner(owner: Object) -> void:
	if owner == null:
		return
	var owner_id := owner.get_instance_id()
	if not _owner_tasks.has(owner_id): return
	for task_id in _owner_tasks[owner_id].keys():
		cancel(int(task_id))


func _process(delta: float) -> void:
	# Tasks scheduled from an expiring callback are deferred to the next
	# scheduler tick, matching a newly-created SceneTreeTimer's frame boundary.
	if _processing: return
	_processing = true
	# IDs survive slot reuse and cancellation from callbacks. Iterate only the
	# original prefix; compact once instead of shifting the array for each expiry.
	var count := _order.size()
	for order_index in count:
		var task_id := _order[order_index]
		if not _task_slots.has(task_id): continue
		var slot := int(_task_slots[task_id])
		var owner_id := int(_owner_ids[slot])
		var owner := instance_from_id(owner_id) if owner_id != 0 else null
		if owner_id != 0 and (not is_instance_valid(owner) or (owner is Node and (owner as Node).is_queued_for_deletion())):
			_release_slot(slot)
			continue
		if _run_when_paused[slot] == 0 and (get_tree().paused or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))):
			continue
		_remaining[slot] -= delta
		if _remaining[slot] > 0.0:
			continue
		var callback := _callbacks[slot]
		_release_slot(slot)
		if callback.is_valid():
			callback.call()
	var write := 0
	for task_id in _order:
		if _task_slots.has(task_id):
			_order[write] = task_id
			write += 1
	_order.resize(write)
	_processing = false


func _release_slot(slot: int) -> void:
	if slot < 0 or slot >= _active.size() or _active[slot] == 0:
		return
	_active[slot] = 0
	var task_id := int(_task_ids[slot])
	var owner_id := int(_owner_ids[slot])
	_task_slots.erase(task_id)
	if _owner_tasks.has(owner_id):
		_owner_tasks[owner_id].erase(task_id)
		if _owner_tasks[owner_id].is_empty(): _owner_tasks.erase(owner_id)
	_remaining[slot] = 0.0
	_owner_ids[slot] = 0
	_task_ids[slot] = 0
	_callbacks[slot] = Callable()
	_free_slots.append(slot)
