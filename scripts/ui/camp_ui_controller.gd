extends CanvasLayer
class_name CampUIController

var _main_flow_coordinator: MainFlowCoordinator = null
var _camp_root: CampRoot = null
var _selected_building_id: String = ""

@onready var currency_label: Label = get_node_or_null("TopBar/CurrencyLabel")
@onready var back_button: Button = get_node_or_null("TopBar/BackButton")
@onready var reset_save_button: Button = get_node_or_null("TopBar/ResetSaveButton")
@onready var clear_save_dialog: ConfirmationDialog = get_node_or_null("ClearSaveDialog")
@onready var building_list: VBoxContainer = get_node_or_null("MainSplit/BuildingListPanel/BuildingList")
@onready var detail_title: Label = get_node_or_null("MainSplit/DetailPanel/DetailContent/DetailTitle")
@onready var detail_level: Label = get_node_or_null("MainSplit/DetailPanel/DetailContent/DetailLevel")
@onready var detail_desc: Label = get_node_or_null("MainSplit/DetailPanel/DetailContent/DetailDesc")
@onready var unlock_button: Button = get_node_or_null("MainSplit/DetailPanel/DetailContent/UnlockButton")
@onready var upgrade_building_button: Button = get_node_or_null("MainSplit/DetailPanel/DetailContent/UpgradeBuildingButton")
@onready var upgrade_options_list: VBoxContainer = get_node_or_null("MainSplit/DetailPanel/DetailContent/UpgradeOptionsList")


func _ready() -> void:
	if back_button != null and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if reset_save_button != null and not reset_save_button.pressed.is_connected(_on_reset_save_pressed):
		reset_save_button.pressed.connect(_on_reset_save_pressed)
	if clear_save_dialog != null and not clear_save_dialog.confirmed.is_connected(_on_clear_save_confirmed):
		clear_save_dialog.confirmed.connect(_on_clear_save_confirmed)
	if unlock_button != null and not unlock_button.pressed.is_connected(_on_unlock_pressed):
		unlock_button.pressed.connect(_on_unlock_pressed)
	if upgrade_building_button != null and not upgrade_building_button.pressed.is_connected(_on_upgrade_building_pressed):
		upgrade_building_button.pressed.connect(_on_upgrade_building_pressed)
	if CampProgression != null and not CampProgression.state_changed.is_connected(_on_camp_state_changed):
		CampProgression.state_changed.connect(_on_camp_state_changed)
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
	if not _main_flow_coordinator.mode_changed.is_connected(_on_mode_changed):
		_main_flow_coordinator.mode_changed.connect(_on_mode_changed)
	_refresh_visibility()


func _unbind_main_flow() -> void:
	if _main_flow_coordinator != null and _main_flow_coordinator.mode_changed.is_connected(_on_mode_changed):
		_main_flow_coordinator.mode_changed.disconnect(_on_mode_changed)
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


func _get_game_root() -> GameRoot:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return current as GameRoot
		current = current.get_parent()
	return null


func _on_mode_changed(_previous: String, _current: String) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var in_camp := _main_flow_coordinator != null and _main_flow_coordinator.get_current_mode() == MainFlowCoordinator.MODE_CAMP
	visible = in_camp
	if in_camp:
		_find_camp_root()
		# 延后一帧刷新，避免 mode_changed 触发时营地世界尚未组装完成
		call_deferred("_refresh_all")


func _find_camp_root() -> void:
	var game_root := _get_game_root()
	var found: CampRoot = null
	if game_root != null:
		var world := game_root.get_world_root()
		if world != null:
			for child in world.get_children():
				if child is CampRoot:
					found = child as CampRoot
					break
	if _camp_root == found:
		return
	if _camp_root != null and is_instance_valid(_camp_root) and _camp_root.building_selected.is_connected(_on_building_selected):
		_camp_root.building_selected.disconnect(_on_building_selected)
	_camp_root = found
	if _camp_root != null and not _camp_root.building_selected.is_connected(_on_building_selected):
		_camp_root.building_selected.connect(_on_building_selected)


func _on_camp_state_changed() -> void:
	if visible:
		_refresh_all()


func _on_building_selected(building_id: String) -> void:
	_selected_building_id = building_id
	_refresh_detail()


func _refresh_all() -> void:
	_find_camp_root()
	_refresh_currency()
	_refresh_building_list()
	_refresh_detail()


func _refresh_currency() -> void:
	if currency_label != null and CampProgression != null:
		currency_label.text = "营地币：%d" % CampProgression.get_camp_currency()


func _refresh_building_list() -> void:
	if building_list == null:
		return
	for child in building_list.get_children():
		child.queue_free()
	for record in CampProgression.get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if building_id.is_empty():
			continue
		var building_name := str(record.get("name", building_id))
		var level := CampProgression.get_building_level(building_id)
		var unlocked := CampProgression.is_building_unlocked(building_id) or CampProgression.is_building_initially_unlocked(building_id)
		var state_text := "Lv.%d" % level if level > 0 else ("已解锁" if unlocked else "未解锁")
		var button := Button.new()
		button.text = "%s（%s）" % [building_name, state_text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		var selected_callable := Callable(self, "_on_building_selected").bind(building_id)
		button.pressed.connect(selected_callable)
		building_list.add_child(button)


func _refresh_detail() -> void:
	var building_id := _selected_building_id
	var record: Dictionary = CampProgression.get_building_record(building_id) if not building_id.is_empty() else {}
	_clear_upgrade_options()
	if record.is_empty():
		if detail_title != null:
			detail_title.text = "选择一个建筑查看详情"
		if detail_level != null:
			detail_level.text = ""
		if detail_desc != null:
			detail_desc.text = ""
		if unlock_button != null:
			unlock_button.visible = false
		if upgrade_building_button != null:
			upgrade_building_button.visible = false
		return
	var building_name := str(record.get("name", building_id))
	var level := CampProgression.get_building_level(building_id)
	var unlocked := CampProgression.is_building_unlocked(building_id) or CampProgression.is_building_initially_unlocked(building_id)
	var max_level := CampProgression.get_building_max_level(building_id)
	if detail_title != null:
		detail_title.text = building_name
	if detail_level != null:
		detail_level.text = "等级：%d / %d" % [level, max_level] if unlocked else "未解锁"
	if detail_desc != null:
		detail_desc.text = str(record.get("description", ""))
	if unlock_button != null:
		var unlock_condition: Variant = record.get("unlock_condition", {})
		var unlock_cost := int((unlock_condition as Dictionary).get("cost", 0)) if unlock_condition is Dictionary else 0
		if unlocked or unlock_cost <= 0:
			unlock_button.visible = false
		else:
			unlock_button.visible = true
			unlock_button.text = "购买解锁（%d 营地币）" % unlock_cost
			unlock_button.disabled = not CampProgression.can_purchase_building_unlock(building_id)
	if upgrade_building_button != null:
		if not unlocked or level >= max_level:
			upgrade_building_button.visible = false
		else:
			upgrade_building_button.visible = true
			upgrade_building_button.text = "升级建筑（Lv.%d → Lv.%d）" % [level, level + 1]
			upgrade_building_button.disabled = false
	_rebuild_upgrade_options(building_id)


func _rebuild_upgrade_options(building_id: String) -> void:
	if upgrade_options_list == null:
		return
	var record := CampProgression.get_building_record(building_id)
	for option in record.get("upgrade_options", []):
		if not (option is Dictionary):
			continue
		var option_id := str(option.get("id", ""))
		var option_name := str(option.get("name", option_id))
		var current_level := CampProgression.get_upgrade_option_level(option_id)
		var max_level := int(option.get("max_level", 1))
		var cost := int(option.get("cost", 0))
		var required_level := int(option.get("required_building_level", 0))
		var row := HBoxContainer.new()
		var info_label := Label.new()
		info_label.text = "%s（Lv.%d/%d）" % [option_name, current_level, max_level]
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy_button := Button.new()
		var requirement_ok := required_level <= 0 or CampProgression.get_building_level(building_id) >= required_level
		buy_button.text = "购买（%d）" % cost
		buy_button.disabled = not CampProgression.can_purchase_upgrade(option_id)
		if not requirement_ok:
			buy_button.text = "需建筑 Lv.%d" % required_level
		var buy_callable := Callable(self, "_on_upgrade_option_pressed").bind(option_id)
		buy_button.pressed.connect(buy_callable)
		row.add_child(info_label)
		row.add_child(buy_button)
		upgrade_options_list.add_child(row)


func _clear_upgrade_options() -> void:
	if upgrade_options_list == null:
		return
	for child in upgrade_options_list.get_children():
		child.queue_free()


func _on_unlock_pressed() -> void:
	if not _selected_building_id.is_empty():
		CampProgression.purchase_building_unlock(_selected_building_id)


func _on_upgrade_building_pressed() -> void:
	if not _selected_building_id.is_empty():
		CampProgression.upgrade_building(_selected_building_id)


func _on_upgrade_option_pressed(option_id: String) -> void:
	CampProgression.purchase_upgrade(option_id)


func _on_reset_save_pressed() -> void:
	if clear_save_dialog != null:
		clear_save_dialog.popup_centered()


func _on_clear_save_confirmed() -> void:
	CampProgression.clear_save_and_refund()
	_selected_building_id = ""
	_refresh_all()


func _on_back_pressed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.enter_start_page()
