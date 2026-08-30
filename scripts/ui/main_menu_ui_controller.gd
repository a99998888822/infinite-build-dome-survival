extends CanvasLayer
class_name MainMenuUIController

const MAIN_MENU_BACKGROUND_TEXTURE_PATH: String = "res://assets/ui/main_menu/bg_main_menu.png"
const MAIN_MENU_TITLE_TEXTURE_PATH: String = "res://assets/ui/main_menu/title_main_menu.png"
const MAIN_MENU_BUTTON_TEXTURE_PATH: String = "res://assets/ui/main_menu/button_main_menu.png"
const ROLE_SELECT_BACKDROP_SCRIPT: Script = preload("res://scripts/ui/role_select_backdrop.gd")
const HINT_MESSAGES: Array[String] = [
	"Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn",
	"在拉莱耶的宅邸中，长眠的克拉斯托弗候汝入梦",
	"永恒长眠的并非亡者，奇妙的万古之中，即便死亡亦会消逝",
	"穹顶之下，古神注视着你……",
	"按下「开始战斗」，直面怪物的视线",
	"不要抬头看……不要去数星星……",
	"它们从深处苏醒，穹顶只是一道脆弱的屏障",
]
const HINT_COLORS: Array[Color] = [
	Color("#6e9d91"),
	Color("#a884b5"),
	Color("#7087a8"),
	Color("#b69a65"),
]
const HINT_INTERVAL := 9.0

var _main_flow_coordinator: MainFlowCoordinator = null
var _selected_character_id: String = ""
var _selected_character_record: Dictionary = {}
var _selected_difficulty_id: String = "standard"
var _title_base_position := Vector2.ZERO
var _button_feedback_tweens: Dictionary = {}
var _button_shake_tweens: Dictionary = {}
var _role_button_tweens: Dictionary = {}
var _character_icon_tween: Tween = null
var _role_select_was_visible := false
var _hint_index := 0
var _hint_elapsed := 0.0
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

@onready var start_page: Control = get_node_or_null("StartPage")
@onready var start_page_background: TextureRect = get_node_or_null("StartPage/Background")
@onready var title_art: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/TitleArea/TitleCenter/TitleStack/TitleArt")
@onready var start_battle_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell")
@onready var camp_entry_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell")
@onready var settings_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/SettingsShell")
@onready var quit_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell")
@onready var start_battle_button_frame: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell/FrameTexture")
@onready var camp_entry_button_frame: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell/FrameTexture")
@onready var quit_button_frame: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/FrameTexture")
@onready var start_battle_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell/StartBattleButton")
@onready var camp_entry_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell/CampEntryButton")
@onready var settings_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/SettingsShell/SettingsButton")
@onready var quit_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/QuitButton")
@onready var hint_label: Label = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/MenuHintLabel")
@onready var character_select_page: Control = get_node_or_null("CharacterSelectPage")
@onready var character_title_label: Label = null
@onready var stats_list: VBoxContainer = null
@onready var weapon_list: VBoxContainer = null
@onready var passive_list: VBoxContainer = null
@onready var difficulty_list: VBoxContainer = null
@onready var character_details_scroll: ScrollContainer = null
@onready var character_list: VBoxContainer = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterList")
@onready var character_icon: TextureRect = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterDetails/CharacterHeader/CharacterIcon")
@onready var character_name_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterDetails/CharacterHeader/CharacterName")
@onready var character_description_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterDetails/CharacterDescription")
@onready var character_stats_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterDetails/StatsLabel")
@onready var character_weapon_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterDetails/WeaponLabel")
@onready var character_passive_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/SelectionBody/CharacterDetails/PassiveLabel")
@onready var difficulty_option: OptionButton = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/DifficultyRow/DifficultyOption")
@onready var difficulty_description_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/DifficultyDescription")
@onready var character_error_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/ErrorLabel")
@onready var character_back_button: Button = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/ButtonRow/BackButton")
@onready var character_confirm_button: Button = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/ButtonRow/ConfirmButton")
@onready var battle_result_panel: Control = get_node_or_null("BattleResultPanel")
@onready var result_title_label: Label = get_node_or_null("BattleResultPanel/CenterContainer/MainPanel/Content/ResultTitleLabel")
@onready var result_summary_label: Label = get_node_or_null("BattleResultPanel/CenterContainer/MainPanel/Content/ResultSummaryLabel")
@onready var result_back_button: Button = get_node_or_null("BattleResultPanel/CenterContainer/MainPanel/Content/ResultBackButton")

var role_select_backdrop: Control = null


func _ready() -> void:
	_setup_role_select_runtime_ui()
	_apply_start_page_assets()
	_setup_start_page_feedback()
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
	if result_back_button != null and not result_back_button.pressed.is_connected(_on_result_back_pressed):
		result_back_button.pressed.connect(_on_result_back_pressed)
	call_deferred("_bind_to_main_flow")


func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	if title_art != null and start_page != null and start_page.visible:
		var title_offset := sin(time * 1.7) * 4.0
		title_art.position = _title_base_position + Vector2(0.0, title_offset)
		_update_hint_effect(delta, time)


func _setup_menu_atmosphere() -> void:
	if title_art != null:
		_title_base_position = title_art.position
	if hint_label != null and not HINT_MESSAGES.is_empty():
		hint_label.text = HINT_MESSAGES[_hint_index]


func _setup_start_page_feedback() -> void:
	_bind_button_feedback(start_battle_button, start_battle_shell)
	_bind_button_feedback(camp_entry_button, camp_entry_shell)
	_bind_button_feedback(settings_button, settings_shell)
	_bind_button_feedback(quit_button, quit_shell)


func _bind_button_feedback(button: Button, shell: Control) -> void:
	if button == null or shell == null:
		return
	shell.resized.connect(_center_button_pivot.bind(shell))
	_center_button_pivot(shell)
	if not button.mouse_entered.is_connected(_on_menu_button_hovered.bind(shell)):
		button.mouse_entered.connect(_on_menu_button_hovered.bind(shell))
	if not button.mouse_exited.is_connected(_on_menu_button_unhovered.bind(shell)):
		button.mouse_exited.connect(_on_menu_button_unhovered.bind(shell))


func _center_button_pivot(shell: Control) -> void:
	shell.pivot_offset = shell.size * 0.5


func _on_menu_button_hovered(shell: Control) -> void:
	_animate_menu_button(shell, Vector2(1.06, 1.06), Color(1.12, 1.12, 1.04, 1))
	var old_shake_tween: Tween = _button_shake_tweens.get(shell)
	if old_shake_tween != null:
		old_shake_tween.kill()
	var shake_tween := create_tween()
	shake_tween.tween_property(shell, "rotation", deg_to_rad(-1.2), 0.055)
	shake_tween.tween_property(shell, "rotation", deg_to_rad(1.2), 0.09)
	shake_tween.tween_property(shell, "rotation", deg_to_rad(-0.8), 0.075)
	shake_tween.tween_property(shell, "rotation", deg_to_rad(0.0), 0.065)
	shake_tween.set_loops()
	_button_shake_tweens[shell] = shake_tween


func _on_menu_button_unhovered(shell: Control) -> void:
	_animate_menu_button(shell, Vector2.ONE, Color.WHITE)
	var shake_tween: Tween = _button_shake_tweens.get(shell)
	if shake_tween != null:
		shake_tween.kill()
	_button_shake_tweens.erase(shell)
	var reset_tween := create_tween()
	reset_tween.tween_property(shell, "rotation", 0.0, 0.1)


func _animate_menu_button(shell: Control, target_scale: Vector2, target_modulate: Color) -> void:
	var old_tween: Tween = _button_feedback_tweens.get(shell)
	if old_tween != null:
		old_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(shell, "scale", target_scale, 0.13)
	tween.tween_property(shell, "modulate", target_modulate, 0.13)
	_button_feedback_tweens[shell] = tween


func _update_hint_effect(delta: float, time: float) -> void:
	if hint_label == null or HINT_MESSAGES.is_empty():
		return
	_hint_elapsed += delta
	if _hint_elapsed >= HINT_INTERVAL:
		_hint_elapsed = 0.0
		_hint_index = (_hint_index + 1) % HINT_MESSAGES.size()
		hint_label.text = HINT_MESSAGES[_hint_index]
	var color_index := _hint_index % HINT_COLORS.size()
	var color := HINT_COLORS[color_index]
	var color_next := HINT_COLORS[(color_index + 1) % HINT_COLORS.size()]
	var color_mix := (sin(time * 0.75) + 1.0) * 0.5
	var flicker := 0.90 + sin(time * 1.2) * 0.04 + sin(time * 2.7) * 0.02
	hint_label.modulate = Color(color.lerp(color_next, color_mix), clampf(flicker, 0.82, 1.0))


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
	_selected_difficulty_id = "standard"
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
	content.add_theme_constant_override("separation", 18)
	_settings_panel.add_child(content)
	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffe18a"))
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)
	_music_slider = _make_volume_row(content, "背景音乐", 100)
	_sfx_slider = _make_volume_row(content, "音效", 100)
	var resolution_row := HBoxContainer.new()
	resolution_row.add_theme_constant_override("separation", 16)
	content.add_child(resolution_row)
	var resolution_label := _make_settings_label("界面分辨率")
	resolution_label.custom_minimum_size = Vector2(150, 42)
	resolution_row.add_child(resolution_label)
	_resolution_option = OptionButton.new()
	_resolution_option.custom_minimum_size = Vector2(300, 42)
	resolution_row.add_child(_resolution_option)
	if WindowSettings != null:
		for size in WindowSettings.get_resolution_presets():
			_resolution_option.add_item("%d × %d" % [size.x, size.y])
	_resolution_option.item_selected.connect(_on_resolution_selected)
	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.add_theme_constant_override("separation", 16)
	content.add_child(fullscreen_row)
	var fullscreen_title := _make_settings_label("全屏：")
	fullscreen_title.custom_minimum_size = Vector2(150, 42)
	fullscreen_title.add_theme_color_override("font_color", Color("#ffe18a"))
	fullscreen_title.add_theme_font_size_override("font_size", 18)
	fullscreen_row.add_child(fullscreen_title)
	var fullscreen_group := ButtonGroup.new()
	_fullscreen_yes_button = _make_fullscreen_option("是", fullscreen_group)
	_fullscreen_no_button = _make_fullscreen_option("否", fullscreen_group)
	fullscreen_row.add_child(_fullscreen_yes_button)
	fullscreen_row.add_child(_fullscreen_no_button)
	_display_settings_note = _make_settings_label("")
	_display_settings_note.custom_minimum_size = Vector2(0, 38)
	_display_settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_display_settings_note.add_theme_color_override("font_color", Color("#e3b65c"))
	_display_settings_note.add_theme_font_size_override("font_size", 13)
	content.add_child(_display_settings_note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var back_button := Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(180, 46)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.add_theme_font_size_override("font_size", 16)
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
	var label := _make_settings_label(title_text)
	label.custom_minimum_size = Vector2(150, 42)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = default_value
	slider.custom_minimum_size = Vector2(300, 42)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := _make_settings_label("100%")
	value_label.custom_minimum_size = Vector2(70, 42)
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
	label.add_theme_color_override("font_color", Color("#d9d0af"))
	label.add_theme_font_size_override("font_size", 16)
	return label

func _make_settings_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111b16")
	style.border_color = Color("#d3a637")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 12
	return style

func _make_settings_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _on_settings_pressed() -> void:
	if _settings_panel == null:
		return
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
		if WindowSettings.is_embedded():
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
		_music_slider.value = music_value
	if _sfx_slider != null:
		_sfx_slider.value = sfx_value
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
	button.custom_minimum_size = Vector2(124, 44)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
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
	var old_center := character_select_page.get_node_or_null("CenterContainer")
	if old_center != null:
		old_center.visible = false
	var runtime := character_select_page.get_node_or_null("RoleSelectRuntime") as Control
	if runtime != null:
		return
	runtime = Control.new()
	runtime.name = "RoleSelectRuntime"
	runtime.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_select_page.add_child(runtime)

	var background := ROLE_SELECT_BACKDROP_SCRIPT.new() as Control
	background.name = "Backdrop"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_select_backdrop = background
	runtime.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	runtime.add_child(margin)

	var page_column := VBoxContainer.new()
	page_column.add_theme_constant_override("separation", 12)
	margin.add_child(page_column)

	var header := VBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 74)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 2)
	page_column.add_child(header)
	var title := Label.new()
	title.text = "选择角色"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffe18a"))
	title.add_theme_color_override("font_shadow_color", Color("#000000"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "SELECT SURVIVOR"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("#8dbda0"))
	header.add_child(subtitle)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page_column.add_child(body)

	var survivor_panel := _make_role_panel("SURVIVORS")
	survivor_panel.custom_minimum_size = Vector2(240, 0)
	survivor_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(survivor_panel)
	var survivor_content := survivor_panel.get_node("Body") as VBoxContainer
	var survivor_scroll := TouchScrollContainer.new()
	survivor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	survivor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	survivor_content.add_child(survivor_scroll)
	character_list = VBoxContainer.new()
	character_list.add_theme_constant_override("separation", 8)
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survivor_scroll.add_child(character_list)

	var center_column := VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 12)
	body.add_child(center_column)

	var summary := PanelContainer.new()
	summary.custom_minimum_size = Vector2(0, 128)
	summary.add_theme_stylebox_override("panel", _make_role_style(Color("#15120f"), Color("#8d6818"), 2, 0))
	center_column.add_child(summary)
	var summary_stack := VBoxContainer.new()
	summary_stack.add_theme_constant_override("separation", 0)
	summary.add_child(summary_stack)
	var summary_body := HBoxContainer.new()
	summary_body.name = "Body"
	summary_body.add_theme_constant_override("separation", 12)
	summary_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_stack.add_child(summary_body)
	character_icon = TextureRect.new()
	character_icon.custom_minimum_size = Vector2(78, 78)
	character_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	character_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	character_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	summary_body.add_child(character_icon)
	var character_info := VBoxContainer.new()
	character_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	character_info.add_theme_constant_override("separation", 5)
	summary_body.add_child(character_info)
	character_name_label = Label.new()
	character_name_label.add_theme_font_size_override("font_size", 25)
	character_name_label.add_theme_color_override("font_color", Color("#c49a4a"))
	character_info.add_child(character_name_label)
	character_title_label = Label.new()
	character_title_label.add_theme_font_size_override("font_size", 11)
	character_title_label.add_theme_color_override("font_color", Color("#8cc56e"))
	character_info.add_child(character_title_label)
	character_description_label = Label.new()
	character_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_description_label.add_theme_color_override("font_color", Color("#c5b887"))
	character_info.add_child(character_description_label)

	var details_frame := PanelContainer.new()
	details_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_padding := 12
	var details_frame_style := _make_role_style(Color("#0b1510"), Color("#8d6818"), 2, 0)
	details_frame_style.content_margin_left = frame_padding
	details_frame_style.content_margin_top = frame_padding
	details_frame_style.content_margin_right = frame_padding
	details_frame_style.content_margin_bottom = frame_padding
	details_frame.add_theme_stylebox_override("panel", details_frame_style)
	center_column.add_child(details_frame)
	character_details_scroll = TouchScrollContainer.new()
	character_details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_details_scroll.clip_contents = true
	details_frame.add_child(character_details_scroll)
	var details_scroll_content := VBoxContainer.new()
	details_scroll_content.name = "DetailsScrollContent"
	details_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_details_scroll.add_child(details_scroll_content)
	var details_padding := 8
	var details_top_spacer := Control.new()
	details_top_spacer.custom_minimum_size = Vector2(0, details_padding)
	details_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_scroll_content.add_child(details_top_spacer)
	var details_panel := PanelContainer.new()
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.add_theme_stylebox_override("panel", _make_role_style(Color("#0d1c13"), Color("#59441f"), 1, 0))
	details_scroll_content.add_child(details_panel)
	var details_content := VBoxContainer.new()
	details_content.name = "DetailsContent"
	details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_content.add_theme_constant_override("separation", 8)
	details_panel.add_child(details_content)
	var stats_title := _make_role_section_title("◆ 基础属性")
	details_content.add_child(stats_title)
	stats_list = VBoxContainer.new()
	stats_list.add_theme_constant_override("separation", 5)
	details_content.add_child(stats_list)
	var weapon_title := _make_role_section_title("◆ 初始武器")
	details_content.add_child(weapon_title)
	weapon_list = VBoxContainer.new()
	weapon_list.add_theme_constant_override("separation", 6)
	details_content.add_child(weapon_list)
	var passive_title := _make_role_section_title("◆ 角色特性")
	details_content.add_child(passive_title)
	passive_list = VBoxContainer.new()
	passive_list.add_theme_constant_override("separation", 6)
	details_content.add_child(passive_list)
	var details_bottom_spacer := Control.new()
	details_bottom_spacer.custom_minimum_size = Vector2(0, details_padding)
	details_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_scroll_content.add_child(details_bottom_spacer)

	var difficulty_panel := _make_role_panel("DIFFICULTY")
	difficulty_panel.name = "DifficultyPanel"
	difficulty_panel.custom_minimum_size = Vector2(270, 0)
	difficulty_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(difficulty_panel)
	var difficulty_content := difficulty_panel.get_node("Body") as VBoxContainer
	difficulty_list = VBoxContainer.new()
	difficulty_list.name = "DifficultyList"
	difficulty_list.add_theme_constant_override("separation", 8)
	difficulty_content.add_child(difficulty_list)
	difficulty_description_label = Label.new()
	difficulty_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_description_label.add_theme_color_override("font_color", Color("#9eab91"))
	difficulty_description_label.visible = false
	difficulty_content.add_child(difficulty_description_label)

	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, 34)
	page_column.add_child(footer)
	character_back_button = _make_role_button("◀ 返回主界面")
	character_back_button.custom_minimum_size = Vector2(160, 34)
	footer.add_child(character_back_button)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	character_confirm_button = _make_role_button("继续 ▶")
	character_confirm_button.custom_minimum_size = Vector2(136, 34)
	footer.add_child(character_confirm_button)
	character_error_label = Label.new()
	character_error_label.visible = false
	page_column.add_child(character_error_label)
	_add_role_select_scanlines(runtime)


func _add_role_select_scanlines(runtime: Control) -> void:
	var scanline_image := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	scanline_image.fill(Color.TRANSPARENT)
	scanline_image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.045))
	scanline_image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 0.045))
	var scanlines := TextureRect.new()
	scanlines.texture = ImageTexture.create_from_image(scanline_image)
	scanlines.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	scanlines.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scanlines.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scanlines.stretch_mode = TextureRect.STRETCH_TILE
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanlines.z_index = 1
	runtime.add_child(scanlines)

func _rebuild_character_list() -> void:
	if character_list == null:
		return
	for child in character_list.get_children():
		child.queue_free()
	for container in [stats_list, weapon_list, passive_list, difficulty_list]:
		if container == null:
			continue
		for child in container.get_children():
			child.queue_free()
	_selected_character_id = ""
	_selected_character_record.clear()
	if character_confirm_button != null:
		character_confirm_button.disabled = true
	var character_records: Array = DataRegistry.get_table("characters") if DataRegistry != null else []
	var first_character_id := ""
	for record in character_records:
		if not (record is Dictionary):
			continue
		var character_id := str(record.get("id", ""))
		if character_id.is_empty():
			continue
		if first_character_id.is_empty():
			first_character_id = character_id
		var button := _make_role_button("%s
%s" % [str(record.get("display_name", character_id)), "初始角色" if record.get("tags", []).has("starter") else "可用角色"])
		button.custom_minimum_size = Vector2(0, 68)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var icon_path := str(record.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			button.icon = load(icon_path) as Texture2D
			button.add_theme_constant_override("icon_max_width", 42)
		button.set_meta("character_id", character_id)
		button.pressed.connect(_on_character_selected.bind(character_id))
		character_list.add_child(button)
	if first_character_id.is_empty():
		if character_error_label != null:
			character_error_label.text = "没有可用角色"
			character_error_label.visible = true
		return
	_build_difficulty_list()
	_on_character_selected(first_character_id)
	call_deferred("_animate_role_select_entries")

func _animate_role_select_entries() -> void:
	var containers: Array = [character_list, difficulty_list]
	for container_variant in containers:
		var container := container_variant as VBoxContainer
		if container == null:
			continue
		for index in container.get_child_count():
			var button := container.get_child(index) as Button
			if button == null:
				continue
			button.pivot_offset = button.size * 0.5
			button.modulate.a = 0.0
			button.scale = Vector2(0.96, 0.96)
			var tween := create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(button, "modulate:a", 1.0, 0.22).set_delay(float(index) * 0.045)
			tween.tween_property(button, "scale", Vector2.ONE, 0.26).set_delay(float(index) * 0.045)

func _on_character_selected(character_id: String) -> void:
	if character_id == _selected_character_id and not _selected_character_record.is_empty():
		return
	_selected_character_id = character_id
	_selected_character_record = DataRegistry.get_record("characters", character_id) if DataRegistry != null else {}
	_refresh_character_details(_selected_character_record)
	_refresh_character_button_states()
	if character_error_label != null:
		character_error_label.visible = false
	if character_confirm_button != null:
		character_confirm_button.disabled = _selected_character_record.is_empty()
	if character_details_scroll != null:
		character_details_scroll.scroll_vertical = 0
	_animate_character_details()

func _on_difficulty_selected(difficulty_id: String) -> void:
	_selected_difficulty_id = difficulty_id if not difficulty_id.is_empty() else "standard"
	_refresh_difficulty_button_states()
	_refresh_difficulty_text()

func _refresh_difficulty_text() -> void:
	if difficulty_description_label == null:
		return
	match _selected_difficulty_id:
		"hard":
			difficulty_description_label.text = "敌人更凶猛，适合熟悉基础玩法后的挑战。"
		"nightmare":
			difficulty_description_label.text = "高压挑战：容错率很低，适合追求极限的玩家。"
		_:
			difficulty_description_label.text = "标准战局：推荐首次体验，完整展现穹顶生存流程。"

func _refresh_character_details(record: Dictionary) -> void:
	if character_name_label == null or stats_list == null or weapon_list == null or passive_list == null:
		return
	if record.is_empty():
		character_name_label.text = "请选择角色"
		character_title_label.text = "SELECT A SURVIVOR"
		character_description_label.text = "选择左侧角色查看基础属性、初始武器与特性。"
		character_icon.texture = null
		return
	character_name_label.text = str(record.get("display_name", record.get("id", "未知角色")))
	character_title_label.text = "STARTER SURVIVOR · 初始角色" if record.get("tags", []).has("starter") else "SURVIVOR · 可用角色"
	character_description_label.text = str(record.get("description", "暂无角色描述"))
	var display_sprite_path := str(record.get("display_sprite", ""))
	character_icon.texture = load(display_sprite_path) as Texture2D if not display_sprite_path.is_empty() and ResourceLoader.exists(display_sprite_path) else null
	_build_stat_rows(record.get("base_stats", {}), record.get("display_stats", []))
	_build_weapon_cards(record.get("start_weapons", []))
	_build_passive_cards(record.get("passive_modifiers", []))

func _build_stat_rows(stats: Variant, display_stat_ids: Variant = []) -> void:
	if not (stats is Dictionary):
		return
	var names := {"max_hp": "生命值", "hp_regen": "生命回复", "shield": "护盾", "armor": "护甲", "move_speed": "移动速度", "load_capacity": "负载上限", "pickup_radius": "拾取范围", "humanity": "理智值", "divinity": "侵蚀度"}
	var caps := {"max_hp": 20.0, "hp_regen": 10.0, "shield": 20.0, "armor": 20.0, "move_speed": 360.0, "load_capacity": 150.0, "pickup_radius": 240.0, "humanity": 100.0, "divinity": 100.0}
	var colors := {"max_hp": Color("#c85f52"), "hp_regen": Color("#d38b61"), "shield": Color("#72a9c8"), "armor": Color("#9c87c7"), "move_speed": Color("#6d9bc8"), "load_capacity": Color("#c49a4a"), "pickup_radius": Color("#73ad79"), "humanity": Color("#82b878"), "divinity": Color("#a979bd")}
	var default_stat_order: Array[String] = ["max_hp", "hp_regen", "shield", "armor", "move_speed", "load_capacity", "pickup_radius", "humanity", "divinity"]
	var stat_order: Array = display_stat_ids if display_stat_ids is Array else default_stat_order
	for stat_id_variant in stat_order:
		var stat_id := str(stat_id_variant)
		if stats.has(stat_id):
			stats_list.add_child(_make_stat_row(str(names.get(stat_id, stat_id)), float(stats[stat_id]), float(caps.get(stat_id, 100.0)), colors.get(stat_id, Color("#c49a4a"))))

func _make_stat_row(label_text: String, value: float, cap: float, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.custom_minimum_size = Vector2(82, 0)
	label.text = label_text
	label.add_theme_color_override("font_color", Color("#9eab91"))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 16)
	bar.max_value = cap
	bar.value = 0.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_role_style(Color("#0a150e"), Color("#385843"), 2, 0))
	bar.add_theme_stylebox_override("fill", _make_role_style(color, color.lightened(0.12), 0, 0))
	row.add_child(bar)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58, 0)
	value_label.text = _format_number(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color("#d6c68e"))
	row.add_child(value_label)
	var tween := create_tween()
	tween.tween_property(bar, "value", value, 0.32)
	return row

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(value)
	return "%.2f" % value

func _build_weapon_cards(weapon_ids: Variant) -> void:
	if not (weapon_ids is Array) or weapon_ids.is_empty():
		weapon_list.add_child(_make_info_card("暂无初始武器", "本局将从基础配置开始。"))
		return
	for weapon_id in weapon_ids:
		var weapon := DataRegistry.get_record("weapons", str(weapon_id)) if DataRegistry != null else {}
		if weapon.is_empty():
			weapon_list.add_child(_make_info_card(str(weapon_id), "武器配置缺失"))
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_role_style(Color("#111b16"), Color("#59441f"), 1, 0))
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path := str(weapon.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path) as Texture2D
		body.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = str(weapon.get("display_name", weapon_id))
		name_label.add_theme_color_override("font_color", Color("#d6c68e"))
		info.add_child(name_label)
		var stats: Dictionary = weapon.get("base_stats", {})
		var kind := "混合" if weapon.get("attack_kind", "") == "mixed" else ("远程" if weapon.get("attack_kind", "") == "ranged" else "近战")
		var damage: float = float(stats.get("ranged_damage", stats.get("melee_damage", 0)))
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.text = "%s · 伤害 %s · 间隔 %.2fs · 负载 %d" % [kind, _format_number(damage), float(weapon.get("attack_interval_ms", 0)) / 1000.0, int(weapon.get("load_cost", 0))]
		detail.add_theme_color_override("font_color", Color("#9eab91"))
		info.add_child(detail)
		var description := Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = str(weapon.get("description", "暂无武器描述"))
		description.add_theme_color_override("font_color", Color("#778979"))
		info.add_child(description)
		body.add_child(info)
		card.add_child(body)
		weapon_list.add_child(card)

func _build_passive_cards(passives: Variant) -> void:
	if not (passives is Array) or passives.is_empty():
		passive_list.add_child(_make_info_card("暂无特殊特性", "该角色使用标准属性和基础武器开始战斗。"))
		return
	for passive in passives:
		var text := str(passive.get("description", passive.get("stat", "未知特性"))) if passive is Dictionary else str(passive)
		passive_list.add_child(_make_info_card("角色特性", text))

func _make_info_card(title_text: String, body_text: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_role_style(Color("#111b16"), Color("#59441f"), 1, 0))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", Color("#d3a637"))
	title.add_theme_font_size_override("font_size", 11)
	content.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = body_text
	body.add_theme_color_override("font_color", Color("#a9a184"))
	body.add_theme_font_size_override("font_size", 11)
	content.add_child(body)
	card.add_child(content)
	return card

func _build_difficulty_list() -> void:
	if difficulty_list == null:
		return
	for child in difficulty_list.get_children():
		child.queue_free()
	var difficulties := [
		{"id": "standard", "name": "STANDARD", "title": "标准", "description": "标准战局，无额外修正。", "color": Color("#c8ae54")},
		{"id": "hard", "name": "HARD", "title": "困难", "description": "敌人更凶猛，适合熟悉基础玩法后的挑战。", "color": Color("#c8794f")},
		{"id": "nightmare", "name": "NIGHTMARE", "title": "梦魇", "description": "高压挑战，容错率很低。", "color": Color("#a873bd")},
	]
	for difficulty in difficulties:
		var button := _make_role_button("%s  %s
%s" % [difficulty["name"], difficulty["title"], difficulty["description"]])
		button.custom_minimum_size = Vector2(0, 76)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_meta("difficulty_id", difficulty["id"])
		button.set_meta("difficulty_color", difficulty["color"])
		button.pressed.connect(_on_difficulty_selected.bind(difficulty["id"]))
		difficulty_list.add_child(button)
	_refresh_difficulty_button_states()
	_refresh_difficulty_text()

func _refresh_difficulty_button_states() -> void:
	if difficulty_list == null:
		return
	for child in difficulty_list.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var selected := str(button.get_meta("difficulty_id", "")) == _selected_difficulty_id
		var color: Color = button.get_meta("difficulty_color", Color("#385843"))
		button.add_theme_stylebox_override("normal", _make_role_style(Color("#2c2817") if selected else Color("#111b16"), color if selected else Color("#59441f"), 2 if selected else 1, 0))
		button.add_theme_stylebox_override("hover", _make_role_style(Color("#473616") if selected else Color("#2b3020"), color.lightened(0.12), 2, 0))
		button.add_theme_stylebox_override("pressed", _make_role_style(Color("#473616"), color.lightened(0.12), 1, 0, true))

func _refresh_character_button_states() -> void:
	if character_list == null:
		return
	for child in character_list.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var selected := str(button.get_meta("character_id", "")) == _selected_character_id
		var normal_background := Color("#2c2817") if selected else Color("#111b16")
		var normal_border := Color("#ffe18a") if selected else Color("#59441f")
		button.add_theme_stylebox_override("normal", _make_role_style(normal_background, normal_border, 2 if selected else 1, 0))
		button.add_theme_stylebox_override("hover", _make_role_style(Color("#473616") if selected else Color("#2b3020"), Color("#ffe18a"), 2, 0))

func _on_character_button_hovered(button: Button) -> void:
	if button == null or button.disabled:
		return
	var old_tween: Tween = _role_button_tweens.get(button)
	if old_tween != null:
		old_tween.kill()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.015, 1.015), 0.1)
	tween.tween_property(button, "modulate", Color(1.06, 1.04, 0.96, 1.0), 0.1)
	_role_button_tweens[button] = tween

func _on_character_button_unhovered(button: Button) -> void:
	if button == null:
		return
	var old_tween: Tween = _role_button_tweens.get(button)
	if old_tween != null:
		old_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)
	_role_button_tweens[button] = tween

func _animate_character_page_in() -> void:
	if character_select_page == null:
		return
	var runtime := character_select_page.get_node_or_null("RoleSelectRuntime") as Control
	if runtime != null:
		runtime.pivot_offset = runtime.size * 0.5
		runtime.modulate.a = 0.0
		runtime.scale = Vector2(0.985, 0.985)
		var runtime_tween := create_tween().set_parallel(true)
		runtime_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		runtime_tween.tween_property(runtime, "modulate:a", 1.0, 0.34)
		runtime_tween.tween_property(runtime, "scale", Vector2.ONE, 0.42)
	else:
		character_select_page.modulate.a = 0.0
		var page_tween := create_tween()
		page_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		page_tween.tween_property(character_select_page, "modulate:a", 1.0, 0.32)

func _animate_character_details() -> void:
	if character_name_label == null:
		return
	if _character_icon_tween != null:
		_character_icon_tween.kill()
	character_name_label.modulate.a = 0.0
	character_description_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(character_name_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(character_description_label, "modulate:a", 1.0, 0.28).set_delay(0.06)
	if character_icon != null:
		character_icon.pivot_offset = character_icon.size * 0.5
		character_icon.modulate.a = 0.0
		character_icon.scale = Vector2(0.90, 0.90)
		tween.tween_property(character_icon, "modulate:a", 1.0, 0.24)
		tween.tween_property(character_icon, "scale", Vector2.ONE, 0.30)
		tween.chain().tween_callback(_start_character_icon_breathing)

func _start_character_icon_breathing() -> void:
	if character_icon == null or not is_instance_valid(character_icon):
		return
	if _character_icon_tween != null:
		_character_icon_tween.kill()
	_character_icon_tween = create_tween().set_loops()
	_character_icon_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_character_icon_tween.tween_property(character_icon, "scale", Vector2(1.015, 1.015), 1.05)
	_character_icon_tween.tween_property(character_icon, "scale", Vector2.ONE, 1.05)

func _make_role_panel(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_role_style(Color("#0d1c14"), Color("#8d6818"), 2, 0))
	var column := VBoxContainer.new()
	column.name = "Body"
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	if not title_text.is_empty():
		var title := Label.new()
		title.text = title_text
		title.custom_minimum_size = Vector2(0, 26)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", Color("#ffe18a"))
		title.add_theme_font_size_override("font_size", 12)
		column.add_child(title)
		var rule := ColorRect.new()
		rule.custom_minimum_size = Vector2(0, 1)
		rule.color = Color("#8d6818")
		column.add_child(rule)
	return panel

func _make_role_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#d3a637"))
	label.add_theme_font_size_override("font_size", 12)
	return label

func _make_role_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#d9d0af"))
	button.add_theme_color_override("font_hover_color", Color("#ffe18a"))
	button.add_theme_color_override("font_pressed_color", Color("#f1df9e"))
	button.add_theme_stylebox_override("normal", _make_role_style(Color("#111b16"), Color("#59441f"), 1, 0))
	button.add_theme_stylebox_override("hover", _make_role_style(Color("#2b3020"), Color("#ffe18a"), 2, 0))
	button.add_theme_stylebox_override("pressed", _make_role_style(Color("#473616"), Color("#d3a637"), 1, 0, true))
	button.add_theme_stylebox_override("disabled", _make_role_style(Color("#121513"), Color("#454238"), 1, 0))
	button.mouse_entered.connect(_on_character_button_hovered.bind(button))
	button.mouse_exited.connect(_on_character_button_unhovered.bind(button))
	return button

func _make_role_style(background: Color, border: Color, border_width: int, radius: int, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.border_color = border.darkened(0.12) if pressed else border
	style.shadow_color = border.darkened(0.72) if not pressed and border_width > 0 else Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 4 if not pressed and border_width > 0 else 0
	style.shadow_offset = Vector2(2, 2) if border_width > 0 else Vector2.ZERO
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0 if not pressed else 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0 if not pressed else 6.0
	return style

func _refresh_result_text() -> void:
	if _main_flow_coordinator == null:
		return
	var victory := _main_flow_coordinator.current_victory
	var summary := _main_flow_coordinator.current_battle_summary
	if result_title_label != null:
		result_title_label.text = "战斗胜利" if victory else "战斗失败"
	if result_summary_label != null:
		var reason := str(summary.get("reason", ""))
		var summary_text := ""
		if reason == "all_waves_cleared":
			summary_text = "通关全部波次！"
		elif reason == "player_died":
			summary_text = "你在第 %d 波阵亡了" % maxi(_main_flow_coordinator.current_wave_index + 1, 1)
		else:
			summary_text = reason
		result_summary_label.text = summary_text


func _on_result_back_pressed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.confirm_battle_result()


func _apply_start_page_assets() -> void:
	_ensure_texture(start_page_background, MAIN_MENU_BACKGROUND_TEXTURE_PATH)
	_ensure_texture(title_art, MAIN_MENU_TITLE_TEXTURE_PATH)
	_ensure_texture(start_battle_button_frame, MAIN_MENU_BUTTON_TEXTURE_PATH)
	_ensure_texture(camp_entry_button_frame, MAIN_MENU_BUTTON_TEXTURE_PATH)
	_ensure_texture(quit_button_frame, MAIN_MENU_BUTTON_TEXTURE_PATH)


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
