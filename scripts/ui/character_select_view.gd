extends Control
class_name CharacterSelectView
## Approved 1280x720 composition, with live controls over the 640x360 artwork.

signal character_selected(character_id: String)
signal difficulty_selected(difficulty_id: String)

const ART := "res://assets/ui/character_select/"
const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("#372d2a")
const MUTED := Color("#69533f")
const CREAM := Color("#eadcc0")

var canvas: Control
var background: TextureRect
var character_list: VBoxContainer
var stats_list: Control
var weapon_list: VBoxContainer
var passive_list: VBoxContainer
var difficulty_list: HBoxContainer
var details_scroll: ScrollContainer
var character_icon: TextureRect
var name_label: Label
var description_label: Label
var back_button: Button
var confirm_button: Button
var error_label: Label
var hover_target: Button
var difficulty_title: Label
var difficulty_description: Label
var _paper_name: Label
var _details: VBoxContainer
var _font: SystemFont
var _bold_font: SystemFont
var _idle: Texture2D
var _walk: AtlasTexture
var _walk_frames := 1
var _walk_fps := 6.0
var _elapsed := 0.0
var _hovered := false
var _keyboard_focus := false
var walking := false
var walk_frame := 0
var _cropped_icons: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	_font.fallbacks = [preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")]
	_bold_font = _font.duplicate() as SystemFont
	_bold_font.font_weight = 700
	var matte := ColorRect.new()
	matte.color = Color("#141319")
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "Composition"
	canvas.size = DESIGN_SIZE
	add_child(canvas)
	background = _image(canvas, load(ART + "background.png"), Rect2(Vector2.ZERO, DESIGN_SIZE))
	background.name = "Background"
	_image(canvas, load(ART + "roster_frame.png"), Rect2(42,174,228,356))
	_label(canvas, "角色名册", Vector2(56,185), 20, Color("#d1c2a3"), 200, false, true)
	var roster_scroll := TouchScrollContainer.new()
	_place(canvas, roster_scroll, Rect2(68,224,188,280))
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_list = VBoxContainer.new()
	character_list.add_theme_constant_override("separation", 6)
	roster_scroll.add_child(character_list)
	name_label = _label(canvas, "", Vector2(424,181), 32, Color("#f0dfb7"), 300, true, true)
	name_label.size.y = 48
	_shadow(name_label)
	character_icon = _image(canvas, null, Rect2(462,349,224,224))
	character_icon.name = "CharacterSprite"
	hover_target = Button.new()
	hover_target.name = "CharacterHover"
	_place(canvas, hover_target, Rect2(524,358,108,210))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		hover_target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hover_target.add_theme_stylebox_override("focus", _focus_style())
	hover_target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hover_target.mouse_entered.connect(func(): _hovered = true; _update_walking())
	hover_target.mouse_exited.connect(func(): _hovered = false; _update_walking())
	hover_target.focus_entered.connect(func():
		_keyboard_focus = not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_update_walking()
	)
	hover_target.focus_exited.connect(func(): _keyboard_focus = false; _update_walking())
	hover_target.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			_keyboard_focus = false
			_update_walking()
	)
	_label(canvas, "出征档案", Vector2(876,183), 20, INK, 300, true)
	_paper_name = _label(canvas, "", Vector2(878,205), 18, MUTED, 320)
	_place(canvas, _rectangle_rule(), Rect2(878,236,320,2))
	# Fixed compact header; only the padded paper body scrolls.
	var dossier_body := MarginContainer.new()
	dossier_body.name = "DossierBody"
	_place(canvas, dossier_body, Rect2(878,234,334,324))
	dossier_body.add_theme_constant_override("margin_top", 12)
	dossier_body.add_theme_constant_override("margin_bottom", 12)
	details_scroll = TouchScrollContainer.new()
	details_scroll.name = "DossierScroll"
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_body.add_child(details_scroll)
	details_scroll.clip_contents = true
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_details = VBoxContainer.new()
	_details.custom_minimum_size.x = 320
	_details.add_theme_constant_override("separation", 0)
	details_scroll.add_child(_details)
	_body_label(_details, "开局属性", 18, MUTED, 26, true)
	stats_list = Control.new()
	_details.add_child(stats_list)
	_rule(_details)
	_spacer(_details, 7)
	_body_label(_details, "初始武器", 18, MUTED, 26, true)
	weapon_list = VBoxContainer.new()
	weapon_list.add_theme_constant_override("separation", 6)
	_details.add_child(weapon_list)
	_spacer(_details, 2)
	_body_label(_details, "角色特性", 18, MUTED, 24, true)
	passive_list = VBoxContainer.new()
	passive_list.add_theme_constant_override("separation", 6)
	_details.add_child(passive_list)
	description_label = Label.new()
	description_label.visible = false
	canvas.add_child(description_label)
	back_button = _button("返回主界面", "back_button.png", Vector2(196,50), 18)
	_place(canvas, back_button, Rect2(40,634,196,50))
	_navigation_content(back_button, false)
	confirm_button = _button("继续", "continue_button.png", Vector2(132,50), 18)
	_place(canvas, confirm_button, Rect2(1110,634,132,50))
	_navigation_content(confirm_button, true)
	_label(canvas, "难度", Vector2(318,641), 20, Color("#c7b89f"), 64)
	difficulty_list = HBoxContainer.new()
	difficulty_list.name = "DifficultyList"
	_place(canvas, difficulty_list, Rect2(392,625,224,64))
	difficulty_list.add_theme_constant_override("separation", 16)
	var difficulty_group := ButtonGroup.new()
	for index in BattleDifficulty.IDS.size():
		var id := BattleDifficulty.IDS[index]
		var button := _button(["I", "II", "III"][index], "difficulty_normal.png", Vector2(64,64), 25)
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.set_meta("difficulty_id", id)
		button.pressed.connect(func(): difficulty_selected.emit(id))
		difficulty_list.add_child(button)
	difficulty_title = _label(canvas, "", Vector2(646,630), 16, Color("#dccbae"), 430)
	difficulty_description = _label(canvas, "", Vector2(646,654), 14, Color("#bdb5a1"), 430)
	_shadow(difficulty_title)
	_shadow(difficulty_description)
	error_label = _label(canvas, "", Vector2(400,590), 18, Color("#ffc0a0"), 650, false, true)
	error_label.visible = false
	resized.connect(_fit_composition)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): reset_animation()
	)
	_fit_composition()
	set_difficulty(BattleDifficulty.DEFAULT_ID)


func _fit_composition() -> void:
	if canvas == null: return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = ((size - DESIGN_SIZE * factor) * 0.5).round()


func rebuild_roster(records: Array) -> String:
	_clear(character_list)
	var first := ""
	var group := ButtonGroup.new()
	for record in records:
		if not (record is Dictionary) or not record.get("enabled", true): continue
		var id := str(record.get("id", ""))
		if id.is_empty(): continue
		if first.is_empty(): first = id
		var button := _button("", "roster_normal.png", Vector2(176,40), 18)
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("character_id", id)
		button.tooltip_text = str(record.get("display_name", id))
		var label := _label(button, str(record.get("display_name", id)), Vector2(52,5), 18, CREAM, 120, true)
		label.name = "CharacterName"
		_image(button, _crop_icon(str(record.get("icon", ""))), Rect2(10,3,32,34), true)
		button.pressed.connect(func(): character_selected.emit(id))
		character_list.add_child(button)
	for index in maxi(0, 6-character_list.get_child_count()):
		var slot := _image(character_list, load(ART + "roster_empty.png"), Rect2(0,0,176,40))
		slot.custom_minimum_size = Vector2(176,40)
	return first


func show_character(record: Dictionary, stats: Dictionary) -> void:
	for container in [stats_list, weapon_list, passive_list]: _clear(container)
	reset_animation()
	if record.is_empty():
		name_label.text = "请选择角色"
		character_icon.texture = null
		return
	var display_name := str(record.get("display_name", record.get("id", "")))
	name_label.text = display_name
	_paper_name.text = display_name + (" / 初始角色" if record.get("tags", []).has("starter") else " / 可用角色")
	description_label.text = str(record.get("description", ""))
	var visuals: Dictionary = record.get("combat_visuals", {})
	_idle = load(str(visuals.get("idle", record.get("display_sprite", "")))) as Texture2D
	character_icon.texture = _idle
	_walk_frames = maxi(1, int(visuals.get("walk_frames", 1)))
	_walk_fps = maxf(1.0, float(visuals.get("walk_fps", 6.0)))
	_walk = AtlasTexture.new()
	_walk.atlas = load(str(visuals.get("walk", visuals.get("idle", "")))) as Texture2D
	_walk.region = Rect2(0,0,64,64)
	var stat_ids: Array = record.get("display_stats", ["max_hp", "move_speed", "load_capacity"])
	var names := {"max_hp":"生命", "move_speed":"移速", "load_capacity":"负载", "humanity":"理智", "divinity":"侵蚀", "finance":"本金", "currency_gain_percent":"金币", "damage_percent":"伤害", "interest_rate":"利率"}
	for index in stat_ids.size():
		var id := str(stat_ids[index])
		var row := Control.new()
		var column := index % 2
		_place(stats_list, row, Rect2(column*162, floori(index/2.0)*22, 158 if column else 128, 22))
		row.tooltip_text = StatDefinitions.get_display_name(id)
		_label(row, str(names.get(id, StatDefinitions.get_display_name(id))), Vector2(0,3), 14, INK, row.size.x)
		var number := _label(row, _number(float(stats.get(id, 0))) + ("%" if StatDefinitions.is_percent_stat(id) else ""), Vector2(0,3), 14, INK, row.size.x)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_list.custom_minimum_size.y = ceili(stat_ids.size()/2.0)*22
	for id in record.get("start_weapons", []):
		var weapon := DataRegistry.get_record("weapons", str(id))
		var card := Control.new()
		card.custom_minimum_size = Vector2(320,48)
		card.tooltip_text = str(weapon.get("description", ""))
		weapon_list.add_child(card)
		_image(card, _crop_icon(str(weapon.get("icon", ""))), Rect2(0,0,44,48), true)
		_label(card, str(weapon.get("display_name", id)), Vector2(62,5), 23, INK, 258, true)
	_build_traits(record)
	for button in character_list.get_children():
		if button is Button:
			var active := str(button.get_meta("character_id", "")) == str(record.id)
			_apply_skin(button, "roster_selected.png" if active else "roster_normal.png")
			button.set_pressed_no_signal(active)
	details_scroll.scroll_vertical = 0


func _build_traits(record: Dictionary) -> void:
	var traits: Array = record.get("traits", [])
	var relics: Array = record.get("start_relics", [])
	if traits.is_empty() and relics.is_empty() and record.get("passive_modifiers", []).is_empty():
		var label := _body_label(passive_list, "每级最大生命 +1", 20, INK, 28)
		label.tooltip_text = "每升一级，最大生命 +1，并回复 1 点生命。"
		return
	for trait_data in traits:
		var card := VBoxContainer.new()
		passive_list.add_child(card)
		_body_label(card, str(trait_data.title), 17, INK, 24, true)
		var body := _body_label(card, str(trait_data.description), 16, MUTED, 24)
		body.clip_text = false
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for passive in record.get("passive_modifiers", []):
		var label := _body_label(passive_list, str(passive.get("description", passive.get("stat", ""))), 16, INK, 26)
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if relics.is_empty(): return
	if traits.is_empty():
		_body_label(passive_list, "开局获得如下四件遗物" if relics.size() == 4 else "开局获得如下遗物", 18, INK, 26)
	var grid := GridContainer.new()
	grid.name = "StartingRelicIcons"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	passive_list.add_child(grid)
	for id in relics:
		var relic := DataRegistry.get_record("relics", str(id))
		var card := Control.new()
		card.custom_minimum_size = Vector2(40,40)
		card.tooltip_text = "%s\n%s\n角色固有，开局奖励仅发放一次，不可移除。" % [relic.display_name, relic.description]
		grid.add_child(card)
		_image(card, _crop_icon(str(relic.get("icon", ""))), Rect2(4,4,32,32), true)


func set_difficulty(id: String) -> void:
	id = BattleDifficulty.normalize(id)
	var profile := BattleDifficulty.get_profile(id)
	difficulty_title.text = str(profile.title)
	difficulty_description.text = str(profile.description) if not str(profile.description).is_empty() else "基础怪物属性 · 常规数量"
	for button in difficulty_list.get_children():
		var active := str(button.get_meta("difficulty_id", "")) == id
		button.set_pressed_no_signal(active)
		_apply_skin(button, "difficulty_selected.png" if active else "difficulty_normal.png")


func reset_animation() -> void:
	_hovered = false
	_keyboard_focus = false
	walking = false
	_elapsed = 0.0
	walk_frame = 0
	if character_icon != null: character_icon.texture = _idle


func _update_walking() -> void:
	var active := (_hovered or _keyboard_focus) and is_visible_in_tree() and _walk != null
	if active == walking: return
	walking = active
	_elapsed = 0.0
	walk_frame = 0
	if walking:
		_walk.region = Rect2(0,0,64,64)
		character_icon.texture = _walk
	else:
		character_icon.texture = _idle


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset_animation()


func _process(delta: float) -> void:
	if not walking: return
	_elapsed += delta
	walk_frame = int(_elapsed * _walk_fps) % _walk_frames
	_walk.region = Rect2(walk_frame*64,0,64,64)


func _place(parent: Node, control: Control, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size


func _image(parent: Node, texture: Texture2D, rect: Rect2, keep_aspect := false) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(parent, image, rect)
	return image


func _crop_icon(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path): return null
	if _cropped_icons.has(path): return _cropped_icons[path]
	var texture := load(path) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(texture.get_image().get_used_rect())
	_cropped_icons[path] = atlas
	return atlas


func _label(parent: Node, value: String, at: Vector2, pixels: int, color: Color, width := 320.0, bold := false, centered := false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _bold_font if bold else _font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	_place(parent, label, Rect2(at, Vector2(width, pixels+10)))
	return label


func _body_label(parent: Node, value: String, pixels: int, color: Color, height: float, bold := false) -> Label:
	var label := _label(parent, value, Vector2.ZERO, pixels, color, 320, bold)
	label.custom_minimum_size = Vector2(320,height)
	return label


func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("#17141b"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _button(value: String, texture_name: String, minimum: Vector2, pixels: int) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", pixels)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_hover_pressed_color", Color("#ffedc9"))
	button.add_theme_color_override("font_hover_color", Color("#ffedc9"))
	button.add_theme_stylebox_override("focus", _focus_style())
	_apply_skin(button, texture_name)
	return button


func _apply_skin(button: Button, texture_name: String) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = load(ART + texture_name)
		style.modulate_color = Color(1.14,1.10,1.06) if state in ["hover", "hover_pressed"] else (Color(0.55,0.55,0.55) if state == "disabled" else Color.WHITE)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, 0)
		button.add_theme_stylebox_override(state, style)


func _navigation_content(button: Button, points_right: bool) -> void:
	# Native Button layout keeps both icon and text inside the painted border.
	var arrow := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	arrow.fill(Color.TRANSPARENT)
	for y in 11:
		for x in range(absi(5-y), 6):
			arrow.set_pixel(6-x if points_right else x+1, y, CREAM)
	button.icon = ImageTexture.create_from_image(arrow)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if points_right else HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("h_separation", 10)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		style.set_content_margin(SIDE_LEFT, 24)
		style.set_content_margin(SIDE_RIGHT, 24)
		style.set_content_margin(SIDE_TOP, 8)
		style.set_content_margin(SIDE_BOTTOM, 8)


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("#c0a5c7")
	style.set_border_width_all(2)
	return style


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _spacer(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _rectangle_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color("#92714f")
	rule.custom_minimum_size = Vector2(320,2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _rule(parent: Node) -> void:
	parent.add_child(_rectangle_rule())


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
