extends Node
## Production playback QA and isolated visual benchmark. No gameplay benchmark.
const VISUAL = preload("res://scripts/effects/selected_spell_visual.gd")
const SOURCE = preload("res://scripts/tools/spell_vfx_sources/selected_hole.gd")
const STRIKE = preload("res://scripts/effects/baked_ground_strike.gd")
const OUT := "res://artifacts/reviews/spell-baked-integration/"
var host: Node2D
var checks := 0
var failures := 0
var results: Array = []

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(9)
		return
	WindowSettings._startup_applied = true
	CampProgression.begin_transient_session()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(480,360)
	get_window().content_scale_size = Vector2i(480,360)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().transparent_bg = true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	host = Node2D.new()
	get_window().add_child(host)
	host.process_mode = Node.PROCESS_MODE_DISABLED
	for key: String in VISUAL.FRAMES.DEFINITIONS:
		var d: Dictionary = VISUAL.FRAMES.DEFINITIONS[key]
		check(VISUAL.FRAMES.TEXTURES[key].get_width() == int(d.size[0])*int(d.columns),"atlas dimensions " + key)
	check(VISUAL.hole_time(1.0,2.0)<0.0,"extended control holds the middle")
	check(is_equal_approx(VISUAL.hole_time(1.9,2.0),0.75),"extended control retains closing tail")
	var strike := STRIKE.new()
	host.add_child(strike)
	strike.setup(364,60,2,0.35,0)
	check(strike.column_scale==Vector2(1,2) and strike.ground_scale==Vector2(2,2),"column height and ground size are independent")
	for t in [0.0,0.08,0.16,0.20,0.28,0.36]:
		strike.advance(t*2.0)
		check(is_equal_approx(strike.column.modulate.a,LightningParticleEffect.ground_alpha_at(t)*0.35),"exact scaled flash alpha")
	strike.free()
	if DisplayServer.get_name() != "headless":
		await capture_selected()
		if OS.get_cmdline_user_args().has("--benchmark"):
			for kind in ["water","black_hole","electric_spark"]:
				for count in [1,20,100]:
					for baked in [false,true]: await benchmark(kind,count,baked)
			FileAccess.open(OUT+"benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	host.free()
	CampProgression.end_transient_session()
	print("SELECTED_SPELL_BAKED_REVIEW checks=%d failures=%d"%[checks,failures])
	get_tree().quit(1 if failures else 0)

func make_visual(kind: String, baked: bool) -> Node2D:
	var node: Node2D
	if not baked:
		node = SOURCE.new()
		host.add_child(node)
		node.configure(kind)
		if kind=="electric_spark":
			var points: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/spells_baked/strike_points.json"))
			node.set_paths(_points(points.primary),_points(points.echo))
	elif kind=="electric_spark":
		node = STRIKE.new()
		host.add_child(node)
		node.setup(182,30,1,1,0)
	else:
		node = WaterWaveEffect.new() if kind=="water" else BlackHoleEffect.new()
		host.add_child(node)
		if kind=="water": node._radius=75.3984
	return node

func _points(values: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p: Array in values: points.append(Vector2(p[0],p[1]))
	return points

func set_time(node: Node2D,kind: String,baked: bool,t: float) -> void:
	if not baked: node.set_time(t+(0.5 if kind=="electric_spark" else 0.0))
	elif kind=="electric_spark": node.advance(t)
	else:
		node._elapsed=t
		if kind=="water": node.queue_redraw()
		else: node._body_visual.queue_redraw()

func capture_selected() -> void:
	DirAccess.make_dir_recursive_absolute(OUT+"playback")
	for kind in ["water","black_hole","electric_spark"]:
		for baked in [false,true]:
			var node := make_visual(kind,baked)
			node.position=Vector2(240,245)
			if baked and kind=="black_hole": node._sorted_visual.global_position=node.global_position
			for i in range(10 if kind=="electric_spark" else 16):
				var t := float(i)/18.0
				set_time(node,kind,baked,t)
				await RenderingServer.frame_post_draw
				get_window().get_texture().get_image().save_png(OUT+"playback/%s_%s_%02d.png"%[kind,"baked" if baked else "source",i])
			node.free()

func benchmark(kind: String,count: int,baked: bool) -> void:
	var nodes: Array[Node2D] = []
	for i in count:
		var node := make_visual(kind,baked)
		node.position=Vector2(60+(i%8)*48,100+(i/8)*12)
		if baked and kind=="black_hole": node._sorted_visual.global_position=node.global_position
		nodes.append(node)
	for i in 8:
		for node in nodes: set_time(node,kind,baked,0.22)
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var update_us := 0
	for i in 90:
		var begin := Time.get_ticks_usec()
		# Match production 18fps art cadence under a simulated 60fps render loop.
		if i%3==0:
			var t := float((i/3)%7)/18.0
			for node in nodes: set_time(node,kind,baked,t)
		update_us += Time.get_ticks_usec()-begin
		await RenderingServer.frame_post_draw
		samples.append(float(Time.get_ticks_usec()-begin)/1000.0)
	samples.sort()
	var result := {"kind":kind,"count":count,"baked":baked,"frame_median_ms":samples[45],"frame_p95_ms":samples[85],"cpu_update_us_per_frame":float(update_us)/90.0}
	results.append(result)
	print("VISUAL_BENCH ",JSON.stringify(result))
	for node in nodes: node.free()
