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
const NUMERIC_FONT: Font = preload("res://assets/font/VT323-Regular.ttf")

var payload: Dictionary = {}
var error_message: String = ""
var amount: int = 0
var is_animating: bool = false
var _amount_initialized: bool = false
var _animation_token: int = 0
var _safe_rect: Rect2 = Rect2()
var _input_blocker: ColorRect = null
var _show_tween: Tween = null

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
	_ensure_input_blocker()
	_connect_buttons()
	_start_tentacle_animation()
	if get_viewport() != null:
		var viewport_callable := Callable(self, "_on_viewport_resized")
		if not get_viewport().size_changed.is_connected(viewport_callable):
			get_viewport().size_changed.connect(viewport_callable)
	_layout_popup()
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
	if hint_label != null:
		var base_position := hint_label.position
		var shake := create_tween()
		shake.tween_property(hint_label, "position", base_position + Vector2(-4.0, 0.0), 0.04)
		shake.tween_property(hint_label, "position", base_position + Vector2(4.0, 0.0), 0.08)
		shake.tween_property(hint_label, "position", base_position, 0.06)


func set_safe_rect(next_rect: Rect2) -> void:
	_safe_rect = next_rect
	_layout_popup()


func show_popup() -> void:
	_layout_popup()
	visible = true
	if _input_blocker != null:
		_input_blocker.visible = true
	if main_panel != null:
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		main_panel.pivot_offset = main_panel.size * 0.5
		main_panel.modulate.a = 0.0
		main_panel.scale = Vector2(0.96, 0.96)
	if _show_tween != null:
		_show_tween.kill()
	_show_tween = create_tween().set_parallel(true)
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(main_panel, "modulate:a", 1.0, 0.24)
	_show_tween.tween_property(main_panel, "scale", Vector2.ONE, 0.30)
	_refresh_visual()
	if amount_edit != null:
		get_tree().create_timer(0.28).timeout.connect(func() -> void:
			if visible and not is_animating:
				amount_edit.grab_focus()
				amount_edit.select_all()
		)


func hide_popup() -> void:
	if _show_tween != null:
		_show_tween.kill()
		_show_tween = null
	visible = false
	is_animating = false
	_animation_token += 1
	if _input_blocker != null:
		_input_blocker.visible = false
	if main_panel != null:
		main_panel.modulate.a = 1.0
		main_panel.scale = Vector2.ONE


func _ensure_input_blocker() -> void:
	if _input_blocker != null:
		return
	_input_blocker = ColorRect.new()
	_input_blocker.name = "InputBlocker"
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.visible = false
	add_child(_input_blocker)
	move_child(_input_blocker, 1)


func _on_viewport_resized() -> void:
	_layout_popup()


func _layout_popup() -> void:
	if main_panel == null or get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _safe_rect
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = _build_fallback_safe_rect(viewport_size)
	var compact := safe.size.y < 620.0 or safe.size.x < 620.0
	_apply_compact_layout(compact)
	var panel_width := clampf(safe.size.x - 16.0, 440.0, 640.0)
	var panel_height := clampf(safe.size.y - 16.0, 420.0, 650.0)
	if safe.size.x < 456.0:
		panel_width = safe.size.x
	if safe.size.y < 436.0:
		panel_height = safe.size.y
	panel_width = minf(panel_width, viewport_size.x)
	panel_height = minf(panel_height, viewport_size.y)
	var panel_size := Vector2(maxf(panel_width, 0.0), maxf(panel_height, 0.0))
	var panel_position := Vector2(safe.position.x + (safe.size.x - panel_size.x) * 0.5, safe.position.y + 92.0)
	if panel_position.y + panel_size.y > safe.end.y:
		panel_position.y = maxf(safe.position.y, safe.end.y - panel_size.y)
	main_panel.anchor_left = 0.0
	main_panel.anchor_top = 0.0
	main_panel.anchor_right = 0.0
	main_panel.anchor_bottom = 0.0
	main_panel.position = panel_position
	main_panel.size = panel_size
	_layout_corner_decorations()


func _apply_compact_layout(compact: bool) -> void:
	var content := get_node_or_null("MainPanel/Content") as VBoxContainer
	var title_row := get_node_or_null("MainPanel/Content/Header/TitleRow") as Control
	var header_line := get_node_or_null("MainPanel/Content/Header/HeaderLine") as Control
	var rate_panel := get_node_or_null("MainPanel/Content/StatsRow/RatePanel") as Control
	var interest_panel := get_node_or_null("MainPanel/Content/StatsRow/InterestPanel") as Control
	var action_row := get_node_or_null("MainPanel/Content/ActionRow") as Control
	var deposit := get_node_or_null("MainPanel/Content/ActionRow/DepositButton") as Control
	var withdraw := get_node_or_null("MainPanel/Content/ActionRow/WithdrawButton") as Control
	var title_label_node := get_node_or_null("MainPanel/Content/Header/TitleRow/TitleGroup/TitleLabel") as Label
	var subtitle_label_node := get_node_or_null("MainPanel/Content/Header/TitleRow/TitleGroup/SubtitleLabel") as Label
	var principal_label_node := get_node_or_null("MainPanel/Content/PrincipalPanel/PrincipalContent/PrincipalLabel") as Label
	var principal_value_node := get_node_or_null("MainPanel/Content/PrincipalPanel/PrincipalContent/PrincipalValue") as Label
	var rate_value_node := get_node_or_null("MainPanel/Content/StatsRow/RatePanel/StatContent/RateValue") as Label
	var interest_value_node := get_node_or_null("MainPanel/Content/StatsRow/InterestPanel/StatContent/InterestValue") as Label
	var deposit_node := deposit as Button
	var withdraw_node := withdraw as Button
	var quick_50_node := get_node_or_null("MainPanel/Content/InputRow/QuickAmounts/Quick50") as Button
	var quick_100_node := get_node_or_null("MainPanel/Content/InputRow/QuickAmounts/Quick100") as Button
	var quick_500_node := get_node_or_null("MainPanel/Content/InputRow/QuickAmounts/Quick500") as Button
	if content != null:
		content.add_theme_constant_override("separation", 7 if compact else 14)
	if main_panel != null:
		var panel_style := main_panel.get_theme_stylebox("panel")
		if panel_style is StyleBox:
			var compact_style := (panel_style as StyleBox).duplicate()
			if compact_style is StyleBoxFlat:
				var flat_style := compact_style as StyleBoxFlat
				flat_style.content_margin_left = 14.0 if compact else 24.0
				flat_style.content_margin_right = 14.0 if compact else 24.0
				flat_style.content_margin_top = 12.0 if compact else 20.0
				flat_style.content_margin_bottom = 12.0 if compact else 20.0
				main_panel.add_theme_stylebox_override("panel", flat_style)
	if title_row != null:
		title_row.custom_minimum_size.y = 58.0 if compact else 68.0
	if header_line != null:
		header_line.custom_minimum_size.y = 2.0 if compact else 3.0
	if animation_stage != null:
		animation_stage.custom_minimum_size.y = 68.0 if compact else 96.0
	if principal_panel != null:
		principal_panel.custom_minimum_size.y = 78.0 if compact else 96.0
	if rate_panel != null:
		rate_panel.custom_minimum_size.y = 62.0 if compact else 76.0
	if interest_panel != null:
		interest_panel.custom_minimum_size.y = 62.0 if compact else 76.0
	if amount_edit != null:
		amount_edit.add_theme_font_override("font", NUMERIC_FONT)
		amount_edit.add_theme_font_size_override("font_size", 24 if compact else 28)
		amount_edit.custom_minimum_size = Vector2(140.0, 40.0 if compact else 44.0)
	if action_row != null:
		action_row.add_theme_constant_override("separation", 12 if compact else 18)
	if deposit != null:
		deposit.custom_minimum_size.y = 48.0 if compact else 56.0
	if withdraw != null:
		withdraw.custom_minimum_size.y = 48.0 if compact else 56.0
	if skip_button != null:
		skip_button.custom_minimum_size.y = 24.0 if compact else 28.0
	if title_label_node != null:
		title_label_node.add_theme_font_size_override("font_size", 26 if compact else 32)
	if subtitle_label_node != null:
		subtitle_label_node.add_theme_font_size_override("font_size", 15 if compact else 18)
	if principal_label_node != null:
		principal_label_node.add_theme_font_size_override("font_size", 14 if compact else 16)
	if principal_value_node != null:
		principal_value_node.add_theme_font_override("font", NUMERIC_FONT)
		principal_value_node.add_theme_font_size_override("font_size", 38 if compact else 48)
	if rate_value_node != null:
		rate_value_node.add_theme_font_override("font", NUMERIC_FONT)
		rate_value_node.add_theme_font_size_override("font_size", 26 if compact else 34)
	if interest_value_node != null:
		interest_value_node.add_theme_font_override("font", NUMERIC_FONT)
		interest_value_node.add_theme_font_size_override("font_size", 26 if compact else 34)
	if deposit_node != null:
		deposit_node.add_theme_font_size_override("font_size", 18 if compact else 22)
	if withdraw_node != null:
		withdraw_node.add_theme_font_size_override("font_size", 18 if compact else 22)
	for quick_button in [quick_50_node, quick_100_node, quick_500_node]:
		if quick_button != null:
			quick_button.add_theme_font_override("font", NUMERIC_FONT)
			quick_button.add_theme_font_size_override("font_size", 18 if compact else 22)
	if footer_note != null:
		footer_note.add_theme_font_size_override("font_size", 13 if compact else 15)


func _build_fallback_safe_rect(viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := minf(220.0, viewport_size.x * 0.18)
	var right := minf(336.0, viewport_size.x * 0.30)
	var top := minf(112.0, viewport_size.y * 0.18)
	var bottom := 16.0
	var safe_left := clampf(left, 0.0, viewport_size.x)
	var safe_top := clampf(top, 0.0, viewport_size.y)
	var safe_right := clampf(right, 0.0, viewport_size.x - safe_left)
	return Rect2(
		Vector2(safe_left, safe_top),
		Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - bottom, 0.0))
	)


func _layout_corner_decorations() -> void:
	if main_panel == null:
		return
	var corners := [
		$CornerTopLeft,
		$CornerTopRight,
		$CornerBottomLeft,
		$CornerBottomRight,
	]
	var positions := [
		main_panel.position + Vector2(-6.0, -6.0),
		main_panel.position + Vector2(main_panel.size.x - 42.0, -6.0),
		main_panel.position + Vector2(-6.0, main_panel.size.y - 42.0),
		main_panel.position + Vector2(main_panel.size.x - 42.0, main_panel.size.y - 42.0),
	]
	for index in corners.size():
		var corner := corners[index] as Control
		if corner == null:
			continue
		corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		corner.position = positions[index]
		corner.size = Vector2(48.0, 48.0)


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
	var phase := fmod(Time.get_ticks_msec() / 1000.0, 4.0) / 4.0
	var color := Color(0.47, 0.70, 0.26, 1.0)
	var alpha := 0.82
	if phase >= 0.90 and phase < 0.925:
		alpha = 0.32
	elif phase >= 0.94 and phase < 0.955:
		color = Color(0.68, 0.34, 0.86, 1.0)
		alpha = 0.58
	footer_note.add_theme_color_override("font_color", Color(color.r, color.g, color.b, alpha))


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
