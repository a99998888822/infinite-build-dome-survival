extends CanvasLayer
class_name MainMenuUIController

var _main_flow_coordinator: MainFlowCoordinator = null
var _selected_character_id: String = ""

@onready var start_page: Control = get_node_or_null("StartPage")
@onready var start_battle_button: Button = get_node_or_null("StartPage/CenterContainer/MainPanel/Content/StartBattleButton")
@onready var camp_entry_button: Button = get_node_or_null("StartPage/CenterContainer/MainPanel/Content/CampEntryButton")
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
	if start_battle_button != null and not start_battle_button.pressed.is_connected(_on_start_battle_pressed):
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if camp_entry_button != null and not camp_entry_button.pressed.is_connected(_on_camp_entry_pressed):
		camp_entry_button.pressed.connect(_on_camp_entry_pressed)
	if character_back_button != null and not character_back_button.pressed.is_connected(_on_character_back_pressed):
		character_back_button.pressed.connect(_on_character_back_pressed)
	if character_confirm_button != null and not character_confirm_button.pressed.is_connected(_on_character_confirm_pressed):
		character_confirm_button.pressed.connect(_on_character_confirm_pressed)
	if result_back_button != null and not result_back_button.pressed.is_connected(_on_result_back_pressed):
		result_back_button.pressed.connect(_on_result_back_pressed)
	call_deferred("_bind_to_main_flow")


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
