extends Node
## Offline only: GPU capture on the project's private desktop helper.
const SOURCE = preload("res://scripts/tools/spell_vfx_sources/selected_hole.gd")
const LIGHTNING = preload("res://scripts/tools/spell_vfx_sources/selected_lightning.gd")
const OUT := "res://artifacts/reviews/spell-baked-integration/raw/"
var root: Window
var host: Node2D
var source: Node2D
var definitions: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(9)
		return
	WindowSettings._startup_applied = true
	CampProgression.begin_transient_session()
	root = get_tree().root
	root.size = Vector2i(480,360)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.transparent_bg = true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	Engine.max_fps = 120
	host = Node2D.new()
	root.add_child(host)
	host.process_mode = Node.PROCESS_MODE_DISABLED
	for kind in ["water", "black_hole"]:
		source = SOURCE.new()
		host.add_child(source)
		source.position = Vector2(240,245)
		source.configure(kind)
		await capture("water_r02" if kind == "water" else "hole_r03",16,0.0)
		if kind == "black_hole":
			source.steady = true
			await capture("hole_steady",36,0.0)
		source.free()
	# Use the approved R01 path, generated with the exact review seed.
	source = LIGHTNING.new()
	host.add_child(source)
	source.position = Vector2(240,245)
	source.configure("electric_spark")
	seed(4102026)
	var generator := LightningParticleEffect.new()
	host.add_child(generator)
	generator._is_ground_strike = true
	generator._control_point_envelope_power = 0.65
	var first: Node2D = generator._create_bolt_path(Vector2(0,-182),Vector2.ZERO)
	var second: Node2D = generator._create_bolt_path(Vector2(0,-182),Vector2.ZERO,first.points)
	source.set_paths(first.points,second.points)
	generator.free()
	for layer in ["primary", "echo", "impact", "ground", "sparks"]:
		await capture("strike_"+layer,4 if layer in ["primary","echo","impact"] else 10,0.0,layer)
	definitions["strike_points"] = {"primary":Array(source.primary.points).map(func(p):return [p.x,p.y]),"echo":Array(source.echo.points).map(func(p):return [p.x,p.y])}
	source.free()
	FileAccess.open(OUT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(definitions,"  "))
	host.free()
	CampProgression.end_transient_session()
	print("SELECTED_SPELLS_BAKED")
	get_tree().quit()

func capture(key: String, count: int, start: float, layer := "") -> void:
	DirAccess.make_dir_recursive_absolute(OUT+key)
	for index in count:
		var t := start + float(index)/18.0
		if layer.is_empty(): source.set_time(t)
		else:
			# Channel brightness is supplied at runtime from the exact flash clock.
			source.set_time(0.5+t+(0.2 if layer=="echo" else 0.0))
			source.back.visible = layer=="ground"
			source.front.visible = layer=="sparks"
			source.primary.visible = layer in ["primary","impact"]
			source.echo.visible = layer=="echo"
			if layer=="primary":
				source.primary.modulate.a = 1.0
				source.primary.impact.hide()
			if layer=="echo": source.echo.modulate.a = 1.0
			if layer=="impact":
				source.primary.modulate.a = 1.0
				source.primary.self_modulate.a = 0.0
				for fork in source.primary.forks + source.extra_forks: fork.hide()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(OUT+key+"/%03d.png"%index)==OK)
		else: await get_tree().process_frame
		# Reset layer-only overrides before the next capture.
		if not layer.is_empty():
			source.primary.self_modulate.a = 1.0
			for fork in source.primary.forks + source.extra_forks: fork.show()
			source.primary.impact.show()
	definitions[key]={"count":count,"fps":18,"pivot":[240,245]}
	print("BAKED ",key," frames=",count)
