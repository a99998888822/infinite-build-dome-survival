extends Control
class_name CampBlueprintUIController

const BG_TOP := Color("#17110b")
const BG_BOTTOM := Color("#070a08")
const PANEL_GREEN := Color("#0d1c14")
const PANEL_GREEN_DARK := Color("#0a110c")
const PANEL_GOLD := Color("#8d6818")
const GOLD := Color("#d3a637")
const GOLD_BRIGHT := Color("#ffe18a")
const TEXT := Color("#d9d0af")
const MUTED := Color("#827a61")
const GREEN := Color("#70bf7d")
const RED := Color("#bd6a62")
const CYAN := Color("#8dbda0")
const TALENT_STATS_WITHOUT_PERCENT_SUFFIX: Dictionary = {
	"attack_speed": true,
}
const HIDDEN_BUILDING_IDS: Dictionary = {
	"camp_kin_nursery": true,
}

var _main_flow_coordinator: MainFlowCoordinator = null
var _selected_building_id := ""
var _building_list: VBoxContainer
var _detail_panel: VBoxContainer
var _summary_grid: GridContainer
var _options_list: VBoxContainer
var _currency_label: Label
var _detail_title: Label
var _detail_level: Label
var _detail_description: Label
var _detail_effects: VBoxContainer
var _options_count_label: Label
var _flash_overlay: ColorRect
var _flicker_time := 0.0
var _last_currency := -1
var _button_tweens: Dictionary = {}
var _upgrade_toast: Label = null
var _currency_tween: Tween = null
var _skip_next_option_animation := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	_bind_main_flow()
	if CampProgression != null and not CampProgression.state_changed.is_connected(_on_camp_state_changed):
		CampProgression.state_changed.connect(_on_camp_state_changed)
	_refresh_all()


func _process(delta: float) -> void:
	_flicker_time += delta
	queue_redraw()
	if _flash_overlay != null and _flash_overlay.modulate.a > 0.0:
		_flash_overlay.modulate.a = maxf(_flash_overlay.modulate.a - delta * 2.4, 0.0)


func _draw() -> void:
	var size := get_viewport_rect().size
	for index in range(24):
		var ratio := float(index) / 23.0
		var color := BG_TOP.lerp(BG_BOTTOM, ratio)
		draw_rect(Rect2(0, ratio * size.y, size.x, size.y / 23.0 + 1.0), color)
	for y in range(0, int(size.y), 4):
		var scan_alpha := 0.026 + 0.012 * sin(_flicker_time * 2.4 + float(y) * 0.12)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.0, 0.0, 0.0, scan_alpha), 1.0)
	for x in range(0, int(size.x), 6):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.13, 0.04, 0.012), 1.0)
	draw_rect(Rect2(8, 8, size.x - 16, size.y - 16), Color(PANEL_GOLD, 0.22), false, 1.0)


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 10)
	margin.add_child(root_column)

	var top_bar := _make_panel(PANEL_GREEN_DARK, PANEL_GOLD, 2)
	top_bar.custom_minimum_size.y = 50
	var top_bar_style := top_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if top_bar_style != null:
		top_bar_style.content_margin_top = 6
		top_bar_style.content_margin_bottom = 6
	root_column.add_child(top_bar)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_row)
	_currency_label = Label.new()
	_currency_label.custom_minimum_size.x = 190
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", 16)
	top_row.add_child(_currency_label)
	var title := Label.new()
	title.text = "营地搭建"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 23)
	top_row.add_child(title)
	var back_button := _make_compact_button("返回主界面", GREEN)
	back_button.custom_minimum_size = Vector2(120, 32)
	back_button.add_theme_font_size_override("font_size", 10)
	back_button.pressed.connect(_on_back_pressed)
	top_row.add_child(back_button)
	var reset_button := _make_compact_button("重置升级", RED)
	reset_button.custom_minimum_size = Vector2(98, 32)
	reset_button.add_theme_font_size_override("font_size", 10)
	reset_button.pressed.connect(_on_reset_pressed.bind(reset_button))
	top_row.add_child(reset_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root_column.add_child(body)

	var left_panel := _make_panel(PANEL_GREEN, PANEL_GOLD, 2)
	left_panel.custom_minimum_size.x = 238
	body.add_child(left_panel)
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_column)
	left_column.add_child(_make_header("营地建筑", "固定设施与成长入口"))
	var building_scroll := TouchScrollContainer.new()
	building_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	building_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_column.add_child(building_scroll)
	var building_content := MarginContainer.new()
	building_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_content.add_theme_constant_override("margin_left", 3)
	building_content.add_theme_constant_override("margin_right", 3)
	building_content.add_theme_constant_override("margin_top", 3)
	building_content.add_theme_constant_override("margin_bottom", 3)
	building_scroll.add_child(building_content)
	_building_list = VBoxContainer.new()
	_building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 7)
	building_content.add_child(_building_list)
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)
	var upper := HBoxContainer.new()
	upper.custom_minimum_size.y = 170
	upper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper.add_theme_constant_override("separation", 12)
	right_column.add_child(upper)
	var detail_panel := _make_panel(PANEL_GREEN, PANEL_GOLD, 2)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 3.0
	upper.add_child(detail_panel)
	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_constant_override("separation", 8)
	detail_panel.add_child(_detail_panel)
	var summary_panel := _make_panel(Color("#15120f"), PANEL_GOLD, 2)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_stretch_ratio = 2.0
	upper.add_child(summary_panel)
	var summary_content := VBoxContainer.new()
	summary_panel.add_child(summary_content)
	summary_content.add_child(_make_header("属性总览", "已应用的营地成长", 16, 9))
	var summary_scroll := TouchScrollContainer.new()
	summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_content.add_child(summary_scroll)
	_summary_grid = GridContainer.new()
	_summary_grid.columns = 2
	_summary_grid.add_theme_constant_override("h_separation", 6)
	_summary_grid.add_theme_constant_override("v_separation", 5)
	summary_scroll.add_child(_summary_grid)

	var options_panel := _make_panel(Color("#0d1513"), PANEL_GOLD, 2)
	options_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(options_panel)
	var options_column := VBoxContainer.new()
	options_column.add_theme_constant_override("separation", 6)
	options_panel.add_child(options_column)
	var options_header := HBoxContainer.new()
	options_column.add_child(options_header)
	options_header.add_child(_make_header("升级选项", "已解锁的属性成长"))
	_options_count_label = Label.new()
	_options_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_options_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_options_count_label.add_theme_color_override("font_color", MUTED)
	options_header.add_child(_options_count_label)
	var scroll := TouchScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	options_column.add_child(scroll)
	_options_list = VBoxContainer.new()
	_options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_options_list)

	_flash_overlay = ColorRect.new()
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.color = Color(1.0, 0.75, 0.2, 0.18)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.modulate.a = 0.0
	add_child(_flash_overlay)
	_add_scanline_overlay()
	_ensure_upgrade_toast()


func _add_scanline_overlay() -> void:
	var scanline_image := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	scanline_image.fill(Color.TRANSPARENT)
	scanline_image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.16))
	scanline_image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 0.16))
	var scanlines := TextureRect.new()
	scanlines.texture = ImageTexture.create_from_image(scanline_image)
	scanlines.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	scanlines.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scanlines.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scanlines.stretch_mode = TextureRect.STRETCH_TILE
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanlines.z_index = 1
	add_child(scanlines)


func _make_header(title_text: String, subtitle: String, title_font_size: int = 18, subtitle_font_size: int = 11) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", title_font_size)
	column.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_color_override("font_color", MUTED)
	sub.add_theme_font_size_override("font_size", subtitle_font_size)
	column.add_child(sub)
	return column


func _make_panel(color: Color, border: Color, border_width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	style.shadow_offset = Vector2(1, 2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", _button_style(Color("#17211d"), accent, 1))
	button.add_theme_stylebox_override("hover", _button_style(Color("#2b3020"), GOLD_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#473616"), GOLD_BRIGHT, 1, true))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#121513"), Color("#454238"), 1))
	_bind_button_feedback(button)
	return button


func _bind_button_feedback(button: Button) -> void:
	button.resized.connect(_center_button_pivot.bind(button))
	_center_button_pivot(button)
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.mouse_exited.connect(_on_button_unhovered.bind(button))


func _center_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _on_button_hovered(button: Button) -> void:
	if button.disabled:
		return
	_animate_button(button, Vector2(1.015, 1.015), Color(1.06, 1.04, 0.96, 1.0), 0.10)


func _on_button_unhovered(button: Button) -> void:
	_animate_button(button, Vector2.ONE, Color.WHITE, 0.12)


func _animate_button(button: Button, target_scale: Vector2, target_modulate: Color, duration: float) -> void:
	var old_tween: Tween = _button_tweens.get(button)
	if old_tween != null:
		old_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "scale", target_scale, duration)
	tween.tween_property(button, "modulate", target_modulate, duration)
	_button_tweens[button] = tween


func _make_compact_button(text_value: String, accent: Color) -> Button:
	var button := _make_button(text_value, accent)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _compact_button_style(Color("#17211d"), accent, 1))
	button.add_theme_stylebox_override("hover", _compact_button_style(Color("#2b3020"), GOLD_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", _compact_button_style(Color("#473616"), GOLD_BRIGHT, 1, true))
	button.add_theme_stylebox_override("disabled", _compact_button_style(Color("#121513"), Color("#454238"), 1))
	return button


func _button_style(color: Color, border: Color, width: int, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var light_edge := border.lightened(0.22)
	var dark_edge := color.darkened(0.70)
	style.border_color = dark_edge if pressed else light_edge
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.shadow_color = light_edge if pressed else dark_edge
	style.shadow_size = width
	style.shadow_offset = Vector2(width, width)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	style.content_margin_left = 10 + (width if pressed else 0)
	style.content_margin_right = 10
	style.content_margin_top = width if pressed else 0
	style.content_margin_bottom = 0
	return style


func _compact_button_style(color: Color, border: Color, width: int, pressed: bool = false) -> StyleBoxFlat:
	var style := _button_style(color, border, width, pressed)
	style.content_margin_left = 7 + (width if pressed else 0)
	style.content_margin_right = 7
	style.content_margin_top = 3 + (width if pressed else 0)
	style.content_margin_bottom = 3
	return style


func _bind_main_flow() -> void:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			_main_flow_coordinator = (current as GameRoot).get_main_flow_coordinator()
			break
		current = current.get_parent()
	if _main_flow_coordinator == null and get_tree().current_scene is GameRoot:
		_main_flow_coordinator = (get_tree().current_scene as GameRoot).get_main_flow_coordinator()
	if _main_flow_coordinator != null and not _main_flow_coordinator.mode_changed.is_connected(_on_mode_changed):
		_main_flow_coordinator.mode_changed.connect(_on_mode_changed)
	_on_mode_changed("", _main_flow_coordinator.get_current_mode() if _main_flow_coordinator != null else "")


func _on_mode_changed(_previous: String, current: String) -> void:
	if current == MainFlowCoordinator.MODE_TALENTS:
		show_talents_page()
	else:
		visible = false


func show_talents_page() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_to_front()
	queue_redraw()
	_refresh_all()


func _on_camp_state_changed() -> void:
	var skip_option_animation := _skip_next_option_animation
	_skip_next_option_animation = false
	if visible:
		_refresh_all(not skip_option_animation, false)


func _refresh_all(animate_option_rows: bool = true, animate_detail: bool = true) -> void:
	_refresh_currency()
	_refresh_buildings()
	_refresh_detail(animate_detail)
	_refresh_summary()
	_refresh_options(animate_option_rows)


func _refresh_currency() -> void:
	if _currency_label == null:
		return
	var value := CampProgression.get_camp_currency()
	var changed := _last_currency >= 0 and value != _last_currency
	_currency_label.text = "营地币：%d" % value
	_currency_label.add_theme_color_override("font_color", GOLD_BRIGHT if changed else GOLD)
	if changed:
		if _currency_tween != null and _currency_tween.is_valid():
			_currency_tween.kill()
		_currency_label.pivot_offset = _currency_label.size * 0.5
		_currency_tween = create_tween()
		_currency_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_currency_tween.tween_property(_currency_label, "scale", Vector2(1.12, 1.12), 0.12)
		_currency_tween.tween_property(_currency_label, "scale", Vector2.ONE, 0.18)
	_last_currency = value


func _refresh_buildings() -> void:
	if _building_list == null:
		return
	for child in _building_list.get_children():
		child.queue_free()
	var records := CampProgression.get_building_records()
	var first_visible_building_id := ""
	for record in records:
		if record is Dictionary:
			var record_id := str(record.get("id", ""))
			if not _is_building_hidden(record_id):
				first_visible_building_id = record_id
				break
	if _selected_building_id.is_empty() or _is_building_hidden(_selected_building_id):
		_selected_building_id = first_visible_building_id
	for record in records:
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if _is_building_hidden(building_id):
			continue
		var level := CampProgression.get_building_level(building_id)
		var unlocked := CampProgression.is_building_unlocked(building_id) or CampProgression.is_building_initially_unlocked(building_id)
		var button := _make_button("", GREEN if unlocked else MUTED)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = false
		var status := "Lv.%d" % level if unlocked else "未解锁"
		button.text = "⌂  %s\n    %s" % [str(record.get("name", building_id)), status]
		if building_id == _selected_building_id:
			button.add_theme_stylebox_override("normal", _button_style(Color("#2c2817"), GOLD_BRIGHT, 2))
		elif unlocked:
			button.add_theme_stylebox_override("normal", _button_style(Color("#14231a"), GREEN, 1))
		else:
			button.add_theme_color_override("font_color", MUTED)
			button.add_theme_stylebox_override("normal", _button_style(Color("#10110e"), Color("#4f493c"), 1))
		button.pressed.connect(_on_building_selected.bind(building_id))
		_building_list.add_child(button)


func _refresh_detail(animate_reveal: bool = true) -> void:
	if _detail_panel == null:
		return
	for child in _detail_panel.get_children():
		child.queue_free()
	var record := CampProgression.get_building_record(_selected_building_id)
	if record.is_empty():
		return
	var level := CampProgression.get_building_level(_selected_building_id)
	var unlocked := CampProgression.is_building_unlocked(_selected_building_id) or CampProgression.is_building_initially_unlocked(_selected_building_id)
	var max_level := CampProgression.get_building_max_level(_selected_building_id)
	var header := HBoxContainer.new()
	_detail_panel.add_child(header)
	_detail_title = Label.new()
	_detail_title.text = str(record.get("name", _selected_building_id))
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.clip_text = true
	_detail_title.add_theme_color_override("font_color", GOLD_BRIGHT)
	_detail_title.add_theme_font_size_override("font_size", 17)
	header.add_child(_detail_title)
	_detail_level = Label.new()
	_detail_level.text = "Lv.%d / %d" % [level, max_level] if unlocked else "未解锁"
	_detail_level.add_theme_color_override("font_color", GREEN if unlocked else RED)
	_detail_level.add_theme_font_size_override("font_size", 12)
	header.add_child(_detail_level)
	_detail_description = Label.new()
	_detail_description.text = str(record.get("description", ""))
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.add_theme_color_override("font_color", TEXT)
	_detail_description.add_theme_font_size_override("font_size", 12)
	_detail_panel.add_child(_detail_description)
	_detail_effects = VBoxContainer.new()
	_detail_effects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(_detail_effects)
	var effect_title := Label.new()
	effect_title.text = "建筑等级收益"
	effect_title.add_theme_color_override("font_color", CYAN)
	effect_title.add_theme_font_size_override("font_size", 12)
	_detail_effects.add_child(effect_title)
	var levels: Variant = record.get("levels", {})
	if levels is Dictionary:
		for level_key in levels.keys():
			if int(str(level_key)) > max_level:
				continue
			var effects := Label.new()
			var effect_names: Array[String] = []
			for effect in levels[level_key]:
				if effect is Dictionary:
					effect_names.append(str(effect.get("name", "")))
			effects.text = "Lv.%s  %s" % [str(level_key), "；".join(effect_names)]
			effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			effects.add_theme_color_override("font_color", GREEN if int(str(level_key)) <= level else MUTED)
			effects.add_theme_font_size_override("font_size", 11)
			_detail_effects.add_child(effects)
	var action_row := HBoxContainer.new()
	_detail_panel.add_child(action_row)
	if animate_reveal:
		_animate_detail_reveal()
	if unlocked and level >= max_level:
		var max_label := Label.new()
		max_label.text = "已达最高等级"
		max_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		max_label.add_theme_font_size_override("font_size", 12)
		_detail_panel.add_child(max_label)
	if not unlocked:
		var unlock_condition: Variant = record.get("unlock_condition", {})
		var unlock_cost := int((unlock_condition as Dictionary).get("cost", 0)) if unlock_condition is Dictionary else 0
		var unlock := _make_compact_button("解锁营地（%d 营地币）" % unlock_cost, GOLD)
		unlock.disabled = not CampProgression.can_purchase_building_unlock(_selected_building_id)
		unlock.pressed.connect(_on_unlock_pressed.bind(unlock))
		action_row.add_child(unlock)
	elif level < max_level:
		var cost := CampProgression.get_building_upgrade_cost(_selected_building_id, level + 1)
		var upgrade := _make_compact_button("升级至 Lv.%d（%d 营地币）" % [level + 1, cost], GOLD)
		upgrade.disabled = not CampProgression.can_purchase_building_upgrade(_selected_building_id)
		upgrade.pressed.connect(_on_building_upgrade_pressed.bind(upgrade))
		action_row.add_child(upgrade)


func _refresh_summary() -> void:
	if _summary_grid == null:
		return
	for child in _summary_grid.get_children():
		child.queue_free()
	var modifiers := CampProgression.get_outgame_modifiers()
	var totals: Dictionary = {}
	for modifier in modifiers:
		if not (modifier is Dictionary):
			continue
		var stat := str(modifier.get("stat", ""))
		if stat.is_empty() or not StatDefinitions.has_stat(stat):
			continue
		var value := float(modifier.get("value", 0.0))
		if is_zero_approx(value):
			continue
		totals[stat] = float(totals.get(stat, 0.0)) + value
	var shown := 0
	var stat_ids: Array[String] = []
	for stat in totals.keys():
		stat_ids.append(str(stat))
	stat_ids.sort()
	for stat in stat_ids:
		var value := float(totals[stat])
		var label := Label.new()
		label.text = "%s  %s" % [StatDefinitions.get_display_name(stat), _format_summary_value(stat, value)]
		label.add_theme_color_override("font_color", GOLD_BRIGHT)
		label.add_theme_font_size_override("font_size", 13)
		label.tooltip_text = StatDefinitions.get_description(stat)
		_summary_grid.add_child(label)
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "\u5c1a\u65e0\u5df2\u5e94\u7528\u5c5e\u6027"
		empty.add_theme_color_override("font_color", MUTED)
		empty.add_theme_font_size_override("font_size", 10)
		_summary_grid.add_child(empty)


func _format_summary_value(stat: String, value: float) -> String:
	return _format_modifier_value(stat, value)


func _format_upgrade_effect(option: Dictionary) -> String:
	var stat := str(option.get("stat", ""))
	var stat_name := StatDefinitions.get_display_name(stat) if StatDefinitions.has_stat(stat) else stat
	return "每级 %s%s" % [stat_name, _format_modifier_value(stat, float(option.get("value_per_level", 0.0)))]


func _format_modifier_value(stat: String, value: float) -> String:
	var sign := "+" if value >= 0.0 else ""
	var suffix := "%" if StatDefinitions.is_percent_stat(stat) and not TALENT_STATS_WITHOUT_PERCENT_SUFFIX.has(stat) else ""
	return "%s%s%s" % [sign, _format_compact_number(value), suffix]


func _format_compact_number(value: float) -> String:
	var rounded_value := roundi(value)
	if is_equal_approx(value, float(rounded_value)):
		return "%d" % rounded_value
	return "%.2f" % value


func _refresh_options(animate_rows: bool = true) -> void:
	if _options_list == null:
		return
	for child in _options_list.get_children():
		child.queue_free()
	var total := 0
	var records := CampProgression.get_building_records()
	for record in records:
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if _is_building_hidden(building_id):
			continue
		var building_level := CampProgression.get_building_level(building_id)
		var unlocked := CampProgression.is_building_unlocked(building_id) or CampProgression.is_building_initially_unlocked(building_id)
		if not unlocked:
			continue
		var options := []
		for option in record.get("upgrade_options", []):
			if not (option is Dictionary):
				continue
			if _is_upgrade_option_unlocked(building_level, option):
				options.append(option)
		if options.is_empty():
			continue
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		var group_title := Label.new()
		group_title.text = "%s  ·  Lv.%d" % [str(record.get("name", building_id)), building_level]
		group_title.add_theme_color_override("font_color", CYAN if building_id == _selected_building_id else GOLD)
		group_title.add_theme_font_size_override("font_size", 12)
		group.add_child(group_title)
		for option in options:
			var option_row := _make_option_row(building_id, option)
			group.add_child(option_row)
			if animate_rows:
				_animate_option_row(option_row, total)
			total += 1
		_options_list.add_child(group)
	_options_count_label.text = "已解锁 %d 项" % total


func _animate_option_row(option_row: Control, index: int) -> void:
	if option_row == null:
		return
	option_row.modulate.a = 0.0
	option_row.position.x += 8.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(option_row, "modulate:a", 1.0, 0.18).set_delay(index * 0.035)
	tween.parallel().tween_property(option_row, "position:x", option_row.position.x - 8.0, 0.22).set_delay(index * 0.035)


func _is_upgrade_option_unlocked(building_level: int, option: Dictionary) -> bool:
	return building_level >= int(option.get("required_building_level", 1))


func _is_building_hidden(building_id: String) -> bool:
	return HIDDEN_BUILDING_IDS.has(building_id)


func _make_option_row(building_id: String, option: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _option_row_style())
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	var option_id := str(option.get("id", ""))
	var current := CampProgression.get_upgrade_option_level(option_id)
	var max_level := int(option.get("max_level", 1))
	var name_label := Label.new()
	name_label.text = str(option.get("name", option_id))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 11)
	info.add_child(name_label)
	var progress := Label.new()
	progress.text = "Lv.%d / %d    %s" % [current, max_level, _format_upgrade_effect(option)]
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress.add_theme_color_override("font_color", GOLD)
	progress.add_theme_font_size_override("font_size", 10)
	info.add_child(progress)
	var progress_bar := ProgressBar.new()
	progress_bar.max_value = max_level
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 5)
	progress_bar.add_theme_stylebox_override("background", _progress_style(Color("#080b09"), Color("#4d442c")))
	progress_bar.add_theme_stylebox_override("fill", _progress_style(GREEN.lerp(GOLD, 0.35), GOLD))
	info.add_child(progress_bar)
	var progress_tween := create_tween()
	progress_tween.tween_property(progress_bar, "value", current, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	line.add_child(info)
	var buy := _make_compact_button("购买 %d" % CampProgression.get_upgrade_cost(option_id), GOLD)
	buy.custom_minimum_size = Vector2(68, 26)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = not CampProgression.can_purchase_upgrade(option_id)
	buy.pressed.connect(_on_option_pressed.bind(option_id, buy))
	line.add_child(buy)
	return row


func _option_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111714")
	style.border_color = Color("#59441f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _progress_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	return style


func _on_building_selected(building_id: String) -> void:
	_selected_building_id = building_id
	_refresh_all(true, false)
	_animate_detail_reveal()
	if AudioManager != null:
		AudioManager.play_ui_sfx("modal_open")


func _on_unlock_pressed(source_button: Button) -> void:
	if CampProgression.purchase_building_unlock(_selected_building_id):
		_play_purchase_feedback(source_button, "建筑已解锁")
	else:
		_play_purchase_error(source_button)


func _on_building_upgrade_pressed(source_button: Button) -> void:
	var old_level := CampProgression.get_building_level(_selected_building_id)
	if CampProgression.upgrade_building(_selected_building_id):
		var new_level := CampProgression.get_building_level(_selected_building_id)
		_play_purchase_feedback(source_button, "Lv.%d  →  Lv.%d" % [old_level, new_level])
	else:
		_play_purchase_error(source_button)


func _on_option_pressed(option_id: String, source_button: Button) -> void:
	var old_level := CampProgression.get_upgrade_option_level(option_id)
	if CampProgression.purchase_upgrade(option_id):
		var new_level := CampProgression.get_upgrade_option_level(option_id)
		_play_purchase_feedback(source_button, "属性升级  Lv.%d  →  Lv.%d" % [old_level, new_level])
	else:
		_play_purchase_error(source_button)


func _on_reset_pressed(source_button: Button) -> void:
	_skip_next_option_animation = true
	CampProgression.reset_upgrade_options_and_refund()
	_play_purchase_feedback(source_button, "升级已重置", false)


func _play_purchase_feedback(source_button: Control, message: String = "升级已生效", show_coin_particles: bool = true) -> void:
	if _flash_overlay != null:
		_flash_overlay.modulate.a = 0.22
	var origin := source_button.get_global_rect().get_center()
	if show_coin_particles:
		for index in range(9):
			var coin := Label.new()
			coin.text = "●"
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			coin.add_theme_color_override("font_color", GOLD_BRIGHT)
			coin.add_theme_font_size_override("font_size", 10 + (index % 3) * 2)
			coin.position = origin + Vector2((index - 4) * 2, (index % 3 - 1) * 2)
			add_child(coin)
			var target := origin + Vector2((index - 4) * 15, -34.0 - (index % 3) * 13)
			var tween := create_tween()
			tween.set_parallel(false)
			tween.tween_property(coin, "position", target, 0.34 + index * 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(coin, "modulate:a", 0.0, 0.16)
			tween.tween_callback(coin.queue_free)
	_show_upgrade_toast(message, origin)
	if AudioManager != null:
		AudioManager.play_ui_sfx("purchase_success")


func _play_purchase_error(source_button: Control) -> void:
	var tween := create_tween()
	tween.tween_property(source_button, "position:x", source_button.position.x - 4.0, 0.04)
	tween.tween_property(source_button, "position:x", source_button.position.x + 4.0, 0.08)
	tween.tween_property(source_button, "position:x", source_button.position.x, 0.06)
	if AudioManager != null:
		AudioManager.play_ui_sfx("purchase_error")


func _ensure_upgrade_toast() -> void:
	if _upgrade_toast != null:
		return
	_upgrade_toast = Label.new()
	_upgrade_toast.name = "UpgradeToast"
	_upgrade_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_toast.add_theme_color_override("font_color", GOLD_BRIGHT)
	_upgrade_toast.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.025, 0.95))
	_upgrade_toast.add_theme_constant_override("outline_size", 1)
	_upgrade_toast.add_theme_font_size_override("font_size", 9)
	_upgrade_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_toast.modulate.a = 0.0
	_upgrade_toast.size = Vector2(220, 20)
	add_child(_upgrade_toast)


func _show_upgrade_toast(message: String, origin: Vector2) -> void:
	if _upgrade_toast == null:
		return
	_upgrade_toast.text = message
	_upgrade_toast.position = origin - Vector2(_upgrade_toast.size.x * 0.5, 32.0)
	_upgrade_toast.modulate.a = 0.0
	_upgrade_toast.scale = Vector2(0.94, 0.94)
	_upgrade_toast.pivot_offset = _upgrade_toast.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_upgrade_toast, "position:y", _upgrade_toast.position.y - 16.0, 0.30)
	tween.tween_property(_upgrade_toast, "modulate:a", 1.0, 0.12)
	tween.tween_property(_upgrade_toast, "scale", Vector2.ONE, 0.15)
	tween.chain().tween_property(_upgrade_toast, "modulate:a", 0.0, 0.22).set_delay(0.42)


func _animate_detail_reveal() -> void:
	if _detail_panel == null:
		return
	_detail_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_detail_panel, "modulate:a", 1.0, 0.24)


func _on_back_pressed() -> void:
	if _main_flow_coordinator == null:
		_bind_main_flow()
	if _main_flow_coordinator != null:
		_main_flow_coordinator.enter_start_page()
	visible = false
	var game_root: GameRoot = null
	if get_tree() != null:
		game_root = get_tree().current_scene as GameRoot
	if game_root != null:
		var main_menu := game_root.get_node_or_null("UiRoot/MainMenuUIController") as MainMenuUIController
		if main_menu != null:
			main_menu.show_start_page()
