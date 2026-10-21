extends Node2D
const BOLT = preload("res://scripts/effects/lightning_pixel_bolt.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	var shared_meshes: Dictionary = {}
	for trial in 128:
		var legacy := BOLT.new()
		var current := BOLT.new()
		var points := PackedVector2Array()
		for i in trial % 10:
			points.append(Vector2(rng.randi_range(-800, 800), rng.randi_range(-800, 800)))
		for bolt in [legacy, current]:
			bolt.points = points
			bolt.grid_origin = Vector2(-63.25, 87.5)
			bolt.cell_size = trial % 4
			bolt.base_alpha = [0.0, 0.4, 0.7, 1.0, 1.4, 2.0][trial % 6]
			bolt.rim_enabled = trial % 2 == 0
		legacy.build()
		current.build(true)
		check(legacy.core_cells == current.core_cells and legacy.rim_cells == current.rim_cells, "identical coverage")
		check(legacy.quad_count == current.quad_count and current.build_count == 1, "identical rectangles")
		if legacy.cached_mesh != null and not current.rim_enabled:
			check(current.cached_instances != null and current.cached_mesh == null, "production creates instances only")
			var arrays: Array = legacy.cached_mesh.surface_get_arrays(0)
			var color: Color = current.cached_instances.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0]
			if not shared_meshes.has(color): shared_meshes[color] = current.cached_instances.mesh
			check(current.cached_instances.mesh == shared_meshes[color], "equal mesh colors share geometry")
			var same_colors := true
			var same_corners := true
			for index in current.quad_count:
				var offset := index * 8
				var buffer: PackedFloat32Array = current.instance_buffer
				var transform := Transform2D(Vector2(buffer[offset], buffer[offset + 4]),
					Vector2(buffer[offset + 1], buffer[offset + 5]), Vector2(buffer[offset + 3], buffer[offset + 7]))
				var corners := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
				var old_color: Color = arrays[Mesh.ARRAY_COLOR][index * 4]
				same_colors = same_colors and color.is_equal_approx(old_color)
				for corner in 4:
					var old_vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index * 4 + corner]
					same_corners = same_corners and (transform * corners[corner]).is_equal_approx(Vector2(old_vertex.x, old_vertex.y))
			check(same_colors, "same GPU colors trial %d" % trial)
			check(same_corners, "same rectangle corners trial %d" % trial)
		elif legacy.cached_mesh != null:
			check(current.cached_instances == null, "optional rim keeps original mesh")
			for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
				check(current.cached_mesh.surface_get_arrays(0)[slot] == legacy.cached_mesh.surface_get_arrays(0)[slot], "rim geometry unchanged")
		else:
			check(current.cached_instances == null, "empty paths allocate no instances")
		legacy.free()
		current.free()
	check(BOLT._shared_quads.size() <= 256, "shared color mesh storage bounded")
	print("LIGHTNING_ECHO_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
