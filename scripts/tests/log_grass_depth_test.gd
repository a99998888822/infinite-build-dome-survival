extends Node
## Real scenery creation and grass batches; pixel checks prove both depth orders.
var output := ""
var failures: Array[String] = []
var ground: CavernPopulationBackdrop
var log_sprite: Sprite2D
var grass: Array[MultiMeshInstance2D] = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	_run.call_deferred()

func check(ok: bool, note: String) -> void:
	print("PASS " if ok else "FAIL ", note)
	if not ok: failures.append(note)

func shot() -> Image:
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _run() -> void:
	get_window().size = Vector2i(512, 384)
	get_window().content_scale_size = Vector2i(512, 384)
	get_viewport().transparent_bg = true
	ground = CavernPopulationBackdrop.new()
	ground.config = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/cavern_meadow_battlefield.json"))
	ground.roots = Node2D.new()
	ground.roots.y_sort_enabled = true
	add_child(ground.roots)
	for row: Dictionary in ground.config.props: ground.prop_textures.append(load(row.texture))
	var atlas := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for index in 4:
		var tex: Texture2D = load(ground.config.grass[index].texture)
		var src := tex.get_image()
		if src.is_compressed(): src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(src, Rect2i(0, 0, 32, 32), Vector2i(index * 32, 0))
	ground.grass_atlas = ImageTexture.create_from_image(atlas)
	ground.grass_material = ShaderMaterial.new()
	ground.grass_material.shader = CavernPopulationBackdrop.GRASS_SHADER
	ground.grass_material.set_shader_parameter("fade_start", -1000.0)
	ground.grass_material.set_shader_parameter("fade_end", -900.0)
	var nodes: Array[Node] = []
	ground._make_solid(ground._placement("prop", 1, Vector2(256, 220), 2.0, false), nodes)
	log_sprite = nodes[0]
	check(log_sprite.z_index == CombatRenderWorld.GRASS_Z and not log_sprite.z_as_relative, "log shares grass layer")
	check(log_sprite.get_child_count() == 1, "log keeps its production terrain collider")
	for point in [Vector2(232, 217), Vector2(280, 221)]:
		var blade := ground._placement("grass", 2, point, 1.0, false)
		blade.tint = Color.WHITE
		var batch := ground._grass_batch([blade], Vector2i.ZERO, false)
		batch.get_parent().position.y = point.y
		batch.position = -batch.get_parent().position
		grass.append(batch)
	check(CombatRenderWorld.ATTACK_Z > log_sprite.z_index, "weapon effects remain above logs and grass")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		for batch in grass: batch.hide()
		var wood := await shot()
		log_sprite.hide()
		for batch in grass: batch.show()
		var blades := await shot()
		log_sprite.show()
		var layered := await shot()
		var overlap := [0, 0]
		var wrong := [0, 0]
		for y in range(175, 241):
			for x in range(210, 303):
				if wood.get_pixel(x, y).a < 0.99 or blades.get_pixel(x, y).a < 0.99: continue
				var side := 0 if x < 256 else 1
				overlap[side] += 1
				var expected := wood.get_pixel(x, y) if side == 0 else blades.get_pixel(x, y)
				var difference := expected - layered.get_pixel(x, y)
				if absf(difference.r) + absf(difference.g) + absf(difference.b) > 0.025: wrong[side] += 1
		for side in 2:
			check(overlap[side] > 5 and wrong[side] == 0, "pixel depth side=%d overlap=%d wrong=%d" % [side, overlap[side], wrong[side]])
		wood.save_png(output.path_join("log_only.png"))
		blades.save_png(output.path_join("grass_only.png"))
		layered.save_png(output.path_join("correct_depth.png"))
	ground.free()
	print("LOG_GRASS_DEPTH_DONE failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
