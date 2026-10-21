extends Node2D
## Immutable pixel rows; paths share one quad mesh and fade in their original
## canvas order. The explicit mesh builder remains available for geometry tools.

const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
static var _shared_quads: Dictionary = {}
var points := PackedVector2Array()
var base_alpha := 1.0
var cell_size := 2
var grid_origin := Vector2.ZERO
var rim_enabled := true
var core_cells: Dictionary = {}
var rim_cells: Dictionary = {}
var cached_mesh: ArrayMesh
var cached_instances: MultiMesh
var instance_buffer := PackedFloat32Array()
var quad_count := 0
var vertex_count := 0
var build_count := 0


static func rasterize(path: PackedVector2Array, size: int, origin: Vector2) -> Dictionary:
	var cells := {}
	if path.is_empty() or size < 1:
		return cells
	for index in maxi(1, path.size() - 1):
		var a := Vector2i(((path[index] - origin) / size).floor())
		var b := Vector2i(((path[mini(index + 1, path.size() - 1)] - origin) / size).floor())
		var dx := absi(b.x - a.x)
		var dy := -absi(b.y - a.y)
		var sx := 1 if a.x < b.x else -1
		var sy := 1 if a.y < b.y else -1
		var error := dx + dy
		while true:
			cells[a] = true
			if a == b:
				break
			var doubled := error * 2
			var next := a
			if doubled >= dy:
				error += dy
				next.x += sx
			if doubled <= dx:
				error += dx
				next.y += sy
			# Bridge diagonal contacts so thin paths stay visibly connected.
			if next.x != a.x and next.y != a.y:
				cells[Vector2i(next.x, a.y) if dx >= -dy else Vector2i(a.x, next.y)] = true
			a = next
	return cells


static func merge_rows(cells: Dictionary) -> Array[Rect2i]:
	var rectangles: Array[Rect2i] = []
	if cells.is_empty(): return rectangles
	var row_indices := {}
	var ys := PackedInt32Array()
	var keys := PackedInt64Array()
	keys.resize(cells.size())
	var cursor := 0
	for cell: Vector2i in cells:
		var row: int = row_indices.get(cell.y, -1)
		if row < 0:
			row = ys.size()
			ys.append(cell.y)
			row_indices[cell.y] = row
		# Preserve original first-seen row order; bias signed X for native sorting.
		keys[cursor] = (row << 32) | (int(cell.x) + 2147483648)
		cursor += 1
	keys.sort()
	var row := int(keys[0] >> 32)
	var start := int(keys[0] & 0xffffffff) - 2147483648
	var last := start
	for i in range(1, keys.size()):
		var next_row := int(keys[i] >> 32)
		var x := int(keys[i] & 0xffffffff) - 2147483648
		if next_row != row or x > last + 1:
			rectangles.append(Rect2i(start, ys[row], last - start + 1, 1))
			start = x
			row = next_row
		last = x
	rectangles.append(Rect2i(start, ys[row], last - start + 1, 1))
	return rectangles


func build(instanced := false) -> void:
	assert(build_count == 0, "Each lightning path is built only once")
	build_count += 1
	core_cells = rasterize(points, cell_size, grid_origin)
	if rim_enabled:
		for cell: Vector2i in core_cells:
			for offset: Vector2i in NEIGHBORS:
				var neighbor := cell + offset
				if not core_cells.has(neighbor):
					rim_cells[neighbor] = true
	var rim_rectangles := merge_rows(rim_cells)
	var core_rectangles := merge_rows(core_cells)
	quad_count = rim_rectangles.size() + core_rectangles.size()
	vertex_count = quad_count * 4
	if quad_count == 0:
		return
	if instanced and not rim_enabled:
		_build_instances(core_rectangles)
		set_notify_transform(true)
	else:
		_build_mesh(rim_rectangles, core_rectangles)
	queue_redraw()


func _build_mesh(rim_rectangles: Array[Rect2i], core_rectangles: Array[Rect2i]) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Allocate once per path. Previously every rectangle constructed three
	# temporary packed arrays and grew the destination buffers independently.
	vertices.resize(vertex_count)
	colors.resize(vertex_count)
	indices.resize(quad_count * 6)
	colors.fill(Color(1.0, 1.0, 1.0, 0.96 * base_alpha))
	var rim_color := Color(0.70, 0.90, 1.0, 0.18 * base_alpha)
	for index in rim_rectangles.size() * 4:
		colors[index] = rim_color
	# Disjoint masks: no overlapping glow beneath the core or at bends.
	write_quads(rim_rectangles, 0, vertices, indices)
	write_quads(core_rectangles, rim_rectangles.size(), vertices, indices)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	cached_mesh = ArrayMesh.new()
	cached_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _build_instances(core_rectangles: Array[Rect2i]) -> void:
	var color := Color(1.0, 1.0, 1.0, 0.96 * base_alpha)
	# Keep opacity in the same UNORM8 mesh attribute as before, rather than
	# multiplying float instance colors in a different shader stage. At most
	# 256 shared meshes cover every alpha representable by the original mesh.
	var key := clampi(int(color.a * 255.0), 0, 255)
	if not _shared_quads.has(key):
		# Preserve the original diagonal and vertex order as well as coverage.
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([color, color, color, color])
		var quad := ArrayMesh.new()
		quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_shared_quads[key] = quad
	cached_instances = MultiMesh.new()
	cached_instances.transform_format = MultiMesh.TRANSFORM_2D
	cached_instances.mesh = _shared_quads[key]
	cached_instances.instance_count = quad_count
	# One 2D transform per disjoint row rectangle, instead of four
	# vertices, four colors, six indices and a fresh mesh surface for every path.
	var buffer := PackedFloat32Array()
	buffer.resize(quad_count * 8)
	var cursor := 0
	var bounds := Rect2()
	for rectangle: Rect2i in core_rectangles:
		var top_left := grid_origin + Vector2(rectangle.position) * cell_size
		var size := Vector2(rectangle.size) * cell_size
		buffer[cursor] = size.x
		buffer[cursor + 3] = top_left.x
		buffer[cursor + 5] = size.y
		buffer[cursor + 7] = top_left.y
		var rect := Rect2(top_left, size)
		bounds = rect if cursor == 0 else bounds.merge(rect)
		cursor += 8
	instance_buffer = buffer
	cached_instances.buffer = instance_buffer
	cached_instances.custom_aabb = AABB(Vector3(bounds.position.x, bounds.position.y, -1), Vector3(bounds.size.x, bounds.size.y, 2))


func write_quads(rectangles: Array[Rect2i], first_quad: int, vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var first := first_quad * 4
	var cursor := first_quad * 6
	for rectangle in rectangles:
		var top_left := grid_origin + Vector2(rectangle.position) * cell_size
		var bottom_right := top_left + Vector2(rectangle.size) * cell_size
		vertices[first] = Vector3(top_left.x, top_left.y, 0)
		vertices[first + 1] = Vector3(bottom_right.x, top_left.y, 0)
		vertices[first + 2] = Vector3(bottom_right.x, bottom_right.y, 0)
		vertices[first + 3] = Vector3(top_left.x, bottom_right.y, 0)
		indices[cursor] = first
		indices[cursor + 1] = first + 1
		indices[cursor + 2] = first + 2
		indices[cursor + 3] = first
		indices[cursor + 4] = first + 2
		indices[cursor + 5] = first + 3
		first += 4
		cursor += 6


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and cached_instances != null:
		var basis := global_transform
		if basis.x != Vector2.RIGHT or basis.y != Vector2.DOWN: queue_redraw()


func _draw() -> void:
	if cached_instances != null:
		var basis := global_transform
		if basis.x != Vector2.RIGHT or basis.y != Vector2.DOWN:
			# Complex transforms use the original precomputed vertices to avoid
			# floating-point edge differences from the extra instance transform.
			_build_mesh(merge_rows(rim_cells), merge_rows(core_cells))
			cached_instances = null
			instance_buffer = PackedFloat32Array()
			set_notify_transform(false)
	if cached_mesh != null:
		draw_mesh(cached_mesh, null)
	elif cached_instances != null:
		draw_multimesh(cached_instances, null)
