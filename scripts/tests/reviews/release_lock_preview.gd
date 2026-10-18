extends RefCounted
## Candidate presentation only. Loaded by the review scene, never production UI.
const NOTICE := "正式版可用"
const PIXEL_FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")


static func apply_talents(page: CampBlueprintUIController) -> void:
	# Candidate only: use the new building nodes, without changing saved data.
	for id in page._nodes:
		var button: TalentNodeButton = page._nodes[id]
		if not button.building or id in ["camp_armory_workshop", "camp_dome_shelter"]: continue
		button.disabled = true
		button.lit = false
		button.queue_redraw()
		var notice := _label(button, NOTICE, 12, Color("bfc0c0"))
		notice.position = Vector2(-10, 34)
		notice.size = Vector2(100, 20)
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.set_meta("release_locked", true)


static func apply_roster(view: CharacterSelectView) -> Array[Texture2D]:
	var capitalist := view.character_list.get_child(1) as Button
	capitalist.disabled = true
	capitalist.focus_mode = Control.FOCUS_NONE
	capitalist.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var skin := capitalist.get_theme_stylebox("disabled").duplicate() as StyleBoxTexture
	skin.texture = _gray(skin.texture, 0.82)
	skin.modulate_color = Color.WHITE
	capitalist.add_theme_stylebox_override("disabled", skin)
	for child in capitalist.get_children():
		if child is TextureRect: child.texture = _gray(child.texture, 0.76)
		elif child is Label:
			child.add_theme_color_override("font_color", Color("77757b"))
			child.position.y = 9
			child.size.y = 35
	var veil := _veil(capitalist, 0.76)
	veil.anchor_left = 0.24
	veil.anchor_right = 0.95
	veil.anchor_top = 0.48
	veil.anchor_bottom = 0.87
	var notice := _label(veil, NOTICE, 22, Color("c0bbc1"))
	notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capitalist.set_meta("release_locked", true)
	# Same full-width frames as the capitalist. The original roster scroll
	# reaches the remaining rows; eight rows fit cleanly in its visible height.
	view.character_list.add_theme_constant_override("separation", 18)
	var textures: Array[Texture2D] = []
	for i in 8:
		var card := view._button("", "roster_normal.png", Vector2(336, 91), 29)
		card.name = "Silhouette%02d" % (i+1)
		card.disabled = true
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		card.add_theme_stylebox_override("disabled", skin)
		view.character_list.add_child(card)
		var portrait := TextureRect.new()
		portrait.name = "SilhouettePortrait"
		portrait.texture = _silhouette(i)
		textures.append(portrait.texture)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		portrait.position = Vector2(14, 14)
		portrait.size = Vector2(62, 62)
		var strip := _veil(card, 0.76)
		strip.anchor_left = 0.24
		strip.anchor_right = 0.95
		strip.anchor_top = 0.30
		strip.anchor_bottom = 0.70
		var text := _label(strip, NOTICE, 22, Color("c0bbc1"))
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.set_meta("release_locked", true)
	# The roster had already cached the two-character height before the review
	# inserted its extra rows. Invalidate it before the parent updates its range.
	view.character_list.update_minimum_size()
	view.roster_scroll.queue_sort.call_deferred()
	return textures


static func _veil(parent: Control, opacity: float) -> ColorRect:
	var veil := ColorRect.new()
	veil.name = "ReleaseVeil"
	veil.color = Color(0.065, 0.065, 0.08, opacity)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return veil


static func _label(parent: Control, text: String, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("151419"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label


static func _gray(texture: Texture2D, brightness: float) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			var value := (color.r*0.299+color.g*0.587+color.b*0.114)*brightness
			image.set_pixel(x,y,Color(value,value,value,color.a))
	return ImageTexture.create_from_image(image)


static func _silhouette(index: int) -> Texture2D:
	# Faceless human busts on a 48px grid. Each uses a distinct head/hair/hat
	# contour; large joined shapes and two solid tones, no antialiasing.
	var parts: Array[PackedVector2Array] = []
	parts.append(PackedVector2Array([Vector2(5,46),Vector2(7,37),Vector2(18,31),Vector2(18,27),Vector2(30,27),Vector2(30,31),Vector2(41,37),Vector2(43,46)]))
	match index:
		0: # Raised hood, pointed cloak shoulders.
			parts.append(PackedVector2Array([Vector2(9,34),Vector2(10,17),Vector2(16,7),Vector2(24,3),Vector2(32,8),Vector2(38,19),Vector2(39,34),Vector2(34,39),Vector2(14,39)]))
		1: # Bent pointed hat with a broad brim.
			parts.append(PackedVector2Array([Vector2(5,20),Vector2(16,18),Vector2(24,2),Vector2(35,5),Vector2(29,8),Vector2(32,18),Vector2(43,22),Vector2(39,25),Vector2(8,25)]))
			parts.append(PackedVector2Array([Vector2(15,22),Vector2(32,22),Vector2(33,31),Vector2(27,36),Vector2(18,32)]))
		2: # High ponytail with swept forehead.
			parts.append(PackedVector2Array([Vector2(15,13),Vector2(22,6),Vector2(33,7),Vector2(36,12),Vector2(44,13),Vector2(45,24),Vector2(40,34),Vector2(39,23),Vector2(35,19),Vector2(33,30),Vector2(24,34),Vector2(17,29)]))
		3: # Closed helmet with comb crest.
			parts.append(PackedVector2Array([Vector2(13,31),Vector2(11,15),Vector2(18,9),Vector2(18,3),Vector2(28,2),Vector2(32,5),Vector2(27,9),Vector2(35,14),Vector2(36,29),Vector2(30,35),Vector2(18,35)]))
		4: # Travel hat, dropped back brim.
			parts.append(PackedVector2Array([Vector2(3,19),Vector2(14,16),Vector2(17,7),Vector2(30,7),Vector2(34,16),Vector2(44,19),Vector2(43,24),Vector2(8,25)]))
			parts.append(PackedVector2Array([Vector2(15,21),Vector2(33,21),Vector2(32,31),Vector2(28,35),Vector2(19,32)]))
		5: # Strong jaw, broad mohawk.
			parts.append(PackedVector2Array([Vector2(12,18),Vector2(18,13),Vector2(18,3),Vector2(23,2),Vector2(23,5),Vector2(31,5),Vector2(31,10),Vector2(35,14),Vector2(36,26),Vector2(30,35),Vector2(18,35),Vector2(12,28)]))
		6: # Long flowing hair, offset parting.
			parts.append(PackedVector2Array([Vector2(8,39),Vector2(11,29),Vector2(10,17),Vector2(14,7),Vector2(24,4),Vector2(34,8),Vector2(38,17),Vector2(35,27),Vector2(41,39),Vector2(32,38),Vector2(27,32),Vector2(20,32),Vector2(17,39)]))
		7: # High collar, swept hair and angular profile.
			parts.append(PackedVector2Array([Vector2(8,28),Vector2(17,31),Vector2(14,23),Vector2(15,12),Vector2(12,8),Vector2(25,5),Vector2(35,9),Vector2(34,18),Vector2(39,23),Vector2(32,26),Vector2(29,32),Vector2(41,27),Vector2(37,42),Vector2(12,42)]))
	var mask := Image.create(48,48,false,Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for y in 48:
		for x in 48:
			for polygon in parts:
				if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),polygon):
					mask.set_pixel(x,y,Color("6e6a73"))
					break
	var image := mask.duplicate() as Image
	for y in range(1,47):
		for x in range(1,47):
			if mask.get_pixel(x,y).a>0 and mask.get_pixel(x,y-1).a==0:
				image.set_pixel(x,y,Color("99919a"))
	return ImageTexture.create_from_image(image)
