extends RefCounted
## Drain after gameplay/animation, before queued canvas redraws (also headless).
static var _pending: Array[Node] = []
static var _scheduled := false
static var _flame_clock: Node

static func request_flame_flush(clock: Node) -> void:
	_flame_clock = clock

static func enqueue(visual: Node) -> void:
	_pending.append(visual)
	if _scheduled: return
	_scheduled = true
	flush.call_deferred()

static func flush() -> void:
	var batch := _pending
	_pending = []
	_scheduled = false
	for visual in batch:
		if is_instance_valid(visual) and visual.is_inside_tree() and not visual.is_queued_for_deletion():
			visual._flush_visual()
	# FlameClock normally runs at priority 100, before this idle drain. Submit
	# changed status instances now so palette/position/expiry appear this frame.
	var clock := _flame_clock
	_flame_clock = null
	if is_instance_valid(clock):
		if clock.is_inside_tree(): clock.flush()
		else: clock.flush.call_deferred() # First flame attaches its clock via the same idle queue.
