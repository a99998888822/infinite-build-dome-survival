extends Node2D
## One immutable mesh per lightning path; fading only changes node opacity.

const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var points := PackedVector2Array()
var base_alpha := 1.0
var cell_size := 2
var grid_origin := Vector2.ZERO
var rim_enabled := true
var core_cells: Dictionary = {}
var rim_cells: Dictionary = {}
var cached_mesh: ArrayMesh
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
	var rows := {}
	for cell: Vector2i in cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var rectangles: Array[Rect2i] = []
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var last := start
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x > last + 1:
				rectangles.append(Rect2i(start, y, last - start + 1, 1))
				start = x
			last = x
		rectangles.append(Rect2i(start, y, last - start + 1, 1))
	return rectangles


func build() -> void:
	assert(build_count == 0, "Each lightning path is built only once")
	build_count += 1
	core_cells = rasterize(points, cell_size, grid_origin)
	if rim_enabled:
		for cell: Vector2i in core_cells:
			for offset: Vector2i in NEIGHBORS:
				var neighbor := cell + offset
				if not core_cells.has(neighbor):
					rim_cells[neighbor] = true
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Disjoint masks: no overlapping glow beneath the core or at bends.
	append_quads(merge_rows(rim_cells), Color(0.70, 0.90, 1.0, 0.18 * base_alpha), vertices, colors, indices)
	append_quads(merge_rows(core_cells), Color(1.0, 1.0, 1.0, 0.96 * base_alpha), vertices, colors, indices)
	vertex_count = vertices.size()
	quad_count = vertex_count / 4
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	cached_mesh = ArrayMesh.new()
	cached_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	queue_redraw()


func append_quads(rectangles: Array[Rect2i], color: Color, vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	for rectangle in rectangles:
		var top_left := grid_origin + Vector2(rectangle.position) * cell_size
		var bottom_right := top_left + Vector2(rectangle.size) * cell_size
		var first := vertices.size()
		vertices.append_array(PackedVector3Array([
			Vector3(top_left.x, top_left.y, 0), Vector3(bottom_right.x, top_left.y, 0),
			Vector3(bottom_right.x, bottom_right.y, 0), Vector3(top_left.x, bottom_right.y, 0)]))
		colors.append_array(PackedColorArray([color, color, color, color]))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))


func _draw() -> void:
	if cached_mesh != null:
		draw_mesh(cached_mesh, null)
