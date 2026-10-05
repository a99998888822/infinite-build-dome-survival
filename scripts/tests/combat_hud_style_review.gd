extends "res://scripts/tests/active_combat_art_review.gd"
## Isolated style study. No production scene, setting, input binding or wave is changed.

const INK := Color("101b1b")
const EDGE := Color("465b58")
const PAPER := Color("e2dbc3")
const MUTED := Color("9bada7")
const ICE := Color("c5edff")
const GOLD := Color("ddbe79")
const URGENT := Color("f2a18e")

class WeaponHeader extends Control:
	var number_source: Label
	var status_source: Label
	var previous_text := ""

	func _process(_delta: float) -> void:
		var current := number_source.text + "|" + status_source.text
		if current != previous_text:
			previous_text = current
			queue_redraw()

	func _draw() -> void:
		var font := number_source.get_theme_font("font")
		# Font drawing uses an explicit baseline; CJK fallback ascenders cannot
		# shift this row as they can with independently centered Label controls.
		for side in 2:
			var text := number_source.text if side == 0 else status_source.text
			var alignment := HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			draw_string_outline(font, Vector2(6, 17), text, alignment, size.x - 12, 12, 1, Color("101c20"))
			draw_string(font, Vector2(6, 17), text, alignment, size.x - 12, 12, Color("e1f4ff"))

var weapon_headers: Array[WeaponHeader] = []
var hint_root: Control
var hint_title: Label
var hint_row: HBoxContainer
var cleanup_root: Control
var cleanup_timer: Label
var cleanup_title: Label
var cleanup_count: Label
var cleanup_note: Label
var cleanup_meter: ColorRect
var cleanup_badge: Panel
var settings_root: Control
var settings_panel: Panel
var mode_buttons: Array[Button] = []
var mode_checks: Array[Label] = []
var movement_description: Label
var hints_check: CheckBox
var quick_cast_check: CheckBox
var selection_description: Label
var left_click_description: Label
var quick_note: Label
var settings_back: Button
var basic_settings_page: Control
var combat_settings_page: Control
var settings_tabs: Array[Button] = []
var settings_tab_marks: Array[ColorRect] = []
var mock_keyboard := false
var mock_aiming := false
var mock_quick_cast := false
var preview_frozen := false


func _build_ui() -> void:
	super._build_ui()
	ui.layer = 40
	for child in ui.get_children():
		if child is PanelContainer:
			child.hide()
	_build_cleanup()
	_build_hints()
	_build_settings()
	_install_settings_navigation()
	cleanup_root.hide()
	settings_root.hide()
	hint_root.hide()
	# F1-F5 switch the isolated study when run manually in the editor.
	if not automatic:
		_prepare_proposed_layout.call_deferred()


func _process(delta: float) -> void:
	if not preview_frozen:
		super._process(delta)


func _physics_process(delta: float) -> void:
	if not preview_frozen:
		super._physics_process(delta)


func _layout() -> void:
	super._layout()
	_apply_bar_padding()


func _apply_bar_padding() -> void:
	if bar == null:
		return
	if not weapon_headers.is_empty() and weapon_headers[0].get_parent() != bar.cards[0]:
		weapon_headers.clear()
	# Apply only to the style-review instance; production resources stay untouched.
	for i in bar.cards.size():
		# Keep source styles consistent; WeaponHeader draws the shared baseline.
		for label in [bar.numbers[i], bar.timers[i]]:
			label.add_theme_font_size_override("font_size", 12)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.numbers[i].position = Vector2(6, 5)
		bar.numbers[i].size = Vector2(12, 18)
		bar.timers[i].position = Vector2(22, 5)
		bar.timers[i].size = Vector2(bar.slot_size - 28, 18)
		bar.icons[i].position = Vector2(8, 23)
		bar.icons[i].size = Vector2(bar.slot_size - 16, bar.slot_size - 27)
		if weapon_headers.size() <= i:
			var header := WeaponHeader.new()
			header.number_source = bar.numbers[i]
			header.status_source = bar.timers[i]
			header.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.cards[i].add_child(header)
			weapon_headers.append(header)
		weapon_headers[i].size = Vector2(bar.slot_size, 23)
		weapon_headers[i].queue_redraw()
		bar.numbers[i].hide()
		bar.timers[i].hide()


func _flow_changed(previous: String, current: String) -> void:
	super._flow_changed(previous, current)
	var in_combat := current == MainFlowCoordinator.STATE_WAVE_COMBAT
	ui.visible = in_combat or current == MainFlowCoordinator.STATE_BATTLE_UTILITY
	bar.visible = in_combat
	hint_root.visible = in_combat and hints_check.button_pressed
	if not in_combat:
		cleanup_root.hide()
	if in_combat:
		settings_root.hide()


func _input(event: InputEvent) -> void:
	if not preview_frozen or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4] and settings_root.visible:
		_close_settings_preview()
	match event.keycode:
		KEY_F1:
			settings_root.hide()
			cleanup_root.hide()
			(battle.hud as BattleHud).wave_panel.show()
			_update_hints(false)
		KEY_F2:
			settings_root.hide()
			_show_cleanup(10, 2)
		KEY_F3:
			settings_root.hide()
			_show_cleanup(3, 1)
		KEY_F4:
			_update_hints(true)
		KEY_F5:
			_open_settings_preview()
		KEY_ESCAPE:
			if settings_root.visible:
				_close_settings_preview()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _install_settings_navigation() -> void:
	var overlay := battle.utility_overlay
	# Reuse the actual basic controls inside the review-only two-column shell.
	# Their source scene and production controller are not changed.
	overlay._settings.reparent(basic_settings_page, false)
	overlay._settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	overlay._settings.position = Vector2(28, 94)
	overlay._settings.size = Vector2(688, 350)
	overlay._settings_footer.reparent(settings_panel, false)
	overlay._settings_footer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	overlay._settings_footer.position = Vector2(588, 496)
	overlay._settings_footer.size = Vector2(336, 40)
	for button in [overlay._return_button, overlay._menu_button]:
		button.custom_minimum_size = Vector2(160, 40)
	overlay._settings_footer.size = Vector2(336, 40)
	settings_back = overlay._return_button
	settings_back.text = "返回战斗"
	flow.modal_requested.connect(func(state: String, payload: Dictionary):
		if state == MainFlowCoordinator.STATE_BATTLE_UTILITY and str(payload.get("page", "")) == "settings":
			_show_settings_preview()
	)
	_select_settings_tab(false)


func _open_settings_preview() -> void:
	if flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT:
		flow.request_battle_utility("settings")


func _show_settings_preview() -> void:
	battle.utility_overlay.hide()
	# The shared production view lays out its controls when opened. Restore the
	# original coordinates after borrowing them for this historical R03 study.
	battle.utility_overlay._settings.position = Vector2(28, 94)
	battle.utility_overlay._settings.size = Vector2(688, 350)
	battle.utility_overlay._settings_footer.position = Vector2(588, 496)
	battle.utility_overlay._settings_footer.size = Vector2(336, 40)
	settings_root.show()
	bar.hide()
	hint_root.hide()
	_select_settings_tab(false)


func _close_settings_preview() -> void:
	battle.utility_overlay._close()


func _select_settings_tab(combat: bool) -> void:
	basic_settings_page.visible = not combat
	combat_settings_page.visible = combat
	for i in settings_tabs.size():
		var chosen := (i == 1) == combat
		var normal := _box(Color("243a30") if chosen else Color("101c16"), Color("56776c") if chosen else Color("263a30"))
		normal.content_margin_left = 18
		settings_tabs[i].add_theme_stylebox_override("normal", normal)
		settings_tabs[i].add_theme_color_override("font_color", ICE if chosen else MUTED)
		settings_tab_marks[i].visible = chosen


func _box(background: Color, border: Color = EDGE, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(3)
	return box


func _panel(parent: Node, rect: Rect2, background: Color = INK, border: Color = EDGE) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(background, border))
	return panel


func _text(parent: Node, text: String, rect: Rect2, font_size: int = 14, color: Color = PAPER, centered: bool = false) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _line(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	parent.add_child(line)
	line.position = rect.position
	line.size = rect.size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _style_checkbox(control: CheckBox) -> void:
	# Make the unchecked box legible on the dark panel as well as the checked mark.
	for enabled in [false, true]:
		var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		bitmap.fill_rect(Rect2i(1, 1, 14, 14), ICE if enabled else MUTED)
		if enabled:
			for point in [Vector2i(4, 7), Vector2i(5, 8), Vector2i(6, 9), Vector2i(7, 8), Vector2i(8, 7), Vector2i(9, 6), Vector2i(10, 5)]:
				bitmap.fill_rect(Rect2i(point, Vector2i(2, 2)), INK)
		else:
			bitmap.fill_rect(Rect2i(2, 2, 12, 12), INK)
		control.add_theme_icon_override("checked" if enabled else "unchecked", ImageTexture.create_from_image(bitmap))


func _build_cleanup() -> void:
	cleanup_root = Control.new()
	ui.add_child(cleanup_root)
	cleanup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cleanup_badge = _panel(cleanup_root, Rect2(572, 4, 136, 48), INK, GOLD)
	cleanup_title = _text(cleanup_badge, "最终清剿", Rect2(0, 2, 136, 16), 12, GOLD, true)
	cleanup_timer = _text(cleanup_badge, "10 s", Rect2(0, 17, 136, 28), 24, PAPER, true)
	var detail := _panel(cleanup_root, Rect2(480, 60, 320, 58), Color(0.035, 0.06, 0.054, 0.94), Color("756442"))
	cleanup_count = _text(detail, "剩余小 Boss  2", Rect2(12, 4, 296, 24), 16, PAPER, true)
	cleanup_note = _text(detail, "停止刷怪 · 清剿完成后结算", Rect2(12, 29, 296, 18), 12, MUTED, true)
	_line(detail, Rect2(12, 52, 296, 2), EDGE)
	cleanup_meter = _line(detail, Rect2(12, 52, 296, 2), GOLD)


func _show_cleanup(seconds: int, bosses: int) -> void:
	(battle.hud as BattleHud).wave_panel.hide()
	cleanup_root.show()
	var accent := URGENT if seconds <= 3 else GOLD
	cleanup_badge.add_theme_stylebox_override("panel", _box(INK, accent))
	cleanup_title.text = "最后 %d 秒" % seconds if seconds <= 3 else "最终清剿"
	cleanup_title.add_theme_color_override("font_color", accent)
	cleanup_timer.text = "%02d s" % seconds
	cleanup_timer.add_theme_color_override("font_color", accent)
	cleanup_count.text = "剩余小 Boss  %d" % bosses
	cleanup_note.text = "时间结束后进入理财" if seconds <= 3 else "停止刷怪 · 清剿完成后结算"
	cleanup_meter.size.x = 296.0 * seconds / 10.0
	cleanup_meter.color = accent


func _build_hints() -> void:
	hint_root = Control.new()
	ui.add_child(hint_root)
	hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_root.position = Vector2(0, 558)
	hint_title = _text(hint_root, "", Rect2(240, 0, 800, 20), 12, ICE, true)
	hint_row = HBoxContainer.new()
	hint_root.add_child(hint_row)
	hint_row.position = Vector2(240, 23)
	hint_row.size = Vector2(800, 28)
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 18)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _hint(key: String, meaning: String) -> void:
	var pair := HBoxContainer.new()
	hint_row.add_child(pair)
	pair.add_theme_constant_override("separation", 7)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := PanelContainer.new()
	pair.add_child(cap)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(Color(0.035, 0.055, 0.055, 0.92))
	style.content_margin_left = 7
	style.content_margin_right = 7
	cap.add_theme_stylebox_override("panel", style)
	_text(cap, key, Rect2(), 12, ICE)
	var label := _text(pair, meaning, Rect2(), 12, PAPER)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _update_hints(aiming: bool) -> void:
	mock_aiming = aiming and not mock_quick_cast
	for child in hint_row.get_children():
		hint_row.remove_child(child)
		child.queue_free()
	hint_title.text = "营地短刀 · 瞄准中" if mock_aiming else ""
	if mock_quick_cast:
		_hint("WASD / 方向键" if mock_keyboard else "右键", "移动")
		_hint("数字键", "直接施放")
		_hint("Esc", "暂停")
	elif mock_aiming:
		_hint("左键", "释放")
		_hint("右键", "取消瞄准" if mock_keyboard else "取消并移动")
		_hint("Esc", "取消瞄准")
	else:
		_hint("WASD / 方向键" if mock_keyboard else "右键", "移动")
		_hint("数字键", "按编号选择武器")
		_hint("Esc", "暂停")
	hint_root.visible = (hints_check == null or hints_check.button_pressed) and (settings_root == null or not settings_root.visible)


func _build_settings() -> void:
	settings_root = Control.new()
	ui.add_child(settings_root)
	settings_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := _line(settings_root, Rect2(0, 0, 1280, 720), Color(0.014, 0.022, 0.021, 0.78))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel = _panel(settings_root, Rect2(164, 79, 952, 562), Color("111b16"), Color("9a8149"))
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(settings_panel, Rect2(1, 1, 198, 560), Color("0e1913"), Color("0e1913"))
	_text(settings_panel, "设置", Rect2(28, 19, 144, 36), 24, GOLD)
	_line(settings_panel, Rect2(200, 24, 1, 514), Color("445044"))
	for i in 2:
		var tab := Button.new()
		settings_panel.add_child(tab)
		tab.position = Vector2(20, 98 + i * 60)
		tab.size = Vector2(160, 48)
		tab.text = "基础设置" if i == 0 else "战斗设置"
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 16)
		for state in ["hover", "pressed"]:
			var style := _box(Color("2b4035"), ICE)
			style.content_margin_left = 18
			tab.add_theme_stylebox_override(state, style)
		tab.pressed.connect(_select_settings_tab.bind(i == 1))
		settings_tabs.append(tab)
		settings_tab_marks.append(_line(tab, Rect2(0, 8, 3, 32), ICE))
	basic_settings_page = Control.new()
	settings_panel.add_child(basic_settings_page)
	basic_settings_page.position = Vector2(208, 0)
	basic_settings_page.size = Vector2(744, 478)
	basic_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text(basic_settings_page, "基础设置", Rect2(28, 19, 260, 36), 24, GOLD)
	_line(basic_settings_page, Rect2(28, 70, 688, 1), Color("445044"))
	combat_settings_page = Control.new()
	settings_panel.add_child(combat_settings_page)
	combat_settings_page.position = Vector2(208, 0)
	combat_settings_page.size = Vector2(744, 562)
	combat_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := combat_settings_page
	_text(content, "战斗设置", Rect2(28, 19, 260, 36), 24, GOLD)
	_line(content, Rect2(28, 70, 688, 1), Color("445044"))
	_text(content, "移动方式", Rect2(28, 86, 400, 24), 16)
	for i in 2:
		var button := Button.new()
		content.add_child(button)
		button.position = Vector2(28 + i * 352, 120)
		button.size = Vector2(336, 80)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_mock_mode.bind(i == 1))
		mode_buttons.append(button)
		_text(button, "鼠标右键" if i == 0 else "方向键 / WASD", Rect2(18, 10, 272, 28), 18)
		_text(button, "点击地面，移动至目的地" if i == 0 else "按住方向键，直接控制移动", Rect2(18, 43, 292, 22), 12, MUTED)
		mode_checks.append(_text(button, "●", Rect2(295, 12, 22, 24), 16, ICE, true))
	_text(content, "战斗操作", Rect2(28, 222, 650, 24), 16)
	var keys_text := ["数字键", "鼠标左键", "鼠标右键", "Esc"]
	var meanings := ["按武器栏编号选择，再次选武器会切换瞄准", "瞄准时确认施放；成功后退出瞄准", "取消瞄准并移动至目的地", "优先取消瞄准；未瞄准时打开暂停"]
	for i in 4:
		var y := 258.0 + i * 36
		var cap := _panel(content, Rect2(28, y, 100, 28), Color("1d2a23"), Color("4a5b4d"))
		_text(cap, keys_text[i], Rect2(0, 0, 100, 28), 12, PAPER, true)
		var description := _text(content, meanings[i], Rect2(144, y, 572, 28), 14, PAPER)
		if i == 0:
			selection_description = description
		if i == 1:
			left_click_description = description
			description.size.x = 426
			quick_cast_check = CheckBox.new()
			content.add_child(quick_cast_check)
			quick_cast_check.position = Vector2(580, y - 2)
			quick_cast_check.size = Vector2(136, 32)
			quick_cast_check.text = "快捷施法"
			quick_cast_check.button_pressed = false
			quick_cast_check.add_theme_font_size_override("font_size", 14)
			quick_cast_check.add_theme_color_override("font_color", ICE)
			_style_checkbox(quick_cast_check)
			quick_cast_check.toggled.connect(_set_mock_quick_cast)
		if i == 2:
			movement_description = description
	var note := _panel(content, Rect2(28, 414, 688, 48), Color("1b2923"), Color("35493b"))
	_line(note, Rect2(0, 0, 2, 48), GOLD)
	_text(note, "赤铜炉灯、坤舆秘仪书：按编号立即施放。", Rect2(16, 2, 650, 23), 12, PAPER)
	quick_note = _text(note, "快捷施法默认关闭：数字键瞄准，再点左键施放。", Rect2(16, 24, 650, 20), 12, MUTED)
	_line(settings_panel, Rect2(236, 482, 688, 1), Color("445044"))
	hints_check = CheckBox.new()
	content.add_child(hints_check)
	hints_check.position = Vector2(24, 499)
	hints_check.size = Vector2(300, 36)
	hints_check.text = "显示操作提示"
	hints_check.button_pressed = true
	hints_check.add_theme_font_size_override("font_size", 14)
	hints_check.add_theme_color_override("font_color", PAPER)
	_style_checkbox(hints_check)
	hints_check.toggled.connect(func(value: bool): hint_root.visible = value)
	_set_mock_mode(false)
	_set_mock_quick_cast(false)


func _set_mock_quick_cast(enabled: bool) -> void:
	mock_quick_cast = enabled
	quick_cast_check.set_pressed_no_signal(enabled)
	selection_description.text = "按编号直接施放，无需进入瞄准" if enabled else "按武器栏编号选择，再次选武器会切换瞄准"
	left_click_description.text = "无需点击左键确认" if enabled else "瞄准时确认施放；成功后退出瞄准"
	quick_note.text = "快捷施法已开启：数字键直接施放，不显示瞄准指示器。" if enabled else "快捷施法默认关闭：数字键瞄准，再点左键施放。"
	if enabled and indicator != null:
		indicator.hide()
	_update_hints(false)


func _set_mock_mode(keyboard: bool) -> void:
	mock_keyboard = keyboard
	for i in mode_buttons.size():
		var is_selected := (i == 1) == keyboard
		mode_buttons[i].add_theme_stylebox_override("normal", _box(Color("233830") if is_selected else Color("14221b"), ICE if is_selected else Color("425447"), 2 if is_selected else 1))
		mode_buttons[i].add_theme_stylebox_override("hover", _box(Color("2a3c33"), ICE))
		mode_buttons[i].add_theme_stylebox_override("pressed", _box(Color("30483c"), ICE))
		mode_checks[i].visible = is_selected
	movement_description.text = "取消瞄准；使用方向键 / WASD 移动" if keyboard else "取消瞄准并移动至目的地"
	_update_hints(mock_aiming)


func _prepare_proposed_layout() -> void:
	preview_frozen = true
	_cancel_aim()
	# Freeze the production HUD's visibility refresh while showing mock phases.
	var hud := battle.hud as BattleHud
	hud.set_process(false)
	var samples: Array[WeaponInstance] = [weapons[8], weapons[0], weapons[1], weapons[2], weapons[3], weapons[5]]
	bar.setup(samples)
	_apply_bar_padding()
	bar.update_slot(0, 0, 6, false, true)
	bar.update_slot(1, 0, 8, false, false)
	bar.update_slot(2, 3, 8, false, false)
	bar.update_slot(3, 7, 10, false, false)
	bar.update_slot(4, 0, 9, true, false)
	bar.update_slot(5, 0, 8, false, false)
	if hud._bond_row != null and hud._bond_row.is_visible_in_tree() and hud._bond_row.get_child_count() > 0:
		hint_root.position.y = bar.position.y - 99
	_update_hints(false)


func _capture_suite() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	preview_frozen = true
	_cancel_aim()
	# Existing eleven-weapon review with the requested text insets.
	bar.update_slot(0, 0, 6, false, true)
	bar.update_slot(1, 3, 8, false, false)
	bar.update_slot(2, 7, 10, false, false)
	bar.update_slot(3, 0, 9, true, false)
	await frames(6)
	await _save_frame("01_current_bottom_layout")
	_prepare_proposed_layout()
	await frames(5)
	_check(bar.numbers[4].get_theme_font_size("font_size") == bar.timers[4].get_theme_font_size("font_size"), "number and status share font size")
	await _save_frame("02_battle_controls")
	_show_cleanup(10, 2)
	await frames(3)
	await _save_frame("03_cleanup_10s")
	_show_cleanup(3, 1)
	_update_hints(true)
	indicator.global_position = player.global_position
	indicator.configure(weapons[8], Vector2(130, -20), true)
	indicator.show()
	await frames(3)
	await _save_frame("04_cleanup_3s_aiming")
	indicator.hide()
	cleanup_root.hide()
	(battle.hud as BattleHud).wave_panel.show()
	await _click_preview((battle.hud as BattleHud).settings_button)
	_check(flow.get_current_state() == MainFlowCoordinator.STATE_BATTLE_UTILITY, "real wrench opens existing settings")
	_check(settings_root.visible and basic_settings_page.visible and not combat_settings_page.visible, "settings defaults to basic tab")
	_check(battle.utility_overlay._settings.is_visible_in_tree(), "original volume and display controls visible in right pane")
	await _save_frame("08_settings_basic")
	await _click_preview(settings_tabs[1])
	_check(combat_settings_page.visible and not basic_settings_page.visible, "battle tab switches right pane")
	_check(not quick_cast_check.button_pressed, "quick cast defaults off")
	_set_mock_mode(false)
	await frames(3)
	await _save_frame("05_settings_mouse")
	await _click_preview(mode_buttons[1])
	await _save_frame("06_settings_keyboard")
	await _click_preview(settings_tabs[0])
	_check(basic_settings_page.visible and not combat_settings_page.visible, "basic tab restores volume and display pane")
	await _click_preview(settings_tabs[1])
	_check(mock_keyboard, "switching tabs retains preview choices")
	await _click_preview(settings_back)
	_check(flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT, "shared return restores combat directly")
	_update_hints(false)
	await frames(3)
	await _save_frame("07_keyboard_hints")
	await _click_preview((battle.hud as BattleHud).settings_button)
	_check(basic_settings_page.visible and not combat_settings_page.visible, "reopening settings defaults to basic tab")
	await _click_preview(settings_tabs[1])
	await _click_preview(mode_buttons[0])
	await _click_preview(quick_cast_check)
	_check(mock_quick_cast and quick_cast_check.button_pressed, "quick cast checked style and hints")
	await _save_frame("09_quick_cast_on")
	await _click_preview(settings_back)
	_update_hints(false)
	await frames(3)
	await _save_frame("10_quick_cast_hints")
	print("COMBAT_HUD_STYLE_REVIEW states=10 checks=", assertions, " failures=", failures.size(), " preview_only=true")
	game.queue_free()
	await frames(4)
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)


func _click_preview(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(1140, 680)
	Input.parse_input_event(motion)
	await frames(3)
