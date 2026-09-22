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
var _fullscreen: CheckButton
var _display_note: Label
var _close_button: Button


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
	_title.text = "游戏百科" if is_encyclopedia else "游戏设置"
	_encyclopedia.visible = is_encyclopedia
	_settings.visible = not is_encyclopedia
	if is_encyclopedia:
		_refresh_entries()
	else:
		_sync_audio_settings()
		_sync_display_settings()
	visible = true
	_layout()
	_close_button.grab_focus()
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
	var panel_size := Vector2(minf(800, viewport_size.x - 32), minf(520, viewport_size.y - 88))
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
	content.add_theme_constant_override("separation", 18)
	_settings.add_child(content)
	_add_volume_control(content, "背景音乐", AudioManager.BUS_BGM, "bgm_volume")
	_add_volume_control(content, "音效", AudioManager.BUS_SFX, "sfx_volume")
	var resolution_label := Label.new()
	resolution_label.text = "窗口分辨率"
	content.add_child(resolution_label)
	_resolution = OptionButton.new()
	_resolution.name = "Resolution"
	_resolution.custom_minimum_size.y = 32
	for resolution in WindowSettings.get_resolution_presets():
		_resolution.add_item("%d × %d" % [resolution.x, resolution.y])
	_resolution.item_selected.connect(func(index: int) -> void: WindowSettings.set_resolution_index(index))
	content.add_child(_resolution)
	_fullscreen = CheckButton.new()
	_fullscreen.name = "Fullscreen"
	_fullscreen.text = "全屏显示"
	_fullscreen.toggled.connect(func(enabled: bool) -> void: WindowSettings.set_fullscreen(enabled))
	content.add_child(_fullscreen)
	_display_note = Label.new()
	_display_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_display_note.add_theme_color_override("font_color", Color("#a8b6a5"))
	content.add_child(_display_note)


func _add_volume_control(parent: VBoxContainer, title: String, bus: String, key: String) -> void:
	var group := VBoxContainer.new()
	parent.add_child(group)
	var label := Label.new()
	label.text = title
	group.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	group.add_child(row)
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
	_fullscreen.set_pressed_no_signal(WindowSettings.is_fullscreen())
	var embedded := WindowSettings.is_embedded()
	var mobile := OS.has_feature("mobile")
	_resolution.disabled = embedded or mobile or WindowSettings.is_fullscreen()
	_fullscreen.disabled = embedded or mobile
	if embedded:
		_display_note.text = "调整窗口或全屏请先关闭编辑器的“嵌入游戏”，再独立运行。"
	elif mobile:
		_display_note.text = "当前设备使用系统屏幕尺寸。音量修改会自动保存。"
	else:
		_display_note.text = "修改立即生效并自动保存。按 Esc 或“返回战斗”继续游戏。"
