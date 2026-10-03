extends CanvasLayer
class_name MainMenuUIController

const MAIN_MENU_BACKGROUND_TEXTURE_PATH: String = "res://assets/ui/main_menu/bg_main_menu.png"
const MAIN_MENU_TITLE_TEXTURE_PATH: String = "res://assets/ui/main_menu/title_main_menu.png"
const CHARACTER_SELECT_VIEW: Script = preload("res://scripts/ui/character_select_view.gd")

var character_view: CharacterSelectView

var _main_flow_coordinator: MainFlowCoordinator = null
var _selected_character_id: String = ""
var _selected_character_record: Dictionary = {}
var _selected_difficulty_id: String = BattleDifficulty.DEFAULT_ID
var _title_base_position := Vector2.ZERO
var _role_select_was_visible := false
var _settings_overlay: Control = null
var _settings_panel: PanelContainer = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _resolution_option: OptionButton = null
var _fullscreen_yes_button: Button = null
var _fullscreen_no_button: Button = null
var _music_value_label: Label = null
var _sfx_value_label: Label = null
var _display_settings_note: Label = null
var _settings_tween: Tween = null

const SETTINGS_PANEL_SIZE := Vector2(620, 430)
const SETTINGS_ROW_HEIGHT := 36.0
const SETTINGS_TITLE_WIDTH := 150.0
const SETTINGS_TITLE_FONT_SIZE := 14
const SETTINGS_TITLE_COLOR := Color("#d9d0af")

@onready var start_page: Control = get_node_or_null("StartPage")
@onready var start_page_background: TextureRect = get_node_or_null("StartPage/Background")
@onready var title_art: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/TitleArea/TitleCenter/TitleStack/TitleArt")
@onready var start_battle_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell/StartBattleButton")
@onready var camp_entry_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell/CampEntryButton")
@onready var settings_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/SettingsShell/SettingsButton")
@onready var quit_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/QuitButton")
@onready var character_select_page: Control = get_node_or_null("CharacterSelectPage")
@onready var stats_list: Control = null
@onready var weapon_list: VBoxContainer = null
@onready var passive_list: VBoxContainer = null
@onready var difficulty_list: Control = null
@onready var character_details_scroll: ScrollContainer = null
@onready var character_list: VBoxContainer = null
@onready var character_icon: TextureRect = null
@onready var character_name_label: Label = null
@onready var character_description_label: Label = null
@onready var character_stats_label: Label = null
@onready var character_weapon_label: Label = null
@onready var character_passive_label: Label = null
@onready var character_error_label: Label = null
@onready var character_back_button: Button = null
@onready var character_confirm_button: Button = null
@onready var battle_result_panel: RunSettlementPanel = get_node_or_null("BattleResultPanel")

var role_select_backdrop: Control = null


func _ready() -> void:
	_setup_role_select_runtime_ui()
	_apply_start_page_assets()
	_create_settings_ui()
	_bind_window_settings()
	_setup_menu_atmosphere()
	if start_battle_button != null and not start_battle_button.pressed.is_connected(_on_start_battle_pressed):
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if camp_entry_button != null and not camp_entry_button.pressed.is_connected(_on_talents_pressed):
		camp_entry_button.pressed.connect(_on_talents_pressed)
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	if character_back_button != null and not character_back_button.pressed.is_connected(_on_character_back_pressed):
		character_back_button.pressed.connect(_on_character_back_pressed)
	if character_confirm_button != null and not character_confirm_button.pressed.is_connected(_on_character_confirm_pressed):
		character_confirm_button.pressed.connect(_on_character_confirm_pressed)
	if battle_result_panel != null:
		battle_result_panel.back_requested.connect(_on_result_back_pressed)
	call_deferred("_bind_to_main_flow")


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	if title_art != null and start_page != null and start_page.visible:
		var title_offset := sin(time * 1.7) * 4.0
		title_art.position = _title_base_position + Vector2(0.0, title_offset)


func _setup_menu_atmosphere() -> void:
	if title_art != null:
		_title_base_position = title_art.position


func _bind_to_main_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		call_deferred("_bind_to_main_flow")
		return
	if _main_flow_coordinator == coordinator:
		return
	_unbind_main_flow()
	_main_flow_coordinator = coordinator
	var state_callable := Callable(self, "_on_flow_changed")
	var mode_callable := Callable(self, "_on_flow_changed")
	if not _main_flow_coordinator.state_changed.is_connected(state_callable):
		_main_flow_coordinator.state_changed.connect(state_callable)
	if not _main_flow_coordinator.mode_changed.is_connected(mode_callable):
		_main_flow_coordinator.mode_changed.connect(mode_callable)
	_main_flow_coordinator.battle_result_changed.connect(_on_result_changed)
	_refresh_visibility()


func _unbind_main_flow() -> void:
	if _main_flow_coordinator == null:
		return
	var state_callable := Callable(self, "_on_flow_changed")
	var mode_callable := Callable(self, "_on_flow_changed")
	if _main_flow_coordinator.state_changed.is_connected(state_callable):
		_main_flow_coordinator.state_changed.disconnect(state_callable)
	if _main_flow_coordinator.mode_changed.is_connected(mode_callable):
		_main_flow_coordinator.mode_changed.disconnect(mode_callable)
	if _main_flow_coordinator.battle_result_changed.is_connected(_on_result_changed):
		_main_flow_coordinator.battle_result_changed.disconnect(_on_result_changed)
	_main_flow_coordinator = null


func _find_main_flow_coordinator() -> MainFlowCoordinator:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return (current as GameRoot).get_main_flow_coordinator()
		current = current.get_parent()
	if get_tree() != null and get_tree().current_scene is GameRoot:
		return (get_tree().current_scene as GameRoot).get_main_flow_coordinator()
	return null


func _on_flow_changed(_previous: String, _current: String) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var flow := _main_flow_coordinator
	if flow == null:
		return
	var mode := flow.get_current_mode()
	var state := flow.get_current_state()
	layer = 40 if state == MainFlowCoordinator.STATE_BATTLE_RESULT else 20
	var showing_character_select := mode == MainFlowCoordinator.MODE_BATTLE and state == MainFlowCoordinator.STATE_CHARACTER_SELECT
	if start_page != null:
		start_page.visible = mode == MainFlowCoordinator.MODE_BOOT
	if character_select_page != null:
		character_select_page.visible = showing_character_select
	if battle_result_panel != null:
		battle_result_panel.visible = mode == MainFlowCoordinator.MODE_BATTLE and state == MainFlowCoordinator.STATE_BATTLE_RESULT
	if showing_character_select and not _role_select_was_visible:
		_animate_character_page_in()
	_role_select_was_visible = showing_character_select
	if character_select_page != null and character_select_page.visible:
		_rebuild_character_list()
	if battle_result_panel != null and battle_result_panel.visible:
		_refresh_result_text()


func _on_start_battle_pressed() -> void:
	_selected_character_id = ""
	_selected_character_record.clear()
	_selected_difficulty_id = BattleDifficulty.DEFAULT_ID
	if character_error_label != null:
		character_error_label.text = ""
		character_error_label.visible = false
	if start_page != null:
		start_page.visible = false
	if character_select_page != null:
		_rebuild_character_list()
		character_select_page.visible = true


func _on_talents_pressed() -> void:
	if _main_flow_coordinator == null:
		_main_flow_coordinator = _find_main_flow_coordinator()
	if _main_flow_coordinator == null:
		return
	_main_flow_coordinator.enter_talents_flow()
	var game_root: GameRoot = null
	if get_tree() != null:
		game_root = get_tree().current_scene as GameRoot
	if game_root == null:
		return
	var talents_ui := game_root.get_node_or_null("UiRoot/CampBlueprintUIController") as CampBlueprintUIController
	if talents_ui != null:
		talents_ui.show_talents_page()


func show_start_page() -> void:
	if character_error_label != null:
		character_error_label.text = ""
		character_error_label.visible = false
	if character_select_page != null:
		character_select_page.visible = false
	_role_select_was_visible = false
	if battle_result_panel != null:
		battle_result_panel.visible = false
	if start_page != null:
		start_page.visible = true



func _create_settings_ui() -> void:
	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	_settings_overlay = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.015, 0.02, 0.86)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.custom_minimum_size = SETTINGS_PANEL_SIZE
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.offset_left = -SETTINGS_PANEL_SIZE.x * 0.5
	_settings_panel.offset_top = -SETTINGS_PANEL_SIZE.y * 0.5
	_settings_panel.offset_right = SETTINGS_PANEL_SIZE.x * 0.5
	_settings_panel.offset_bottom = SETTINGS_PANEL_SIZE.y * 0.5
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.add_theme_stylebox_override("panel", _make_settings_panel_style())
	overlay.add_child(_settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(content)
	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffe18a"))
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	_music_slider = _make_volume_row(content, "背景音乐", 100)
	_sfx_slider = _make_volume_row(content, "音效", 100)
	var resolution_row := HBoxContainer.new()
	resolution_row.add_theme_constant_override("separation", 12)
	content.add_child(resolution_row)
	var resolution_label := _make_settings_title("界面分辨率")
	resolution_row.add_child(resolution_label)
	_resolution_option = OptionButton.new()
	_resolution_option.custom_minimum_size = Vector2(300, 36)
	resolution_row.add_child(_resolution_option)
	if WindowSettings != null:
		for size in WindowSettings.get_resolution_presets():
			_resolution_option.add_item("%d × %d" % [size.x, size.y])
	_resolution_option.item_selected.connect(_on_resolution_selected)
	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.add_theme_constant_override("separation", 12)
	content.add_child(fullscreen_row)
	var fullscreen_title := _make_settings_title("全屏：")
	fullscreen_row.add_child(fullscreen_title)
	var fullscreen_group := ButtonGroup.new()
	_fullscreen_yes_button = _make_fullscreen_option("是", fullscreen_group)
	_fullscreen_no_button = _make_fullscreen_option("否", fullscreen_group)
	fullscreen_row.add_child(_fullscreen_yes_button)
	fullscreen_row.add_child(_fullscreen_no_button)
	_display_settings_note = _make_settings_label("")
	_display_settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_display_settings_note.add_theme_color_override("font_color", Color("#e3b65c"))
	_display_settings_note.add_theme_font_size_override("font_size", 11)
	_display_settings_note.visible = false
	content.add_child(_display_settings_note)
	var credit_row := HBoxContainer.new()
	credit_row.add_theme_constant_override("separation", 12)
	content.add_child(credit_row)
	var credit_title := _make_settings_title("Credit")
	credit_row.add_child(credit_title)
	var credit_area := PanelContainer.new()
	credit_area.custom_minimum_size = Vector2(300, SETTINGS_ROW_HEIGHT)
	credit_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credit_area.add_theme_stylebox_override("panel", _make_credit_area_style())
	credit_row.add_child(credit_area)
	var credit_scroll := ScrollContainer.new()
	credit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	credit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	credit_scroll.custom_minimum_size = Vector2(0, SETTINGS_ROW_HEIGHT)
	credit_area.add_child(credit_scroll)
	var credit_text := Label.new()
	credit_text.text = "Ark Pixel Font | SIL Open Font License 1.1"
	credit_text.custom_minimum_size = Vector2(0, SETTINGS_ROW_HEIGHT)
	credit_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit_text.add_theme_color_override("font_color", Color("#d9d0af"))
	credit_text.add_theme_font_size_override("font_size", 10)
	credit_scroll.add_child(credit_text)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var back_button := Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(180, 40)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_color_override("font_color", Color("#d9d0af"))
	back_button.add_theme_color_override("font_hover_color", Color("#ffe18a"))
	back_button.add_theme_stylebox_override("normal", _make_settings_button_style(Color("#111b16"), Color("#59441f")))
	back_button.add_theme_stylebox_override("hover", _make_settings_button_style(Color("#2b3020"), Color("#ffe18a")))
	back_button.pressed.connect(_close_settings)
	content.add_child(back_button)
	_load_settings_values()

func _make_volume_row(parent: VBoxContainer, title_text: String, default_value: int) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := _make_settings_title(title_text)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = default_value
	slider.custom_minimum_size = Vector2(300, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := _make_settings_label("100%")
	value_label.custom_minimum_size = Vector2(70, 36)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	slider.value_changed.connect(_on_volume_slider_changed.bind(slider, value_label, title_text))
	if title_text == "背景音乐":
		_music_value_label = value_label
	else:
		_sfx_value_label = value_label
	return slider

func _make_settings_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", SETTINGS_TITLE_COLOR)
	label.add_theme_font_size_override("font_size", SETTINGS_TITLE_FONT_SIZE)
	return label


func _make_settings_title(text_value: String) -> Label:
	var label := _make_settings_label(text_value)
	label.custom_minimum_size = Vector2(SETTINGS_TITLE_WIDTH, SETTINGS_ROW_HEIGHT)
	return label

func _make_settings_panel_style() -> StyleBoxFlat:
	return SettingsUIStyle.panel()

func _make_credit_area_style() -> StyleBoxFlat:
	return SettingsUIStyle.credit()

func _make_settings_button_style(background: Color, border: Color) -> StyleBoxFlat:
	return SettingsUIStyle.button(background, border)

func _on_settings_pressed() -> void:
	if _settings_panel == null:
		return
	_load_settings_values()
	var overlay := _settings_panel.get_parent() as Control
	if overlay == null:
		return
	overlay.visible = true
	_settings_panel.pivot_offset = _settings_panel.size * 0.5
	_settings_panel.modulate.a = 0.0
	_settings_panel.scale = Vector2(0.94, 0.94)
	if _settings_tween != null and _settings_tween.is_valid():
		_settings_tween.kill()
	_settings_tween = create_tween().set_parallel(true)
	_settings_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_settings_tween.tween_property(_settings_panel, "modulate:a", 1.0, 0.20)
	_settings_tween.tween_property(_settings_panel, "scale", Vector2.ONE, 0.26)
	AudioManager.play_ui_sfx("modal_open")

func _close_settings() -> void:
	if _settings_panel == null:
		return
	var overlay := _settings_panel.get_parent() as Control
	if overlay == null:
		return
	if _settings_tween != null and _settings_tween.is_valid():
		_settings_tween.kill()
	_settings_tween = create_tween().set_parallel(true)
	_settings_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_settings_tween.tween_property(_settings_panel, "modulate:a", 0.0, 0.14)
	_settings_tween.tween_property(_settings_panel, "scale", Vector2(0.94, 0.94), 0.14)
	_settings_tween.chain().tween_callback(func() -> void:
		overlay.visible = false
		_settings_panel.scale = Vector2.ONE
	)
	AudioManager.play_ui_sfx("modal_close")

func _on_volume_slider_changed(value: float, slider: HSlider, value_label: Label, title_text: String) -> void:
	var percentage := clampi(roundi(value), 0, 100)
	value_label.text = "%d%%" % percentage
	var bus_name := AudioManager.BUS_BGM if title_text == "背景音乐" else AudioManager.BUS_SFX
	AudioManager.set_bus_volume(bus_name, percentage)

func _on_resolution_selected(index: int) -> void:
	if WindowSettings == null or index < 0 or index >= WindowSettings.get_resolution_presets().size():
		return
	WindowSettings.set_resolution_index(index)

func _on_fullscreen_option_pressed(fullscreen_enabled: bool) -> void:
	if WindowSettings == null:
		return
	WindowSettings.set_fullscreen(fullscreen_enabled)

func _bind_window_settings() -> void:
	if WindowSettings == null:
		return
	var settings_callable := Callable(self, "_on_window_settings_changed")
	if not WindowSettings.settings_changed.is_connected(settings_callable):
		WindowSettings.settings_changed.connect(settings_callable)
	_sync_window_settings_controls()


func _on_window_settings_changed() -> void:
	_sync_window_settings_controls()


func _sync_window_settings_controls() -> void:
	if WindowSettings == null:
		return
	var fullscreen := WindowSettings.is_fullscreen()
	if _display_settings_note != null:
		var is_embedded := WindowSettings.is_embedded()
		_display_settings_note.visible = is_embedded
		if is_embedded:
			_display_settings_note.text = "编辑器嵌入运行时不支持调整窗口尺寸或全屏；当前设置会保存，请关闭编辑器的“嵌入游戏”后运行"
		else:
			_display_settings_note.text = ""
	if _resolution_option != null:
		_resolution_option.select(WindowSettings.get_resolution_index())
	if _fullscreen_yes_button != null:
		_fullscreen_yes_button.set_pressed_no_signal(fullscreen)
		_fullscreen_yes_button.text = "● 是" if fullscreen else "○ 是"
	if _fullscreen_no_button != null:
		_fullscreen_no_button.set_pressed_no_signal(not fullscreen)
		_fullscreen_no_button.text = "● 否" if not fullscreen else "○ 否"


func _load_settings_values() -> void:
	var music_value := CampProgression.get_volume_setting("bgm_volume", 100)
	var sfx_value := CampProgression.get_volume_setting("sfx_volume", 100)
	if _music_slider != null:
		_music_slider.set_value_no_signal(music_value)
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(sfx_value)
	if _music_value_label != null:
		_music_value_label.text = "%d%%" % music_value
	if _sfx_value_label != null:
		_sfx_value_label.text = "%d%%" % sfx_value
	_sync_window_settings_controls()


func _make_fullscreen_option(text_value: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = "○ %s" % text_value
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(124, 36)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#a9a184"))
	button.add_theme_color_override("font_hover_color", Color("#ffe18a"))
	button.add_theme_color_override("font_pressed_color", Color("#ffe18a"))
	button.add_theme_stylebox_override("normal", _make_settings_button_style(Color("#111b16"), Color("#59441f")))
	button.add_theme_stylebox_override("hover", _make_settings_button_style(Color("#2b3020"), Color("#ffe18a")))
	button.add_theme_stylebox_override("pressed", _make_settings_button_style(Color("#473616"), Color("#d3a637")))
	button.pressed.connect(_on_fullscreen_option_pressed.bind(text_value == "是"))
	return button

func _on_quit_pressed() -> void:
	if get_tree() != null:
		get_tree().quit()


func _on_character_back_pressed() -> void:
	_selected_character_id = ""
	_selected_character_record.clear()
	if _main_flow_coordinator != null and _main_flow_coordinator.get_current_mode() == MainFlowCoordinator.MODE_BATTLE:
		_main_flow_coordinator.enter_start_page()
		return
	if character_select_page != null:
		character_select_page.visible = false
	if start_page != null:
		start_page.visible = true


func _on_character_confirm_pressed() -> void:
	if _main_flow_coordinator == null or _selected_character_id.is_empty():
		return
	if character_confirm_button != null:
		character_confirm_button.disabled = true
	_confirm_character_selection_now()


func _confirm_character_selection_now() -> void:
	var modifiers: Array = []
	if CampProgression != null and CampProgression.has_method("get_outgame_modifiers"):
		modifiers = CampProgression.get_outgame_modifiers()
	_main_flow_coordinator.enter_battle_selection(_selected_character_id, [], modifiers, _selected_difficulty_id)
	var confirmed := _main_flow_coordinator.confirm_character_selection()
	if not confirmed:
		if character_error_label != null:
			character_error_label.text = "进入战斗失败，请重试"
			character_error_label.visible = true
		if character_confirm_button != null:
			character_confirm_button.disabled = false
		return


func _setup_role_select_runtime_ui() -> void:
	if character_select_page == null:
		return
	character_view = CHARACTER_SELECT_VIEW.new() as CharacterSelectView
	character_view.name = "RoleSelectRuntime"
	character_select_page.add_child(character_view)
	character_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_view.character_selected.connect(_on_character_selected)
	character_view.difficulty_selected.connect(_on_difficulty_selected)
	character_list = character_view.character_list
	character_icon = character_view.character_icon
	character_name_label = character_view.name_label
	character_description_label = character_view.description_label
	character_details_scroll = character_view.details_scroll
	stats_list = character_view.stats_list
	weapon_list = character_view.weapon_list
	passive_list = character_view.passive_list
	difficulty_list = character_view.difficulty_list
	character_back_button = character_view.back_button
	character_confirm_button = character_view.confirm_button
	character_error_label = character_view.error_label
	role_select_backdrop = character_view.background


func _rebuild_character_list() -> void:
	if character_view == null:
		return
	_selected_character_id = ""
	_selected_character_record.clear()
	character_confirm_button.disabled = true
	var records: Array = DataRegistry.get_table("characters") if DataRegistry != null else []
	var first_id := character_view.rebuild_roster(records)
	character_view.set_difficulty(_selected_difficulty_id)
	if first_id.is_empty():
		character_error_label.text = "没有可用角色"
		character_error_label.visible = true
		return
	_on_character_selected(first_id)


func _on_character_selected(character_id: String) -> void:
	if character_id == _selected_character_id and not _selected_character_record.is_empty():
		return
	_selected_character_id = character_id
	_selected_character_record = DataRegistry.get_record("characters", character_id) if DataRegistry != null else {}
	character_view.show_character(_selected_character_record, _get_character_starting_stats(_selected_character_record))
	character_error_label.visible = false
	character_confirm_button.disabled = _selected_character_record.is_empty()


func _on_difficulty_selected(difficulty_id: String) -> void:
	_selected_difficulty_id = BattleDifficulty.normalize(difficulty_id)
	character_view.set_difficulty(_selected_difficulty_id)


func _animate_character_page_in() -> void:
	if character_view == null:
		return
	character_view.modulate.a = 0.0
	create_tween().tween_property(character_view, "modulate:a", 1.0, 0.25)


func _get_character_starting_stats(record: Dictionary) -> Dictionary:
	# Use the same acquisition/modifier path as a run, without touching live state.
	var preview := PlayerController.new()
	preview.auto_initialize_on_ready = false
	if not preview.initialize_from_character(str(record.get("id", ""))):
		preview.free()
		return {}
	var bank := BattleFinanceSystem.new()
	bank.initialize(preview, func(): return 0, func(_delta, _reason): return true)
	preview.relic_added.connect(bank.on_relic_added)
	preview.grant_starting_relics()
	var result: Dictionary = {}
	for stat_id in StatDefinitions.get_all_stat_ids():
		result[stat_id] = preview.get_stat(stat_id)
	result["finance"] = bank.principal
	result["interest_rate"] = bank.get_interest_rate()
	preview.free()
	return result

func _refresh_result_text() -> void:
	if _main_flow_coordinator == null:
		return
	if battle_result_panel != null and not _main_flow_coordinator.current_battle_summary.is_empty():
		battle_result_panel.present(_main_flow_coordinator.current_battle_summary)


func _on_result_changed(_victory: bool, _summary: Dictionary) -> void:
	_refresh_result_text()


func _on_result_back_pressed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.confirm_battle_result()


func _apply_start_page_assets() -> void:
	_ensure_texture(start_page_background, MAIN_MENU_BACKGROUND_TEXTURE_PATH)
	_ensure_texture(title_art, MAIN_MENU_TITLE_TEXTURE_PATH)


func _ensure_texture(texture_rect: TextureRect, fallback_path: String) -> void:
	if texture_rect == null:
		return
	if texture_rect.texture == null:
		texture_rect.texture = _load_menu_texture(fallback_path)
	if texture_rect.texture != null:
		texture_rect.visible = true


func _load_menu_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource as Texture2D
