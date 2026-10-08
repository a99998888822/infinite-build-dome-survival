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
var _settings_panel: GameSettingsPanel = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _resolution_option: OptionButton = null
var _fullscreen_yes_button: Button = null
var _fullscreen_no_button: Button = null
var _music_value_label: Label = null
var _sfx_value_label: Label = null
var _display_settings_note: Label = null
var _settings_tween: Tween = null
var _language_option: OptionButton

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
	_create_language_selector()
	L10n.locale_changed.connect(_on_locale_changed)
	_create_settings_ui()
	get_viewport().size_changed.connect(_layout_settings)
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
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.visible = false
	add_child(_settings_overlay)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.014, 0.022, 0.021, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(backdrop)
	_settings_panel = GameSettingsPanel.new()
	_settings_panel.name = "SettingsPanel"
	_settings_overlay.add_child(_settings_panel)
	_settings_panel.open_page(false)
	_settings_panel.back_requested.connect(_close_settings)
	_music_slider = _settings_panel.volume_controls.bgm_volume.slider
	_sfx_slider = _settings_panel.volume_controls.sfx_volume.slider
	_music_value_label = _settings_panel.volume_controls.bgm_volume.label
	_sfx_value_label = _settings_panel.volume_controls.sfx_volume.label
	_resolution_option = _settings_panel.resolution
	_fullscreen_yes_button = _settings_panel.fullscreen_yes
	_fullscreen_no_button = _settings_panel.fullscreen_no
	_display_settings_note = _settings_panel.display_note
	_layout_settings()


func _layout_settings() -> void:
	if _settings_panel != null:
		_settings_panel.fit_to_viewport(get_viewport().get_visible_rect().size)


func _input(event: InputEvent) -> void:
	if _settings_overlay == null or not _settings_overlay.is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _resolution_option.get_popup().visible: return
		get_viewport().set_input_as_handled()
		_close_settings()


func _on_settings_pressed() -> void:
	if _settings_panel == null:
		return
	_settings_panel.open_page(false)
	_layout_settings()
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
			character_error_label.text = "error.main_menu.battle_start_failed"
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
		character_error_label.text = "error.main_menu.no_characters"
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
	if title_art != null:
		var path := str(L10n.locale_definitions.get(L10n.locale, {}).get("title_texture", MAIN_MENU_TITLE_TEXTURE_PATH))
		title_art.texture = _load_menu_texture(path)
		title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_art.visible = title_art.texture != null


func _create_language_selector() -> void:
	if start_page == null:
		return
	var row := HBoxContainer.new()
	row.name = "LanguageSelector"
	start_page.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -268
	row.offset_right = -20
	row.offset_top = 18
	row.offset_bottom = 56
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "ui.main_menu.language"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("dcc795"))
	row.add_child(label)
	_language_option = OptionButton.new()
	_language_option.name = "LanguageOption"
	_language_option.custom_minimum_size = Vector2(160, 38)
	_language_option.size_flags_horizontal = Control.SIZE_SHRINK_END
	_language_option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_language_option.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in L10n.supported_locales:
		_language_option.add_item(str(L10n.locale_definitions[id].native_name))
	_language_option.add_theme_font_size_override("font_size", 16)
	_language_option.add_theme_color_override("font_color", Color("e2d5b3"))
	for state in ["normal", "hover", "pressed", "focus"]:
		_language_option.add_theme_stylebox_override(state, _language_style(state in ["hover", "focus"]))
	var popup := _language_option.get_popup()
	popup.add_theme_stylebox_override("panel", _language_style(false))
	popup.add_theme_stylebox_override("hover", _language_style(true))
	popup.add_theme_color_override("font_color", Color("e2d5b3"))
	popup.add_theme_color_override("font_hover_color", Color("fff0bd"))
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_constant_override("v_separation", 12)
	popup.add_theme_constant_override("start_padding", 12)
	popup.add_theme_constant_override("end_padding", 12)
	popup.add_theme_constant_override("indent", 10)
	for index in popup.item_count:
		popup.set_item_indent(index, 1)
	row.add_child(_language_option)
	_language_option.select(L10n.supported_locales.find(L10n.locale))
	_language_option.item_selected.connect(func(index: int): L10n.set_locale(L10n.supported_locales[index]))


func _language_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("27362b") if highlighted else Color("111d18")
	style.border_color = Color("d6b476") if highlighted else Color("887647")
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _on_locale_changed() -> void:
	_apply_start_page_assets()
	if _language_option != null:
		_language_option.select(L10n.supported_locales.find(L10n.locale))
	if _settings_panel != null:
		_settings_panel.sync_all()


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
