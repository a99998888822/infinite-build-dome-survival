extends ScrollContainer
class_name TouchScrollContainer

@export var touch_drag_enabled := true
@export_range(1.0, 32.0, 1.0) var drag_threshold: float = 8.0

var _active_touch_index := -1
var _press_position := Vector2.ZERO
var _last_drag_position := Vector2.ZERO
var _is_touch_dragging := false


func _input(event: InputEvent) -> void:
	if not touch_drag_enabled or not OS.has_feature("mobile") or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_touch_drag()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _active_touch_index >= 0 or not get_global_rect().has_point(event.position):
			return
		_active_touch_index = event.index
		_press_position = event.position
		_last_drag_position = event.position
		_is_touch_dragging = false
		return
	if event.index != _active_touch_index:
		return
	if _is_touch_dragging:
		get_viewport().set_input_as_handled()
	_clear_touch_drag()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _active_touch_index:
		return
	if not _is_touch_dragging:
		if event.position.distance_to(_press_position) < drag_threshold:
			return
		_is_touch_dragging = true
	var delta := event.position - _last_drag_position
	_last_drag_position = event.position
	_apply_drag_delta(delta)
	get_viewport().set_input_as_handled()


func _apply_drag_delta(delta: Vector2) -> void:
	if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		var horizontal_max := _get_scroll_maximum(get_h_scroll_bar())
		scroll_horizontal = clampi(scroll_horizontal - roundi(delta.x), 0, horizontal_max)
	if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		var vertical_max := _get_scroll_maximum(get_v_scroll_bar())
		scroll_vertical = clampi(scroll_vertical - roundi(delta.y), 0, vertical_max)


func _get_scroll_maximum(scroll_bar: ScrollBar) -> int:
	if scroll_bar == null:
		return 0
	return maxi(roundi(scroll_bar.max_value - scroll_bar.page), 0)


func _clear_touch_drag() -> void:
	_active_touch_index = -1
	_press_position = Vector2.ZERO
	_last_drag_position = Vector2.ZERO
	_is_touch_dragging = false
