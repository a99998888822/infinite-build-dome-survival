extends Node2D
class_name ParticleLightField

const MAX_LIGHTS: int = 96

# The visual contract stays unchanged, while short-lived lights reuse slots
# instead of allocating dictionaries and shifting storage on every expiry.
var _positions: Array[Vector2] = []
var _colors: Array[Color] = []
var _energies: PackedFloat32Array = PackedFloat32Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _durations: PackedFloat32Array = PackedFloat32Array()
var _remainings: PackedFloat32Array = PackedFloat32Array()
var _active: PackedByteArray = PackedByteArray()
var _free_slots: Array[int] = []
var _order: Array[int] = []


func _ready() -> void:
	z_index = 15
	if not is_in_group("particle_light_field"):
		add_to_group("particle_light_field")
	queue_redraw()


func add_light(global_position: Vector2, color: Color, energy: float, radius: float, duration: float = 0.18) -> void:
	if energy <= 0.0 or radius <= 0.0:
		return
	var slot := -1
	if _order.size() >= MAX_LIGHTS:
		slot = _order[0]
		_order.remove_at(0)
	else:
		slot = _take_free_slot()
	_positions[slot] = to_local(global_position)
	_colors[slot] = color
	_energies[slot] = energy
	_radii[slot] = radius
	_durations[slot] = maxf(duration, 0.02)
	_remainings[slot] = _durations[slot]
	_active[slot] = 1
	_order.append(slot)
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for order_index in range(_order.size() - 1, -1, -1):
		var slot := _order[order_index]
		_remainings[slot] -= delta
		if _remainings[slot] <= 0.0:
			_order.remove_at(order_index)
			_release_slot(slot)
	queue_redraw()


func _draw() -> void:
	for slot in _order:
		var duration := maxf(_durations[slot], 0.02)
		var remaining := clampf(_remainings[slot] / duration, 0.0, 1.0)
		var energy := clampf(_energies[slot] * remaining, 0.0, 2.5)
		var position := _positions[slot]
		var radius := _radii[slot]
		var base := _colors[slot]
		draw_circle(position, radius, Color(base.r, base.g, base.b, 0.012 * energy))
		draw_circle(position, radius * 0.68, Color(base.r, base.g, base.b, 0.028 * energy))
		draw_circle(position, radius * 0.36, Color(base.r, base.g, base.b, 0.07 * energy))
		draw_circle(position, radius * 0.13, Color(1.0, 1.0, 1.0, 0.08 * energy))


func _take_free_slot() -> int:
	if not _free_slots.is_empty():
		return _free_slots.pop_back()
	var slot := _positions.size()
	_positions.append(Vector2.ZERO)
	_colors.append(Color.TRANSPARENT)
	_energies.append(0.0)
	_radii.append(0.0)
	_durations.append(0.0)
	_remainings.append(0.0)
	_active.append(0)
	return slot


func _release_slot(slot: int) -> void:
	if slot < 0 or slot >= _active.size() or _active[slot] == 0:
		return
	_active[slot] = 0
	_free_slots.append(slot)
