extends Control
class_name CampBlueprintUIController

const NODE_BACKGROUND = preload("res://assets/ui/talents/icon_background.png")
const HUD_BACKGROUND = preload("res://assets/ui/talents/hud_background.png")
const HUD_BORDER_BACKGROUND = preload("res://assets/ui/talents/hud_border_background.png")
const UPGRADE_ARROW = preload("res://assets/ui/talents/upgrade_arrow.png")
const PIXEL_FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const PAGE_FRAME = preload("res://scripts/ui/talent_page_frame.gd")
const TEXT := Color("d1c5ac")
const GOLD := Color("d9b978")
const MUTED := Color("86808a")

var _main_flow_coordinator: MainFlowCoordinator
var _content: Control
var _tree: TalentTreeCanvas
var _nodes: Dictionary = {}
var _records: Dictionary = {}
var _node_labels: Dictionary = {}
var _node_levels: Dictionary = {}
var _summary_values: Dictionary = {}
var _summary_panel: Panel
var _summary_title: Label
var _summary_empty: Label
var _detail_panel: Panel
var _detail_title: Label
var _detail_effect: Label
var _detail_next: Label
var _detail_cost: Label
var _currency_label: Label
var _reset_button: Button
var _back_button: Button
var _hint: Label
var _upgrade_button: TextureButton
var _upgrade_tooltip: Panel
var _upgrade_tooltip_text: Label
var _selected_id := ""
var _zoom := 0.8
var _pan := Vector2.ZERO
var _density := 1.0
var _dragging := false
var _drag_button := MOUSE_BUTTON_NONE
var _layout_initialized := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_interface()
	_bind_main_flow.call_deferred()
	get_viewport().size_changed.connect(_layout_content)
	CampProgression.state_changed.connect(_refresh_all)
	L10n.locale_changed.connect(_refresh_all)
	_layout_content()
	_refresh_all()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("100f14"))
	for y in range(0, int(size.y), 8):
		draw_rect(Rect2(0, y, size.x, 1), Color(0.16, 0.14, 0.18, 0.12))


func _build_interface() -> void:
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_tree = TalentTreeCanvas.new()
	_content.add_child(_tree)
	for building in CampProgression.get_building_records():
		_add_node(building, true)
		for option in building.get("upgrade_options", []): _add_node(option, false)
	_upgrade_button = TextureButton.new()
	_upgrade_button.texture_normal = UPGRADE_ARROW
	_upgrade_button.texture_disabled = TalentNodeButton._grayscale(UPGRADE_ARROW)
	_upgrade_button.ignore_texture_size = true
	_upgrade_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_upgrade_button.size = Vector2(16, 17)
	_upgrade_button.focus_mode = Control.FOCUS_NONE
	_upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_upgrade_button.pressed.connect(_purchase_selected)
	_upgrade_button.gui_input.connect(_on_node_input.bind(_upgrade_button))
	_upgrade_button.mouse_entered.connect(_show_upgrade_tooltip)
	_upgrade_button.mouse_exited.connect(_hide_upgrade_tooltip)
	_tree.add_child(_upgrade_button)
	_upgrade_button.visible = false
	_detail_panel = _panel()
	_content.add_child(_detail_panel)
	_detail_title = _label(16, GOLD)
	_detail_effect = _label(12, TEXT)
	_detail_next = _label(12, GOLD)
	_detail_cost = _label(12, GOLD)
	for label in [_detail_title, _detail_effect, _detail_next, _detail_cost]: _detail_panel.add_child(label)
	_detail_title.position = Vector2(18, 14)
	_detail_effect.position = Vector2(18, 42)
	_detail_next.position = Vector2(18, 64)
	_detail_cost.position = Vector2(18, 90)
	_summary_panel = _panel()
	_content.add_child(_summary_panel)
	_summary_title = _label(16, GOLD)
	_summary_title.position = Vector2(16, 14)
	_summary_panel.add_child(_summary_title)
	_summary_empty = _label(12, MUTED)
	_summary_empty.position = Vector2(16, 52)
	_summary_panel.add_child(_summary_empty)
	_currency_label = _label(20, GOLD)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_currency_label)
	var index := 0
	for building in CampProgression.get_building_records():
		for option in building.get("upgrade_options", []):
			var row := _label(12, MUTED)
			row.position = Vector2(16 + floori(index / 14.0) * 142, 52 + (index % 14) * 20)
			row.size = Vector2(140, 20)
			_summary_panel.add_child(row)
			_summary_values[str(option.stat)] = row
			index += 1
	_reset_button = _button("", 12)
	_reset_button.pressed.connect(_on_reset_pressed)
	_content.add_child(_reset_button)
	_back_button = _button("", 14)
	_back_button.pressed.connect(_on_back_pressed)
	_content.add_child(_back_button)
	_hint = _label(12, MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_content.add_child(_hint)
	# A local hover panel appears immediately, independent of the global tooltip delay.
	_upgrade_tooltip = _panel()
	_upgrade_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_tooltip.z_index = 10
	_upgrade_tooltip.visible = false
	_upgrade_tooltip_text = _label(12, GOLD)
	_upgrade_tooltip_text.position = Vector2(12, 8)
	_upgrade_tooltip.add_child(_upgrade_tooltip_text)
	_content.add_child(_upgrade_tooltip)
	var page_frame := Control.new()
	page_frame.set_script(PAGE_FRAME)
	page_frame.name = "PageFrame"
	page_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_frame.z_index = 20
	add_child(page_frame)
	page_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _add_node(record: Dictionary, building: bool) -> void:
	var id := str(record.id)
	var node := TalentNodeButton.new()
	node.configure(record, building, NODE_BACKGROUND)
	node.name = id
	var extent := 104.0 if building else 84.0
	node.size = Vector2.ONE * extent
	var point: Array = record.get("tree_position", [0, 0])
	node.position = Vector2(float(point[0]), float(point[1])) - node.size / 2.0
	node.pressed.connect(select_node.bind(id))
	node.gui_input.connect(_on_node_input.bind(node))
	_tree.add_child(node)
	_nodes[id] = node
	_records[id] = record
	var caption := _label(12, TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, extent + 6)
	node.add_child(caption)
	_node_labels[id] = caption
	var level := _label(18, TEXT)
	level.add_theme_color_override("font_outline_color", Color("100f14"))
	level.add_theme_constant_override("outline_size", 3)
	node.add_child(level)
	_node_levels[id] = level


func _panel() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _skin(Color.WHITE, HUD_BORDER_BACKGROUND))
	return panel


func _skin(tint: Color = Color.WHITE, texture: Texture2D = HUD_BACKGROUND) -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = texture
	skin.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 6 if texture == HUD_BORDER_BACKGROUND else 4)
		skin.set_content_margin(side, 8)
	return skin


func _button(caption: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_stylebox_override("normal", _skin())
	button.add_theme_stylebox_override("hover", _skin(Color(1.35, 1.28, 1.1)))
	button.add_theme_stylebox_override("pressed", _skin(Color(0.8, 0.8, 0.8)))
	button.add_theme_stylebox_override("disabled", _skin(Color(0.65, 0.65, 0.65)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("100f14"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _layout_content() -> void:
	if _content == null: return
	var viewport_size := get_viewport_rect().size
	_density = minf(5.0 / 3.0, minf(viewport_size.x / 1152.0, viewport_size.y / 648.0))
	_content.scale = Vector2.ONE * _density
	_content.size = viewport_size / _density
	var extent := _content.size
	_detail_panel.position = Vector2(32, 32)
	_detail_panel.size = Vector2(320, 124)
	_summary_panel.position = Vector2(extent.x - 334, 32)
	_summary_panel.size = Vector2(302, 348)
	_currency_label.position = Vector2(extent.x * 0.47 - 180, 30)
	_currency_label.size = Vector2(360, 36)
	_reset_button.position = _summary_panel.position - Vector2(102, 0)
	_reset_button.size = Vector2(94, 32)
	_back_button.position = Vector2(32, extent.y - 64)
	_back_button.size = Vector2(132, 32)
	_hint.position = Vector2(extent.x - 266, extent.y - 56)
	_hint.size = Vector2(234, 24)
	if not _layout_initialized:
		# Preserve the readable default scale as branches open; icons keep HUD padding.
		_zoom = 0.6
		_layout_initialized = true
	_apply_view()
	queue_redraw()


func _apply_view() -> void:
	_hide_upgrade_tooltip()
	_tree.scale = Vector2.ONE * _zoom
	_tree.position = (_content.size * Vector2(0.47, 0.54) + _pan).round()


func zoom_at(pointer: Vector2, factor: float) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom * factor, 0.3, 1.8)
	var origin := _tree.position
	_pan += (pointer - origin) * (1.0 - _zoom / old_zoom)
	_apply_view()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_stop_drag()
		return
	if event is InputEventMouseButton:
		if not event.pressed and event.button_index == _drag_button:
			_stop_drag()
			get_viewport().set_input_as_handled()
			return
		# Capture right drag before HUD panels and buttons can consume it.
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_start_drag(MOUSE_BUTTON_RIGHT)
			get_viewport().set_input_as_handled()
			return
	if _dragging and event is InputEventMouseMotion:
		_pan += event.relative / _density
		_apply_view()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(get_local_mouse_position() / _density, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_node("")
			_start_drag(MOUSE_BUTTON_LEFT)
			accept_event()


func _start_drag(button: MouseButton) -> void:
	_drag_button = button
	_dragging = true
	_hide_upgrade_tooltip()


func _stop_drag() -> void:
	_dragging = false
	_drag_button = MOUSE_BUTTON_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_stop_drag()
		_hide_upgrade_tooltip()


func _on_node_input(event: InputEvent, source: Control) -> void:
	if not event is InputEventMouseButton: return
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var pointer: Vector2 = (source.get_global_transform() * event.position) / _density
		zoom_at(pointer, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
		source.accept_event()


func select_node(id: String) -> void:
	_hide_upgrade_tooltip()
	_selected_id = id if _nodes.has(id) and _nodes[id].visible else ""
	_refresh_all()


func _refresh_all() -> void:
	if _tree == null: return
	_tree.edges.clear()
	for id in _nodes:
		var node: TalentNodeButton = _nodes[id]
		node.visible = node.building or CampProgression.is_upgrade_visible(id)
		var level := CampProgression.get_building_level(id) if node.building else CampProgression.get_upgrade_option_level(id)
		var maximum := CampProgression.get_building_max_level(id) if node.building else int(_records[id].max_level)
		node.lit = level > 0
		node.selected = id == _selected_id
		node.queue_redraw()
		var caption: Label = _node_labels[id]
		caption.text = L10n.source(str(_records[id].name))
		caption.size = caption.get_minimum_size()
		caption.position = Vector2(roundf((node.size.x - caption.size.x) / 2.0), node.size.y + 6)
		caption.add_theme_color_override("font_color", GOLD if node.selected else TEXT if node.lit else MUTED)
		var badge: Label = _node_levels[id]
		badge.text = "%d/%d" % [level, maximum]
		badge.size = badge.get_minimum_size()
		badge.position = Vector2(roundf((node.size.x - badge.size.x) / 2.0), node.size.y - badge.size.y - 2)
		badge.add_theme_color_override("font_color", GOLD if node.lit or node.selected else TEXT)
		if not node.building and node.visible:
			var parent := str(_records[id].get("requires_upgrade", ""))
			if parent.is_empty(): parent = CampProgression.get_upgrade_option_parent_building_id(id)
			var parent_node: TalentNodeButton = _nodes[parent]
			_tree.edges.append({"from": parent_node.position + parent_node.size / 2.0, "to": node.position + node.size / 2.0, "lit": node.lit})
	if not _selected_id.is_empty() and not _nodes[_selected_id].visible: _selected_id = ""
	_tree.queue_redraw()
	_refresh_detail()
	_refresh_summary()


func _refresh_summary() -> void:
	var totals: Dictionary = {}
	for modifier in CampProgression.get_outgame_modifiers():
		var stat := str(modifier.stat)
		totals[stat] = float(totals.get(stat, 0.0)) + float(modifier.value)
	var visible_count := 0
	for stat in _summary_values:
		var value := float(totals.get(stat, 0.0))
		var label: Label = _summary_values[stat]
		label.visible = not is_zero_approx(value)
		label.text = "%s %s" % [_stat_name(stat), _signed_number(value)] if label.visible else ""
		if not label.visible: continue
		label.position = Vector2(16 + floori(visible_count / 14.0) * 142, 52 + (visible_count % 14) * 20)
		label.add_theme_color_override("font_color", GOLD)
		visible_count += 1
	_summary_empty.text = L10n.text("ui.talent_tree.empty")
	_summary_empty.visible = visible_count == 0
	_currency_label.text = L10n.text("ui.talent_tree.balance") % str(CampProgression.get_camp_currency())
	_summary_title.text = L10n.source("升级属性汇总")
	_reset_button.text = L10n.text("ui.camp.reset_upgrades")
	_back_button.text = L10n.text("ui.common.return_to_main_menu")
	_hint.text = L10n.text("ui.talent_tree.navigation")


func _refresh_detail() -> void:
	_detail_panel.visible = not _selected_id.is_empty()
	_upgrade_button.visible = _detail_panel.visible
	if _selected_id.is_empty():
		_hide_upgrade_tooltip()
		return
	var record: Dictionary = _records[_selected_id]
	var node: TalentNodeButton = _nodes[_selected_id]
	var level := CampProgression.get_building_level(_selected_id) if node.building else CampProgression.get_upgrade_option_level(_selected_id)
	var maximum := CampProgression.get_building_max_level(_selected_id) if node.building else int(record.max_level)
	var cost := 0
	var next_level := mini(level + 1, maximum)
	if node.building:
		cost = int(record.get("unlock_condition", {}).get("cost", 0)) if level == 0 else CampProgression.get_building_upgrade_cost(_selected_id)
		_detail_effect.text = L10n.text("ui.talent_tree.obtained") % _building_benefits(record, level)
		_detail_next.text = L10n.text("ui.talent_tree.after_upgrade") % _building_benefits(record, next_level)
		_upgrade_button.disabled = not (CampProgression.can_purchase_building_unlock(_selected_id) if level == 0 else CampProgression.can_purchase_building_upgrade(_selected_id))
	else:
		cost = CampProgression.get_upgrade_cost(_selected_id)
		_detail_effect.text = L10n.text("ui.talent_tree.obtained") % _upgrade_benefits(record, level)
		_detail_next.text = L10n.text("ui.talent_tree.after_upgrade") % _upgrade_benefits(record, next_level)
		_upgrade_button.disabled = not CampProgression.can_purchase_upgrade(_selected_id)
	_detail_title.text = L10n.source(str(record.name)) + "："
	_detail_next.visible = level < maximum
	_detail_cost.text = L10n.source("已升满") if level >= maximum else L10n.text("ui.talent_tree.cost") % cost
	_detail_cost.position.y = 90 if level < maximum else 68
	_detail_cost.add_theme_color_override("font_color", Color("bd786d") if cost > CampProgression.get_camp_currency() and level < maximum else GOLD)
	_upgrade_button.position = node.position + Vector2(node.size.x + 6, (node.size.y - _upgrade_button.size.y) / 2)
	_upgrade_button.move_to_front()
	_upgrade_tooltip_text.text = L10n.text("ui.talent_tree.maxed") if level >= maximum else L10n.text("ui.talent_tree.upgrade_tooltip") % cost
	if _upgrade_tooltip.visible: _position_upgrade_tooltip()


func _show_upgrade_tooltip() -> void:
	if _dragging or not is_visible_in_tree() or not _upgrade_button.visible: return
	_position_upgrade_tooltip()
	_upgrade_tooltip.show()


func _hide_upgrade_tooltip() -> void:
	if _upgrade_tooltip != null: _upgrade_tooltip.hide()


func _position_upgrade_tooltip() -> void:
	_upgrade_tooltip_text.size = _upgrade_tooltip_text.get_minimum_size()
	_upgrade_tooltip.size = _upgrade_tooltip_text.size + Vector2(24, 16)
	var arrow := _upgrade_button.get_global_rect()
	var point := _content.get_global_transform().affine_inverse() * Vector2(arrow.end.x, arrow.position.y)
	point += Vector2(10, 0)
	if point.x + _upgrade_tooltip.size.x > _content.size.x - 8:
		point.x -= _upgrade_tooltip.size.x + arrow.size.x / _density + 20
	_upgrade_tooltip.position = point.clamp(Vector2(8, 8), _content.size - _upgrade_tooltip.size - Vector2(8, 8)).round()


func _upgrade_benefits(record: Dictionary, level: int) -> String:
	return _stat_name(str(record.stat)) + _signed_number(float(record.value_per_level) * level)


func _building_benefits(record: Dictionary, level: int) -> String:
	# Building levels add cumulative bonuses; preview only this node's contribution.
	var stats: Dictionary = {}
	var perks := PackedStringArray()
	var first_tier := false
	for level_key in record.get("levels", {}):
		if int(level_key) > level: continue
		for effect in record.levels[level_key]:
			if effect.has("stat"):
				var stat := str(effect.stat)
				stats[stat] = float(stats.get(stat, 0.0)) + float(effect.value)
			else:
				var unlock := str(effect.get("unlock", ""))
				if unlock.begins_with("camp_upgrade_"): first_tier = true
				elif unlock == "run_start_random_relic": perks.append(L10n.text("ui.talent_tree.start_relic"))
				elif unlock == "run_start_double_level": perks.append(L10n.text("ui.talent_tree.start_levels"))
				else: perks.append(L10n.source(str(effect.get("name", ""))))
	var entries := PackedStringArray()
	for stat in stats: entries.append(_stat_name(stat) + _signed_number(float(stats[stat])))
	entries.append_array(perks)
	if entries.is_empty(): return L10n.text("ui.talent_tree.first_tier_obtained" if first_tier else "ui.talent_tree.none")
	return L10n.text("ui.talent_tree.benefit_separator").join(entries)


func _signed_number(value: float) -> String:
	return ("+" if value >= 0 else "") + _number(value)


func _stat_name(stat: String) -> String:
	if stat == "shop_offer_count_bonus": return L10n.source("商店选项")
	return L10n.source(StatDefinitions.get_display_name(stat))


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _purchase_selected() -> void:
	if _selected_id.is_empty(): return
	var node: TalentNodeButton = _nodes[_selected_id]
	var success := false
	if node.building:
		success = CampProgression.upgrade_building(_selected_id) if node.lit else CampProgression.purchase_building_unlock(_selected_id)
	else: success = CampProgression.purchase_upgrade(_selected_id)
	if success: AudioManager.play_ui_sfx("purchase_success")
	_refresh_all()


func _on_reset_pressed() -> void:
	CampProgression.reset_upgrade_options_and_refund()
	_refresh_all()


func _bind_main_flow() -> void:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			_main_flow_coordinator = (current as GameRoot).get_main_flow_coordinator()
			break
		current = current.get_parent()
	if _main_flow_coordinator == null and get_tree().current_scene is GameRoot:
		_main_flow_coordinator = (get_tree().current_scene as GameRoot).get_main_flow_coordinator()
	if _main_flow_coordinator != null:
		if not _main_flow_coordinator.mode_changed.is_connected(_on_mode_changed):
			_main_flow_coordinator.mode_changed.connect(_on_mode_changed)
		_on_mode_changed("", _main_flow_coordinator.get_current_mode())


func _on_mode_changed(_previous: String, current: String) -> void:
	if current == MainFlowCoordinator.MODE_TALENTS: show_talents_page()
	else:
		visible = false
		_stop_drag()


func show_talents_page() -> void:
	visible = true
	move_to_front()
	_layout_content()
	_refresh_all()


func _on_back_pressed() -> void:
	if _main_flow_coordinator == null: _bind_main_flow()
	if _main_flow_coordinator != null: _main_flow_coordinator.enter_start_page()
	visible = false
	_stop_drag()
	var game_root := get_tree().current_scene as GameRoot
	if game_root != null:
		var menu := game_root.get_node_or_null("UiRoot/MainMenuUIController") as MainMenuUIController
		if menu != null: menu.show_start_page()
