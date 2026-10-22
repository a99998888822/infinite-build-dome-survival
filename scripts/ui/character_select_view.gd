extends Control
class_name CharacterSelectView
## Approved basement composition, laid out directly on the 1920 x 1080 canvas.

signal character_selected(character_id: String)
signal difficulty_selected(difficulty_id: String)

const ART := "res://assets/ui/character_select/"
const DESIGN_SIZE := Vector2(1920, 1080)
const ART_SIZE := Vector2(1920, 1080) # Native 960 x 540 background at exactly 2x.
const ART_PIXEL_PITCH := 0.697674419
const INK := Color("#43313d")
const MUTED := INK
const CREAM := Color("#c4a787")
const PAPER_WIDTH := 323.720930
const FOOT_ANCHOR := Vector2(962.790698, 800.930233)
const STARTING_WEAPON_ICON_SIZE := Vector2(36, 36)
const STARTING_ENCHANTMENT_ICON_SIZE := Vector2(32, 32)
const BREATH_PERIOD := 3.0
const BREATH_STRETCH := 0.025
const NOVICE_PREVIEW_SIZE := Vector2(288, 288)
const BREATH_SHADER := preload("res://assets/shaders/character_select_breathing.gdshader")
const ROSTER_ART := preload("res://scripts/ui/character_roster_art.gd")
const ROSTER_CARD_SIZE := Vector2(234.418605, 63.488372)
const LOCKED_COLOR := Color("a5a0a7")
const RELEASE_PLACEHOLDER_COUNT := 12

var canvas: Control
var background: TextureRect
var character_list: NativeHudBox
var roster_scroll: ScrollContainer
var stats_list: Control
var weapon_list: NativeHudBox
var passive_list: NativeHudBox
var difficulty_list: NativeHudBox
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
var _details: NativeHudBox
var _font: FontFile
var _bold_font: FontFile
var _idle: Texture2D
var _walk: AtlasTexture
var _walk_frames := 1
var _walk_frame_size := Vector2.ONE
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
var _gray_roster_skins: Dictionary = {}
var _item_tooltip: Panel
var _item_tooltip_label: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = preload("res://assets/font/native_hud/character.res")
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
	background = _image(canvas, load(ART + "background.png"), Rect2(Vector2.ZERO, ART_SIZE))
	background.name = "Background"
	_label(canvas, "ui.character.roster", Vector2(89.302326,164.651163), 24, CREAM, 201)
	roster_scroll = TouchScrollContainer.new()
	roster_scroll.name = "RosterScroll"
	roster_scroll.mouse_drag_enabled = true
	# All cards share the novice frame; the scrollbar stays in its padding.
	_place(canvas, roster_scroll, Rect2(72.55814,220.465116,245.581395,597.209302))
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	roster_scroll.follow_focus = true
	_style_scrollbar(roster_scroll)
	character_list = NativeHudBox.column(2.790698)
	character_list.custom_minimum_size.x = 234.418605
	character_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	character_list.separation = 9.767442
	roster_scroll.add_child(character_list)
	character_list.bind_scroll(roster_scroll)
	name_label = _label(canvas, "", Vector2.ZERO, 33, CREAM, 279, false, true)
	name_label.size.y = 50.232558
	_shadow(name_label)
	_image(canvas, load(ART + "character_shadow.png"), Rect2(856.744186,792.55814,214.883721,16.744186))
	character_icon = _image(canvas, null, Rect2(800.930233,507.906977,323.023256,323.023256))
	character_icon.name = "CharacterSprite"
	_breath_material = ShaderMaterial.new()
	_breath_material.shader = BREATH_SHADER
	character_icon.material = _breath_material
	hover_target = Button.new()
	hover_target.name = "CharacterHover"
	_place(canvas, hover_target, Rect2(800.930233,482.093023,323.023256,348.837209))
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
	_label(canvas, "ui.character.profile", Vector2(1520.930233,209.302326), 24, INK, PAPER_WIDTH)
	_paper_name = _label(canvas, "", Vector2(1520.930233,249.069767), 20, INK, PAPER_WIDTH)
	_place(canvas, _rectangle_rule(), Rect2(1518.139535,286.046512,PAPER_WIDTH,1.395349))
	# Fixed compact header; only the padded paper body scrolls.
	var dossier_body := MarginContainer.new()
	dossier_body.name = "DossierBody"
	_place(canvas, dossier_body, Rect2(1520.930233,301.395349,334.883721,574.883721))
	dossier_body.add_theme_constant_override("margin_top", 4)
	dossier_body.add_theme_constant_override("margin_bottom", 4)
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
	_details = NativeHudBox.column(2.790698)
	_details.custom_minimum_size.x = PAPER_WIDTH
	_details.separation = 0.000000
	details_scroll.add_child(_details)
	_details.bind_scroll(details_scroll)
	_body_label(_details, "ui.character.starting_stats", 24, INK, 53)
	stats_list = Control.new()
	_details.add_child(stats_list)
	_spacer(_details, 21)
	_body_label(_details, "ui.character.traits", 24, INK, 56)
	passive_list = NativeHudBox.column(2.790698)
	passive_list.separation = 2.790698
	_details.add_child(passive_list)
	_spacer(_details, 14)
	_body_label(_details, "ui.character.starting_weapon", 24, INK, 42)
	weapon_list = NativeHudBox.column(2.790698)
	weapon_list.separation = 4.186047
	_details.add_child(weapon_list)
	description_label = Label.new()
	description_label.visible = false
	canvas.add_child(description_label)
	back_button = _button("", "back_button.png", Vector2(156.27907,64.186047), 24)
	_place(canvas, back_button, Rect2(64.186047,957.209302,156.27907,64.186047))
	_navigation_content(back_button, false)
	confirm_button = _button("", "continue_button.png", Vector2(156.27907,64.186047), 24)
	_place(canvas, confirm_button, Rect2(1724.651163,957.209302,156.27907,64.186047))
	_navigation_content(confirm_button, true)
	_shadow(_label(canvas, "ui.character.difficulty", Vector2(432.55814,971.162791), 24, CREAM, 153))
	difficulty_list = NativeHudBox.horizontal(2.790698)
	difficulty_list.name = "DifficultyList"
	_place(canvas, difficulty_list, Rect2(608.372093,943.255814,312.55814,89.302326))
	difficulty_list.separation = 22.325581
	var difficulty_group := ButtonGroup.new()
	for index in BattleDifficulty.IDS.size():
		var id := BattleDifficulty.IDS[index]
		var button := _button(["I", "II", "III"][index], "difficulty_normal.png", Vector2(89.302326,89.302326), 33)
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.set_meta("difficulty_id", id)
		button.pressed.connect(func(): difficulty_selected.emit(id))
		difficulty_list.add_child(button)
	difficulty_title = _label(canvas, "", Vector2(976.744186,951.627907), 24, CREAM, 558)
	difficulty_description = _label(canvas, "", Vector2(976.744186,990.697674), 20, CREAM, 558)
	_shadow(difficulty_title)
	_shadow(difficulty_description)
	error_label = _label(canvas, "", Vector2(418.604651,879.069767), 24, Color("#ffc0a0"), 977, false, true)
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
	canvas.position = (size - DESIGN_SIZE) * 0.5
	ItemIconArt.refresh_branch(canvas)


func rebuild_roster(records: Array) -> String:
	_clear(character_list)
	var first := ""
	var group := ButtonGroup.new()
	for record in records:
		if not (record is Dictionary) or not record.get("enabled", true): continue
		var id := str(record.get("id", ""))
		if id.is_empty(): continue
		var locked := bool(record.get("release_locked", false))
		if first.is_empty() and not locked: first = id
		var portrait := _crop_icon(str(record.get("icon", "")))
		if locked and portrait != null: portrait = ROSTER_ART.gray(portrait, 0.8)
		var button := _roster_card(L10n.source(str(record.get("display_name", id))), portrait)
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("character_id", id)
		button.set_meta("release_locked", locked)
		button.tooltip_text = L10n.source(str(record.get("display_name", id)))
		if locked:
			button.get_node("CharacterName").add_theme_color_override("font_color", LOCKED_COLOR)
			_apply_skin(button, "roster_normal.png")
		button.pressed.connect(func(): character_selected.emit(id))
	for index in RELEASE_PLACEHOLDER_COUNT:
		var button := _roster_card("ui.character.release_locked", ROSTER_ART.silhouette(index))
		button.name = "ReleaseCharacter%02d" % (index + 1)
		button.set_meta("release_placeholder", true)
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.get_node("CharacterName").add_theme_color_override("font_color", LOCKED_COLOR)
		# A locked slot uses the exact normal novice frame, without a dim overlay.
		button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("normal"))
	roster_scroll.scroll_vertical = 0
	# Refresh the range after the VBox recalculates when the roster shrinks.
	roster_scroll.queue_sort.call_deferred()
	return first


func _roster_card(title: String, portrait: Texture2D) -> Button:
	var button := _button("", "roster_normal.png", ROSTER_CARD_SIZE, 20)
	var label := _label(button, title, Vector2(61.395349, 0), 20, CREAM, 163)
	label.name = "CharacterName"
	label.size.y = ROSTER_CARD_SIZE.y
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var icon := _image(button, portrait, Rect2(9.767442, 9.767442, 43.255814, 43.255814), true)
	icon.name = "Portrait"
	character_list.add_child(button)
	return button


func show_character(record: Dictionary, stats: Dictionary) -> void:
	_hide_item_tooltip()
	for container in [stats_list, weapon_list, passive_list]: _clear(container)
	reset_animation()
	_breath_material.set_shader_parameter("release_locked", bool(record.get("release_locked", false)))
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
	_walk_frame_size = Vector2(_walk.atlas.get_width() / _walk_frames, _walk.atlas.get_height())
	_walk.region = Rect2(Vector2.ZERO, _walk_frame_size)
	var stat_ids: Array = record.get("display_stats", ["max_hp", "move_speed", "load_capacity"])
	var names := {"max_hp":L10n.text("stat.health.short_name"), "move_speed":L10n.text("stat.move_speed.short_name"), "load_capacity":L10n.text("stat.load.short_name"), "humanity":L10n.text("stat.humanity.name"), "divinity":L10n.text("stat.divinity.short_name"), "finance":L10n.text("stat.principal.short_name"), "currency_gain_percent":L10n.text("stat.gold.name"), "damage_percent":L10n.text("stat.damage.name"), "interest_rate":L10n.text("stat.interest_rate.name")}
	var row_height := _compact_text_height(20, 33)
	for index in stat_ids.size():
		var id := str(stat_ids[index])
		var row := Control.new()
		_place(stats_list, row, Rect2(0,index*row_height,PAPER_WIDTH,row_height))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label(row, L10n.source(str(names.get(id, StatDefinitions.get_display_name(id)))), Vector2.ZERO, 20, INK, 188)
		var number := _label(row, _number(float(stats.get(id, 0))) + ("%" if StatDefinitions.is_percent_stat(id) else ""), Vector2.ZERO, 20, INK, 265)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for label in row.get_children():
			label.size.y = row_height
	stats_list.custom_minimum_size = Vector2(PAPER_WIDTH,stat_ids.size()*row_height)
	for id in record.get("start_weapons", []):
		_build_starting_weapon(record, str(id))
	_build_traits(record)
	for button in character_list.get_children():
		if button is Button and not button.get_meta("release_placeholder", false):
			var active := str(button.get_meta("character_id", "")) == str(record.id)
			_apply_skin(button, "roster_selected.png" if active else "roster_normal.png")
			button.set_pressed_no_signal(active)
	details_scroll.scroll_vertical = 0
	details_scroll.queue_sort.call_deferred()


func _build_starting_weapon(record: Dictionary, weapon_id: String) -> void:
	var weapon := DataRegistry.get_record("weapons", weapon_id)
	var card := NativeHudBox.horizontal(2.790698)
	card.set_meta("weapon_id", weapon_id)
	card.custom_minimum_size = Vector2(PAPER_WIDTH, STARTING_WEAPON_ICON_SIZE.y)
	card.separation = 7.674419
	_bind_item_tooltip(card, "%s\n%s" % [L10n.source(weapon.get("display_name", weapon_id)), L10n.source(weapon.get("description", ""))])
	weapon_list.add_child(card)
	var source := FinanceUIStyle.item_icon(str(weapon.get("icon", "")))
	var weapon_icon := _image(card, source, Rect2(Vector2.ZERO, STARTING_WEAPON_ICON_SIZE), true)
	weapon_icon.name = "WeaponIcon"
	weapon_icon.custom_minimum_size = STARTING_WEAPON_ICON_SIZE
	weapon_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ItemIconArt.bind_texture(weapon_icon, source, true, 36.0, null, STARTING_WEAPON_ICON_SIZE.x)
	# Wrap additional enchantments within the paper, beside their own weapon.
	var content := HFlowContainer.new()
	content.name = "WeaponContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("h_separation", 7)
	content.add_theme_constant_override("v_separation", 3)
	card.add_child(content)
	var title := _label(content, L10n.source(str(weapon.get("display_name", weapon_id))), Vector2.ZERO, 20, INK, 0)
	title.clip_text = false
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for attachment in record.get("start_weapon_attachments", []):
		if not (attachment is Dictionary) or str(attachment.get("weapon_id", "")) != weapon_id:
			continue
		var item_id := str(attachment.get("item_id", ""))
		var item := DataRegistry.get_record("augmentations", item_id)
		var texture := FinanceUIStyle.item_icon(str(item.get("icon", "")))
		if texture == null: continue
		var icon := _image(content, texture, Rect2(Vector2.ZERO, STARTING_ENCHANTMENT_ICON_SIZE), true)
		icon.set_meta("enchantment_id", item_id)
		icon.custom_minimum_size = STARTING_ENCHANTMENT_ICON_SIZE
		ItemIconArt.bind_texture(icon, texture, true, 32.0, null, 32.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		_bind_item_tooltip(icon, "%s\n%s" % [L10n.source(item.get("display_name", item_id)), L10n.source(item.get("description", ""))])


func _build_traits(record: Dictionary) -> void:
	var traits: Array = record.get("traits", [])
	var relics: Array = record.get("start_relics", [])
	var no_health_growth := int(record.get("max_hp_per_level", 0)) == 0
	if not bool(record.get("manual_withdrawal_allowed", true)):
		_body_label(passive_list, "ui.character.no_withdrawal", 20, INK, 28)
	if traits.is_empty() and relics.is_empty() and record.get("passive_modifiers", []).is_empty():
		if not no_health_growth:
			_body_label(passive_list, "ui.character.health_per_level", 20, INK, 28)
		return
	for trait_data in traits:
		var card := NativeHudBox.column(2.790698)
		card.separation = 1.395349
		passive_list.add_child(card)
		_body_label(card, str(trait_data.title), 24, INK, 33)
		var body := _body_label(card, L10n.source(str(trait_data.description)), 20, INK, 28)
		body.clip_text = false
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for passive in record.get("passive_modifiers", []):
		var label := _body_label(passive_list, L10n.source(str(passive.get("description", passive.get("stat", "")))), 20, INK, 28)
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if relics.is_empty(): return
	if traits.is_empty():
		_body_label(passive_list, "ui.character.four_starting_relics" if relics.size() == 4 else "开局获得如下遗物", 20, INK, 28)
	var grid := GridContainer.new()
	grid.name = "StartingRelicIcons"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 17)
	grid.add_theme_constant_override("v_separation", 6)
	passive_list.add_child(grid)
	for id in relics:
		var relic := DataRegistry.get_record("relics", str(id))
		var card := Control.new()
		card.custom_minimum_size = Vector2(50, 50)
		_bind_item_tooltip(card, L10n.text("ui.character.innate_relic_tooltip") % [L10n.source(relic.display_name), L10n.source(relic.description)])
		grid.add_child(card)
		var relic_icon := _image(card, FinanceUIStyle.item_icon(str(relic.get("icon", ""))), Rect2(7, 7, 36, 36), true)
		relic_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
	GameTooltipLayer.apply_pixel_text(_item_tooltip_label)
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
	paragraph.add_string(text, _item_tooltip_label.get_theme_font("font"), 16)
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
	# The novice shares its full 96px battle frame, displayed at exactly 3x.
	var native_novice := _idle.resource_path.ends_with("novice_96/idle.png")
	var display_scale := 262.325581 / maxf(1.0, used.size.y)
	character_icon.size = NOVICE_PREVIEW_SIZE if native_novice else (_idle.get_size() * display_scale).snapped(Vector2.ONE * ART_PIXEL_PITCH)
	var pixel_scale := character_icon.size / _idle.get_size()
	var foot := Vector2(_idle.get_width() * 0.5, used.end.y)
	character_icon.position = FOOT_ANCHOR - (foot * pixel_scale).snapped(Vector2.ONE * ART_PIXEL_PITCH)
	if native_novice: character_icon.position = (FOOT_ANCHOR - foot * pixel_scale).round()
	_character_rest_position = character_icon.position
	var name_y := character_icon.position.y + snappedf(used.position.y * pixel_scale.y, ART_PIXEL_PITCH) - 55.813953
	name_label.position = Vector2(FOOT_ANCHOR.x - name_label.size.x / 2.0, name_y)
	hover_target.position = Vector2(character_icon.position.x, name_y)
	hover_target.size = Vector2(character_icon.size.x, character_icon.position.y + character_icon.size.y - name_y)


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
		_walk.region = Rect2(Vector2.ZERO, _walk_frame_size)
		character_icon.texture = _walk
	else:
		character_icon.texture = _idle


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset_animation()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _idle == null: return
	if not walking:
		if _idle.resource_path.ends_with("novice_96/idle.png"):
			_breath_material.set_shader_parameter("breath_amount", 0.0)
			return
		_breath_elapsed = fmod(_breath_elapsed + delta, BREATH_PERIOD)
		_breath_material.set_shader_parameter("breath_amount", BREATH_STRETCH * sin(TAU * _breath_elapsed / BREATH_PERIOD))
		return
	_elapsed += delta
	walk_frame = int(_elapsed * _walk_fps) % _walk_frames
	_walk.region = Rect2(Vector2(walk_frame * _walk_frame_size.x, 0), _walk_frame_size)


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
	ItemIconArt.bind_texture(image, texture, true)
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
	label.add_theme_constant_override("line_spacing", 2)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	_place(parent, label, Rect2(at, Vector2(width, pixels+6.976744)))
	return label


func _body_label(parent: Node, value: String, pixels: int, color: Color, height: float, bold := false) -> Label:
	var label := _label(parent, value, Vector2.ZERO, pixels, color, PAPER_WIDTH, bold)
	label.custom_minimum_size = Vector2(PAPER_WIDTH,_compact_text_height(pixels, height))
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


func _compact_text_height(pixels: int, previous_height: float) -> float:
	# Halve only the whitespace; retain the full font line height.
	var text_height := _font.get_height(pixels)
	var height := text_height + maxf(0.0, previous_height - text_height) * 0.5
	return ceilf(height / ART_PIXEL_PITCH) * ART_PIXEL_PITCH


func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("#161119"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


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
	var texture := load(ART + texture_name) as Texture2D
	if button.get_meta("release_locked", false):
		if not _gray_roster_skins.has(texture_name):
			_gray_roster_skins[texture_name] = ROSTER_ART.gray(texture, 0.85)
		texture = _gray_roster_skins[texture_name]
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = texture
		var hover_tint := Color(1.10, 1.10, 1.10) if button.get_meta("release_locked", false) else Color(1.14, 1.10, 1.06)
		style.modulate_color = hover_tint if state in ["hover", "hover_pressed"] else (Color(0.55,0.55,0.55) if state == "disabled" else Color.WHITE)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, 0)
		button.add_theme_stylebox_override(state, style)


func _navigation_content(button: Button, points_right: bool) -> void:
	var content := NativeHudBox.horizontal(2.790698)
	content.name = "NavigationContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.separation = 9.767442
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var words := [L10n.text("ui.common.continue"), "▶"] if points_right else ["◀", L10n.text("ui.common.back")]
	for word in words:
		var is_arrow: bool = word in ["◀", "▶"]
		var label := _label(content, word, Vector2.ZERO, 20 if is_arrow else 24, CREAM, 0)
		label.clip_text = false
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if is_arrow:
			var symbols := SystemFont.new()
			symbols.font_names = PackedStringArray(["Segoe UI Symbol", "sans-serif"])
			symbols.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			label.add_theme_font_override("font", symbols)


func _style_scrollbar(scroll: ScrollContainer) -> void:
	scroll.add_theme_constant_override("h_separation", 6)
	var bar := scroll.get_v_scroll_bar()
	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#161119") if state == "scroll" else Color("#b09174")
		style.content_margin_left = 2.790698
		style.content_margin_right = 2.790698
		style.content_margin_top = 16.744186 if state != "scroll" else 0
		style.content_margin_bottom = 16.744186 if state != "scroll" else 0
		bar.add_theme_stylebox_override(state, style)
	for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(icon_name, ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8)))


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("#c0a5c7")
	style.set_border_width_all(1)
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
	rule.custom_minimum_size = Vector2(PAPER_WIDTH,1.395349)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _rule(parent: Node) -> void:
	parent.add_child(_rectangle_rule())


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
