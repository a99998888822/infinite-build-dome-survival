extends CanvasLayer
class_name MainMenuUIController

const MAIN_MENU_BACKGROUND_TEXTURE_PATH: String = "res://assets/ui/main_menu/bg_main_menu.png"
const MAIN_MENU_TITLE_TEXTURE_PATH: String = "res://assets/ui/main_menu/title_main_menu.png"
const MAIN_MENU_BUTTON_TEXTURE_PATH: String = "res://assets/ui/main_menu/button_main_menu.png"
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
const HINT_INTERVAL := 4.5

var _main_flow_coordinator: MainFlowCoordinator = null
var _selected_character_id: String = ""
var _title_base_position := Vector2.ZERO
var _button_feedback_tweens: Dictionary = {}
var _button_shake_tweens: Dictionary = {}
var _hint_index := 0
var _hint_elapsed := 0.0

@onready var start_page: Control = get_node_or_null("StartPage")
@onready var start_page_background: TextureRect = get_node_or_null("StartPage/Background")
@onready var title_art: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/TitleArea/TitleCenter/TitleStack/TitleArt")
@onready var start_battle_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell")
@onready var camp_entry_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell")
@onready var quit_shell: Control = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell")
@onready var start_battle_button_frame: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell/FrameTexture")
@onready var camp_entry_button_frame: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell/FrameTexture")
@onready var quit_button_frame: TextureRect = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/FrameTexture")
@onready var start_battle_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/StartBattleShell/StartBattleButton")
@onready var camp_entry_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/CampEntryShell/CampEntryButton")
@onready var quit_button: Button = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/QuitButton")
@onready var hint_label: Label = get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/MenuHintLabel")
@onready var character_select_page: Control = get_node_or_null("CharacterSelectPage")
@onready var character_list: VBoxContainer = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/CharacterList")
@onready var character_error_label: Label = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/ErrorLabel")
@onready var character_back_button: Button = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/ButtonRow/BackButton")
@onready var character_confirm_button: Button = get_node_or_null("CharacterSelectPage/CenterContainer/MainPanel/Content/ButtonRow/ConfirmButton")
@onready var battle_result_panel: Control = get_node_or_null("BattleResultPanel")
@onready var result_title_label: Label = get_node_or_null("BattleResultPanel/CenterContainer/MainPanel/Content/ResultTitleLabel")
@onready var result_summary_label: Label = get_node_or_null("BattleResultPanel/CenterContainer/MainPanel/Content/ResultSummaryLabel")
@onready var result_back_button: Button = get_node_or_null("BattleResultPanel/CenterContainer/MainPanel/Content/ResultBackButton")


func _ready() -> void:
	_apply_start_page_assets()
	_setup_start_page_feedback()
	_setup_menu_atmosphere()
	if start_battle_button != null and not start_battle_button.pressed.is_connected(_on_start_battle_pressed):
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if camp_entry_button != null and not camp_entry_button.pressed.is_connected(_on_camp_entry_pressed):
		camp_entry_button.pressed.connect(_on_camp_entry_pressed)
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
	var flicker := 0.84 + sin(time * 19.0) * 0.08 + sin(time * 47.0) * 0.04
	hint_label.modulate = Color(color.lerp(color_next, color_mix), clampf(flicker, 0.62, 1.0))


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
	if start_page != null:
		start_page.visible = mode == MainFlowCoordinator.MODE_BOOT
	if character_select_page != null:
		character_select_page.visible = mode == MainFlowCoordinator.MODE_BATTLE and state == MainFlowCoordinator.STATE_CHARACTER_SELECT
	if battle_result_panel != null:
		battle_result_panel.visible = mode == MainFlowCoordinator.MODE_BATTLE and state == MainFlowCoordinator.STATE_BATTLE_RESULT
	if character_select_page != null and character_select_page.visible:
		_rebuild_character_list()
	if battle_result_panel != null and battle_result_panel.visible:
		_refresh_result_text()


func _on_start_battle_pressed() -> void:
	_selected_character_id = ""
	if character_error_label != null:
		character_error_label.text = ""
	if start_page != null:
		start_page.visible = false
	if character_select_page != null:
		_rebuild_character_list()
		character_select_page.visible = true


func _on_camp_entry_pressed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.enter_camp_flow()


func _on_quit_pressed() -> void:
	if get_tree() != null:
		get_tree().quit()


func _on_character_back_pressed() -> void:
	_selected_character_id = ""
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
	var modifiers: Array = []
	if CampProgression != null and CampProgression.has_method("get_outgame_modifiers"):
		modifiers = CampProgression.get_outgame_modifiers()
	_main_flow_coordinator.enter_battle_selection(_selected_character_id, [], modifiers)
	var confirmed := _main_flow_coordinator.confirm_character_selection()
	if not confirmed and character_error_label != null:
		character_error_label.text = "进入战斗失败，请重试"


func _rebuild_character_list() -> void:
	if character_list == null:
		return
	for child in character_list.get_children():
		child.queue_free()
	if character_confirm_button != null:
		character_confirm_button.disabled = true
	var character_records: Array = DataRegistry.get_table("characters") if DataRegistry != null else []
	if character_records.is_empty() and character_error_label != null:
		character_error_label.text = "没有可用角色"
	for record in character_records:
		if not (record is Dictionary):
			continue
		var character_id := str(record.get("id", ""))
		if character_id.is_empty():
			continue
		var display_name := str(record.get("display_name", character_id))
		var description := str(record.get("description", ""))
		var button := Button.new()
		button.text = display_name if description.is_empty() else "%s\n%s" % [display_name, description]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 56)
		var selected_callable := Callable(self, "_on_character_selected").bind(character_id)
		button.pressed.connect(selected_callable)
		character_list.add_child(button)


func _on_character_selected(character_id: String) -> void:
	_selected_character_id = character_id
	if character_error_label != null:
		character_error_label.text = ""
	if character_confirm_button != null:
		character_confirm_button.disabled = false


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
