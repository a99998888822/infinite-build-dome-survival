extends Node2D

const LIGHTNING = preload("res://scripts/effects/lightning_particle_effect.gd")
var failures := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	pixel_test()
	await timing_test()
	CampProgression.end_transient_session()
	print("LIGHTNING_PIXEL_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", message)

func timing_test() -> void:
	CampProgression.begin_transient_session()
	for ground in [false, true]:
		var effect := LIGHTNING.new()
		add_child(effect)
		effect.set_process(false)
		effect._is_ground_strike = ground
		effect.position = Vector2(63, 87)
		effect._emit_bolt(Vector2(50, 80), Vector2(250, 120))
		var pulse_count: int = effect._path_pulses.size()
		check(pulse_count == 1, "one initial path, ground=%s" % ground)
		var snapshot: PackedVector2Array = effect._path_pulses[0].bolt.points.duplicate()
		var initial_node_id: int = effect._path_pulses[0].bolt.get_instance_id()
		var initial_mesh = effect._path_pulses[0].bolt.cached_mesh
		var echo_snapshot := PackedVector2Array()
		check(snapshot.size() == 10, "200px arc uses ten control points instead of dense samples")
		check(snapshot[0] == Vector2(-13, -7) and snapshot[-1] == Vector2(187, 33), "contact endpoints stay anchored")
		var times := [0.01, 0.09, 0.17, 0.21, 0.29]
		var expected := [1.0, 0.6, 0.0, 1.0, 0.6]
		var previous := 0.0
		for i in times.size():
			effect._process(times[i] - previous)
			previous = times[i]
			check(is_equal_approx(effect._path_pulses[0].bolt.modulate.a, expected[i]), "alpha at %.2fs = %.1f" % [times[i], expected[i]])
			var bolt = effect._path_pulses[0].bolt
			if times[i] < LIGHTNING.FLASH_SECONDS + LIGHTNING.DARK_SECONDS:
				check(bolt.points == snapshot, "initial geometry remains fixed while fading")
				check(bolt.cached_mesh == initial_mesh and bolt.build_count == 1, "cached pixel mesh is reused during fading")
			else:
				if echo_snapshot.is_empty():
					echo_snapshot = bolt.points.duplicate()
				check(bolt.points != snapshot and bolt.get_instance_id() != initial_node_id, "echo is a new node with different geometry")
				check(bolt.points == echo_snapshot, "echo fades independently with no third path")
				check(bolt.points[0] == snapshot[0] and bolt.points[-1] == snapshot[-1], "redrawn path preserves both contact endpoints")
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		effect._process(1.0)
		check(is_equal_approx(effect._path_pulses[0].age, previous), "battle pause freezes fade and flashback")
		GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		effect._process(0.08)
		check(effect._path_pulses.is_empty() and effect.get_active_particle_count() == 0, "both flashes expire without path particles")
		effect._chain_finished = true
		effect._try_finish_chain()
		check(effect.is_queued_for_deletion(), "effect retires after final hop and flashback")
		await frames(2)
	# Compare identical random input against V2's 12px displacement envelope.
	var geometry := LIGHTNING.new()
	geometry._control_point_spacing = 24.0
	geometry._control_point_envelope_power = 0.65
	seed(4102026)
	var old_points := geometry._build_bolt_control_points(Vector2.ZERO, Vector2(240, 0), Vector2.RIGHT, Vector2.DOWN, 12.0 / 26.0)
	seed(4102026)
	var new_points := geometry._build_bolt_control_points(Vector2.ZERO, Vector2(240, 0), Vector2.RIGHT, Vector2.DOWN, LIGHTNING.CONTROL_JITTER_PIXELS / 26.0)
	var old_displacement := 0.0
	var new_displacement := 0.0
	for i in range(1, old_points.size() - 1):
		old_displacement += absf(old_points[i].y)
		new_displacement += absf(new_points[i].y)
	check(new_points.size() == old_points.size() and new_displacement > old_displacement * 1.6, "jitter increases by two thirds without adding main-path samples")
	geometry.free()


func pixel_test() -> void:
	for size in [2, 3]:
		# All octants, negative coordinates, zero-length and repeated segments.
		for finish in [Vector2(57, 15), Vector2(15, 57), Vector2(-15, 57), Vector2(-57, 15), Vector2(-57, -15), Vector2(-15, -57), Vector2(15, -57), Vector2(57, -15), Vector2.ZERO]:
			var path := PackedVector2Array([Vector2.ZERO, finish, Vector2.ZERO])
			var pixels := LIGHTNING.PIXEL_BOLT.rasterize(path, size, Vector2.ZERO)
			var visited := {}
			var queue: Array[Vector2i] = [pixels.keys()[0]]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				if visited.has(cell):
					continue
				visited[cell] = true
				for offset: Vector2i in LIGHTNING.PIXEL_BOLT.NEIGHBORS:
					if pixels.has(cell + offset) and not visited.has(cell + offset):
						queue.append(cell + offset)
			check(visited.size() == pixels.size(), "pixel path is four-connected in every octant, size=%d" % size)
			check(pixels.has(Vector2i((finish / size).floor())), "pixel path includes endpoint cell")
			var reconstructed := {}
			var no_overlap := true
			for rectangle: Rect2i in LIGHTNING.PIXEL_BOLT.merge_rows(pixels):
				for x in range(rectangle.position.x, rectangle.end.x):
					var cell := Vector2i(x, rectangle.position.y)
					no_overlap = no_overlap and not reconstructed.has(cell)
					reconstructed[cell] = true
			check(no_overlap and reconstructed == pixels, "merged quads exactly cover cells without alpha overlap")
		var bolt := LIGHTNING.PIXEL_BOLT.new()
		bolt.points = PackedVector2Array([Vector2(-63, -87), Vector2(24, -6), Vector2(157, 24)])
		bolt.cell_size = size
		bolt.grid_origin = Vector2(-63, -87)
		bolt.build()
		check(bolt.cached_mesh.get_surface_count() == 1 and bolt.vertex_count > 0, "white core and blue rim share one mesh surface")
		check(bolt.core_cells.keys().all(func(cell): return not bolt.rim_cells.has(cell)), "core and rim masks do not overlap")
		var aligned := true
		for vertex: Vector3 in bolt.cached_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var world := Vector2(vertex.x, vertex.y) - bolt.grid_origin
			aligned = aligned and is_zero_approx(fposmod(world.x, size)) and is_zero_approx(fposmod(world.y, size))
		check(aligned, "all mesh corners align to the shared world grid")
		bolt.free()

