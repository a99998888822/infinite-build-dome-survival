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
@onready var footer_note: Label = $MainPanel/Content/FooterNote
@onready var animation_stage: Control = $MainPanel/Content/AnimationStage
@onready var principal_panel: PanelContainer = $MainPanel/Content/PrincipalPanel
@onready var coin_particles: Control = $CoinParticles


func _ready() -> void:
	_connect_buttons()
	_start_tentacle_animation()
	hide_popup()
	_refresh_visual()
	_refresh_footer_color()


func _process(_delta: float) -> void:
	_refresh_footer_color()


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
		title_label.text = "深渊金库"
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
		return "当前没有可操作的金币或本金"
	if amount > gold and amount > principal:
		return "存入不得超过当前金币，取出不得超过理财本金"
	if amount > gold:
		return "存入金额超过当前金币"
	if amount > principal:
		return "取出金额超过理财本金"
	if bool(payload.get("requires_deposit_for_interest", false)):
		return "本波开始前需存入至少 %d 本金以获取利息" % int(payload.get("deposit_requirement", 50))
	return ""


func _refresh_footer_color() -> void:
	if footer_note == null:
		return
	var phase := fmod(Time.get_ticks_msec() / 1000.0, 6.0) / 6.0
	var color := Color(0.47, 0.70, 0.26, 1.0)
	if phase < 0.333:
		color = Color(0.47, 0.70, 0.26, 1.0).lerp(Color(0.68, 0.34, 0.86, 1.0), phase * 3.0)
	elif phase < 0.666:
		color = Color(0.68, 0.34, 0.86, 1.0).lerp(Color(0.88, 0.20, 0.24, 1.0), (phase - 0.333) * 3.0)
	else:
		color = Color(0.88, 0.20, 0.24, 1.0).lerp(Color(0.47, 0.70, 0.26, 1.0), (phase - 0.666) * 3.0)
	footer_note.add_theme_color_override("font_color", color)


func _start_tentacle_animation() -> void:
	var corners := [
		$CornerTopLeft,
		$CornerTopRight,
		$CornerBottomLeft,
		$CornerBottomRight,
	]
	for index in corners.size():
		var corner := corners[index] as Control
		if corner == null:
			continue
		var sway := create_tween().set_loops()
		sway.set_trans(Tween.TRANS_SINE)
		sway.set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(corner, "scale", Vector2(1.02, 1.02), 3.0).set_delay(index * 0.6)
		sway.tween_property(corner, "scale", Vector2.ONE, 3.0)


func _format_error_reason(reason: String) -> String:
	match reason:
		"amount_must_be_positive":
			return "操作失败 请输入大于 0 的整数"
		"amount_exceeds_gold":
			return "操作失败 存入数量不能超过当前金币"
		"amount_exceeds_principal":
			return "操作失败 取出数量不能超过理财本金"
		"gold_delta_failed":
			return "操作失败 金币变更未成功"
		"invalid_action":
			return "操作失败 未知理财操作"
		_:
			return "操作失败 请重试"


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
		error_message = "存入金额不能超过当前金币"
		_refresh_visual()
		return
	_play_operation_animation(ACTION_DEPOSIT, amount)


func _on_withdraw_pressed() -> void:
	if is_animating or amount <= 0:
		return
	if amount > int(payload.get("principal", 0)):
		error_message = "取出金额不能超过理财本金"
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
	bill.custom_minimum_size = Vector2(60.0, 32.0)
	bill.size = Vector2(60.0, 32.0)
	var stage_width := animation_stage.size.x
	var center_bill := Vector2(stage_width * 0.5 - 30.0, 34.0)
	bill.position = Vector2(-80.0, 34.0) if action == ACTION_DEPOSIT else center_bill
	animation_stage.add_child(bill)
	var hand := TextureRect.new()
	hand.texture = HAND_TEXTURE
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.size = Vector2(48.0, 56.0)
	var center_hand := Vector2(stage_width * 0.5 - 60.0, 20.0)
	hand.position = Vector2(-120.0, 20.0) if action == ACTION_DEPOSIT else Vector2(stage_width + 72.0, 20.0)
	if action == ACTION_WITHDRAW:
		hand.flip_h = true
	hand.modulate.a = 0.0
	animation_stage.add_child(hand)
	var target_bill := center_bill + Vector2(0.0, -10.0) if action == ACTION_DEPOSIT else Vector2(-80.0, 34.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	var final_hand_position := Vector2(-120.0, 20.0) if action == ACTION_DEPOSIT else Vector2(stage_width + 72.0, 20.0)
	tween.parallel().tween_property(bill, "position", target_bill, 1.02).set_delay(0.18)
	tween.parallel().tween_property(bill, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(bill, "modulate:a", 0.0, 0.18).set_delay(1.02)
	tween.parallel().tween_property(bill, "scale", Vector2(0.8, 0.8), 0.18).set_delay(1.02)
	tween.parallel().tween_property(hand, "modulate:a", 0.85, 0.18).set_delay(0.12)
	tween.parallel().tween_property(hand, "position", center_hand, 0.36).set_delay(0.12)
	tween.parallel().tween_property(hand, "position", final_hand_position, 0.36).set_delay(0.60)
	tween.parallel().tween_property(hand, "modulate:a", 0.0, 0.18).set_delay(1.02)
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
	var principal_rect := principal_panel.get_global_rect()
	for index in range(5):
		var coin := TextureRect.new()
		coin.texture = COIN_TEXTURE
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(12.0, 12.0)
		coin.position = Vector2(
			principal_rect.position.x + principal_rect.size.x * randf_range(0.4, 0.6),
			principal_rect.position.y + principal_rect.size.y * 0.55,
		)
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
