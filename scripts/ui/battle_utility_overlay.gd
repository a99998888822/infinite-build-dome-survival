extends CanvasLayer
class_name BattleUtilityOverlay

const TABLES: Array[String] = ["relics", "weapons"]
const CATEGORY_NAMES: Array[String] = ["遗物", "武器"]

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
var _basic_settings: VBoxContainer
var _combat_settings: VBoxContainer
var _settings_tabs: Array[Button] = []
var _settings_view: GameSettingsPanel
var _quick_cast: CheckBox
var _show_hints: CheckBox


func _ready() -> void:
	visible = false
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.014, 0.022, 0.021, 0.78)
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
	_close_button.text = "ui.common.return_to_battle"
	_close_button.custom_minimum_size = Vector2(104, 32)
	_close_button.pressed.connect(_close)
	header.add_child(_close_button)
	_build_encyclopedia(content)
	_build_settings()
	get_viewport().size_changed.connect(_layout)
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
	_title.text = "ui.hud.encyclopedia"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_color_override("font_color", SettingsUIStyle.GOLD)
	_panel.visible = is_encyclopedia
	_settings_view.visible = not is_encyclopedia
	if is_encyclopedia:
		_refresh_entries()
	else:
		_settings_view.open_page(true)
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
	_settings_view.fit_to_viewport(viewport_size)
	var target_size := Vector2(800, 520)
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
	_search.placeholder_text = "ui.encyclopedia.search_placeholder"
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
		var title := L10n.source(str(record.get("display_name", record.get("name", ""))))
		var description := _describe_record(table, record)
		if not query.is_empty() and (title + "\n" + description).findn(query) < 0:
			continue
		_records.append(record)
		_entries.add_item(title)
	if _records.is_empty():
		FinanceUIStyle.set_item_icon(_entry_icon, null)
		_entry_title.text = "ui.encyclopedia.empty.title"
		_entry_details.text = "ui.encyclopedia.empty.hint"
	else:
		_entries.select(0)
		_entries.ensure_current_is_visible()
		_show_entry(0)


func _show_entry(index: int) -> void:
	if index < 0 or index >= _records.size():
		return
	var record := _records[index]
	_entry_title.text = L10n.source(str(record.get("display_name", record.get("name", ""))))
	var icon_path := str(record.get("icon", ""))
	FinanceUIStyle.set_item_icon(_entry_icon, FinanceUIStyle.item_icon(icon_path))
	_entry_icon.visible = _entry_icon.texture != null
	_entry_details.text = _describe_record(TABLES[_category.selected], record)
	_entry_details.scroll_to_line(0)


func _describe_record(table: String, record: Dictionary) -> String:
	var lines: Array[String] = [L10n.source(str(record.get("description", "")))]
	if table == "relics":
		var max_stack := int(record.get("max_stack", 0))
		lines.append(L10n.text("ui.encyclopedia.stack_limit") % max_stack if max_stack > 0 else L10n.text("ui.encyclopedia.stack_unlimited"))
	elif table == "weapons":
		lines.append(L10n.text("ui.encyclopedia.weapon.load_level") % [int(record.get("load_cost", 0)), int(record.get("max_level", 1))])
		lines.append(L10n.text("ui.encyclopedia.weapon.cooldown") % (float(record.get("active_cooldown_ms", record.get("attack_interval_ms", 0))) / 1000.0))
	return "\n\n".join(lines)


func _build_settings() -> void:
	_settings_view = GameSettingsPanel.new()
	_settings_view.name = "GameSettings"
	add_child(_settings_view)
	_settings_view.hide()
	_settings_view.back_requested.connect(_close)
	_settings_view.main_menu_requested.connect(_return_to_main_menu)
	# Keep the public integration handles pointed at the shared live controls.
	_settings = _settings_view.content_scroll
	_basic_settings = _settings_view.basic_settings
	_combat_settings = _settings_view.combat_settings
	_settings_tabs = _settings_view.tabs
	_quick_cast = _settings_view.quick_cast
	_show_hints = _settings_view.show_hints
	_volume_controls = _settings_view.volume_controls
	_resolution = _settings_view.resolution
	_fullscreen_yes = _settings_view.fullscreen_yes
	_fullscreen_no = _settings_view.fullscreen_no
	_display_note = _settings_view.display_note
	_settings_footer = _settings_view.footer
	_return_button = _settings_view.return_button
	_menu_button = _settings_view.menu_button


func _select_settings_page(index: int) -> void:
	_settings_view.select_page(index)


func _return_to_main_menu() -> void:
	AudioManager.play_ui_sfx("modal_close")
	if is_instance_valid(_flow):
		_flow.return_to_main_menu_from_settings()
