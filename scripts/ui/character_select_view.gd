extends Control
class_name CharacterSelectView
## Approved basement r5: 688x384 scene grid, original-resolution UI frames.

signal character_selected(character_id: String)
signal difficulty_selected(difficulty_id: String)

const ART := "res://assets/ui/character_select/"
const DESIGN_SIZE := Vector2(2752, 1536)
const INK := Color("#43313d")
const MUTED := INK
const CREAM := Color("#c4a787")
const PAPER_WIDTH := 464.0
const FOOT_ANCHOR := Vector2(1380, 1148)
const STARTING_WEAPON_ICON_SIZE := Vector2(62, 68)
const STARTING_ENCHANTMENT_ICON_SIZE := Vector2(36, 36)
const BREATH_PERIOD := 3.0
const BREATH_STRETCH := 0.025
const BREATH_SHADER := preload("res://assets/shaders/character_select_breathing.gdshader")

var canvas: Control
var background: TextureRect
var character_list: VBoxContainer
var roster_scroll: ScrollContainer
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
var _font: FontFile
var _bold_font: FontFile
var _idle: Texture2D
var _walk: AtlasTexture
var _walk_frames := 1
var _walk_fps := 6.0
var _elapsed := 0.0
var _breath_elapsed := 0.0
var _character_rest_position := Vector2.ZERO
var _breath_material: ShaderMaterial
var _hovered := false
var _keyboard_focus := false
var walking := false
var walk_frame := 0
var _cropped_icons: Dictionary = {}
var _item_tooltip: Panel
var _item_tooltip_label: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf").duplicate() as FontFile
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_bold_font = _font
	_build_item_tooltip()
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
	_label(canvas, "ui.character.roster", Vector2(128,236), 34, CREAM, 288)
	roster_scroll = TouchScrollContainer.new()
	roster_scroll.name = "RosterScroll"
	# 336px cards, then an 8px gap and an 8px scrollbar in the frame padding.
	_place(canvas, roster_scroll, Rect2(104,316,352,856))
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	roster_scroll.follow_focus = true
	_style_scrollbar(roster_scroll)
	character_list = VBoxContainer.new()
	character_list.custom_minimum_size.x = 336
	character_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	character_list.add_theme_constant_override("separation", 14)
	roster_scroll.add_child(character_list)
	name_label = _label(canvas, "", Vector2.ZERO, 48, CREAM, 400, false, true)
	name_label.size.y = 72
	_shadow(name_label)
	_image(canvas, load(ART + "character_shadow.png"), Rect2(1228,1136,308,24))
	character_icon = _image(canvas, null, Rect2(1148,728,463,463))
	character_icon.name = "CharacterSprite"
	_breath_material = ShaderMaterial.new()
	_breath_material.shader = BREATH_SHADER
	character_icon.material = _breath_material
	hover_target = Button.new()
	hover_target.name = "CharacterHover"
	_place(canvas, hover_target, Rect2(1148,691,463,500))
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
	_label(canvas, "ui.character.profile", Vector2(2180,300), 34, INK, PAPER_WIDTH)
	_paper_name = _label(canvas, "", Vector2(2180,357), 29, INK, PAPER_WIDTH)
	_place(canvas, _rectangle_rule(), Rect2(2176,410,PAPER_WIDTH,2))
	# Fixed compact header; only the padded paper body scrolls.
	var dossier_body := MarginContainer.new()
	dossier_body.name = "DossierBody"
	_place(canvas, dossier_body, Rect2(2180,432,480,824))
	dossier_body.add_theme_constant_override("margin_top", 6)
	dossier_body.add_theme_constant_override("margin_bottom", 6)
	details_scroll = TouchScrollContainer.new()
	details_scroll.name = "DossierScroll"
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_body.add_child(details_scroll)
	details_scroll.clip_contents = true
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_style_scrollbar(details_scroll)
	details_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): _hide_item_tooltip())
	_details = VBoxContainer.new()
	_details.custom_minimum_size.x = PAPER_WIDTH
	_details.add_theme_constant_override("separation", 0)
	details_scroll.add_child(_details)
	_body_label(_details, "ui.character.starting_stats", 34, INK, 76)
	stats_list = Control.new()
	_details.add_child(stats_list)
	_spacer(_details, 30)
	_body_label(_details, "ui.character.traits", 34, INK, 80)
	passive_list = VBoxContainer.new()
	passive_list.add_theme_constant_override("separation", 4)
	_details.add_child(passive_list)
	_spacer(_details, 20)
	_body_label(_details, "ui.character.starting_weapon", 34, INK, 60)
	weapon_list = VBoxContainer.new()
	weapon_list.add_theme_constant_override("separation", 6)
	_details.add_child(weapon_list)
	description_label = Label.new()
	description_label.visible = false
	canvas.add_child(description_label)
	back_button = _button("", "back_button.png", Vector2(224,92), 34)
	_place(canvas, back_button, Rect2(92,1372,224,92))
	_navigation_content(back_button, false)
	confirm_button = _button("", "continue_button.png", Vector2(224,92), 34)
	_place(canvas, confirm_button, Rect2(2472,1372,224,92))
	_navigation_content(confirm_button, true)
	_shadow(_label(canvas, "ui.character.difficulty", Vector2(620,1392), 34, CREAM, 220))
	difficulty_list = HBoxContainer.new()
	difficulty_list.name = "DifficultyList"
	_place(canvas, difficulty_list, Rect2(872,1352,448,128))
	difficulty_list.add_theme_constant_override("separation", 32)
	var difficulty_group := ButtonGroup.new()
	for index in BattleDifficulty.IDS.size():
		var id := BattleDifficulty.IDS[index]
		var button := _button(["I", "II", "III"][index], "difficulty_normal.png", Vector2(128,128), 48)
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.set_meta("difficulty_id", id)
		button.pressed.connect(func(): difficulty_selected.emit(id))
		difficulty_list.add_child(button)
	difficulty_title = _label(canvas, "", Vector2(1400,1364), 34, CREAM, 800)
	difficulty_description = _label(canvas, "", Vector2(1400,1420), 29, CREAM, 800)
	_shadow(difficulty_title)
	_shadow(difficulty_description)
	error_label = _label(canvas, "", Vector2(600,1260), 34, Color("#ffc0a0"), 1400, false, true)
	error_label.visible = false
	resized.connect(_fit_composition)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): reset_animation()
	)
	_fit_composition()
	set_difficulty(BattleDifficulty.DEFAULT_ID)


func _fit_composition() -> void:
	_hide_item_tooltip()
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
		var button := _button("", "roster_normal.png", Vector2(336,91), 29)
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("character_id", id)
		button.tooltip_text = L10n.source(str(record.get("display_name", id)))
		var label := _label(button, L10n.source(str(record.get("display_name", id))), Vector2(88,0), 29, CREAM, 234)
		label.name = "CharacterName"
		label.size.y = 91
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_image(button, _crop_icon(str(record.get("icon", ""))), Rect2(14,14,62,62), true)
		button.pressed.connect(func(): character_selected.emit(id))
		character_list.add_child(button)
	roster_scroll.scroll_vertical = 0
	# Refresh the range after the VBox recalculates when the roster shrinks.
	roster_scroll.queue_sort.call_deferred()
	return first


func show_character(record: Dictionary, stats: Dictionary) -> void:
	_hide_item_tooltip()
	for container in [stats_list, weapon_list, passive_list]: _clear(container)
	reset_animation()
	if record.is_empty():
		name_label.text = "ui.character.select_prompt"
		character_icon.texture = null
		return
	var display_name := L10n.source(str(record.get("display_name", record.get("id", ""))))
	name_label.text = display_name
	_paper_name.text = display_name
	description_label.text = L10n.source(str(record.get("description", "")))
	var visuals: Dictionary = record.get("combat_visuals", {})
	_idle = load(str(visuals.get("idle", record.get("display_sprite", "")))) as Texture2D
	character_icon.texture = _idle
	_position_character()
	_walk_frames = maxi(1, int(visuals.get("walk_frames", 1)))
	_walk_fps = maxf(1.0, float(visuals.get("walk_fps", 6.0)))
	_walk = AtlasTexture.new()
	_walk.atlas = load(str(visuals.get("walk", visuals.get("idle", "")))) as Texture2D
	_walk.region = Rect2(0,0,64,64)
	var stat_ids: Array = record.get("display_stats", ["max_hp", "move_speed", "load_capacity"])
	var names := {"max_hp":L10n.text("stat.health.short_name"), "move_speed":L10n.text("stat.move_speed.short_name"), "load_capacity":L10n.text("stat.load.short_name"), "humanity":L10n.text("stat.humanity.name"), "divinity":L10n.text("stat.divinity.short_name"), "finance":L10n.text("stat.principal.short_name"), "currency_gain_percent":L10n.text("stat.gold.name"), "damage_percent":L10n.text("stat.damage.name"), "interest_rate":L10n.text("stat.interest_rate.name")}
	var row_height := _compact_text_height(29, 48)
	for index in stat_ids.size():
		var id := str(stat_ids[index])
		var row := Control.new()
		_place(stats_list, row, Rect2(0,index*row_height,PAPER_WIDTH,row_height))
		row.tooltip_text = StatDefinitions.get_display_name(id)
		_label(row, L10n.source(str(names.get(id, StatDefinitions.get_display_name(id)))), Vector2.ZERO, 29, INK, 270)
		var number := _label(row, _number(float(stats.get(id, 0))) + ("%" if StatDefinitions.is_percent_stat(id) else ""), Vector2.ZERO, 29, INK, 380)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for label in row.get_children():
			label.size.y = row_height
	stats_list.custom_minimum_size = Vector2(PAPER_WIDTH,stat_ids.size()*row_height)
	for id in record.get("start_weapons", []):
		_build_starting_weapon(record, str(id))
	_build_traits(record)
	for button in character_list.get_children():
		if button is Button:
			var active := str(button.get_meta("character_id", "")) == str(record.id)
			_apply_skin(button, "roster_selected.png" if active else "roster_normal.png")
			button.set_pressed_no_signal(active)
	details_scroll.scroll_vertical = 0
	details_scroll.queue_sort.call_deferred()


func _build_starting_weapon(record: Dictionary, weapon_id: String) -> void:
	var weapon := DataRegistry.get_record("weapons", weapon_id)
	var card := HBoxContainer.new()
	card.set_meta("weapon_id", weapon_id)
	card.custom_minimum_size = Vector2(PAPER_WIDTH, STARTING_WEAPON_ICON_SIZE.y)
	card.add_theme_constant_override("separation", 11)
	_bind_item_tooltip(card, "%s\n%s" % [L10n.source(weapon.get("display_name", weapon_id)), L10n.source(weapon.get("description", ""))])
	weapon_list.add_child(card)
	var weapon_icon := _image(card, _crop_icon(str(weapon.get("icon", ""))), Rect2(Vector2.ZERO, STARTING_WEAPON_ICON_SIZE), true)
	weapon_icon.name = "WeaponIcon"
	weapon_icon.custom_minimum_size = STARTING_WEAPON_ICON_SIZE
	weapon_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Wrap additional enchantments within the paper, beside their own weapon.
	var content := HFlowContainer.new()
	content.name = "WeaponContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("h_separation", 10)
	content.add_theme_constant_override("v_separation", 4)
	card.add_child(content)
	var title := _label(content, L10n.source(str(weapon.get("display_name", weapon_id))), Vector2.ZERO, 29, INK, 0)
	title.clip_text = false
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for attachment in record.get("start_weapon_attachments", []):
		if not (attachment is Dictionary) or str(attachment.get("weapon_id", "")) != weapon_id:
			continue
		var item_id := str(attachment.get("item_id", ""))
		var item := DataRegistry.get_record("augmentations", item_id)
		var texture := _crop_icon(str(item.get("icon", "")))
		if texture == null: continue
		var icon := _image(content, texture, Rect2(Vector2.ZERO, STARTING_ENCHANTMENT_ICON_SIZE), true)
		icon.set_meta("enchantment_id", item_id)
		icon.custom_minimum_size = STARTING_ENCHANTMENT_ICON_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		_bind_item_tooltip(icon, "%s\n%s" % [L10n.source(item.get("display_name", item_id)), L10n.source(item.get("description", ""))])


func _build_traits(record: Dictionary) -> void:
	var traits: Array = record.get("traits", [])
	var relics: Array = record.get("start_relics", [])
	var no_health_growth := int(record.get("max_hp_per_level", 0)) == 0
	if not bool(record.get("manual_withdrawal_allowed", true)):
		_body_label(passive_list, "ui.character.no_withdrawal", 29, INK, 40)
	if traits.is_empty() and relics.is_empty() and record.get("passive_modifiers", []).is_empty():
		if not no_health_growth:
			_body_label(passive_list, "ui.character.health_per_level", 29, INK, 40)
		return
	for trait_data in traits:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		passive_list.add_child(card)
		_body_label(card, str(trait_data.title), 34, INK, 48)
		var body := _body_label(card, L10n.source(str(trait_data.description)), 29, INK, 40)
		body.clip_text = false
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for passive in record.get("passive_modifiers", []):
		var label := _body_label(passive_list, L10n.source(str(passive.get("description", passive.get("stat", "")))), 29, INK, 40)
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if relics.is_empty(): return
	if traits.is_empty():
		_body_label(passive_list, "ui.character.four_starting_relics" if relics.size() == 4 else "开局获得如下遗物", 29, INK, 40)
	var grid := GridContainer.new()
	grid.name = "StartingRelicIcons"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	passive_list.add_child(grid)
	for id in relics:
		var relic := DataRegistry.get_record("relics", str(id))
		var card := Control.new()
		card.custom_minimum_size = Vector2(72,72)
		_bind_item_tooltip(card, L10n.text("ui.character.innate_relic_tooltip") % [L10n.source(relic.display_name), L10n.source(relic.description)])
		grid.add_child(card)
		_image(card, _crop_icon(str(relic.get("icon", ""))), Rect2(4,4,64,64), true)


func _build_item_tooltip() -> void:
	_item_tooltip = Panel.new()
	_item_tooltip.name = "ItemTooltip"
	_item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14201dfc")
	style.border_color = Color("8c9274")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_item_tooltip.add_theme_stylebox_override("panel", style)
	_item_tooltip_label = Label.new()
	_item_tooltip_label.position = Vector2(10, 10)
	_item_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_tooltip_label.add_theme_font_override("font", _font)
	_item_tooltip_label.add_theme_font_size_override("font_size", 16)
	_item_tooltip_label.add_theme_color_override("font_color", Color("f1e6d2"))
	_item_tooltip.add_child(_item_tooltip_label)
	GameTooltipLayer.for_owner(self).add_child(_item_tooltip)
	_item_tooltip.hide()


func _bind_item_tooltip(anchor: Control, text: String) -> void:
	# Use viewport-space hover signals, without the native tooltip delay.
	anchor.mouse_entered.connect(_show_item_tooltip.bind(anchor, text))
	anchor.mouse_exited.connect(_hide_item_tooltip)


func _show_item_tooltip(anchor: Control, text: String) -> void:
	if text.is_empty() or not anchor.is_visible_in_tree(): return
	var viewport_size := get_viewport_rect().size
	var width := minf(320.0, viewport_size.x - 40.0)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, _font, 16)
	_item_tooltip_label.size.x = width
	_item_tooltip_label.text = text
	# Size before showing, so the first frame wraps and clamps correctly.
	var height := paragraph.get_size().y + maxf(0, paragraph.get_line_count() - 1) * _item_tooltip_label.get_theme_constant("line_spacing")
	_item_tooltip_label.custom_minimum_size = Vector2(width, height)
	_item_tooltip_label.size = Vector2(width, height)
	_item_tooltip.size = Vector2(width + 20, height + 20)
	var bounds := anchor.get_global_rect()
	var point := Vector2(bounds.position.x - _item_tooltip.size.x - 10, bounds.position.y)
	point.x = clampf(point.x, 10, maxf(10, viewport_size.x - _item_tooltip.size.x - 10))
	point.y = clampf(point.y, 10, maxf(10, viewport_size.y - _item_tooltip.size.y - 10))
	_item_tooltip.position = point.round()
	_item_tooltip.show()


func _hide_item_tooltip() -> void:
	if _item_tooltip != null: _item_tooltip.hide()


func _position_character() -> void:
	if _idle == null: return
	var used := _idle.get_image().get_used_rect()
	_breath_material.set_shader_parameter("foot_y", float(used.end.y) / _idle.get_height())
	# Size from idle once; every animation frame retains the same 64px canvas.
	var side := roundf(64.0 * 376.0 / maxf(1.0, used.size.y))
	character_icon.size = Vector2.ONE * side
	character_icon.position = FOOT_ANCHOR - (Vector2(32,58) * side / 64.0).round()
	_character_rest_position = character_icon.position
	var name_y := character_icon.position.y + roundf(used.position.y * side / 64.0) - 80
	name_label.position = Vector2(FOOT_ANCHOR.x - name_label.size.x / 2.0, name_y)
	hover_target.position = Vector2(character_icon.position.x, name_y)
	hover_target.size = Vector2(side, character_icon.position.y + side - name_y)


func set_difficulty(id: String) -> void:
	id = BattleDifficulty.normalize(id)
	var profile := BattleDifficulty.get_profile(id)
	difficulty_title.text = str(profile.title)
	difficulty_description.text = L10n.source(str(profile.description)) if not L10n.source(str(profile.description)).is_empty() else "difficulty.normal.summary"
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
	_reset_breathing()
	if character_icon != null: character_icon.texture = _idle


func _reset_breathing() -> void:
	_breath_elapsed = 0.0
	if _breath_material != null: _breath_material.set_shader_parameter("breath_amount", 0.0)
	if character_icon != null: character_icon.position = _character_rest_position


func _update_walking() -> void:
	var active := (_hovered or _keyboard_focus) and is_visible_in_tree() and _walk != null
	if active == walking: return
	walking = active
	_reset_breathing()
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
	if not is_visible_in_tree() or _idle == null: return
	if not walking:
		_breath_elapsed = fmod(_breath_elapsed + delta, BREATH_PERIOD)
		_breath_material.set_shader_parameter("breath_amount", BREATH_STRETCH * sin(TAU * _breath_elapsed / BREATH_PERIOD))
		return
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


func _label(parent: Node, value: String, at: Vector2, pixels: int, color: Color, width := PAPER_WIDTH, bold := false, centered := false) -> Label:
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
	var label := _label(parent, value, Vector2.ZERO, pixels, color, PAPER_WIDTH, bold)
	label.custom_minimum_size = Vector2(PAPER_WIDTH,_compact_text_height(pixels, height))
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _compact_text_height(pixels: int, previous_height: float) -> float:
	# Halve only the whitespace; retain the full font line height.
	var text_height := _font.get_height(pixels)
	return ceilf(text_height + maxf(0.0, previous_height - text_height) * 0.5)


func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("#161119"))
	label.add_theme_constant_override("shadow_offset_x", 2)
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
	var content := HBoxContainer.new()
	content.name = "NavigationContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var words := [L10n.text("ui.common.continue"), "▶"] if points_right else ["◀", L10n.text("ui.common.back")]
	for word in words:
		var is_arrow: bool = word in ["◀", "▶"]
		var label := _label(content, word, Vector2.ZERO, 29 if is_arrow else 34, CREAM, 0)
		label.clip_text = false
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if is_arrow:
			var symbols := SystemFont.new()
			symbols.font_names = PackedStringArray(["Segoe UI Symbol", "sans-serif"])
			symbols.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			label.add_theme_font_override("font", symbols)


func _style_scrollbar(scroll: ScrollContainer) -> void:
	scroll.add_theme_constant_override("h_separation", 8)
	var bar := scroll.get_v_scroll_bar()
	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#161119") if state == "scroll" else Color("#b09174")
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 24 if state != "scroll" else 0
		style.content_margin_bottom = 24 if state != "scroll" else 0
		bar.add_theme_stylebox_override(state, style)
	for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(icon_name, ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8)))


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
	rule.color = Color("#b09174")
	rule.custom_minimum_size = Vector2(PAPER_WIDTH,2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _rule(parent: Node) -> void:
	parent.add_child(_rectangle_rule())


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
