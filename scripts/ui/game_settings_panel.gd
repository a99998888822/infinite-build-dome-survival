extends PanelContainer
class_name GameSettingsPanel
## Production settings shared by the main menu and battle; matches the R03 study.

signal back_requested
signal main_menu_requested

const PAPER := Color("e2dbc3")
const MUTED := Color("9bada7")
const ICE := Color("c5edff")
const GOLD := Color("ddbe79")
const PREFERRED_SIZE := Vector2(952, 562)

var content_scroll: ScrollContainer
var basic_settings: VBoxContainer
var combat_settings: VBoxContainer
var tabs: Array[Button] = []
var mode_buttons: Array[Button] = []
var mode_checks: Array[Label] = []
var wheelchair_mode: CheckBox
var quick_cast: CheckBox
var show_hints: CheckBox
var volume_controls: Dictionary = {}
var resolution: OptionButton
var fullscreen_yes: Button
var fullscreen_no: Button
var display_note: Label
var footer: HBoxContainer
var return_button: Button
var menu_button: Button
var _canvas: Control
var _sidebar: Panel
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
	add_theme_stylebox_override("panel", _box(Color("111b16"), Color("9a8149")))
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)
	_sidebar = Panel.new()
	_sidebar.add_theme_stylebox_override("panel", _box(Color("0e1913"), Color("0e1913"), 0))
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_sidebar)
	_sidebar_title = _label(_canvas, "ui.settings.title", 24, GOLD)
	_divider = _line(_canvas)
	_heading = _label(_canvas, "ui.settings.general", 24, GOLD)
	_header_line = _line(_canvas)
	_footer_line = _line(_canvas)
	var group := ButtonGroup.new()
	for i in 2:
		var tab := Button.new()
		tab.name = "BasicSettingsTab" if i == 0 else "CombatSettingsTab"
		tab.text = "ui.settings.general" if i == 0 else "战斗设置"
		tab.toggle_mode = true
		tab.button_group = group
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override("font_size", 16)
		_canvas.add_child(tab)
		tab.pressed.connect(select_page.bind(i))
		tabs.append(tab)
		_tab_marks.append(_line(tab, ICE))
	content_scroll = ScrollContainer.new()
	content_scroll.name = "Settings"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_canvas.add_child(content_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(pages)
	_build_basic(pages)
	_build_combat(pages)
	_build_footer()
	WindowSettings.settings_changed.connect(sync_display)
	CombatSettings.settings_changed.connect(sync_combat)
	resized.connect(_layout)
	sync_all()
	select_page(0)
	_layout()


func open_page(in_battle: bool) -> void:
	return_button.text = "ui.common.return_to_battle" if in_battle else "ui.common.back"
	menu_button.visible = in_battle
	sync_all()
	select_page(0)
	return_button.grab_focus()


func fit_to_viewport(viewport_size: Vector2) -> void:
	size = PREFERRED_SIZE.min((viewport_size - Vector2(32, 32)).max(Vector2(320, 280)))
	position = ((viewport_size - size) * 0.5).floor()
	_layout()


func _layout() -> void:
	if _canvas == null: return
	var sidebar_width := 200.0 if size.x >= 900 else 168.0
	var left := sidebar_width + 36.0
	var width := maxf(100, size.x - left - 28)
	_sidebar.position = Vector2.ONE
	_sidebar.size = Vector2(sidebar_width - 2, size.y - 2)
	_sidebar_title.position = Vector2(28, 19)
	_sidebar_title.size = Vector2(sidebar_width - 48, 36)
	_divider.position = Vector2(sidebar_width, 24)
	_divider.size = Vector2(1, size.y - 48)
	for i in tabs.size():
		tabs[i].position = Vector2(20, 98 + i * 60)
		tabs[i].size = Vector2(sidebar_width - 40, 48)
		_tab_marks[i].position = Vector2(0, 8)
		_tab_marks[i].size = Vector2(3, 32)
	_heading.position = Vector2(left, 19)
	_heading.size = Vector2(width, 36)
	_header_line.position = Vector2(left, 70)
	_header_line.size = Vector2(width, 1)
	var content_top := 94.0 if basic_settings.visible else 86.0
	content_scroll.position = Vector2(left, content_top)
	content_scroll.size = Vector2(width, maxf(80, size.y - content_top - 100))
	_footer_line.position = Vector2(left, size.y - 80)
	_footer_line.size = Vector2(width, 1)
	footer.position = Vector2(left, size.y - 66)
	footer.size = Vector2(width, 40)


func select_page(index: int) -> void:
	basic_settings.visible = index == 0
	combat_settings.visible = index == 1
	show_hints.visible = index == 1
	_heading.text = "ui.settings.general" if index == 0 else "战斗设置"
	content_scroll.scroll_vertical = 0
	for i in tabs.size():
		var selected := i == index
		tabs[i].set_pressed_no_signal(selected)
		var normal := _box(Color("243a30") if selected else Color("101c16"), Color("56776c") if selected else Color("263a30"))
		normal.content_margin_left = 18
		var hover := _box(Color("2b4035"), ICE)
		hover.content_margin_left = 18
		for state in ["normal", "pressed"]: tabs[i].add_theme_stylebox_override(state, normal)
		for state in ["hover", "hover_pressed"]: tabs[i].add_theme_stylebox_override(state, hover)
		tabs[i].add_theme_color_override("font_color", ICE if selected else MUTED)
		tabs[i].add_theme_color_override("font_pressed_color", ICE)
		_tab_marks[i].visible = selected
	_layout()


func _build_basic(parent: Node) -> void:
	basic_settings = VBoxContainer.new()
	basic_settings.name = "BasicSettings"
	basic_settings.add_theme_constant_override("separation", 12)
	parent.add_child(basic_settings)
	for spec in [["ui.settings.audio.music", AudioManager.BUS_BGM, "bgm_volume"], ["ui.settings.audio.sound_effects", AudioManager.BUS_SFX, "sfx_volume"]]:
		var row := _basic_row(spec[0])
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size.y = 28
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var amount := _label(row, "100%", 14, PAPER)
		amount.custom_minimum_size.x = 56
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		volume_controls[spec[2]] = {"slider": slider, "label": amount}
		slider.value_changed.connect(func(value: float):
			amount.text = "%d%%" % roundi(value)
			AudioManager.set_bus_volume(spec[1], roundi(value)))
	var resolution_row := _basic_row("ui.settings.display.resolution")
	resolution = OptionButton.new()
	resolution.name = "Resolution"
	resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SettingsUIStyle.apply_button(resolution)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := resolution.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = 12
		style.content_margin_right = 12
		resolution.add_theme_stylebox_override(state, style)
	resolution.get_popup().add_theme_constant_override("start_padding", 12)
	resolution.get_popup().add_theme_constant_override("end_padding", 12)
	for preset in WindowSettings.get_resolution_presets(): resolution.add_item("%d × %d" % [preset.x, preset.y])
	resolution.item_selected.connect(func(index: int): WindowSettings.set_resolution_index(index))
	resolution_row.add_child(resolution)
	var fullscreen_row := _basic_row("ui.settings.display.fullscreen")
	var group := ButtonGroup.new()
	for enabled in [true, false]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(124, 36)
		SettingsUIStyle.apply_button(button)
		fullscreen_row.add_child(button)
		button.pressed.connect(func(): WindowSettings.set_fullscreen(enabled))
		if enabled: fullscreen_yes = button
		else: fullscreen_no = button
	var credit_row := _basic_row("Credit")
	var credit := PanelContainer.new()
	credit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credit.add_theme_stylebox_override("panel", SettingsUIStyle.credit())
	credit_row.add_child(credit)
	var credit_text := _label(credit, "Ark Pixel Font | SIL Open Font License 1.1", 10, PAPER)
	credit_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	display_note = _label(basic_settings, "", 12, PAPER)
	display_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_combat(parent: Node) -> void:
	combat_settings = VBoxContainer.new()
	combat_settings.name = "CombatSettings"
	combat_settings.add_theme_constant_override("separation", 0)
	parent.add_child(combat_settings)
	wheelchair_mode = _checkbox("ui.settings.auto_attack", PAPER)
	wheelchair_mode.name = "WheelchairMode"
	wheelchair_mode.custom_minimum_size.y = 28
	wheelchair_mode.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wheelchair_mode.toggled.connect(func(value: bool): CombatSettings.set_option("wheelchair_mode", value))
	combat_settings.add_child(wheelchair_mode)
	_space(combat_settings, 16)
	_label(combat_settings, "ui.settings.movement.mode", 16).custom_minimum_size.y = 24
	_space(combat_settings, 10)
	var movement := HBoxContainer.new()
	movement.add_theme_constant_override("separation", 16)
	combat_settings.add_child(movement)
	var group := ButtonGroup.new()
	for i in 2:
		var button := Button.new()
		button.name = "MouseMovement" if i == 0 else "KeyboardMovement"
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 80)
		movement.add_child(button)
		var title := _label(button, "ui.settings.controls.right_mouse" if i == 0 else "方向键 / WASD", 18)
		title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		title.offset_left = 18
		title.offset_top = 10
		title.offset_right = -40
		title.offset_bottom = 38
		var description := _label(button, "ui.settings.movement.mouse_hint" if i == 0 else "按住方向键，直接控制移动", 12, MUTED)
		description.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		description.offset_left = 18
		description.offset_top = 43
		description.offset_right = -10
		description.offset_bottom = 65
		var mark := _label(button, "●", 16, ICE)
		mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -40
		mark.offset_top = 12
		mark.offset_right = -18
		mark.offset_bottom = 36
		mode_checks.append(mark)
		mode_buttons.append(button)
		button.pressed.connect(func(): CombatSettings.set_option("keyboard_movement", i == 1))
	_space(combat_settings, 22)
	_label(combat_settings, "ui.settings.controls.title", 16).custom_minimum_size.y = 24
	_space(combat_settings, 12)
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	combat_settings.add_child(keys)
	for key_name in ["ui.settings.controls.number_keys", "ui.settings.controls.left_mouse", "ui.settings.controls.right_mouse", "Esc"]:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 28
		row.add_theme_constant_override("separation", 16)
		keys.add_child(row)
		var keycap := PanelContainer.new()
		keycap.custom_minimum_size = Vector2(100, 28)
		keycap.add_theme_stylebox_override("panel", _box(Color("1d2a23"), Color("4a5b4d")))
		row.add_child(keycap)
		var key_label := _label(keycap, key_name, 12)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key_labels.append(key_label)
		var description := _label(row, "", 14)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_key_descriptions.append(description)
		if key_name == "ui.settings.controls.left_mouse":
			quick_cast = _checkbox("ui.settings.controls.quick_cast", ICE)
			quick_cast.name = "QuickCast"
			quick_cast.custom_minimum_size = Vector2(136, 28)
			quick_cast.toggled.connect(func(value: bool): CombatSettings.set_option("quick_cast", value))
			row.add_child(quick_cast)


func _build_footer() -> void:
	footer = HBoxContainer.new()
	footer.name = "SettingsActions"
	footer.add_theme_constant_override("separation", 16)
	_canvas.add_child(footer)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(left)
	show_hints = _checkbox("ui.settings.controls.show_hints", PAPER)
	show_hints.name = "ShowCombatHints"
	show_hints.toggled.connect(func(value: bool): CombatSettings.set_option("show_hints", value))
	left.add_child(show_hints)
	return_button = Button.new()
	return_button.name = "ReturnButton"
	return_button.text = "ui.common.return_to_battle"
	return_button.custom_minimum_size = Vector2(160, 40)
	SettingsUIStyle.apply_button(return_button)
	return_button.pressed.connect(func(): back_requested.emit())
	footer.add_child(return_button)
	menu_button = Button.new()
	menu_button.name = "MainMenuButton"
	menu_button.text = "ui.settings.return_to_main_menu"
	menu_button.custom_minimum_size = Vector2(160, 40)
	SettingsUIStyle.apply_button(menu_button)
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
		var normal := _box(Color("233830") if selected else Color("14221b"), ICE if selected else Color("425447"), 2 if selected else 1)
		for state in ["normal", "pressed"]: mode_buttons[i].add_theme_stylebox_override(state, normal)
		for state in ["hover", "hover_pressed"]: mode_buttons[i].add_theme_stylebox_override(state, _box(Color("2a3c33"), ICE))
		mode_buttons[i].set_pressed_no_signal(selected)
		mode_checks[i].visible = selected
	quick_cast.set_pressed_no_signal(CombatSettings.quick_cast)
	wheelchair_mode.set_pressed_no_signal(CombatSettings.wheelchair_mode)
	show_hints.set_pressed_no_signal(CombatSettings.show_hints)
	_key_descriptions[0].text = "ui.settings.controls.number_quick_cast_hint" if CombatSettings.quick_cast else "ui.settings.controls.number_select_hint"
	_key_descriptions[1].text = "ui.settings.controls.no_click_needed" if CombatSettings.quick_cast else "ui.settings.controls.confirm_cast_hint"
	_key_descriptions[2].text = "ui.settings.controls.cancel_keyboard_hint" if CombatSettings.keyboard_movement else "ui.settings.controls.cancel_mouse_hint"
	_key_descriptions[3].text = "ui.settings.controls.escape_hint"
	_key_labels[0].text = "ui.settings.controls.mouse_wheel" if CombatSettings.keyboard_movement else "ui.settings.controls.number_keys"
	if CombatSettings.keyboard_movement:
		_key_descriptions[0].text = "ui.settings.controls.wheel_hint"
		_key_descriptions[1].text = "ui.settings.controls.click_quick_cast_hint" if CombatSettings.quick_cast else "ui.settings.controls.click_aim_hint"
	if CombatSettings.wheelchair_mode:
		_key_labels[0].text = "ui.settings.controls.auto_attack"
		_key_descriptions[0].text = "ui.settings.controls.auto_attack_hint"
		_key_descriptions[1].text = "ui.settings.controls.no_click_needed"
		_key_descriptions[2].text = "ui.settings.controls.keyboard_hint" if CombatSettings.keyboard_movement else "ui.settings.controls.mouse_move_hint"
		_key_descriptions[3].text = "ui.settings.controls.pause_hint"


func _basic_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation", 12)
	basic_settings.add_child(row)
	_label(row, title, 14).custom_minimum_size = Vector2(120, 36)
	return row


static func _box(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(0)
	return box


static func _label(parent: Node, text: String, font_size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func _line(parent: Node, color: Color = Color("445044")) -> ColorRect:
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
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_hover_color", ICE)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for enabled in [false, true]:
		var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		bitmap.fill_rect(Rect2i(1, 1, 14, 14), ICE if enabled else MUTED)
		if enabled:
			for point in [Vector2i(4, 7), Vector2i(5, 8), Vector2i(6, 9), Vector2i(7, 8), Vector2i(8, 7), Vector2i(9, 6), Vector2i(10, 5)]: bitmap.fill_rect(Rect2i(point, Vector2i(2, 2)), Color("101b1b"))
		else: bitmap.fill_rect(Rect2i(2, 2, 12, 12), Color("101b1b"))
		control.add_theme_icon_override("checked" if enabled else "unchecked", ImageTexture.create_from_image(bitmap))
	return control
