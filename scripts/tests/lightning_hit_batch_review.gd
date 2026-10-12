extends Node2D
## Optional GPU comparison against a saved pre-optimization script.
const BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
var reference_path := ""
var output := ""
var failures := 0
var rows: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="): reference_path = arg.trim_prefix("--reference=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport

func _run() -> void:
	if DisplayServer.get_name() == "headless" or reference_path.is_empty():
		push_error("GPU and --reference=<saved original script> required")
		get_tree().quit(1)
		return
	CampProgression.begin_transient_session()
	WindowSettings._startup_applied = true
	var reference: Script = load(reference_path)
	for count in [1, 12]:
		for sample_age in [0.0, 0.06, 0.14]:
			var left := _viewport()
			var right := _viewport()
			var originals: Array[Node2D] = []
			var combined: Node2D
			reference._random_ready = true
			reference._random.seed = 719
			BURST._random_ready = true
			BURST._random.seed = 719
			var params := {"count_multiplier": 0.6, "distance_multiplier": 0.5, "glow_radius_multiplier": 0.5}
			for i in count:
				var point := Vector2(256, 160) + Vector2.from_angle(TAU * i / count) * (0.0 if count == 1 else 22.0)
				var old: Node2D = reference.spawn(left, point, Vector2.RIGHT, 1.0, params)
				old.set_process(false)
				originals.append(old)
				combined = BURST.spawn(right, point, Vector2.RIGHT, 1.0, params)
				combined.set_process(false)
			for old in originals: old._process(sample_age)
			combined._process(sample_age)
			var max_instance_error := 0.0
			for batch_index in 2:
				var cursor := 0
				# Compare both renderer readbacks; Compatibility quantizes custom
				# data, so comparing a CPU buffer to a GPU readback is misleading.
				var combined_buffer: PackedFloat32Array = combined.batches[batch_index].multimesh.buffer
				for old in originals:
					var original_buffer: PackedFloat32Array = old.batches[batch_index].multimesh.buffer
					var offset := old.global_position - combined.global_position
					for i in original_buffer.size():
						var expected := original_buffer[i] + (offset.x if i % 16 == 3 else offset.y if i % 16 == 7 else 0.0)
						max_instance_error = maxf(max_instance_error, absf(combined_buffer[cursor + i] - expected))
					cursor += original_buffer.size()
			if max_instance_error > 0.0001: failures += 1
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var before := left.get_texture().get_image()
			var after := right.get_texture().get_image()
			var a := before.get_data()
			var b := after.get_data()
			var different := 0
			var max_error := 0
			for i in a.size():
				var error := absi(int(a[i]) - int(b[i]))
				if error > 0: different += 1
				max_error = maxi(max_error, error)
			# Grouping white atlases changes alpha-compositing order: allow two
			# 8-bit rounding steps, while independently verifying all instance data.
			if max_error > 2: failures += 1
			rows.append({"hits": count, "age": sample_age, "different_channels": different, "max_channel_error": max_error, "max_instance_error": max_instance_error})
			if not output.is_empty():
				before.save_png(output.path_join("lightning_before_%d_%d.png" % [count, roundi(sample_age * 1000)]))
				after.save_png(output.path_join("lightning_after_%d_%d.png" % [count, roundi(sample_age * 1000)]))
			left.queue_free()
			right.queue_free()
			await get_tree().process_frame
	print("LIGHTNING_BATCH_REVIEW ", JSON.stringify({"rows": rows, "failures": failures}))
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)
