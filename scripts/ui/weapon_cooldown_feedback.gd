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
	draw_rect(Rect2(rect.position.round(), rect.size.round()), color)


func _corners(inset: float, length: float, color: Color) -> void:
	var extent: Vector2 = get_parent().size.round()
	for xsign in [-1, 1]:
		for ysign in [-1, 1]:
			var corner := Vector2(inset if xsign < 0 else extent.x - inset, inset if ysign < 0 else extent.y - inset)
			_pixel_box(Rect2(corner + Vector2(0 if xsign < 0 else -length, 0 if ysign < 0 else -2), Vector2(length, 2)), color)
			_pixel_box(Rect2(corner + Vector2(0 if xsign < 0 else -2, 2 if ysign < 0 else -length), Vector2(2, length - 2)), color)


func _draw() -> void:
	var extent: Vector2 = get_parent().size.round()
	if ready_age < READY_DURATION:
		var fade := 1.0 if ready_age < 0.14 else 1.0 - (ready_age - 0.14) / 0.24
		var spread := 0.0 if ready_age < 0.07 else 2.0 if ready_age < 0.15 else 4.0
		_corners(-spread, 14, Color(INK, fade))
		_corners(2 - spread, 10, Color(LIGHT, fade))
		if ready_age < 0.16:
			_pixel_box(Rect2(12, 0, extent.x - 24, 2), Color(GRAY, fade))
			_pixel_box(Rect2(0, 12, 2, extent.y - 24), Color(GRAY, fade))
			_pixel_box(Rect2(extent.x - 2, 12, 2, extent.y - 24), Color(GRAY, fade))
		# Only two tiny square glints, confined to the top of this slot.
		for side in [-1, 1]:
			_pixel_box(Rect2(extent.x * 0.5 + side * (8 + spread) - 1, -4 - spread, 2, 2), Color(LIGHT, fade))
