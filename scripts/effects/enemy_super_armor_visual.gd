extends Node2D
## V02 resistance feedback; draws over the sprite without owning its material.
const OUTLINE = preload("res://assets/shaders/enemy_super_armor.gdshader")
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const DURATION := 2.0
const TEXT_DURATION := 0.8

var enemy: Node2D
var outline: Sprite2D
var caption: Label
var elapsed := 0.0
var remaining := 0.0
var pulses := 0
var _last_texture: Texture2D


func _ready() -> void:
	enemy = get_parent()
	enemy.died.connect(func(_enemy, _drop, _position): clear())
	process_priority = 10
	outline = Sprite2D.new()
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = OUTLINE
	outline.material = shader_material
	add_child(outline)
	caption = Label.new()
	var font := FONT.duplicate() as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	caption.add_theme_font_override("font", font)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("ffe369"))
	caption.add_theme_color_override("font_outline_color", Color("342912"))
	caption.add_theme_constant_override("outline_size", 3)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size = Vector2(160, 30)
	caption.pivot_offset = caption.size * 0.5
	caption.scale = Vector2.ONE * 0.7
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 20
	add_child(caption)
	clear()


func pulse() -> void:
	if remaining <= 0.0:
		elapsed = 0.0
		pulses += 1
		caption.text = L10n.text("combat.super_armor")
	remaining = DURATION
	show()
	set_process(true)
	_sync()


func clear() -> void:
	remaining = 0.0
	elapsed = 0.0
	hide()
	set_process(false)


func _process(delta: float) -> void:
	if not is_instance_valid(enemy) or not enemy.is_alive():
		clear()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed += delta
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		clear()
		return
	_sync()


func _sync() -> void:
	var body := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if body == null or body.texture == null:
		return
	outline.visible = body.visible
	outline.transform = body.transform
	outline.flip_h = body.flip_h
	outline.flip_v = body.flip_v
	outline.centered = body.centered
	outline.offset = body.offset
	outline.z_index = body.z_index + 1
	if _last_texture != body.texture:
		_last_texture = body.texture
		outline.texture = body.texture
		var source := body.texture
		var uv := Vector4(0, 0, 1, 1)
		if source is AtlasTexture:
			var atlas := source as AtlasTexture
			var size := atlas.atlas.get_size()
			uv = Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y,
				atlas.region.end.x / size.x, atlas.region.end.y / size.y)
			source = atlas.atlas
		outline.material.set_shader_parameter("source_texture", source)
		outline.material.set_shader_parameter("frame_uv", uv)
	outline.material.set_shader_parameter("elapsed", elapsed)
	outline.material.set_shader_parameter("strength", smoothstep(0.0, 0.08, elapsed) * smoothstep(0.0, 0.14, remaining))
	var rise := 1.0 - pow(1.0 - clampf(elapsed / TEXT_DURATION, 0.0, 1.0), 1.65)
	# Stay on the body's vertical axis; label never inherits sprite mirroring.
	caption.position = Vector2(body.position.x - 80.0, lerpf(body.position.y * 0.4, body.position.y * 1.29, rise))
	caption.modulate.a = (1.0 - smoothstep(0.30, TEXT_DURATION, elapsed)) if body.visible else 0.0
