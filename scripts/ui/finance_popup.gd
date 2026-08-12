extends Control
class_name FinancePopup

signal operation_submitted(action: String, amount: int)
signal skipped

const ACTION_NONE: String = "none"
const ACTION_DEPOSIT: String = "deposit"
const ACTION_WITHDRAW: String = "withdraw"

var payload: Dictionary = {}
var error_message: String = ""

@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var hint_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/HintLabel")
@onready var custom_amount_edit: LineEdit = get_node_or_null("CenterContainer/MainPanel/Content/CustomRow/AmountEdit")
@onready var deposit_all_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ButtonGrid/DepositAllButton")
@onready var deposit_half_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ButtonGrid/DepositHalfButton")
@onready var withdraw_all_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ButtonGrid/WithdrawAllButton")
@onready var withdraw_half_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ButtonGrid/WithdrawHalfButton")
@onready var custom_deposit_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/CustomActionRow/CustomDepositButton")
@onready var custom_withdraw_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/CustomActionRow/CustomWithdrawButton")
@onready var skip_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/SkipButton")


func _ready() -> void:
	_connect_buttons()
	hide_popup()
	_refresh_visual()


func configure(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)
	error_message = ""
	_refresh_visual()


func show_error(reason: String) -> void:
	error_message = _format_error_reason(reason)
	_refresh_visual()


func show_popup() -> void:
	visible = true
	_refresh_visual()
	if custom_amount_edit != null:
		custom_amount_edit.grab_focus()


func hide_popup() -> void:
	visible = false


func _connect_buttons() -> void:
	if deposit_all_button != null and not deposit_all_button.pressed.is_connected(_on_deposit_all_pressed):
		deposit_all_button.pressed.connect(_on_deposit_all_pressed)
	if deposit_half_button != null and not deposit_half_button.pressed.is_connected(_on_deposit_half_pressed):
		deposit_half_button.pressed.connect(_on_deposit_half_pressed)
	if withdraw_all_button != null and not withdraw_all_button.pressed.is_connected(_on_withdraw_all_pressed):
		withdraw_all_button.pressed.connect(_on_withdraw_all_pressed)
	if withdraw_half_button != null and not withdraw_half_button.pressed.is_connected(_on_withdraw_half_pressed):
		withdraw_half_button.pressed.connect(_on_withdraw_half_pressed)
	if custom_deposit_button != null and not custom_deposit_button.pressed.is_connected(_on_custom_deposit_pressed):
		custom_deposit_button.pressed.connect(_on_custom_deposit_pressed)
	if custom_withdraw_button != null and not custom_withdraw_button.pressed.is_connected(_on_custom_withdraw_pressed):
		custom_withdraw_button.pressed.connect(_on_custom_withdraw_pressed)
	if skip_button != null and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)


func _refresh_visual() -> void:
	if title_label != null:
		title_label.text = "理财操作"
	if summary_label != null:
		summary_label.text = _build_summary_text()
	if hint_label != null:
		hint_label.text = _build_hint_text()
	var gold := int(payload.get("gold", 0))
	var withdrawable := int(payload.get("withdrawable_principal", payload.get("principal", 0)))
	if deposit_all_button != null:
		deposit_all_button.disabled = gold <= 0
	if deposit_half_button != null:
		deposit_half_button.disabled = gold <= 0
	if withdraw_all_button != null:
		withdraw_all_button.disabled = withdrawable <= 0
	if withdraw_half_button != null:
		withdraw_half_button.disabled = withdrawable <= 0
	if custom_deposit_button != null:
		custom_deposit_button.disabled = gold <= 0
	if custom_withdraw_button != null:
		custom_withdraw_button.disabled = withdrawable <= 0


func _build_summary_text() -> String:
	return "波次：%d\n当前金币：%d\n理财本金：%d\n可取本金：%d\n当前利率：%.1f%%\n预计波末利息：%d" % [
		int(payload.get("wave_number", 0)),
		int(payload.get("gold", 0)),
		int(payload.get("principal", 0)),
		int(payload.get("withdrawable_principal", payload.get("principal", 0))),
		float(payload.get("interest_rate", 0.0)),
		int(payload.get("estimated_interest", 0)),
	]


func _build_hint_text() -> String:
	var lines: Array[String] = []
	if not error_message.is_empty():
		lines.append(error_message)
	if int(payload.get("locked_until_wave_number", 0)) >= int(payload.get("wave_number", 0)):
		lines.append("定期存单锁定中：本波暂不可取出本金。")
	if bool(payload.get("requires_deposit_for_interest", false)):
		lines.append("高利契约：本波开始前必须存入本金，波末才可收息。")
	lines.append("可跳过，也可选择一种存入或取出操作。")
	return "\n".join(lines)


func _get_custom_amount() -> int:
	if custom_amount_edit == null:
		return 0
	return maxi(0, int(custom_amount_edit.text.strip_edges()))


func _format_error_reason(reason: String) -> String:
	match reason:
		"amount_must_be_positive":
			return "操作失败：请输入大于 0 的整数。"
		"amount_exceeds_gold":
			return "操作失败：存入数量不能超过当前金币。"
		"amount_exceeds_principal_or_locked":
			return "操作失败：取出数量不能超过可取本金。"
		"gold_delta_failed":
			return "操作失败：金币变更未成功。"
		"invalid_action":
			return "操作失败：未知理财操作。"
		_:
			return "操作失败：%s。" % reason


func _on_deposit_all_pressed() -> void:
	operation_submitted.emit(ACTION_DEPOSIT, int(payload.get("gold", 0)))


func _on_deposit_half_pressed() -> void:
	operation_submitted.emit(ACTION_DEPOSIT, int(ceil(float(payload.get("gold", 0)) * 0.5)))


func _on_withdraw_all_pressed() -> void:
	operation_submitted.emit(ACTION_WITHDRAW, int(payload.get("withdrawable_principal", payload.get("principal", 0))))


func _on_withdraw_half_pressed() -> void:
	operation_submitted.emit(ACTION_WITHDRAW, int(ceil(float(payload.get("withdrawable_principal", payload.get("principal", 0))) * 0.5)))


func _on_custom_deposit_pressed() -> void:
	operation_submitted.emit(ACTION_DEPOSIT, _get_custom_amount())


func _on_custom_withdraw_pressed() -> void:
	operation_submitted.emit(ACTION_WITHDRAW, _get_custom_amount())


func _on_skip_pressed() -> void:
	skipped.emit()
