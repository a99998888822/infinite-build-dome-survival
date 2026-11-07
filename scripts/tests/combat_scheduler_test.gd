extends Node

const SCHEDULER = preload("res://scripts/effects/effect_scheduler.gd")
var failures := 0
var events: Array = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var scheduler := SCHEDULER.new()
	add_child(scheduler)
	scheduler.set_process(false)
	var owner := Node.new()
	add_child(owner)
	var cancel_id := [0]
	scheduler.schedule(0, func():
		events.append("first")
		scheduler.cancel(cancel_id[0])
		scheduler.schedule(0, func(): events.append("next"), owner), owner)
	cancel_id[0] = scheduler.schedule(0, func(): events.append("cancelled"), owner)
	scheduler.schedule(0, func(): events.append("last"), owner)
	scheduler._process(0.01)
	check(events == ["first", "last"], "cancelled callback skipped; appended callback deferred")
	scheduler._process(0.01)
	check(events == ["first", "last", "next"], "reused slot retains next-frame order")
	check(scheduler._order.is_empty() and scheduler._task_slots.is_empty() and scheduler._owner_tasks.is_empty(), "all scheduler indexes released")
	for i in 1000: scheduler.schedule(0, func(): events.append("bulk"), owner)
	scheduler.cancel_owner(owner)
	scheduler._process(1)
	check(events.size() == 3, "owner cancellation removes all tasks")
	check(scheduler._order.is_empty() and scheduler._owner_tasks.is_empty(), "owner cancellation compacts queue")
	scheduler.schedule(0, func(): events.append("paused"), owner)
	scheduler.schedule(0, func(): events.append("ui"), owner, true)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	scheduler._process(1)
	check(events.back() == "ui" and events.size() == 4, "UI task runs while combat paused")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	scheduler._process(1)
	check(events.back() == "paused" and events.size() == 5, "combat task resumes")
	scheduler.schedule(0, func(): events.append("dead"), owner)
	owner.free()
	scheduler._process(1)
	check(events.size() == 5 and scheduler._order.is_empty(), "freed owner cannot run")
	scheduler.free()
	var measured := SCHEDULER.new()
	add_child(measured)
	measured.set_process(false)
	var called := [0]
	for i in 5000: measured.schedule(0, func(): called[0] += 1, self)
	measured._process(0.016)
	check(called[0] == 5000 and measured._order.is_empty(), "dense task batch retains all callbacks")
	var owners: Array[Node] = []
	for i in 1000:
		var task_owner := Node.new()
		add_child(task_owner)
		owners.append(task_owner)
		measured.schedule(10, func(): pass, task_owner)
	for task_owner in owners: measured.cancel_owner(task_owner)
	measured._process(1)
	check(measured._order.is_empty(), "dense owner cleanup removes every task")
	for task_owner in owners: task_owner.free()
	measured.free()
	print("COMBAT_SCHEDULER failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
