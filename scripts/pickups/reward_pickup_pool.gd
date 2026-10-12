extends Node
## Idle orbs remain owned by this node, outside the active pickup root.
const EXP_SCENE = preload("res://scenes/pickups/exp_orb.tscn")
const MAX_IDLE := 128
var _idle: Array[ExpOrb] = []

func warmup(count := 32) -> void:
	while _idle.size() < mini(count, MAX_IDLE):
		var orb := EXP_SCENE.instantiate() as ExpOrb
		add_child(orb)
		orb.recycle_callback = recycle
		orb.park_for_pool()
		_idle.append(orb)

func acquire_exp() -> ExpOrb:
	while not _idle.is_empty():
		var orb := _idle.pop_back() as ExpOrb
		if is_instance_valid(orb) and not orb.is_queued_for_deletion(): return orb
	var orb := EXP_SCENE.instantiate() as ExpOrb
	orb.recycle_callback = recycle
	return orb

func recycle(orb: ExpOrb) -> void:
	if not is_instance_valid(orb) or orb.is_queued_for_deletion(): return
	orb.park_for_pool()
	if _idle.size() >= MAX_IDLE:
		orb.queue_free()
		return
	orb.reparent(self)
	_idle.append(orb)
