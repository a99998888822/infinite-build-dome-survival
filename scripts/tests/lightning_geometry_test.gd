extends Node2D
const BEFORE = preload("res://scripts/tests/fixtures/lightning_geometry_original_bolt.gd")
const AFTER = preload("res://scripts/effects/lightning_pixel_bolt.gd")
const LIGHTNING = preload("res://scripts/effects/lightning_particle_effect.gd")
var checks := 0
var failures := 0
var cases: Array[Dictionary] = []
var output := "artifacts/reports/lightning_geometry_cpu_metrics.json"

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func new_bolt(factory: Script, entry: Dictionary) -> Node2D:
	var bolt: Node2D = factory.new()
	bolt.points = entry.points
	bolt.grid_origin = entry.origin
	bolt.cell_size = entry.size
	bolt.base_alpha = entry.alpha
	bolt.rim_enabled = entry.rim
	return bolt

func compare(entry: Dictionary, label: String) -> void:
	var old := new_bolt(BEFORE, entry)
	var current := new_bolt(AFTER, entry)
	old.build()
	current.build()
	check(old.core_cells == current.core_cells and old.rim_cells == current.rim_cells, label + " exact masks")
	check(old.quad_count == current.quad_count and old.vertex_count == current.vertex_count, label + " counts")
	check(old.build_count == current.build_count, label + " immutable build")
	check((old.cached_mesh == null) == (current.cached_mesh == null), label + " empty mesh")
	if old.cached_mesh != null and current.cached_mesh != null:
		var a: Array = old.cached_mesh.surface_get_arrays(0)
		var b: Array = current.cached_mesh.surface_get_arrays(0)
		for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
			check(a[slot] == b[slot], label + " mesh array " + str(slot))
	old.free()
	current.free()

func profile_original() -> Dictionary:
	var cost := {"raster_usec":0,"rows_usec":0,"fill_usec":0,"upload_usec":0,"quads":0}
	for entry in cases:
		var bolt := new_bolt(BEFORE, entry)
		var at := Time.get_ticks_usec()
		var cells := BEFORE.rasterize(bolt.points, bolt.cell_size, bolt.grid_origin)
		cost.raster_usec += Time.get_ticks_usec() - at
		at = Time.get_ticks_usec()
		var rectangles := BEFORE.merge_rows(cells)
		cost.rows_usec += Time.get_ticks_usec() - at
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		at = Time.get_ticks_usec()
		bolt.append_quads(rectangles, Color(1,1,1,.96 * bolt.base_alpha), vertices, colors, indices)
		cost.fill_usec += Time.get_ticks_usec() - at
		at = Time.get_ticks_usec()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		cost.upload_usec += Time.get_ticks_usec() - at
		cost.quads += rectangles.size()
		bolt.free()
	return cost

func run() -> void:
	CampProgression.begin_transient_session()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	var mask_random := RandomNumberGenerator.new()
	mask_random.seed = 20102026
	for trial in 256:
		var cells := {}
		for i in 128:
			cells[Vector2i(mask_random.randi_range(-500,500),mask_random.randi_range(-5,5))] = true
		check(BEFORE.merge_rows(cells) == AFTER.merge_rows(cells), "sparse disconnected row order %d" % trial)
	var extreme := {Vector2i(2147483647, -2147483648):true, Vector2i(-2147483648, 2147483647):true,
		Vector2i(-2147483647, 2147483647):true, Vector2i(-1, -2147483648):true,Vector2i(0, -2147483648):true}
	check(BEFORE.merge_rows(extreme) == AFTER.merge_rows(extreme), "full signed cell coordinate range")
	var generator := LIGHTNING.new()
	generator._control_point_spacing = 24
	generator._control_point_envelope_power = .65
	seed(20102026)
	for i in 128:
		var length: float = [8,32,96,170,182,320,720,1500][i % 8]
		var direction := Vector2.from_angle(TAU * (i % 16) / 16.0)
		var start := Vector2(-63.25, 87.5)
		var points := PackedVector2Array(generator._build_bolt_control_points(start, start + direction * length,
			direction, direction.orthogonal(), minf(20, length*.3)/26.0))
		for j in points.size(): points[j] = points[j].round()
		cases.append({"points":points,"origin":Vector2(-63.25,87.5),"size":2,"alpha":.7,"rim":false})
	generator.free()
	for i in cases.size():
		compare(cases[i], "native %d" % i)
		var with_rim := cases[i].duplicate()
		with_rim.rim = true
		with_rim.size = 3
		compare(with_rim, "rim %d" % i)
	for points in [PackedVector2Array(), PackedVector2Array([Vector2.ZERO]),
			PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
			PackedVector2Array([Vector2.ZERO,Vector2(50,50),Vector2(-50,50),Vector2(50,-50),Vector2.ZERO])]:
		for size in [0,1,2,3]:
			compare({"points":points,"origin":Vector2(1.2,-.5),"size":size,"alpha":0.0,"rim":true}, "edge")
	var profile := profile_original()
	var rows: Array = []
	for before in [true, false, false, true, false, true, true, false]:
		var factory: Script = BEFORE if before else AFTER
		var total_quads := 0
		var at := Time.get_ticks_usec()
		for i in 1024:
			var bolt := new_bolt(factory, cases[i % cases.size()])
			bolt.build()
			total_quads += bolt.quad_count
			bolt.free()
		rows.append({"before":before,"ms":(Time.get_ticks_usec()-at)/1000.0,"builds":1024,"quads":total_quads})
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"profile":profile,"checks":checks,"failures":failures},"\t"))
	CampProgression.end_transient_session()
	print("LIGHTNING_GEOMETRY checks=",checks," failures=",failures," profile=",profile)
	get_tree().quit(0 if failures == 0 else 1)
