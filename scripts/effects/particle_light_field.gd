extends Node2D
class_name ParticleLightField

const MAX_LIGHTS: int = 96
const CIRCLE_SEGMENTS := 64
const LIGHT_RADII := [1.0, 0.68, 0.36, 0.13]
const LIGHT_ALPHAS := [0.012, 0.028, 0.07, 0.08]
var _circle_mesh_cache: Dictionary = {}

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
		# Four original translucent disks, in the same order, share cached geometry.
		# Radius/energy are instance transforms/colors; no retessellation while fading.
		var transform := Transform2D(Vector2(radius, 0), Vector2(0, radius), position)
		draw_mesh(_get_circle_mesh(base), null, transform, Color(1, 1, 1, energy))


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


func _get_circle_mesh(base: Color) -> ArrayMesh:
	var key := Color(base.r, base.g, base.b, 1.0)
	if _circle_mesh_cache.has(key):
		return _circle_mesh_cache[key]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for disk in LIGHT_RADII.size():
		var first := vertices.size()
		var color := Color(base.r, base.g, base.b, LIGHT_ALPHAS[disk]) if disk < 3 else Color(1, 1, 1, LIGHT_ALPHAS[disk])
		vertices.append(Vector3.ZERO)
		colors.append(color)
		for step in CIRCLE_SEGMENTS:
			var point := Vector2.from_angle(float(step) * TAU / CIRCLE_SEGMENTS) * float(LIGHT_RADII[disk])
			vertices.append(Vector3(point.x, point.y, 0))
			colors.append(color)
		for step in CIRCLE_SEGMENTS:
			indices.append_array(PackedInt32Array([first, first + 1 + step, first + 1 + (step + 1) % CIRCLE_SEGMENTS]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Arbitrary user tint inputs must not grow the cache without a bound.
	if _circle_mesh_cache.size() >= 32:
		_circle_mesh_cache.clear()
	_circle_mesh_cache[key] = mesh
	return mesh
