extends Node2D
## Isolates the 2D renderer's fixed cost from its per-item and per-draw cost.
## Usage: --scene res://scenes/tests/render_floor_probe.tscn -- --count=2000
##        --mode=shared|unique --subviewport=0|1 --frames=300
## Prints one JSON line so a background capture run can be parsed from its log.

const TEX_SIZE := 32
const WARMUP_FRAMES := 60

var count := 500
var mode := "shared"
var use_sub_viewport := false
var frames := 300
var moving := false
var _root: Node2D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--subviewport="): use_sub_viewport = arg.trim_prefix("--subviewport=") != "0"
		elif arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--move="): moving = arg.trim_prefix("--move=") != "0"
		elif arg.begins_with("--redraw="): moving = arg.trim_prefix("--redraw=") != "0"
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if use_sub_viewport:
		var layer := CanvasLayer.new()
		add_child(layer)
		var container := SubViewportContainer.new()
		container.size = Vector2(1920, 1080)
		container.stretch = true
		container.stretch_shrink = 1
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1920, 1080)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = true
		viewport.handle_input_locally = false
		container.add_child(viewport)
		_root = Node2D.new()
		viewport.add_child(_root)
	else:
		_root = Node2D.new()
		add_child(_root)
	var camera := Camera2D.new()
	camera.position = Vector2(960, 540)
	_root.add_child(camera)
	camera.make_current()
	_spawn()
	await get_tree().process_frame
	var samples: Array[float] = []
	var draws: Array[float] = []
	var objects: Array[float] = []
	var previous := Time.get_ticks_usec()
	var collected := 0
	while collected < frames + WARMUP_FRAMES:
		if moving:
			# Moving items force a transform update (and, for drawn items, a canvas
			# command rebuild) every frame; static items reuse their cached state.
			var phase := float(collected) * 0.25
			for index in _root.get_child_count():
				var item := _root.get_child(index) as Node2D
				if item is Camera2D: continue
				item.position.y += sin(phase + float(index)) * 0.5
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if collected >= WARMUP_FRAMES:
			samples.append((now - previous) / 1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		previous = now
		collected += 1
	print("RENDER_FLOOR ", JSON.stringify({
		"count": count, "mode": mode, "subviewport": use_sub_viewport, "frames": frames,
		"wall_mean": _mean(samples), "wall_p95": _percentile(samples, 0.95),
		"draws_mean": _mean(draws), "objects_mean": _mean(objects),
		"fps_mean": 1000.0 / maxf(_mean(samples), 0.001),
	}))
	get_tree().quit(0)


func _spawn() -> void:
	if count <= 0:
		return
	var shared := _make_texture(0)
	var columns := maxi(1, ceili(sqrt(float(count))))
	for index in count:
		var sprite := Sprite2D.new()
		sprite.texture = shared if mode == "shared" else _make_texture(index + 1)
		sprite.position = Vector2(float(index % columns) * 40.0 - columns * 20.0, float(index / columns) * 40.0 - 540.0)
		_root.add_child(sprite)


func _make_texture(seed_value: int) -> ImageTexture:
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.15 + float(seed_value % 7) * 0.1, 0.4, 0.7, 1.0))
	return ImageTexture.create_from_image(image)


func _mean(values: Array[float]) -> float:
	if values.is_empty(): return 0.0
	var total := 0.0
	for value in values: total += value
	return total / values.size()


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty(): return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[mini(ordered.size() - 1, int(ordered.size() * fraction))]
