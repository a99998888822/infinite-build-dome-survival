extends "res://scripts/tests/reflection_load_review.gd"
## Diagnostic only: split wall-clock frames at the engine's frame signals.
var frame_start := 0
var draw_start := 0
var exits := 0
var exit_first := 0
var exit_last := 0
var render_measurement_enabled := false
var warm_reflection := false
var warmup_frame_ms: Array = []

func _ready() -> void:
	warm_reflection = "--warm-reflection" in OS.get_cmdline_user_args()
	get_tree().process_frame.connect(mark_frame)
	RenderingServer.frame_pre_draw.connect(mark_draw)
	super._ready()

func setup(entry: Dictionary) -> void:
	await super.setup(entry)
	warmup_frame_ms.clear()
	if not warm_reflection: return
	var warm_root := Node2D.new()
	host.add_child(warm_root)
	for i in 12:
		# Render-only samples: no spawn(), damage, group membership or audio.
		var beam := LightReflectionEffect.new()
		warm_root.add_child(beam)
		beam.set_process(false)
		beam.global_position = battle.player.global_position + Vector2(i * 3, 0)
		beam._visual_tier = i % 3
		beam._visual_detail = i % 3
		beam._orientation = float(i) * 0.15
		beam._elapsed = 0.24
		beam.queue_redraw()
	for i in 4:
		var begin := Time.get_ticks_usec()
		if DisplayServer.get_name() == "headless": await frames()
		else: await RenderingServer.frame_post_draw
		warmup_frame_ms.append((Time.get_ticks_usec() - begin) / 1000.0)
		await frames()
	warm_root.queue_free()
	await frames(4)

func mark_frame() -> void:
	frame_start = Time.get_ticks_usec()
	draw_start = 0
	exits = 0
	exit_first = 0
	exit_last = 0
	if not measuring: render_measurement_enabled = false
	if measuring and not render_measurement_enabled:
		RenderingServer.viewport_set_measure_render_time(game._world_viewport.get_viewport_rid(), true)
		render_measurement_enabled = true

func mark_draw() -> void:
	draw_start = Time.get_ticks_usec()

func track_child(node: Node) -> void:
	super.track_child(node)
	if node is LightReflectionEffect or node is LegacyLightReflectionEffect or node.get_script() == SHARED_BASELINE:
		node.tree_exiting.connect(mark_exit)

func mark_exit() -> void:
	if not measuring: return
	var at := Time.get_ticks_usec()
	if exits == 0: exit_first = at
	exit_last = at
	exits += 1

func sample_frame() -> void:
	if not measuring: return
	var previous_draw := previous
	super.sample_frame()
	var row: Dictionary = samples.back()
	row.process_frame_id = Engine.get_process_frames()
	row.step = current_step
	row.warm_reflection = warm_reflection
	if current_step == 0: row.warmup_frame_ms = warmup_frame_ms.duplicate()
	row.between_frames_ms = (frame_start - previous_draw) / 1000.0
	row.before_render_ms = (draw_start - frame_start) / 1000.0
	row.render_stage_ms = (previous - draw_start) / 1000.0
	row.exiting_reflections = exits
	row.exit_signal_span_ms = (exit_last - exit_first) / 1000.0
	row.renderer_setup_cpu_ms = RenderingServer.get_frame_setup_time_cpu()
	var rid := game._world_viewport.get_viewport_rid()
	row.viewport_render_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(rid)
	row.viewport_render_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(rid)
