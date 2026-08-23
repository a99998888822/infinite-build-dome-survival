extends Control
class_name MobileJoystick

signal direction_changed(direction: Vector2)

const OUTER_FILL_COLOR := Color(0.03, 0.08, 0.06, 0.44)
const OUTER_LINE_COLOR := Color(0.68, 0.78, 0.47, 0.78)
const KNOB_FILL_COLOR := Color(0.78, 0.67, 0.26, 0.80)
const KNOB_LINE_COLOR := Color(0.95, 0.88, 0.56, 0.96)

@export_range(0.0, 0.5, 0.01) var deadzone_ratio: float = 0.16
@export_range(0.2, 0.8, 0.01) var knob_radius_ratio: float = 0.36
@export_range(48.0, 128.0, 1.0) var joystick_radius: float = 78.0

var _mobile_input_enabled := false
var _active_touch_index := -1
var _touch_origin := Vector2.ZERO
var _joystick_center := Vector2.ZERO
var _knob_offset := Vector2.ZERO
var _direction := Vector2.ZERO
var _touch_blocker_root: Node = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_mobile_input_enabled(enabled: bool) -> void:
	_mobile_input_enabled = enabled
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enabled:
		_reset_touch()


func set_touch_blocker_root(root: Node) -> void:
	_touch_blocker_root = root


func _input(event: InputEvent) -> void:
	if not _mobile_input_enabled:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_touch()


func _draw() -> void:
	if _active_touch_index < 0:
		return
	var center := _joystick_center
	var outer_radius := _get_outer_radius()
	var knob_radius := outer_radius * knob_radius_ratio
	draw_circle(center, outer_radius, OUTER_FILL_COLOR)
	draw_arc(center, outer_radius, 0.0, TAU, 48, OUTER_LINE_COLOR, 2.0, true)
	draw_circle(center + _knob_offset, knob_radius, KNOB_FILL_COLOR)
	draw_arc(center + _knob_offset, knob_radius, 0.0, TAU, 32, KNOB_LINE_COLOR, 2.0, true)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _active_touch_index >= 0 or _is_touch_blocked(event.position):
			return
		_active_touch_index = event.index
		_touch_origin = _screen_to_local(event.position)
		_joystick_center = _get_visual_center(_touch_origin)
		_update_from_screen_position(event.position)
		get_viewport().set_input_as_handled()
		return
	if event.index != _active_touch_index:
		return
	_reset_touch()
	get_viewport().set_input_as_handled()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _active_touch_index:
		return
	_update_from_screen_position(event.position)
	get_viewport().set_input_as_handled()


func _update_from_screen_position(screen_position: Vector2) -> void:
	var local_position := _screen_to_local(screen_position)
	var outer_radius := _get_outer_radius()
	if outer_radius <= 0.0:
		return
	_knob_offset = (local_position - _touch_origin).limit_length(outer_radius)
	var magnitude := _knob_offset.length() / outer_radius
	var next_direction := Vector2.ZERO
	if magnitude > deadzone_ratio:
		var remapped_magnitude := (magnitude - deadzone_ratio) / maxf(1.0 - deadzone_ratio, 0.001)
		next_direction = _knob_offset.normalized() * clampf(remapped_magnitude, 0.0, 1.0)
	_set_direction(next_direction)
	queue_redraw()


func _reset_touch() -> void:
	_active_touch_index = -1
	_knob_offset = Vector2.ZERO
	_set_direction(Vector2.ZERO)
	queue_redraw()


func _set_direction(next_direction: Vector2) -> void:
	if _direction.is_equal_approx(next_direction):
		return
	_direction = next_direction
	direction_changed.emit(_direction)


func _get_outer_radius() -> float:
	return joystick_radius


func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func _get_visual_center(touch_origin: Vector2) -> Vector2:
	var edge_margin := _get_outer_radius() + 8.0
	return Vector2(
		clampf(touch_origin.x, edge_margin, maxf(edge_margin, size.x - edge_margin)),
		clampf(touch_origin.y, edge_margin, maxf(edge_margin, size.y - edge_margin))
	)


func _is_touch_blocked(screen_position: Vector2) -> bool:
	if _touch_blocker_root == null or not is_instance_valid(_touch_blocker_root):
		return false
	for node in _touch_blocker_root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control.get_global_rect().has_point(screen_position):
			return true
	return false
