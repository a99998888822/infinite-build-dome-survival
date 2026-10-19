extends PanelContainer
class_name GameSettingsPanel
## Settings shared by the main menu and battle, using the talent page's pixel HUD skin.

signal back_requested
signal main_menu_requested
signal combat_guide_requested

const PIXEL_STYLE = preload("res://scripts/ui/settings_pixel_style.gd")
const PAGE_FRAME = preload("res://scripts/ui/talent_page_frame.gd")
const PALETTE = preload("res://scripts/ui/hud_palette.gd")
const PAPER := PALETTE.TEXT
const MUTED := PALETTE.MUTED
const GOLD := PALETTE.ACTIVE
const PREFERRED_SIZE := Vector2(1586.666667, 936.666667)


var content_scroll: ScrollContainer
var basic_settings: NativeHudBox
var combat_settings: NativeHudBox
var tabs: Array[Button] = []
var mode_buttons: Array[Button] = []
var mode_checks: Array[Label] = []
var _mode_titles: Array[Label] = []
var _mode_descriptions: Array[Label] = []
var quick_cast: CheckBox
var show_hints: CheckBox
var volume_controls: Dictionary = {}
var resolution: OptionButton
var fullscreen_yes: Button
var fullscreen_no: Button
var display_note: Label
var footer: NativeHudBox
var return_button: Button
var menu_button: Button
var guide_button: Button
var _canvas: Control
var _sidebar: Panel
var _body_panel: Panel
var _sidebar_title: Label
var _divider: ColorRect
var _heading: Label
var _header_line: ColorRect
var _footer_line: ColorRect
var _tab_marks: Array[ColorRect] = []
var _key_descriptions: Array[Label] = []
var _key_labels: Array[Label] = []


func _ready() -> void:
	L10n.locale_changed.connect(sync_all)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_font_override("font", PIXEL_STYLE.FONT)
	add_theme_stylebox_override("panel", _box(PALETTE.BACKDROP, PALETTE.BACKDROP, 0))
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)
	_sidebar = Panel.new()
	_sidebar.add_theme_stylebox_override("panel", PIXEL_STYLE.skin(true))
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_sidebar)
	_body_panel = Panel.new()
	_body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_panel.add_theme_stylebox_override("panel", PIXEL_STYLE.skin(true))
	_canvas.add_child(_body_panel)
	_sidebar_title = _label(_canvas, "ui.settings.title", 40, PAPER)
	_divider = _line(_canvas)
	_heading = _label(_canvas, "ui.settings.general", 40, PAPER)
	_header_line = _line(_canvas)
	_footer_line = _line(_canvas)
	var group := ButtonGroup.new()
	for i in 2:
		var tab := Button.new()
		tab.name = ["BasicSettingsTab", "CombatSettingsTab"][i]
		tab.text = ["ui.settings.general", "战斗设置"][i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override("font_size", 27)
		_canvas.add_child(tab)
		tab.pressed.connect(select_page.bind(i))
		tabs.append(tab)
		_tab_marks.append(_line(tab, GOLD))
	content_scroll = ScrollContainer.new()
	content_scroll.name = "Settings"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	_canvas.add_child(content_scroll)
	PIXEL_STYLE.apply_scrollbar(content_scroll.get_v_scroll_bar())
	var pages := NativeHudBox.column(6.666667)
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(pages)
	pages.bind_scroll(content_scroll)
	_build_basic(pages)
	_build_combat(pages)
	_build_footer()
	var frame := Control.new()
	frame.set_script(PAGE_FRAME)
	frame.pixel_width = 2.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 10
	_canvas.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	WindowSettings.settings_changed.connect(sync_display)
	CombatSettings.settings_changed.connect(sync_combat)
	resized.connect(_layout)
	sync_all()
	select_page(0)
	_layout()


func open_page(in_battle: bool) -> void:
	return_button.text = "ui.common.return_to_battle" if in_battle else "ui.common.back"
	menu_button.visible = in_battle
	guide_button.visible = in_battle and not OS.has_feature("mobile")
	sync_all()
	select_page(0)
	return_button.grab_focus()


func fit_to_viewport(viewport_size: Vector2) -> void:
	size = PREFERRED_SIZE.min((viewport_size - Vector2(53.333333, 53.333333)).max(Vector2(533.333333, 466.666667)))
	scale = Vector2.ONE
	pivot_offset = size * 0.5
	position = (viewport_size - size) * 0.5
	_layout()


func _layout() -> void:
	if _canvas == null: return
	var sidebar_width := 333.333333 if size.x >= 1500 else 280.0
	var left := sidebar_width + 60.0
	var width := maxf(166.666667, size.x - left - 73.333333)
	_sidebar.position = Vector2(40, 40)
	_sidebar.size = Vector2(sidebar_width - 40, size.y - 80)
	_body_panel.position = Vector2(sidebar_width + 26.666667, 40)
	_body_panel.size = Vector2(size.x - sidebar_width - 66.666667, size.y - 80)
	_sidebar_title.position = Vector2(66.666667, 66.666667)
	_sidebar_title.size = Vector2(sidebar_width - 80, 60)
	_divider.visible = false
	for i in tabs.size():
		tabs[i].position = Vector2(66.666667, 180 + i * 100)
		tabs[i].size = Vector2(sidebar_width - 93.333333, 80)
		_tab_marks[i].position = Vector2(0, 13.333333)
		_tab_marks[i].size = Vector2(5, 53.333333)
	_heading.position = Vector2(left, 66.666667)
	_heading.size = Vector2(width, 60)
	_header_line.position = Vector2(left, 143.333333)
	_header_line.size = Vector2(width, 3.333333)
	var content_top := 180.0
	content_scroll.position = Vector2(left, content_top)
	content_scroll.size = Vector2(width, maxf(133.333333, size.y - content_top - 180))
	_footer_line.position = Vector2(left, size.y - 153.333333)
	_footer_line.size = Vector2(width, 1.666667)
	footer.position = Vector2(left, size.y - 130)
	footer.size = Vector2(width, 66.666667)


func select_page(index: int) -> void:
	basic_settings.visible = index == 0
	combat_settings.visible = index == 1
	show_hints.visible = index != 0
	_heading.text = ["ui.settings.general", "战斗设置"][index]
	content_scroll.scroll_vertical = 0
	for i in tabs.size():
		var selected := i == index
		tabs[i].set_pressed_no_signal(selected)
		PIXEL_STYLE.apply_button(tabs[i], false, selected)
		tabs[i].add_theme_font_size_override("font_size", 27)
		tabs[i].add_theme_color_override("font_color", GOLD if selected else MUTED)
		_tab_marks[i].visible = selected
	_layout()
	_layout.call_deferred()


func _build_basic(parent: Node) -> void:
	basic_settings = NativeHudBox.column(6.666667)
	basic_settings.name = "BasicSettings"
	basic_settings.separation = 20.000000
	parent.add_child(basic_settings)
	for spec in [["ui.settings.audio.music", AudioManager.BUS_BGM, "bgm_volume"], ["ui.settings.audio.sound_effects", AudioManager.BUS_SFX, "sfx_volume"]]:
		var row := _basic_row(spec[0])
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size.y = 46.666667
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		PIXEL_STYLE.apply_slider(slider)
		var amount := _label(row, "100%", 23, PAPER)
		amount.custom_minimum_size.x = 93.333333
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		volume_controls[spec[2]] = {"slider": slider, "label": amount}
		slider.value_changed.connect(func(value: float):
			amount.text = "%d%%" % roundi(value)
			AudioManager.set_bus_volume(spec[1], roundi(value)))
	var resolution_row := _basic_row("ui.settings.display.resolution")
	resolution = OptionButton.new()
	resolution.name = "Resolution"
	var arrow_image := resolution.get_theme_icon("arrow").get_image()
	arrow_image.resize(20, 20, Image.INTERPOLATE_NEAREST)
	resolution.add_theme_icon_override("arrow", ImageTexture.create_from_image(arrow_image))
	resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution.add_theme_constant_override("arrow_margin", 20)
	PIXEL_STYLE.apply_button(resolution)
	PIXEL_STYLE.apply_popup(resolution.get_popup())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := resolution.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = 20
		style.content_margin_right = 20
		resolution.add_theme_stylebox_override(state, style)
	resolution.get_popup().add_theme_constant_override("start_padding", 12)
	resolution.get_popup().add_theme_constant_override("end_padding", 12)
	for preset in WindowSettings.get_resolution_presets(): resolution.add_item("%d × %d" % [preset.x, preset.y])
	resolution.item_selected.connect(func(index: int): WindowSettings.set_resolution_index(index))
	var resolution_padding := MarginContainer.new()
	resolution_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_padding.add_theme_constant_override("margin_right", 27)
	resolution_row.add_child(resolution_padding)
	resolution_padding.add_child(resolution)
	var fullscreen_row := _basic_row("ui.settings.display.fullscreen")
	var group := ButtonGroup.new()
	for enabled in [true, false]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(206.666667, 60)
		PIXEL_STYLE.apply_button(button)
		fullscreen_row.add_child(button)
		button.pressed.connect(func(): WindowSettings.set_fullscreen(enabled))
		if enabled: fullscreen_yes = button
		else: fullscreen_no = button
	var credit_row := _basic_row("Credit")
	var credit := PanelContainer.new()
	credit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credit.add_theme_stylebox_override("panel", PIXEL_STYLE.skin(false, Color(0.85, 0.85, 0.85), Vector2(16.666667, 6.666667)))
	credit_row.add_child(credit)
	var credit_text := _label(credit, "Ark Pixel Font | SIL Open Font License 1.1", 17, PAPER)
	credit_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	display_note = _label(basic_settings, "", 20, PAPER)
	display_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_combat(parent: Node) -> void:
	combat_settings = NativeHudBox.column(6.666667)
	combat_settings.name = "CombatSettings"
	combat_settings.separation = 0.000000
	parent.add_child(combat_settings)
	_label(combat_settings, "ui.settings.movement.mode", 27).custom_minimum_size.y = 40
	_space(combat_settings, 17)
	var movement_padding := MarginContainer.new()
	movement_padding.add_theme_constant_override("margin_right", 53)
	combat_settings.add_child(movement_padding)
	var movement := NativeHudBox.horizontal(6.666667)
	movement.separation = 26.666667
	movement_padding.add_child(movement)
	var group := ButtonGroup.new()
	for i in 2:
		var button := Button.new()
		button.name = "MouseMovement" if i == 0 else "KeyboardMovement"
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 133.333333)
		movement.add_child(button)
		var title := _label(button, "ui.settings.controls.right_mouse" if i == 0 else "方向键 / WASD", 30)
		_mode_titles.append(title)
		title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		title.offset_left = 30
		title.offset_top = 16.666667
		title.offset_right = -66.666667
		title.offset_bottom = 63.333333
		var description := _label(button, "ui.settings.movement.mouse_hint" if i == 0 else "按住方向键，直接控制移动", 20, MUTED)
		_mode_descriptions.append(description)
		description.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		description.offset_left = 30
		description.offset_top = 71.666667
		description.offset_right = -16.666667
		description.offset_bottom = 108.333333
		var mark := _label(button, "◆", 27, GOLD)
		mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -66.666667
		mark.offset_top = 20
		mark.offset_right = -30
		mark.offset_bottom = 60
		mode_checks.append(mark)
		mode_buttons.append(button)
		button.pressed.connect(func(): CombatSettings.set_option("keyboard_movement", i == 1))
	_space(combat_settings, 37)
	_label(combat_settings, "ui.settings.controls.title", 27).custom_minimum_size.y = 40
	_space(combat_settings, 20)
	var keys := NativeHudBox.column(6.666667)
	keys.separation = 13.333333
	combat_settings.add_child(keys)
	for key_name in ["ui.settings.controls.number_keys", "ui.settings.controls.left_mouse", "ui.settings.controls.right_mouse", "Esc", "ui.settings.controls.mouse_wheel"]:
		var row := NativeHudBox.horizontal(6.666667)
		row.custom_minimum_size.y = 46.666667
		row.separation = 26.666667
		keys.add_child(row)
		var keycap := PanelContainer.new()
		keycap.custom_minimum_size = Vector2(166.666667, 46.666667)
		keycap.add_theme_stylebox_override("panel", PIXEL_STYLE.skin(false, Color.WHITE, Vector2(13.333333, 3.333333)))
		row.add_child(keycap)
		var key_label := _label(keycap, key_name, 20)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key_labels.append(key_label)
		var description := _label(row, "", 23)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_key_descriptions.append(description)
		if key_name == "ui.settings.controls.left_mouse":
			quick_cast = _checkbox("ui.settings.controls.quick_cast", GOLD)
			quick_cast.name = "QuickCast"
			quick_cast.custom_minimum_size = Vector2(226.666667, 46.666667)
			quick_cast.toggled.connect(func(value: bool): CombatSettings.set_option("quick_cast", value))
			row.add_child(quick_cast)
	_space(combat_settings, 30)
	guide_button = Button.new()
	guide_button.name = "ReplayCombatGuide"
	guide_button.text = "ui.guide.replay"
	guide_button.custom_minimum_size = Vector2(0, 60)
	guide_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	PIXEL_STYLE.apply_button(guide_button)
	guide_button.pressed.connect(func(): combat_guide_requested.emit())
	combat_settings.add_child(guide_button)
	guide_button.hide()


func _build_footer() -> void:
	footer = NativeHudBox.horizontal(6.666667)
	footer.name = "SettingsActions"
	footer.separation = 26.666667
	_canvas.add_child(footer)
	var left := NativeHudBox.horizontal(6.666667)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(left)
	show_hints = _checkbox("ui.settings.controls.show_hints", PAPER)
	show_hints.name = "ShowCombatHints"
	show_hints.toggled.connect(func(value: bool): CombatSettings.set_option("show_hints", value))
	left.add_child(show_hints)
	return_button = Button.new()
	return_button.name = "ReturnButton"
	return_button.text = "ui.common.return_to_battle"
	return_button.custom_minimum_size = Vector2(266.666667, 66.666667)
	PIXEL_STYLE.apply_button(return_button)
	return_button.pressed.connect(func(): back_requested.emit())
	footer.add_child(return_button)
	menu_button = Button.new()
	menu_button.name = "MainMenuButton"
	menu_button.text = "ui.settings.return_to_main_menu"
	menu_button.tooltip_text = "ui.settlement.retreat_hint"
	menu_button.custom_minimum_size = Vector2(266.666667, 66.666667)
	PIXEL_STYLE.apply_button(menu_button)
	menu_button.pressed.connect(func(): main_menu_requested.emit())
	footer.add_child(menu_button)


func sync_all() -> void:
	for key: String in volume_controls:
		var value := CampProgression.get_volume_setting(key, 100)
		volume_controls[key].slider.set_value_no_signal(value)
		volume_controls[key].label.text = "%d%%" % value
	sync_display()
	sync_combat()


func sync_display() -> void:
	resolution.select(WindowSettings.get_resolution_index())
	var fullscreen := WindowSettings.is_fullscreen()
	fullscreen_yes.set_pressed_no_signal(fullscreen)
	fullscreen_no.set_pressed_no_signal(not fullscreen)
	PIXEL_STYLE.apply_button(fullscreen_yes, false, fullscreen)
	PIXEL_STYLE.apply_button(fullscreen_no, false, not fullscreen)
	fullscreen_yes.text = "ui.settings.yes_selected" if fullscreen else "ui.settings.yes_unselected"
	fullscreen_no.text = "ui.settings.no_unselected" if fullscreen else "ui.settings.no_selected"
	var native_locked := WindowSettings.is_embedded() or OS.has_feature("mobile")
	resolution.disabled = native_locked or fullscreen
	fullscreen_yes.disabled = native_locked
	fullscreen_no.disabled = native_locked
	display_note.text = "ui.settings.autosave_hint"
	if WindowSettings.is_embedded(): display_note.text = "ui.settings.display.embedded_hint"
	elif OS.has_feature("mobile"): display_note.text = "ui.settings.display.system_size_hint"


func sync_combat() -> void:
	for i in mode_buttons.size():
		var selected := (i == 1) == CombatSettings.keyboard_movement
		PIXEL_STYLE.apply_button(mode_buttons[i], true, selected, true)
		mode_buttons[i].set_pressed_no_signal(selected)
		mode_checks[i].visible = selected
		mode_checks[i].add_theme_color_override("font_color", PALETTE.WARM_ACTIVE)
		_mode_titles[i].add_theme_color_override("font_color", PALETTE.WARM_TEXT if selected else PAPER)
		_mode_descriptions[i].add_theme_color_override("font_color", PALETTE.WARM_MUTED if selected else MUTED)
	quick_cast.set_pressed_no_signal(CombatSettings.quick_cast)
	show_hints.set_pressed_no_signal(CombatSettings.show_hints)
	_key_descriptions[0].text = "ui.settings.skills.manual_quick" if CombatSettings.quick_cast else "ui.settings.skills.manual_select"
	_key_descriptions[1].text = "ui.settings.controls.no_click_needed" if CombatSettings.quick_cast else "ui.settings.controls.confirm_cast_hint"
	_key_descriptions[2].text = "ui.settings.controls.cancel_keyboard_hint" if CombatSettings.keyboard_movement else "ui.settings.controls.cancel_mouse_hint"
	_key_descriptions[3].text = "ui.settings.controls.escape_hint"
	_key_labels[4].get_parent().get_parent().visible = CombatSettings.keyboard_movement
	_key_descriptions[4].text = "ui.settings.controls.wheel_hint"
	if CombatSettings.keyboard_movement:
		_key_descriptions[1].text = "ui.settings.controls.click_quick_cast_hint" if CombatSettings.quick_cast else "ui.settings.controls.click_aim_hint"


func _basic_row(title: String) -> NativeHudBox:
	var row := NativeHudBox.horizontal(6.666667)
	row.custom_minimum_size.y = 60
	row.separation = 20.000000
	basic_settings.add_child(row)
	_label(row, title, 23).custom_minimum_size = Vector2(200, 60)
	return row


static func _box(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	return PIXEL_STYLE.flat(background, border, border_width)


static func _label(parent: Node, text: String, font_size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PIXEL_STYLE.FONT)
	label.add_theme_constant_override("line_spacing", 5)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func _line(parent: Node, color: Color = PALETTE.BORDER) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


static func _space(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


static func _checkbox(text: String, color: Color) -> CheckBox:
	var control := CheckBox.new()
	control.text = text
	control.add_theme_font_override("font", PIXEL_STYLE.FONT)
	control.add_theme_constant_override("h_separation", 7)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var padding := control.get_theme_stylebox(state).duplicate() as StyleBox
		padding.set_content_margin_all(6.666667)
		control.add_theme_stylebox_override(state, padding)
	control.add_theme_font_size_override("font_size", 23)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_hover_color", GOLD)
	control.add_theme_color_override("font_pressed_color", color)
	control.add_theme_color_override("font_hover_pressed_color", GOLD)
	control.add_theme_color_override("font_focus_color", GOLD)
	var focus := PIXEL_STYLE.flat(Color.TRANSPARENT, GOLD)
	focus.draw_center = false
	control.add_theme_stylebox_override("focus", focus)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for enabled in [false, true]:
		var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		bitmap.fill_rect(Rect2i(1, 1, 14, 14), GOLD if enabled else MUTED)
		if enabled:
			for point in [Vector2i(4, 7), Vector2i(5, 8), Vector2i(6, 9), Vector2i(7, 8), Vector2i(8, 7), Vector2i(9, 6), Vector2i(10, 5)]: bitmap.fill_rect(Rect2i(point, Vector2i(2, 2)), PALETTE.SHADOW)
		else: bitmap.fill_rect(Rect2i(2, 2, 12, 12), PALETTE.SHADOW)
		control.add_theme_icon_override("checked" if enabled else "unchecked", ImageTexture.create_from_image(_native_check_bitmap(bitmap)))
	return control


static func _native_check_bitmap(bitmap: Image) -> Image:
	bitmap.resize(27, 27, Image.INTERPOLATE_NEAREST)
	return bitmap
