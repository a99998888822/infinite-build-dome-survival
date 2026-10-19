extends RefCounted
## Repeated hit poses share one idle flush. Nodes may die/reset before it.
static var _pending: Array[Node] = []
static var _scheduled := false

static func enqueue(enemy: Node) -> void:
	_pending.append(enemy)
	if _scheduled: return
	_scheduled = true
	# frame_pre_draw is too late for Sprite2D's queued canvas redraw: state can
	# be correct there while this frame still renders the old offset. The idle
	# queue drains before rendering and also runs with the dummy renderer.
	flush.call_deferred()

static func flush() -> void:
	var batch := _pending
	_pending = []
	_scheduled = false
	for enemy in batch:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy._flush_hit_visual()
