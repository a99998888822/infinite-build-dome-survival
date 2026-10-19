extends Control
## Approved cooldown-only border. It never transforms the icon or card.
const READY_DURATION := 0.38
const INK := Color("293b3e")
const GRAY := Color("8fa7a6")
const LIGHT := Color("d5e3df")
var source: WeaponInstance
var ready_age := 1.0
var ready_delay := -1.0
var ready_count := 0

func configure(weapon: WeaponInstance) -> void:
	source = weapon
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.cooldown_ready_changed.connect(on_ready_changed)
	visibility_changed.connect(_visibility_changed)
	set_physics_process(false)

func detach() -> void:
	if source.cooldown_ready_changed.is_connected(on_ready_changed):
		source.cooldown_ready_changed.disconnect(on_ready_changed)
	clear_feedback()

func on_ready_changed(ready: bool) -> void:
	if not ready:
		clear_feedback()
		return
	if not is_visible_in_tree() or is_queued_for_deletion(): return
	# Coalesce immediate automatic recasts; only a still-ready slot lights up.
	ready_delay = 0.05
	set_physics_process(true)

func _visibility_changed() -> void:
	if not is_visible_in_tree(): clear_feedback()

func clear_feedback() -> void:
	ready_age = 1.0
	ready_delay = -1.0
	set_physics_process(false)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		clear_feedback()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	ready_age += delta
	if ready_delay >= 0.0:
		ready_delay -= delta
		if ready_delay <= 0.0:
			ready_delay = -1.0
			ready_age = 0.0
			ready_count += 1
	queue_redraw()
	if ready_age >= READY_DURATION and ready_delay < 0.0:
		set_physics_process(false)


func _pixel_box(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)


func _corners(inset: float, length: float, color: Color) -> void:
	var extent: Vector2 = get_parent().size
	for xsign in [-1, 1]:
		for ysign in [-1, 1]:
			var corner := Vector2(inset if xsign < 0 else extent.x - inset, inset if ysign < 0 else extent.y - inset)
			_pixel_box(Rect2(corner + Vector2(0 if xsign < 0 else -length, 0 if ysign < 0 else -3.333333), Vector2(length, 3.333333)), color)
			_pixel_box(Rect2(corner + Vector2(0 if xsign < 0 else -3.333333, 3.333333 if ysign < 0 else -length), Vector2(3.333333, length - 3.333333)), color)


func _draw() -> void:
	var extent: Vector2 = get_parent().size
	if ready_age < READY_DURATION:
		var fade := 1.0 if ready_age < 0.14 else 1.0 - (ready_age - 0.14) / 0.24
		var spread := 0.0 if ready_age < 0.07 else 3.333333 if ready_age < 0.15 else 6.666667
		_corners(-spread, 23.333333, Color(INK, fade))
		_corners(3.333333 - spread, 16.666667, Color(LIGHT, fade))
		if ready_age < 0.16:
			_pixel_box(Rect2(20, 0, extent.x - 40, 3.333333), Color(GRAY, fade))
			_pixel_box(Rect2(0, 20, 3.333333, extent.y - 40), Color(GRAY, fade))
			_pixel_box(Rect2(extent.x - 3.333333, 20, 3.333333, extent.y - 40), Color(GRAY, fade))
		# Only two tiny square glints, confined to the top of this slot.
		for side in [-1, 1]:
			_pixel_box(Rect2(extent.x * 0.5 + side * (13.333333 + spread) - 1.666667, -6.666667 - spread, 3.333333, 3.333333), Color(LIGHT, fade))
