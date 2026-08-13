extends Control
class_name InterestSettlementPopup

signal confirmed

var payload: Dictionary = {}

@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var details_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/DetailsLabel")
@onready var confirm_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ConfirmButton")


func _ready() -> void:
	if confirm_button != null and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	hide_popup()


func configure(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)
	_refresh_visual()


func show_popup() -> void:
	visible = true
	_refresh_visual()


func hide_popup() -> void:
	visible = false


func _refresh_visual() -> void:
	if title_label != null:
		title_label.text = "利息结算"
	if summary_label != null:
		summary_label.text = "本金：%d\n当前利率：%.1f%%" % [
			int(payload.get("principal", 0)),
			float(payload.get("interest_rate", 0.0)),
		]
	if details_label != null:
		details_label.text = _build_details_text()


func _build_details_text() -> String:
	var results: Array = payload.get("settlement_results", [])
	if results.is_empty():
		var single_result: Variant = payload.get("last_settlement_result", {})
		if single_result is Dictionary and not (single_result as Dictionary).is_empty():
			results = [single_result]
	if results.is_empty():
		return "本波没有利息结算记录。"
	var lines: Array[String] = []
	for result in results:
		if not (result is Dictionary):
			continue
		var result_data: Dictionary = result
		var source_label := _source_label(str(result_data.get("source", "")))
		if bool(result_data.get("blocked", false)):
			lines.append("%s：未收息（高利契约）" % source_label)
			continue
		if not bool(result_data.get("success", false)):
			lines.append("%s：未收息（%s）" % [source_label, str(result_data.get("reason", "unknown"))])
			continue
		var gain := int(result_data.get("gain", 0))
		if gain > 0:
			lines.append("%s：+%d 利息（利率 %.1f%%）" % [source_label, gain, float(result_data.get("interest_rate", 0.0))])
		else:
			lines.append("%s：无利息收益" % source_label)
	return "\n".join(lines)


func _source_label(source: String) -> String:
	match source:
		"wave_end":
			return "波末结算"
		"periodic":
			return "周期分红钟"
		"annuity":
			return "永续年金（秒结）"
		"dividend_check":
			return "分红支票"
		_:
			return "利息结算"


func _on_confirm_pressed() -> void:
	confirmed.emit()
