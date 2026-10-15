extends Node
## Real GPU sampling across the entire approved atlas, at native combat size.
var output := ""
var checks := 0
var failures := 0
var samples: Array[Dictionary] = []
var viewport: SubViewport
var original: Sprite2D
var fixed: Sprite2D

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frame_image() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func set_size(side: int) -> void:
	viewport.size = Vector2i(side*2,side)
	original.position = Vector2(side*.5,side*.5)
	fixed.position = Vector2(side*1.5,side*.5)
	original.scale = Vector2.ONE*side/128.0
	fixed.scale = original.scale

func same_pixels(a: Image, b: Image) -> bool:
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			if not is_equal_approx(p.a,q.a) or (p.a > 0.0 and not p.is_equal_approx(q)): return false
	return true

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.unfocusable = true
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	original = Sprite2D.new()
	fixed = Sprite2D.new()
	viewport.add_child(original)
	viewport.add_child(fixed)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/player/pixel_minify.gdshader")
	fixed.material = material
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/player/actions/novice_128/animations.json"))
	var expected_cells := 0
	for clip: String in data.clips:
		var settings: Dictionary = data.clips[clip]
		expected_cells += int(settings.frames)
		original.texture = load(settings.texture)
		fixed.texture = original.texture
		original.hframes = int(settings.frames)
		fixed.hframes = original.hframes
		for frame in original.hframes:
			original.frame = frame
			fixed.frame = frame
			var label := "%s_%02d" % [clip,frame]
			set_size(64)
			var image := await frame_image()
			var before := image.get_region(Rect2i(0,0,64,64))
			var after := image.get_region(Rect2i(64,0,64,64))
			var interiors_unchanged := true
			var silhouette_preserved := true
			var hard_alpha := true
			var changed := 0
			for y in 64:
				for x in 64:
					var a := before.get_pixel(x,y)
					var b := after.get_pixel(x,y)
					if a.a > .5 and b.a < .5: silhouette_preserved = false
					if b.a > .01 and b.a < .99: hard_alpha = false
					if a.is_equal_approx(b): continue
					changed += 1
					var interior := true
					for ny in range(maxi(0,y-1),mini(64,y+2)):
						for nx in range(maxi(0,x-1),mini(64,x+2)):
							if before.get_pixel(nx,ny).a < .5: interior = false
					if interior: interiors_unchanged = false
			check(interiors_unchanged and silhouette_preserved and hard_alpha, "preserves interior colors, occupied pixels and hard alpha " + label)
			image.save_png(output.path_join(label + ".png"))
			samples.append({"clip":clip,"frame":frame,"changed_pixels":changed})
			if frame == 0:
				fixed.flip_h = true
				var mirrored := (await frame_image()).get_region(Rect2i(64,0,64,64))
				mirrored.flip_x()
				check(same_pixels(after,mirrored), "left-facing sampling mirrors exactly " + clip)
				fixed.flip_h = false
			set_size(128)
			image = await frame_image()
			check(same_pixels(image.get_region(Rect2i(0,0,128,128)),image.get_region(Rect2i(128,0,128,128))), "full-size sampling preserves the approved art " + label)
	set_size(64)
	fixed.self_modulate.a = .25
	var faded := (await frame_image()).get_region(Rect2i(64,0,64,64))
	var max_alpha := 0.0
	for y in 64:
		for x in 64: max_alpha = maxf(max_alpha,faded.get_pixel(x,y).a)
	check(absf(max_alpha-.25)<.01, "revive blink alpha still modulates the sprite")
	check(samples.size()==expected_cells and int(samples[0].changed_pixels)>0, "all configured action cells exercised and idle boundary pixels recovered")
	FileAccess.open(output.path_join("sampling.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"))
	viewport.queue_free()
	await get_tree().process_frame
	print("PIXEL_SAMPLING_COMPLETE checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
