extends CanvasLayer
class_name BattleUtilityOverlay

const TABLES: Array[String] = ["relics", "weapons", "bonds"]
const CATEGORY_NAMES: Array[String] = ["遗物", "武器", "羁绊"]

var _flow: MainFlowCoordinator
var _panel: PanelContainer
var _title: Label
var _encyclopedia: VBoxContainer
var _settings: ScrollContainer
var _category: OptionButton
var _search: LineEdit
var _entries: ItemList
var _entry_icon: TextureRect
var _entry_title: Label
var _entry_details: RichTextLabel
var _records: Array[Dictionary] = []
var _volume_controls: Dictionary = {}
var _resolution: OptionButton
var _fullscreen_yes: Button
var _fullscreen_no: Button
var _display_note: Label
var _close_button: Button
var _settings_footer: HBoxContainer
var _return_button: Button
var _menu_button: Button
var _showing_settings: bool = false


func _ready() -> void:
	visible = false
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.005, 0.014, 0.014, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_panel = PanelContainer.new()
	_panel.name = "UtilityPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111b18")
	style.border_color = Color("#8f8858")
	style.set_border_width_all(2)
	style.set_content_margin_all(16.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color("#e5d7a4"))
	header.add_child(_title)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "返回战斗"
	_close_button.custom_minimum_size = Vector2(104, 32)
	_close_button.pressed.connect(_close)
	header.add_child(_close_button)
	_build_encyclopedia(content)
	_build_settings(content)
	_build_settings_footer(content)
	get_viewport().size_changed.connect(_layout)
	WindowSettings.settings_changed.connect(_sync_display_settings)
	_layout()


func bind_flow(flow: MainFlowCoordinator) -> void:
	if _flow == flow:
		return
	if is_instance_valid(_flow):
		_flow.modal_requested.disconnect(_on_modal_requested)
		_flow.state_changed.disconnect(_on_state_changed)
	_flow = flow
	_flow.modal_requested.connect(_on_modal_requested)
	_flow.state_changed.connect(_on_state_changed)


func _on_modal_requested(state: String, payload: Dictionary) -> void:
	if state != MainFlowCoordinator.STATE_BATTLE_UTILITY:
		return
	var is_encyclopedia := str(payload.get("page", "")) == "encyclopedia"
	_showing_settings = not is_encyclopedia
	_title.text = "游戏百科" if is_encyclopedia else "设置"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_encyclopedia else HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", SettingsUIStyle.GOLD)
	_close_button.visible = is_encyclopedia
	_encyclopedia.visible = is_encyclopedia
	_settings.visible = not is_encyclopedia
	_settings_footer.visible = not is_encyclopedia
	if _showing_settings:
		_panel.add_theme_stylebox_override("panel", SettingsUIStyle.panel())
	if is_encyclopedia:
		_refresh_entries()
	else:
		_sync_audio_settings()
		_sync_display_settings()
	visible = true
	_layout()
	if is_encyclopedia:
		_close_button.grab_focus()
	else:
		_return_button.grab_focus()
	AudioManager.play_ui_sfx("modal_open")


func _on_state_changed(_previous: String, current: String) -> void:
	if current != MainFlowCoordinator.STATE_BATTLE_UTILITY:
		visible = false


func _close() -> void:
	if _flow != null:
		_flow.close_battle_utility()
	AudioManager.play_ui_sfx("modal_close")


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	# Let an open dropdown consume Escape first; otherwise close even while
	# the search field owns keyboard focus.
	if _category.get_popup().visible or _resolution.get_popup().visible:
		return
	get_viewport().set_input_as_handled()
	_close()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var target_size := Vector2(620, 454) if _showing_settings else Vector2(800, 520)
	var panel_size := Vector2(minf(target_size.x, viewport_size.x - 32), minf(target_size.y, viewport_size.y - 88))
	_panel.position = Vector2((viewport_size.x - panel_size.x) * 0.5, 64 + (viewport_size.y - 80 - panel_size.y) * 0.5)
	_panel.size = panel_size
	_entries.custom_minimum_size.x = clampf(panel_size.x * 0.28, 144, 216)


func _build_encyclopedia(parent: VBoxContainer) -> void:
	_encyclopedia = VBoxContainer.new()
	_encyclopedia.name = "Encyclopedia"
	_encyclopedia.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_encyclopedia.add_theme_constant_override("separation", 10)
	parent.add_child(_encyclopedia)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	_encyclopedia.add_child(filters)
	_category = OptionButton.new()
	_category.custom_minimum_size = Vector2(100, 32)
	for category_name in CATEGORY_NAMES:
		_category.add_item(category_name)
	_category.item_selected.connect(func(_index: int) -> void: _refresh_entries())
	filters.add_child(_category)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "搜索名称或效果"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _refresh_entries())
	filters.add_child(_search)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	_encyclopedia.add_child(body)
	_entries = ItemList.new()
	_entries.name = "Entries"
	_entries.auto_height = false
	_entries.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_entries.item_selected.connect(_show_entry)
	body.add_child(_entries)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	detail.add_child(heading)
	_entry_icon = TextureRect.new()
	_entry_icon.custom_minimum_size = Vector2(48, 48)
	_entry_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_entry_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_entry_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heading.add_child(_entry_icon)
	_entry_title = Label.new()
	_entry_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_title.add_theme_font_size_override("font_size", 18)
	_entry_title.add_theme_color_override("font_color", Color("#e5d7a4"))
	heading.add_child(_entry_title)
	_entry_details = RichTextLabel.new()
	_entry_details.name = "Description"
	_entry_details.bbcode_enabled = true
	_entry_details.selection_enabled = true
	_entry_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_details.add_theme_font_size_override("normal_font_size", 15)
	detail.add_child(_entry_details)


func _refresh_entries() -> void:
	_entries.clear()
	_records.clear()
	var table := TABLES[_category.selected]
	var query := _search.text.strip_edges()
	for record: Dictionary in DataRegistry.get_table(table):
		var title := str(record.get("display_name", record.get("name", "")))
		var description := _describe_record(table, record)
		if not query.is_empty() and (title + "\n" + description).findn(query) < 0:
			continue
		_records.append(record)
		_entries.add_item(title)
	if _records.is_empty():
		_entry_icon.texture = null
		_entry_title.text = "没有匹配的条目"
		_entry_details.text = "请尝试其他名称或效果关键词。"
	else:
		_entries.select(0)
		_entries.ensure_current_is_visible()
		_show_entry(0)


func _show_entry(index: int) -> void:
	if index < 0 or index >= _records.size():
		return
	var record := _records[index]
	_entry_title.text = str(record.get("display_name", record.get("name", "")))
	var icon_path := str(record.get("icon", ""))
	_entry_icon.texture = load(icon_path) as Texture2D if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null
	_entry_icon.visible = _entry_icon.texture != null
	_entry_details.text = _describe_record(TABLES[_category.selected], record)
	_entry_details.scroll_to_line(0)


func _describe_record(table: String, record: Dictionary) -> String:
	if table == "bonds":
		return BondDisplay.build_bond_reference_text(record)
	var lines: Array[String] = [str(record.get("description", ""))]
	var bond_text := BondDisplay.build_item_bond_text(record)
	if not bond_text.is_empty():
		lines.append(bond_text)
	if table == "relics":
		var max_stack := int(record.get("max_stack", 0))
		lines.append("叠加上限：%d" % max_stack if max_stack > 0 else "叠加上限：不限")
	elif table == "weapons":
		lines.append("基础负载：%d　最高等级：%d" % [int(record.get("load_cost", 0)), int(record.get("max_level", 1))])
		lines.append("基础攻击间隔：%.2f 秒" % (float(record.get("attack_interval_ms", 0)) / 1000.0))
	return "\n\n".join(lines)


func _build_settings(parent: VBoxContainer) -> void:
	_settings = ScrollContainer.new()
	_settings.name = "Settings"
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_settings)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_settings.add_child(content)
	_add_volume_control(content, "背景音乐", AudioManager.BUS_BGM, "bgm_volume")
	_add_volume_control(content, "音效", AudioManager.BUS_SFX, "sfx_volume")
	var resolution_row := _settings_row(content, "界面分辨率")
	_resolution = OptionButton.new()
	_resolution.name = "Resolution"
	_resolution.custom_minimum_size.y = 36
	_resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SettingsUIStyle.apply_button(_resolution)
	for resolution in WindowSettings.get_resolution_presets():
		_resolution.add_item("%d × %d" % [resolution.x, resolution.y])
	_resolution.item_selected.connect(func(index: int) -> void: WindowSettings.set_resolution_index(index))
	resolution_row.add_child(_resolution)
	var fullscreen_row := _settings_row(content, "全屏：")
	var group := ButtonGroup.new()
	_fullscreen_yes = _fullscreen_option(fullscreen_row, group, true)
	_fullscreen_no = _fullscreen_option(fullscreen_row, group, false)
	var credit_row := _settings_row(content, "Credit")
	var credit := PanelContainer.new()
	credit.custom_minimum_size.y = 36
	credit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credit.add_theme_stylebox_override("panel", SettingsUIStyle.credit())
	credit_row.add_child(credit)
	var credit_text := Label.new()
	credit_text.text = "Ark Pixel Font | SIL Open Font License 1.1"
	credit_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	credit_text.add_theme_font_size_override("font_size", 10)
	credit_text.add_theme_color_override("font_color", SettingsUIStyle.TEXT)
	credit.add_child(credit_text)
	_display_note = Label.new()
	_display_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_display_note.add_theme_color_override("font_color", SettingsUIStyle.TEXT)
	_display_note.add_theme_font_size_override("font_size", 12)
	content.add_child(_display_note)


func _settings_row(parent: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(120, 36)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SettingsUIStyle.TEXT)
	row.add_child(label)
	return row


func _fullscreen_option(row: HBoxContainer, group: ButtonGroup, enabled: bool) -> Button:
	var button := Button.new()
	button.name = "FullscreenYes" if enabled else "FullscreenNo"
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(124, 36)
	SettingsUIStyle.apply_button(button)
	button.pressed.connect(func() -> void: WindowSettings.set_fullscreen(enabled))
	row.add_child(button)
	return button


func _build_settings_footer(parent: VBoxContainer) -> void:
	_settings_footer = HBoxContainer.new()
	_settings_footer.name = "SettingsActions"
	_settings_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_footer.add_theme_constant_override("separation", 16)
	parent.add_child(_settings_footer)
	_return_button = Button.new()
	_return_button.name = "ReturnButton"
	_return_button.text = "返回"
	_return_button.custom_minimum_size = Vector2(180, 40)
	SettingsUIStyle.apply_button(_return_button)
	_return_button.pressed.connect(_close)
	_settings_footer.add_child(_return_button)
	_menu_button = Button.new()
	_menu_button.name = "MainMenuButton"
	_menu_button.text = "返回主菜单"
	_menu_button.tooltip_text = "结束当前战局，返回主菜单。"
	_menu_button.custom_minimum_size = Vector2(180, 40)
	SettingsUIStyle.apply_button(_menu_button)
	_menu_button.pressed.connect(_return_to_main_menu)
	_settings_footer.add_child(_menu_button)


func _return_to_main_menu() -> void:
	AudioManager.play_ui_sfx("modal_close")
	if is_instance_valid(_flow):
		_flow.return_to_main_menu_from_settings()


func _add_volume_control(parent: VBoxContainer, title: String, bus: String, key: String) -> void:
	var row := _settings_row(parent, title)
	var slider := HSlider.new()
	slider.name = bus + "Volume"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size.y = 28
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var percentage := Label.new()
	percentage.custom_minimum_size.x = 56
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percentage.add_theme_font_size_override("font_size", 14)
	percentage.add_theme_color_override("font_color", SettingsUIStyle.TEXT)
	row.add_child(percentage)
	slider.value_changed.connect(func(value: float) -> void:
		percentage.text = "%d%%" % roundi(value)
		AudioManager.set_bus_volume(bus, roundi(value))
	)
	_volume_controls[key] = {"slider": slider, "label": percentage}


func _sync_audio_settings() -> void:
	for key: String in _volume_controls:
		var value := CampProgression.get_volume_setting(key, 100)
		var controls: Dictionary = _volume_controls[key]
		(controls.slider as HSlider).set_value_no_signal(value)
		(controls.label as Label).text = "%d%%" % value


func _sync_display_settings() -> void:
	_resolution.select(WindowSettings.get_resolution_index())
	var fullscreen := WindowSettings.is_fullscreen()
	_fullscreen_yes.set_pressed_no_signal(fullscreen)
	_fullscreen_no.set_pressed_no_signal(not fullscreen)
	_fullscreen_yes.text = "● 是" if fullscreen else "○ 是"
	_fullscreen_no.text = "○ 否" if fullscreen else "● 否"
	var embedded := WindowSettings.is_embedded()
	var mobile := OS.has_feature("mobile")
	_resolution.disabled = embedded or mobile or WindowSettings.is_fullscreen()
	_fullscreen_yes.disabled = embedded or mobile
	_fullscreen_no.disabled = embedded or mobile
	if embedded:
		_display_note.text = "调整窗口或全屏请先关闭编辑器的“嵌入游戏”，再独立运行。"
	elif mobile:
		_display_note.text = "当前设备使用系统屏幕尺寸。音量修改会自动保存。"
	else:
		_display_note.text = "修改立即生效并自动保存。按 Esc 或“返回”回到原界面。"
