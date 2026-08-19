extends Control
class_name CampBlueprintUIController

const BG_TOP := Color("#0b1514")
const BG_BOTTOM := Color("#241712")
const PANEL_GREEN := Color("#10251f")
const PANEL_GREEN_DARK := Color("#071512")
const PANEL_GOLD := Color("#7d5b17")
const GOLD := Color("#e8b63d")
const GOLD_BRIGHT := Color("#ffe48a")
const TEXT := Color("#e1d5a7")
const MUTED := Color("#8d8871")
const GREEN := Color("#76d28b")
const RED := Color("#b76b67")
const CYAN := Color("#6eafa2")

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
var _coin_target: Control
var _flicker_time := 0.0
var _last_currency := -1


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
	var split := size.y / 2.0
	for index in range(18):
		var ratio := float(index) / 17.0
		var color := BG_TOP.lerp(BG_BOTTOM, ratio)
		draw_rect(Rect2(0, ratio * size.y, size.x, size.y / 17.0 + 2.0), color)
	for y in range(0, int(size.y), 5):
		var scan_alpha := 0.035 + 0.018 * sin(_flicker_time * 7.0 + float(y) * 0.09)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.02, 0.02, 0.01, scan_alpha), 1.0)
	draw_line(Vector2(0, split), Vector2(size.x, split), Color(0.85, 0.57, 0.16, 0.04), 1.0)


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 14)
	margin.add_child(root_column)

	var top_bar := _make_panel(PANEL_GREEN_DARK, PANEL_GOLD, 2)
	top_bar.custom_minimum_size.y = 64
	root_column.add_child(top_bar)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_row)
	_currency_label = Label.new()
	_currency_label.custom_minimum_size.x = 230
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", 22)
	top_row.add_child(_currency_label)
	var title := Label.new()
	title.text = "营地搭建"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 32)
	top_row.add_child(title)
	var back_button := _make_button("返回主界面", GREEN)
	back_button.custom_minimum_size = Vector2(150, 42)
	back_button.pressed.connect(_on_back_pressed)
	top_row.add_child(back_button)
	var reset_button := _make_button("重置升级", RED)
	reset_button.custom_minimum_size = Vector2(120, 42)
	reset_button.pressed.connect(_on_reset_pressed)
	top_row.add_child(reset_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_column.add_child(body)

	var left_panel := _make_panel(PANEL_GREEN, PANEL_GOLD, 2)
	left_panel.custom_minimum_size.x = 265
	body.add_child(left_panel)
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_column)
	left_column.add_child(_make_header("营地建筑", "固定设施与成长入口"))
	_building_list = VBoxContainer.new()
	_building_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_building_list.add_theme_constant_override("separation", 7)
	left_column.add_child(_building_list)
	var left_hint := Label.new()
	left_hint.text = "穹顶之下，真相渐显。"
	left_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_hint.add_theme_color_override("font_color", MUTED)
	left_column.add_child(left_hint)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 14)
	body.add_child(right_column)

	var upper := HBoxContainer.new()
	upper.custom_minimum_size.y = 198
	upper.add_theme_constant_override("separation", 14)
	right_column.add_child(upper)
	var detail_panel := _make_panel(PANEL_GREEN, PANEL_GOLD, 2)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper.add_child(detail_panel)
	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 8)
	detail_panel.add_child(_detail_panel)
	var summary_panel := _make_panel(Color("#15120f"), PANEL_GOLD, 2)
	summary_panel.custom_minimum_size.x = 310
	upper.add_child(summary_panel)
	var summary_column := VBoxContainer.new()
	summary_panel.add_child(summary_column)
	summary_column.add_child(_make_header("属性总览", "已应用的营地成长"))
	_summary_grid = GridContainer.new()
	_summary_grid.columns = 2
	_summary_grid.add_theme_constant_override("h_separation", 8)
	_summary_grid.add_theme_constant_override("v_separation", 8)
	summary_column.add_child(_summary_grid)

	var options_panel := _make_panel(Color("#0d1513"), PANEL_GOLD, 2)
	options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(options_panel)
	var options_column := VBoxContainer.new()
	options_column.add_theme_constant_override("separation", 8)
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
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_column.add_child(scroll)
	_options_list = VBoxContainer.new()
	_options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_options_list)

	_flash_overlay = ColorRect.new()
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.color = Color(1.0, 0.75, 0.2, 0.18)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.modulate.a = 0.0
	add_child(_flash_overlay)


func _make_header(title_text: String, subtitle: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_color_override("font_color", MUTED)
	sub.add_theme_font_size_override("font_size", 11)
	column.add_child(sub)
	return column


func _make_panel(color: Color, border: Color, border_width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
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
	button.add_theme_stylebox_override("pressed", _button_style(Color("#473616"), GOLD_BRIGHT, 2))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#121513"), Color("#454238"), 1))
	return button


func _button_style(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
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
	visible = current == MainFlowCoordinator.MODE_CAMP
	if visible:
		_refresh_all()


func _on_camp_state_changed() -> void:
	if visible:
		_refresh_all()


func _refresh_all() -> void:
	_refresh_currency()
	_refresh_buildings()
	_refresh_detail()
	_refresh_summary()
	_refresh_options()


func _refresh_currency() -> void:
	if _currency_label == null:
		return
	var value := CampProgression.get_camp_currency()
	_currency_label.text = "营地币：%d" % value
	_currency_label.add_theme_color_override("font_color", GOLD_BRIGHT if value != _last_currency else GOLD)
	_last_currency = value


func _refresh_buildings() -> void:
	if _building_list == null:
		return
	for child in _building_list.get_children():
		child.queue_free()
	var records := CampProgression.get_building_records()
	if _selected_building_id.is_empty() and not records.is_empty():
		_selected_building_id = str(records[0].get("id", ""))
	for record in records:
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		var level := CampProgression.get_building_level(building_id)
		var unlocked := CampProgression.is_building_unlocked(building_id) or CampProgression.is_building_initially_unlocked(building_id)
		var button := _make_button("", GREEN if unlocked else MUTED)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 56
		button.disabled = false
		var status := "Lv.%d" % level if unlocked else "未解锁"
		button.text = "⌂  %s\n    %s" % [str(record.get("name", building_id)), status]
		if building_id == _selected_building_id:
			button.add_theme_stylebox_override("normal", _button_style(Color("#263524"), GOLD_BRIGHT, 2))
		button.pressed.connect(_on_building_selected.bind(building_id))
		_building_list.add_child(button)


func _refresh_detail() -> void:
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
	_detail_title.add_theme_color_override("font_color", GOLD_BRIGHT)
	_detail_title.add_theme_font_size_override("font_size", 21)
	header.add_child(_detail_title)
	_detail_level = Label.new()
	_detail_level.text = "Lv.%d / %d" % [level, max_level] if unlocked else "未解锁"
	_detail_level.add_theme_color_override("font_color", GREEN if unlocked else RED)
	header.add_child(_detail_level)
	_detail_description = Label.new()
	_detail_description.text = str(record.get("description", ""))
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.add_theme_color_override("font_color", TEXT)
	_detail_panel.add_child(_detail_description)
	_detail_effects = VBoxContainer.new()
	_detail_effects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(_detail_effects)
	var effect_title := Label.new()
	effect_title.text = "建筑等级收益"
	effect_title.add_theme_color_override("font_color", CYAN)
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
			effects.add_theme_color_override("font_color", GREEN if int(str(level_key)) <= level else MUTED)
			_detail_effects.add_child(effects)
	var action_row := HBoxContainer.new()
	_detail_panel.add_child(action_row)
	if not unlocked:
		var unlock_condition: Variant = record.get("unlock_condition", {})
		var unlock_cost := int((unlock_condition as Dictionary).get("cost", 0)) if unlock_condition is Dictionary else 0
		var unlock := _make_button("解锁营地（%d 营地币）" % unlock_cost, GOLD)
		unlock.disabled = not CampProgression.can_purchase_building_unlock(_selected_building_id)
		unlock.pressed.connect(_on_unlock_pressed)
		action_row.add_child(unlock)
	elif level < max_level:
		var cost := CampProgression.get_building_upgrade_cost(_selected_building_id, level + 1)
		var upgrade := _make_button("升级至 Lv.%d（%d 营地币）" % [level + 1, cost], GOLD)
		upgrade.disabled = not CampProgression.can_purchase_building_upgrade(_selected_building_id)
		upgrade.pressed.connect(_on_building_upgrade_pressed)
		action_row.add_child(upgrade)


func _refresh_summary() -> void:
	if _summary_grid == null:
		return
	for child in _summary_grid.get_children():
		child.queue_free()
	var modifiers := CampProgression.get_outgame_modifiers()
	var totals := {}
	for modifier in modifiers:
		if modifier is Dictionary:
			var stat := str(modifier.get("stat", ""))
			totals[stat] = float(totals.get(stat, 0.0)) + float(modifier.get("value", 0.0))
	var shown := 0
	for stat in ["damage_percent", "attack_speed", "melee_damage", "ranged_damage", "max_hp", "armor", "luck", "drop_rate_percent"]:
		if not totals.has(stat) or is_zero_approx(float(totals[stat])):
			continue
		var label := Label.new()
		label.text = "%s  %+g" % [StatDefinitions.get_display_name(stat), totals[stat]]
		label.add_theme_color_override("font_color", GOLD_BRIGHT)
		_summary_grid.add_child(label)
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "尚无已应用属性"
		empty.add_theme_color_override("font_color", MUTED)
		_summary_grid.add_child(empty)


func _refresh_options() -> void:
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
		var building_level := CampProgression.get_building_level(building_id)
		var unlocked := CampProgression.is_building_unlocked(building_id) or CampProgression.is_building_initially_unlocked(building_id)
		if not unlocked:
			continue
		var options := []
		for option in record.get("upgrade_options", []):
			if not (option is Dictionary):
				continue
			var required := int(option.get("required_building_level", 1))
			if building_level >= required:
				options.append(option)
		if options.is_empty():
			continue
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 5)
		var group_title := Label.new()
		group_title.text = "%s  ·  Lv.%d" % [str(record.get("name", building_id)), building_level]
		group_title.add_theme_color_override("font_color", CYAN if building_id == _selected_building_id else GOLD)
		group.add_child(group_title)
		for option in options:
			group.add_child(_make_option_row(building_id, option))
			total += 1
		_options_list.add_child(group)
	_options_count_label.text = "已解锁 %d 项" % total


func _make_option_row(building_id: String, option: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _button_style(Color("#111714"), Color("#59441f"), 1))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var option_id := str(option.get("id", ""))
	var current := CampProgression.get_upgrade_option_level(option_id)
	var max_level := int(option.get("max_level", 1))
	var name_label := Label.new()
	name_label.text = str(option.get("name", option_id))
	name_label.add_theme_color_override("font_color", TEXT)
	info.add_child(name_label)
	var progress := Label.new()
	progress.text = "Lv.%d / %d    每级 +%s" % [current, max_level, str(option.get("value_per_level", 0))]
	progress.add_theme_color_override("font_color", GOLD)
	info.add_child(progress)
	line.add_child(info)
	var buy := _make_button("购买 %d" % CampProgression.get_upgrade_cost(option_id), GOLD)
	buy.disabled = not CampProgression.can_purchase_upgrade(option_id)
	buy.pressed.connect(_on_option_pressed.bind(option_id))
	line.add_child(buy)
	return row


func _on_building_selected(building_id: String) -> void:
	_selected_building_id = building_id
	_refresh_all()


func _on_unlock_pressed() -> void:
	if CampProgression.purchase_building_unlock(_selected_building_id):
		_play_purchase_feedback()


func _on_building_upgrade_pressed() -> void:
	if CampProgression.upgrade_building(_selected_building_id):
		_play_purchase_feedback()


func _on_option_pressed(option_id: String) -> void:
	if CampProgression.purchase_upgrade(option_id):
		_play_purchase_feedback()


func _on_reset_pressed() -> void:
	CampProgression.reset_upgrade_options_and_refund()
	_play_purchase_feedback()


func _play_purchase_feedback() -> void:
	if _flash_overlay != null:
		_flash_overlay.modulate.a = 0.22
	for index in range(9):
		var coin := Label.new()
		coin.text = "●"
		coin.add_theme_color_override("font_color", GOLD_BRIGHT)
		coin.add_theme_font_size_override("font_size", 14 + (index % 3) * 3)
		coin.position = Vector2(350 + index * 22, 120 + (index % 4) * 12)
		add_child(coin)
		var target := Vector2(90, 35)
		var tween := create_tween()
		tween.set_parallel(false)
		tween.tween_property(coin, "position", target + Vector2(index * 2, 0), 0.45 + index * 0.025).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(coin, "modulate:a", 0.0, 0.14)
		tween.tween_callback(coin.queue_free)


func _on_back_pressed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.enter_start_page()
