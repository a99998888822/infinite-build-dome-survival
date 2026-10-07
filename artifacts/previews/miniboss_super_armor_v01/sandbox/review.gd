extends Node2D
## Isolated art review: no production controller, damage or control state.

const FRAMES: SpriteFrames = preload("res://reference/frames.tres")
const OUTLINE: Shader = preload("res://warm_outline.gdshader")
const GROUND: Texture2D = preload("res://reference/ground.png")
const FPS := 30
const DURATION := 2.8
const ARMOR_START := 0.35
const ARMOR_END := 2.35
const TEXT_DURATION := 0.8

var bodies: Array[Sprite2D] = []
var review_font: FontFile = preload("res://reference/chinese.otf").duplicate()
var captions: Array[Label] = []
var phase_label: Label
var clock := 0.0
var output := ""
var pose := "idle"
var mirrored := false
var capturing := false

func _ready() -> void:
	review_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	review_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--pose="): pose = arg.trim_prefix("--pose=")
		if arg == "--mirrored": mirrored = true
	_make_stage()
	_seek(0.0)
	if not output.is_empty():
		capturing = true
		_capture.call_deferred()

func _make_stage() -> void:
	_label("霸体 · 视觉预览", Vector2(28, 22), 24, Color("eee7d4"))
	_label("钢甲骑士   /   V02", Vector2(30, 63), 12, Color("8e9c98"))
	_label("实战尺寸", Vector2(40, 118), 16, Color("c9d2ca"))
	_label("轮廓与飘字 · 2 倍放大", Vector2(365, 118), 16, Color("c9d2ca"))
	for rect in [Rect2(24, 156, 300, 298), Rect2(344, 156, 592, 298)]:
		var ground := TextureRect.new()
		ground.texture = GROUND
		ground.position = rect.position
		ground.size = rect.size
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ground.clip_contents = true
		ground.modulate = Color(0.82, 0.82, 0.82)
		ground.z_index = -2
		add_child(ground)
	_make_body(Vector2(174, 365), 1.0)
	_make_body(Vector2(640, 425), 2.0)
	phase_label = _label("", Vector2(30, 476), 16, Color("e0d9bc"))
	_label("黄橙红流动描边   ·   字体 0.7 倍   ·   流速 4 倍", Vector2(30, 509), 12, Color("8e9c98"))
	_label("2.0 秒", Vector2(855, 476), 16, Color("b4bea8"))

func _make_body(anchor: Vector2, zoom: float) -> void:
	var host := Node2D.new()
	host.position = anchor
	host.scale = Vector2.ONE * zoom
	add_child(host)
	var body := Sprite2D.new()
	body.position = Vector2(0, -52.08)
	body.scale = Vector2.ONE * 0.56
	body.texture = FRAMES.get_frame_texture("idle", 0)
	body.flip_h = mirrored
	var material := ShaderMaterial.new()
	material.shader = OUTLINE
	body.material = material
	host.add_child(body)
	bodies.append(body)
	var caption := Label.new()
	caption.text = "霸体"
	caption.add_theme_font_override("font", review_font)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("ffe369"))
	caption.add_theme_color_override("font_outline_color", Color("342912"))
	caption.add_theme_constant_override("outline_size", 3)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size = Vector2(80, 30)
	caption.pivot_offset = caption.size * 0.5
	caption.scale = Vector2.ONE * 0.7
	caption.z_index = 20
	host.add_child(caption)
	captions.append(caption)

func _label(value: String, pos: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_override("font", review_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	add_child(label)
	return label

func _process(delta: float) -> void:
	if not capturing:
		clock = fmod(clock + delta, DURATION)
		_seek(clock)

func _seek(time: float) -> void:
	clock = time
	var age := time - ARMOR_START
	var strength := smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(ARMOR_END - 0.14, ARMOR_END, time))
	var text_progress := clampf(age / TEXT_DURATION, 0.0, 1.0)
	var rise := 1.0 - pow(1.0 - text_progress, 1.65)
	var fade := 1.0 - smoothstep(0.30, TEXT_DURATION, age)
	var frame_index := 0
	if pose == "move": frame_index = int(time * 10.0) % FRAMES.get_frame_count("move")
	elif pose == "windup": frame_index = mini(int(fmod(time, 1.66) * 7.0), 6)
	for index in bodies.size():
		var body := bodies[index]
		body.texture = FRAMES.get_frame_texture(pose, frame_index)
		var atlas := body.texture as AtlasTexture
		var size := atlas.atlas.get_size()
		var uv_rect := Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y, atlas.region.end.x / size.x, atlas.region.end.y / size.y)
		var material := body.material as ShaderMaterial
		material.set_shader_parameter("source_texture", atlas.atlas)
		material.set_shader_parameter("frame_uv", uv_rect)
		material.set_shader_parameter("elapsed", maxf(age, 0.0))
		material.set_shader_parameter("strength", strength)
		var caption := captions[index]
		caption.position = Vector2(-40, lerpf(-21.0, -67.0, rise))
		caption.modulate.a = fade if age >= 0.0 and age <= TEXT_DURATION else 0.0
	phase_label.text = "常态" if age < 0.0 else ("触发 · 霸体" if age < TEXT_DURATION else ("霸体持续" if time < ARMOR_END else "霸体结束"))
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(24, 99), Vector2(936, 99), Color("273633"), 1.0)
	for rect in [Rect2(24, 156, 300, 298), Rect2(344, 156, 592, 298)]:
		draw_rect(rect, Color("35433c"), false, 1.0)
	var swatches := [Color("ffe038"), Color("ff731a"), Color("ff2614")]
	for i in 3:
		draw_rect(Rect2(848 + i * 24, 50, 18, 3), swatches[i])
	var progress := clampf((clock - ARMOR_START) / (ARMOR_END - ARMOR_START), 0.0, 1.0)
	draw_rect(Rect2(196, 482, 624, 3), Color("273633"))
	draw_rect(Rect2(196, 482, 624 * progress, 3), Color("cdbb79"))

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		for time in [0.0, 0.35, 0.5, 0.75, 1.2, 2.4]: _seek(time)
		print("ARMOR_PREVIEW_HEADLESS_OK bodies=", bodies.size(), " poses=", FRAMES.get_animation_names())
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(output)
	for i in 3: await get_tree().process_frame
	for i in roundi(DURATION * FPS):
		_seek(float(i) / FPS)
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(output.path_join("frame_%04d.png" % i))
		if error != OK:
			push_error("Preview capture failed: " + str(error))
			get_tree().quit(3)
			return
	print("ARMOR_PREVIEW_CAPTURE_OK frames=", roundi(DURATION * FPS), " pose=", pose, " mirrored=", mirrored)
	get_tree().quit()
