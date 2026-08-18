extends Control
class_name FinancePopup

signal operation_submitted(action: String, amount: int)
signal skipped

const ACTION_NONE: String = "none"
const ACTION_DEPOSIT: String = "deposit"
const ACTION_WITHDRAW: String = "withdraw"
const COIN_TEXTURE: Texture2D = preload("res://assets/ui/finance/finance_coin.svg")
const BILL_TEXTURE: Texture2D = preload("res://assets/ui/finance/finance_bill.svg")
const HAND_TEXTURE: Texture2D = preload("res://assets/ui/finance/finance_hand.svg")

var payload: Dictionary = {}
var error_message: String = ""
var amount: int = 0
var is_animating: bool = false
var _amount_initialized: bool = false
var _animation_token: int = 0

@onready var main_panel: PanelContainer = $MainPanel
@onready var title_label: Label = $MainPanel/Content/Header/TitleRow/TitleGroup/TitleLabel
@onready var principal_value: Label = $MainPanel/Content/PrincipalPanel/PrincipalContent/PrincipalValue
@onready var rate_value: Label = $MainPanel/Content/StatsRow/RatePanel/StatContent/RateValue
@onready var interest_value: Label = $MainPanel/Content/StatsRow/InterestPanel/StatContent/InterestValue
@onready var amount_edit: LineEdit = $MainPanel/Content/InputRow/AmountEdit
@onready var deposit_button: Button = $MainPanel/Content/ActionRow/DepositButton
@onready var withdraw_button: Button = $MainPanel/Content/ActionRow/WithdrawButton
@onready var skip_button: Button = $MainPanel/Content/SkipButton
@onready var quick_50_button: Button = $MainPanel/Content/InputRow/QuickAmounts/Quick50
@onready var quick_100_button: Button = $MainPanel/Content/InputRow/QuickAmounts/Quick100
@onready var quick_500_button: Button = $MainPanel/Content/InputRow/QuickAmounts/Quick500
@onready var hint_label: Label = $MainPanel/Content/HintLabel
@onready var animation_stage: Control = $MainPanel/Content/AnimationStage
@onready var coin_particles: Control = $CoinParticles


func _ready() -> void:
	_connect_buttons()
	hide_popup()
	_refresh_visual()


func configure(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)
	error_message = ""
	_amount_initialized = false
	amount = int(payload.get("gold", 0))
	if amount_edit != null:
		amount_edit.text = str(amount)
	_amount_initialized = true
	_refresh_visual()


func show_error(reason: String) -> void:
	is_animating = false
	error_message = _format_error_reason(reason)
	_refresh_visual()


func show_popup() -> void:
	visible = true
	modulate.a = 0.0
	_refresh_visual()
	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	if amount_edit != null:
		amount_edit.grab_focus()
		amount_edit.select_all()


func hide_popup() -> void:
	visible = false
	is_animating = false
	_animation_token += 1


func _connect_buttons() -> void:
	if amount_edit != null and not amount_edit.text_changed.is_connected(_on_amount_changed):
		amount_edit.text_changed.connect(_on_amount_changed)
	if deposit_button != null and not deposit_button.pressed.is_connected(_on_deposit_pressed):
		deposit_button.pressed.connect(_on_deposit_pressed)
	if withdraw_button != null and not withdraw_button.pressed.is_connected(_on_withdraw_pressed):
		withdraw_button.pressed.connect(_on_withdraw_pressed)
	if skip_button != null and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if quick_50_button != null and not quick_50_button.pressed.is_connected(_on_quick_amount_pressed.bind(50)):
		quick_50_button.pressed.connect(_on_quick_amount_pressed.bind(50))
	if quick_100_button != null and not quick_100_button.pressed.is_connected(_on_quick_amount_pressed.bind(100)):
		quick_100_button.pressed.connect(_on_quick_amount_pressed.bind(100))
	if quick_500_button != null and not quick_500_button.pressed.is_connected(_on_quick_amount_pressed.bind(500)):
		quick_500_button.pressed.connect(_on_quick_amount_pressed.bind(500))


func _refresh_visual() -> void:
	var gold := int(payload.get("gold", 0))
	var principal := int(payload.get("principal", 0))
	var rate := float(payload.get("interest_rate", 0.0))
	var interest := int(payload.get("estimated_interest", 0))
	if title_label != null:
		title_label.text = "\u6df1\u6e0a\u91d1\u5e93"
	if principal_value != null:
		principal_value.text = _format_number(principal)
	if rate_value != null:
		rate_value.text = "%.1f%%" % rate
	if interest_value != null:
		interest_value.text = _format_number(interest)
	if hint_label != null:
		hint_label.text = _build_hint_text(gold, principal)
	var valid_amount := amount > 0
	if deposit_button != null:
		deposit_button.disabled = is_animating or not valid_amount or amount > gold
	if withdraw_button != null:
		withdraw_button.disabled = is_animating or not valid_amount or amount > principal
	if skip_button != null:
		skip_button.disabled = is_animating
	if quick_50_button != null:
		quick_50_button.disabled = is_animating
	if quick_100_button != null:
		quick_100_button.disabled = is_animating
	if quick_500_button != null:
		quick_500_button.disabled = is_animating


func _build_hint_text(gold: int, principal: int) -> String:
	if not error_message.is_empty():
		return error_message
	if gold <= 0 and principal <= 0:
		return "\u5f53\u524d\u6ca1\u6709\u53ef\u64cd\u4f5c\u7684\u91d1\u5e01\u6216\u672c\u91d1"
	if amount > gold and amount > principal:
		return "\u5b58\u5165\u4e0d\u5f97\u8d85\u8fc7\u5f53\u524d\u91d1\u5e01\uff0c\u53d6\u51fa\u4e0d\u5f97\u8d85\u8fc7\u7406\u8d22\u672c\u91d1"
	if amount > gold:
		return "\u5b58\u5165\u91d1\u989d\u8d85\u8fc7\u5f53\u524d\u91d1\u5e01"
	if amount > principal:
		return "\u53d6\u51fa\u91d1\u989d\u8d85\u8fc7\u7406\u8d22\u672c\u91d1"
	if bool(payload.get("requires_deposit_for_interest", false)):
		return "\u672c\u6ce2\u5f00\u59cb\u524d\u9700\u5b58\u5165\u81f3\u5c11 %d \u672c\u91d1\u4ee5\u83b7\u53d6\u5229\u606f" % int(payload.get("deposit_requirement", 50))
	return "\u8bf7\u9009\u62e9\u5b58\u5165\u3001\u53d6\u51fa\u6216\u8df3\u8fc7"


func _format_error_reason(reason: String) -> String:
	match reason:
		"amount_must_be_positive":
			return "\u64cd\u4f5c\u5931\u8d25 \u8bf7\u8f93\u5165\u5927\u4e8e 0 \u7684\u6574\u6570"
		"amount_exceeds_gold":
			return "\u64cd\u4f5c\u5931\u8d25 \u5b58\u5165\u6570\u91cf\u4e0d\u80fd\u8d85\u8fc7\u5f53\u524d\u91d1\u5e01"
		"amount_exceeds_principal":
			return "\u64cd\u4f5c\u5931\u8d25 \u53d6\u51fa\u6570\u91cf\u4e0d\u80fd\u8d85\u8fc7\u7406\u8d22\u672c\u91d1"
		"gold_delta_failed":
			return "\u64cd\u4f5c\u5931\u8d25 \u91d1\u5e01\u53d8\u66f4\u672a\u6210\u529f"
		"invalid_action":
			return "\u64cd\u4f5c\u5931\u8d25 \u672a\u77e5\u7406\u8d22\u64cd\u4f5c"
		_:
			return "\u64cd\u4f5c\u5931\u8d25 \u8bf7\u91cd\u8bd5"


func _on_amount_changed(value: String) -> void:
	if not _amount_initialized:
		return
	var sanitized := value.strip_edges()
	amount = maxi(0, int(sanitized) if sanitized.is_valid_int() else 0)
	error_message = ""
	_refresh_visual()


func _on_quick_amount_pressed(value: int) -> void:
	if is_animating:
		return
	amount = maxi(0, amount + value)
	amount_edit.text = str(amount)
	_refresh_visual()


func _on_deposit_pressed() -> void:
	if is_animating or amount <= 0:
		return
	if amount > int(payload.get("gold", 0)):
		error_message = "\u5b58\u5165\u91d1\u989d\u4e0d\u80fd\u8d85\u8fc7\u5f53\u524d\u91d1\u5e01"
		_refresh_visual()
		return
	_play_operation_animation(ACTION_DEPOSIT, amount)


func _on_withdraw_pressed() -> void:
	if is_animating or amount <= 0:
		return
	if amount > int(payload.get("principal", 0)):
		error_message = "\u53d6\u51fa\u91d1\u989d\u4e0d\u80fd\u8d85\u8fc7\u7406\u8d22\u672c\u91d1"
		_refresh_visual()
		return
	_play_operation_animation(ACTION_WITHDRAW, amount)


func _on_skip_pressed() -> void:
	if is_animating:
		return
	skipped.emit()


func _play_operation_animation(action: String, operation_amount: int) -> void:
	is_animating = true
	error_message = ""
	_animation_token += 1
	var token := _animation_token
	_refresh_visual()
	var bill := TextureRect.new()
	bill.texture = BILL_TEXTURE
	bill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bill.custom_minimum_size = Vector2(90.0, 48.0)
	bill.size = Vector2(90.0, 48.0)
	bill.position = Vector2(120.0, 44.0) if action == ACTION_DEPOSIT else Vector2(120.0, 2.0)
	animation_stage.add_child(bill)
	var hand := TextureRect.new()
	hand.texture = HAND_TEXTURE
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.size = Vector2(48.0, 56.0)
	hand.position = Vector2(24.0, 24.0) if action == ACTION_DEPOSIT else Vector2(216.0, -8.0)
	hand.modulate.a = 0.0
	animation_stage.add_child(hand)
	var target_y := -12.0 if action == ACTION_DEPOSIT else 58.0
	var target_x := 112.0 if action == ACTION_DEPOSIT else 128.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(bill, "position", Vector2(target_x, target_y), 0.58)
	tween.parallel().tween_property(bill, "modulate:a", 0.0, 0.58)
	tween.parallel().tween_property(hand, "modulate:a", 0.85, 0.12)
	tween.parallel().tween_property(hand, "position", hand.position + Vector2(0.0, -8.0 if action == ACTION_DEPOSIT else 8.0), 0.58)
	tween.tween_callback(func() -> void:
		bill.queue_free()
		hand.queue_free()
		if token != _animation_token:
			return
		_spawn_coins(action)
		principal_value.pivot_offset = principal_value.size * 0.5
		var bump := create_tween()
		bump.set_trans(Tween.TRANS_BACK)
		bump.set_ease(Tween.EASE_OUT)
		bump.tween_property(principal_value, "scale", Vector2(1.12, 1.12), 0.12)
		bump.tween_property(principal_value, "scale", Vector2.ONE, 0.18)
		get_tree().create_timer(0.16).timeout.connect(func() -> void:
			if token == _animation_token:
				operation_submitted.emit(action, operation_amount)
				is_animating = false
				_refresh_visual()
		)
	)

func _spawn_coins(action: String) -> void:
	if action != ACTION_DEPOSIT:
		return
	for index in range(6):
		var coin := TextureRect.new()
		coin.texture = COIN_TEXTURE
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(22.0, 22.0)
		coin.position = Vector2(170.0 + randf_range(-45.0, 45.0), 60.0)
		coin.modulate.a = 0.0
		coin_particles.add_child(coin)
		var target := coin.position + Vector2(randf_range(-32.0, 32.0), randf_range(-36.0, -12.0))
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_parallel()
		tween.tween_property(coin, "position", target, 0.42)
		tween.tween_property(coin, "modulate:a", 1.0, 0.08)
		tween.chain().tween_property(coin, "modulate:a", 0.0, 0.24)
		tween.tween_callback(coin.queue_free)


func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	return ("-" if value < 0 else "") + grouped
