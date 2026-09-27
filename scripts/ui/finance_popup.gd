extends Control
class_name FinancePopup

signal trade_cancelled(reason: String)
signal trade_choice_made(accepted: bool)

const BOARD: Texture2D = preload("res://assets/ui/finance/finance_board.png")
var flow: MainFlowCoordinator
var payload: Dictionary = {}
var main_panel: Panel
var economy_log: EconomyLogPanel
var portrait: BankCounterPortrait
var trade_presentation: GoblinTradePresentation
var shop_grid: VirtualShopGrid
var workbench: EnchantmentWorkbench
var amount_input: LineEdit
var bank_confirm: Button
var start_button: Button
var _title: Label
var _summary: Label
var _principal_protection: Label
var _bank_preview: Label
var _bank: ScrollContainer
var _bank_header: VBoxContainer
var _bank_form: VBoxContainer
var _receipt: Label
var _contract: Label
var _deposit: Button
var _withdraw: Button
var _tabs: HBoxContainer
var _tab_buttons: Dictionary = {}
var _shop: Control
var _enchant_scroll: ScrollContainer
var _stock: Label
var _refresh: Button
var _feedback: Label
var _sale_layer: Control
var _sale_box: PanelContainer
var _sale_text: RichTextLabel
var _sale_confirm: Button
var _quote: Dictionary = {}
var _tooltip: PanelContainer
var _tooltip_text: RichTextLabel
var _active_tab := "shop"
var _bank_action := "deposit"
var _generation := -1
var _safe_rect := Rect2(16, 72, 800, 520)
var _compact := false
var _notice_timer: Timer
var _sale_icon: TextureRect
var _sale_items: HBoxContainer
var _live_trade_token := ""
var _refresh_glow := FinanceUIStyle.box("293329", "d5c578", 5)
var _glow_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.wait_time = 3.0
	_notice_timer.timeout.connect(func():
		if get_viewport().get_visible_rect().size.y < 480:
			_summary.show()
			_feedback.hide()
	)
	add_child(_notice_timer)
	_layout()


func bind_flow(coordinator: MainFlowCoordinator) -> void:
	flow = coordinator
	shop_grid.flow = flow
	workbench.flow = flow


func configure(next_payload: Dictionary) -> void:
	payload = next_payload
	economy_log.bind_journal(flow.get_economy_journal() if flow != null else null)
	var generation := int(payload.get("offer_generation", 0))
	var new_shelf := generation != _generation
	_generation = generation
	if new_shelf:
		shop_grid.set_offers(payload.get("offers", []), true)
	else:
		shop_grid.refresh_availability()
	_summary.text = "金币 %d　│　本金 %d　│　利率 %.1f%%　│　预计利息 +%d" % [int(payload.get("gold", 0)), int(payload.get("principal", 0)), float(payload.get("interest_rate", 0)), int(payload.get("estimated_interest", 0))]
	var humanity := float(payload.get("humanity", 100))
	var protection: Dictionary = payload.get("principal_revive", {})
	_principal_protection.visible = not protection.is_empty()
	if not protection.is_empty():
		_principal_protection.text = "%s：%s" % [protection.display_name, FinanceUIStyle.principal_revive_status(protection)]
		_principal_protection.tooltip_text = "已有复活次数用尽后自动触发。先消耗%d本金，再按扣款后的最大生命恢复%s%%；不增加随身金币，也不占用银行操作次数。" % [int(protection.principal_cost), HumanityEconomy.number(float(protection.health_percent))]
	var nominal := int(payload.get("nominal_estimated_interest", 0))
	var retention := float(payload.get("interest_multiplier", 1.0))
	_summary.tooltip_text = "单次基础预计：应得 %d，理智损耗 %s，预计入账 %d。\n实际利率 %s%%；未入账小数 %s。\n不含随机翻倍和后续额外结息。\n%s" % [nominal, HumanityEconomy.number(nominal * (1.0 - retention)), int(payload.get("estimated_interest", 0)), HumanityEconomy.number(float(payload.get("interest_rate", 0)) * retention), "%.3f" % float(payload.get("interest_remainder", 0)), HumanityEconomy.describe(humanity)]
	_refresh_bank()
	var remaining := 0
	for offer in shop_grid.offers:
		if not bool(offer.get("purchased", false)): remaining += 1
	_stock.text = "剩余 %d / %d 件" % [remaining, shop_grid.offers.size()]
	_refresh.text = "刷新 · %d 金币" % int(payload.get("refresh_cost", 0))
	_refresh.disabled = int(payload.get("gold", 0)) < int(payload.get("refresh_cost", 0))
	FinanceUIStyle.button(_refresh)
	if bool(payload.get("strong_refresh", false)):
		_refresh.text = "强力刷新 · 免费"
		_refresh.add_theme_stylebox_override("normal", _refresh_glow)
		_refresh.add_theme_stylebox_override("hover", _refresh_glow)
		_refresh.tooltip_text = "消耗1次强力刷新：本次幸运+100，保底一件史诗（紫色）遗物。可跨波保留，直到主动刷新时使用。"
	else:
		_refresh.tooltip_text = ""
		_refresh.remove_theme_color_override("font_hover_color")
	if bool(payload.get("interest_pact", false)):
		var terms: Dictionary = payload.get("interest_pact_terms", {})
		_summary.tooltip_text += "\n哥布林交易（已接受%d次）：利率+%s%%，每回合理智-%d；本金取空后仍持续。" % [int(terms.get("count", 0)), str(terms.get("interest_bonus", 0)), int(terms.get("sanity_per_wave", 0))]
	workbench.refresh()
	if new_shelf:
		var settled := 0
		for result in payload.get("settlement_results", []): settled += int(result.get("gain", 0))
		_feedback.text = "本波利息 +%d 金币 · 已入随身金币" % settled if settled > 0 else "准备完成后，点击开始下一波。"
		FinanceUIStyle.label(_feedback, 12, FinanceUIStyle.MUTED)
	_sync_live_trade()


func _process(delta: float) -> void:
	if not visible or not bool(payload.get("strong_refresh", false)): return
	_glow_time += delta
	var color := Color.from_hsv(fmod(_glow_time * 0.18, 1.0), 0.55, 1.0)
	_refresh_glow.border_color = color
	_refresh.add_theme_color_override("font_color", color)
	_refresh.add_theme_color_override("font_hover_color", color)


func _sync_live_trade() -> void:
	var offer: Dictionary = payload.get("goblin_trade", {})
	if offer.is_empty():
		if not _live_trade_token.is_empty():
			_live_trade_token = ""
			cancel_trade("resolved")
		return
	var token := str(offer.get("token", ""))
	if token == _live_trade_token: return
	_live_trade_token = token
	present_trade(str(offer.speech), str(offer.body), str(offer.detail))
	trade_presentation.start_wave_on_accept = str(offer.id) == "principal_advance"
	trade_presentation._yes.tooltip_text = str(offer.body)
	if not str(offer.detail).is_empty():
		trade_presentation._yes.tooltip_text += "\n" + str(offer.detail)
	if str(offer.id) == "strong_refresh":
		trade_presentation._yes.tooltip_text += "\n存款仍归你所有，下次进入银行可手动取出。强力刷新可跨波保留。"
	_layout()


func show_popup() -> void:
	_sale_layer.hide()
	_tooltip.hide()
	show()
	_layout()


func hide_popup() -> void:
	cancel_trade("finance_closed")
	hide()
	_sale_layer.hide()
	_tooltip.hide()
	if flow != null: flow.clear_stat_preview()


func present_trade(speech: String, body: String, detail: String = "") -> void:
	# Also used by the isolated visual review.
	if trade_presentation == null:
		trade_presentation = GoblinTradePresentation.new()
		main_panel.add_child(trade_presentation)
		main_panel.move_child(trade_presentation, economy_log.get_index())
		trade_presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		trade_presentation.cancelled.connect(_on_trade_cancelled)
		trade_presentation.choice_made.connect(_on_trade_choice)
	trade_presentation.present(speech, body, detail)
	_layout()


func cancel_trade(reason: String) -> void:
	if trade_presentation != null: trade_presentation.cancel(reason)


func _on_trade_cancelled(reason: String) -> void:
	if not _live_trade_token.is_empty():
		_live_trade_token = ""
		if flow != null: flow.cancel_goblin_trade()
	_layout()
	trade_cancelled.emit(reason)


func _on_trade_choice(accepted: bool) -> void:
	trade_choice_made.emit(accepted)
	if not accepted or _live_trade_token.is_empty() or flow == null: return
	var result := flow.accept_goblin_trade(_live_trade_token)
	if bool(result.get("success", false)):
		_live_trade_token = ""
		cancel_trade("accepted")
		if flow.get_current_state() == MainFlowCoordinator.STATE_FINANCE_POPUP:
			configure(flow.get_preparation_payload())
			_feedback_message("交易已接受。", true)
	else:
		show_error(str(result.get("reason", "trade_expired")))
		flow.cancel_goblin_trade()
		_live_trade_token = ""
		cancel_trade("expired")


func set_safe_rect(rect: Rect2) -> void:
	_safe_rect = rect
	if main_panel != null: _layout()


func show_error(code: String) -> void:
	_feedback_message(FinanceUIStyle.reason(code), false)


func _build() -> void:
	main_panel = Panel.new()
	main_panel.name = "MainPanel"
	main_panel.add_theme_stylebox_override("panel", FinanceUIStyle.box("292b20", "9c9169", 0))
	add_child(main_panel)
	var board := NinePatchRect.new()
	board.texture = BOARD
	board.patch_margin_left = 16
	board.patch_margin_top = 16
	board.patch_margin_right = 16
	board.patch_margin_bottom = 16
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_child(board)
	_title = _label("哥布林银行", main_panel, 22, FinanceUIStyle.TEXT)
	_summary = _label("", main_panel, 13, FinanceUIStyle.GOLD)
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bank = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.scroll(_bank)
	main_panel.add_child(_bank)
	_bank_header = VBoxContainer.new()
	_bank_header.add_theme_constant_override("separation", 8)
	main_panel.add_child(_bank_header)
	var bank_body := VBoxContainer.new()
	bank_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_body.add_theme_constant_override("separation", 8)
	_bank.add_child(bank_body)
	portrait = BankCounterPortrait.new()
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bank_header.add_child(portrait)
	_principal_protection = _label("", bank_body, 12, FinanceUIStyle.GOLD)
	_principal_protection.name = "PrincipalReviveStatus"
	_principal_protection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_principal_protection.mouse_filter = Control.MOUSE_FILTER_PASS
	_principal_protection.hide()
	_bank_form = VBoxContainer.new()
	_bank_form.add_theme_constant_override("separation", 8)
	bank_body.add_child(_bank_form)
	var actions := HBoxContainer.new()
	_bank_form.add_child(actions)
	_deposit = _button("存入本金", actions)
	_deposit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deposit.pressed.connect(_choose_bank_action.bind("deposit"))
	_withdraw = _button("取出本金", actions)
	_withdraw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_withdraw.pressed.connect(_choose_bank_action.bind("withdraw"))
	amount_input = LineEdit.new()
	amount_input.placeholder_text = "输入金额"
	amount_input.max_length = 12
	amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	amount_input.add_theme_font_size_override("font_size", 14)
	amount_input.add_theme_stylebox_override("normal", FinanceUIStyle.box("1c251e", "626b4e", 6))
	amount_input.add_theme_color_override("font_color", FinanceUIStyle.TEXT)
	_bank_form.add_child(amount_input)
	amount_input.text_submitted.connect(func(_value): _submit_bank())
	var shortcuts := HBoxContainer.new()
	_bank_form.add_child(shortcuts)
	for portion in [0.25, 0.5, 1.0]:
		var quick := _button("全部" if portion == 1.0 else ("1/2" if portion == 0.5 else "1/4"), shortcuts)
		quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.pressed.connect(func():
			amount_input.text = str(floori(float(payload.get("gold" if _bank_action == "deposit" else "principal", 0)) * portion))
			_update_bank_confirm()
		)
	_bank_preview = _label("", _bank_form, 12, FinanceUIStyle.GOLD)
	_bank_preview.name = "PrincipalStatPreview"
	_bank_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bank_confirm = _button("确认存入", _bank_form)
	bank_confirm.pressed.connect(_submit_bank)
	amount_input.text_changed.connect(func(_value): _update_bank_confirm())
	_receipt = _label("", bank_body, 14, FinanceUIStyle.GREEN)
	_receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract = _label("", bank_body, 12, FinanceUIStyle.MUTED)
	_contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	main_panel.add_child(_tabs)
	for entry in [["bank", "理财"], ["shop", "购买"], ["enchant", "附魔"]]:
		var tab := _button(entry[1], _tabs)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_tab.bind(entry[0]))
		_tab_buttons[entry[0]] = tab
	_shop = Control.new()
	main_panel.add_child(_shop)
	shop_grid = VirtualShopGrid.new()
	_shop.add_child(shop_grid)
	shop_grid.purchase_requested.connect(_buy)
	shop_grid.preview_requested.connect(func(offer):
		if flow != null: flow.set_stat_preview_from_offer(offer)
	)
	shop_grid.preview_cleared.connect(func():
		if flow != null: flow.clear_stat_preview()
	)
	_stock = _label("", _shop, 12, FinanceUIStyle.MUTED)
	_refresh = _button("刷新", _shop)
	_refresh.pressed.connect(_refresh_shop)
	_enchant_scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.scroll(_enchant_scroll)
	main_panel.add_child(_enchant_scroll)
	workbench = EnchantmentWorkbench.new()
	workbench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workbench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enchant_scroll.add_child(workbench)
	workbench.sale_requested.connect(_open_sale)
	workbench.feedback_requested.connect(_feedback_message)
	workbench.tooltip_requested.connect(_show_tooltip)
	workbench.tooltip_hidden.connect(func(): _tooltip.hide())
	_feedback = _label("", main_panel, 12, FinanceUIStyle.MUTED)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _button("开始下一波", main_panel)
	FinanceUIStyle.button(start_button, true)
	start_button.pressed.connect(func():
		if flow != null and not _sale_layer.visible: flow.close_finance_popup()
	)
	economy_log = EconomyLogPanel.new()
	economy_log.name = "FinanceLog"
	main_panel.add_child(economy_log)
	_build_sale_dialog()
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", FinanceUIStyle.box("17231c", "98956a", 12))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 20
	main_panel.add_child(_tooltip)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.scroll_active = false
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.add_theme_font_size_override("normal_font_size", 12)
	_tooltip_text.add_theme_constant_override("line_separation", 4)
	_tooltip.add_child(_tooltip_text)
	_tooltip.hide()


func _build_sale_dialog() -> void:
	_sale_layer = Control.new()
	_sale_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel.add_child(_sale_layer)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.025, 0.04, 0.03, 0.88)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sale_layer.add_child(dimmer)
	_sale_box = PanelContainer.new()
	_sale_box.add_theme_stylebox_override("panel", FinanceUIStyle.box("2d3427", "ab9b6a", 18))
	_sale_layer.add_child(_sale_box)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_sale_box.add_child(body)
	var sale_heading := HBoxContainer.new()
	sale_heading.add_theme_constant_override("separation", 12)
	body.add_child(sale_heading)
	_sale_icon = TextureRect.new()
	_sale_icon.custom_minimum_size = Vector2(44, 44)
	_sale_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sale_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sale_heading.add_child(_sale_icon)
	_label("确认出售", sale_heading, 20, FinanceUIStyle.GOLD)
	_sale_text = RichTextLabel.new()
	_sale_text.bbcode_enabled = true
	_sale_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sale_text.add_theme_color_override("default_color", FinanceUIStyle.TEXT)
	_sale_text.add_theme_font_size_override("normal_font_size", 14)
	body.add_child(_sale_text)
	_sale_items = HBoxContainer.new()
	_sale_items.add_theme_constant_override("separation", 8)
	body.add_child(_sale_items)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	var cancel := _button("取消", actions)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): _sale_layer.hide())
	_sale_confirm = _button("确认出售", actions)
	_sale_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sale_confirm.pressed.connect(_confirm_sale)
	_sale_layer.hide()


func _layout() -> void:
	main_panel.position = _safe_rect.position
	main_panel.size = _safe_rect.size
	var w := main_panel.size.x
	var h := main_panel.size.y
	_compact = w < 700
	var short_window := get_viewport().get_visible_rect().size.y < 480
	FinanceUIStyle.label(_title, 18 if short_window else 22)
	_place(_title, Rect2(20, 6 if short_window else 12, w - 40, 26 if short_window else 30))
	_place(_summary, Rect2(20, 32 if short_window else 46, w - 40, 18 if short_window else 22))
	var body_y := 54.0 if short_window else 78.0
	var body_bottom := h - (46.0 if short_window else 60.0)
	var bank_width := clampf(w * 0.23, 112.0, 150.0) if _compact else 226.0
	var work_x := 20.0 + bank_width + (12.0 if _compact else 16.0)
	var work_w := w - work_x - 20.0
	_place(_tabs, Rect2(work_x, body_y, work_w, 28 if short_window else 30))
	var content_y := body_y + (34.0 if short_window else 40.0)
	var content_h := maxf(24, body_bottom - content_y)
	# Reserve a permanent banker column on every tab. Compact forms use the
	# right-hand workspace; wide forms scroll underneath the pinned portrait.
	var header_h := minf(160.0, maxf(70.0, (body_bottom - body_y) * 0.52))
	var trade_active := trade_presentation != null and trade_presentation.is_active()
	var trade_height := 0.0
	if trade_active:
		var reserved_space := 4.0 if _compact else 40.0
		var available_height := maxf(82, body_bottom - body_y - 48 - reserved_space)
		trade_height = minf(trade_presentation.get_preferred_height(bank_width), available_height)
		header_h = minf(header_h, maxf(48, body_bottom - body_y - trade_height - reserved_space))
	# Integer scroll origins keep the last form row fully inside the viewport.
	header_h = floorf(header_h)
	portrait.show()
	_place(_bank_header, Rect2(20, body_y, bank_width, header_h))
	var bank_rect := Rect2(work_x, content_y, work_w, content_h) if _compact else Rect2(20, body_y + header_h + 8, bank_width, maxf(24, body_bottom - body_y - header_h - 8))
	if trade_active:
		var card_rect := Rect2(20, body_y + header_h + 4, bank_width, trade_height)
		trade_presentation.arrange(card_rect, Rect2(20, body_y + 24, bank_width, maxf(1, header_h - 24)), Rect2(Vector2.ZERO, main_panel.size))
		if not _compact:
			bank_rect.position.y = card_rect.end.y + 8
			bank_rect.size.y = maxf(24, body_bottom - bank_rect.position.y)
	_place(_bank, bank_rect)
	_place(_shop, Rect2(work_x, content_y, work_w, content_h))
	_place(_enchant_scroll, Rect2(work_x, content_y, work_w, content_h))
	workbench.custom_minimum_size.y = 296
	_place(shop_grid, Rect2(0, 0, work_w, maxf(16, content_h if short_window else content_h - 38)))
	_place(_stock, Rect2(148 if short_window else 0, content_h + 8 if short_window else content_h - 30, maxf(40, work_w - 294) if short_window else maxf(40, work_w - 140), 28))
	_stock.visible = not short_window or work_w >= 360
	_place(_refresh, Rect2(0 if short_window else work_w - 136, content_h + 8 if short_window else content_h - 30, 136, 28))
	_place(_feedback, Rect2(84, h - 50, maxf(50, w - 252), 38))
	_feedback.visible = not short_window
	_summary.show()
	_place(start_button, Rect2(w - 154, h - 38 if short_window else h - 50, 134, 30 if short_window else 36))
	_place(economy_log, Rect2(Vector2.ZERO, main_panel.size))
	economy_log.apply_finance_layout(Rect2(20, body_y, w - 40, body_bottom - body_y), Rect2(20, start_button.position.y, 52, start_button.size.y))
	var sale_size := Vector2(minf(420, w - 32), minf(360, h - 32))
	_place(_sale_box, Rect2((Vector2(w, h) - sale_size) * 0.5, sale_size))
	if not _compact and _active_tab == "bank": _active_tab = "shop"
	_select_tab(_active_tab)


func _select_tab(tab: String) -> void:
	_active_tab = tab
	_bank.visible = not _compact or tab == "bank"
	_bank_header.show()
	_shop.visible = tab == "shop"
	_enchant_scroll.visible = tab == "enchant"
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.visible = key != "bank" or _compact
		FinanceUIStyle.tab(button, key == tab)
	if _tooltip != null: _tooltip.hide()
	if flow != null: flow.clear_stat_preview()


func _refresh_bank() -> void:
	var trade_locked := bool(payload.get("trade_withdraw_blocked", false))
	var locked := bool(payload.get("manual_operation_used", false)) or trade_locked
	_bank_form.visible = not locked
	_receipt.visible = locked
	if locked:
		var last: Dictionary = payload.get("last_manual_operation", {})
		_receipt.text = "本波已%s %d 金币\n下波可再次办理存取。" % ["存入" if str(last.get("action", "")) == "deposit" else "取出", int(last.get("amount", 0))]
		if trade_locked: _receipt.text = "交易限制：本次银行存取已关闭。\n下次进入银行恢复。"
	elif bool(payload.get("trade_deposit_blocked", false)):
		_receipt.show()
		_receipt.text = "交易限制：本次不可存款，仍可取款。"
		_bank_action = "withdraw"
	_choose_bank_action(_bank_action)
	_contract.text = ""
	_contract.visible = bool(payload.get("has_high_yield_contract", false))
	if _contract.visible:
		var bonus := float(payload.get("deposit_bonus_rate", 0.0))
		var bonus_text := HumanityEconomy.number(bonus)
		var status := "本波利率已 +%s 个百分点" % bonus_text if bool(payload.get("deposit_bonus_active", false)) else "达标后利率 +%s 个百分点；未达标仍正常结息" % bonus_text
		_contract.text = "高利契约：手动存入 %d / %d\n%s" % [int(payload.get("wave_start_deposit_amount", 0)), int(payload.get("deposit_requirement", 0)), status]


func _choose_bank_action(action: String) -> void:
	_bank_action = action
	FinanceUIStyle.button(_deposit, action == "deposit")
	FinanceUIStyle.button(_withdraw, action == "withdraw")
	bank_confirm.text = "确认存入" if action == "deposit" else "确认取出"
	_withdraw.disabled = int(payload.get("principal", 0)) <= 0
	_deposit.disabled = bool(payload.get("trade_deposit_blocked", false))
	_deposit.tooltip_text = "交易限制：本次不可存款。" if _deposit.disabled else ""
	_withdraw.disabled = _withdraw.disabled or bool(payload.get("trade_withdraw_blocked", false))
	_update_bank_confirm()


func _bank_amount_error() -> String:
	if bool(payload.get("trade_withdraw_blocked", false)): return "trade_bank_blocked"
	if _bank_action == "deposit" and bool(payload.get("trade_deposit_blocked", false)): return "trade_deposit_blocked"
	if bool(payload.get("manual_operation_used", false)):
		return "bank_operation_used"
	var value := amount_input.text.strip_edges()
	if not value.is_valid_int() or value.to_int() <= 0:
		return "amount_must_be_positive"
	var balance := int(payload.get("gold" if _bank_action == "deposit" else "principal", 0))
	if value.to_int() > balance:
		return "amount_exceeds_gold" if _bank_action == "deposit" else "amount_exceeds_principal"
	return ""


func _update_bank_confirm() -> void:
	var error := _bank_amount_error()
	bank_confirm.disabled = not error.is_empty()
	bank_confirm.tooltip_text = FinanceUIStyle.reason(error) if not error.is_empty() else ""
	amount_input.add_theme_color_override("font_color", Color("e1a184") if error.begins_with("amount_exceeds") else FinanceUIStyle.TEXT)
	_bank_preview.text = flow.get_bank_stat_preview(_bank_action, amount_input.text.to_int()) if error.is_empty() and flow != null else ""
	_bank_preview.visible = not _bank_preview.text.is_empty()
	if _bank_preview.visible:
		_reveal_bank_preview.call_deferred()


func _reveal_bank_preview() -> void:
	if _bank_preview.is_visible_in_tree():
		_bank.ensure_control_visible(_bank_preview)


func _submit_bank() -> void:
	if flow == null: return
	var error := _bank_amount_error()
	if not error.is_empty():
		show_error(error)
		return
	var result := flow.submit_finance_operation(_bank_action, amount_input.text.strip_edges().to_int())
	if bool(result.get("success", false)):
		cancel_trade(_bank_action)
		portrait.react(_bank_action, int(result.get("amount", 0)), int(result.get("source_balance_before", 0)))
		_feedback_message("存取已完成。仍可购买、出售和配置附魔。", true)
	else: show_error(str(result.get("reason", "")))


func _buy(offer: Dictionary) -> void:
	if flow == null: return
	var result := flow.submit_shop_purchase(offer, "shop")
	if bool(result.get("success", false)):
		cancel_trade("purchase")
		_feedback_message("已购买：" + str(offer.get("display_name", "")), true)
	else: show_error(str(result.get("reason", "")))


func _refresh_shop() -> void:
	if flow == null: return
	var result := flow.request_shop_refresh()
	if bool(result.get("success", false)): _feedback_message("强力刷新已使用，保底史诗遗物。" if bool(result.get("strong_refresh", false)) else "货架已刷新。", true)
	else: show_error(str(result.get("reason", "")))


func _open_sale(kind: String, id: String) -> void:
	_quote = flow.get_inventory_sale_quote(kind, id)
	if not bool(_quote.get("success", false)):
		show_error(str(_quote.get("reason", "")))
		return
	_tooltip.hide()
	_sale_icon.texture = FinanceUIStyle.item_icon(str(_quote.get("icon", "")))
	for child in _sale_items.get_children():
		_sale_items.remove_child(child)
		child.queue_free()
	_sale_items.visible = kind == "weapon" and not (_quote.get("returned_ids", []) as Array).is_empty()
	if _sale_items.visible:
		_label("归还背包", _sale_items, 12, FinanceUIStyle.MUTED)
		for returned_id in _quote.get("returned_ids", []):
			var returned_item := flow.get_bound_player().item_inventory.find_item(str(returned_id))
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(30, 30)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = FinanceUIStyle.item_icon(str(returned_item.get("icon", "")))
			icon.tooltip_text = str(returned_item.get("display_name", ""))
			_sale_items.add_child(icon)
	var lines: Array[String] = ["[b]%s[/b]" % str(_quote.get("display_name", ""))]
	if kind == "weapon":
		lines.append("武器等级：%d\n基础回收：%d\n升级回收：%d" % [int(_quote.get("level", 1)), int(_quote.get("base_value", 0)), int(_quote.get("upgrade_value", 0))])
		if int(_quote.get("title_bonus", 0)) > 0: lines.append("称号「%s」加价：%d" % [str(_quote.get("title", "")), int(_quote.get("title_bonus", 0))])
		var returned: Array = _quote.get("returned_items", [])
		lines.append("附魔将归还背包：" + ("、".join(returned) if not returned.is_empty() else "无"))
	else:
		var detail := ItemInventoryCard.new()
		detail.item_instance = flow.get_bound_player().item_inventory.find_item(id)
		lines.append(detail._build_tooltip())
		detail.free()
	lines.append(HumanityEconomy.sale_tooltip(_quote))
	lines.append("\n[color=#D4BC81]获得 %d 金币[/color]" % int(_quote.get("total", 0)))
	_sale_text.text = "\n\n".join(lines)
	_sale_confirm.text = "出售 · %d 金币" % int(_quote.get("total", 0))
	_sale_layer.show()
	_sale_confirm.grab_focus()


func _confirm_sale() -> void:
	if not _sale_layer.visible or _quote.is_empty(): return
	var result := flow.submit_inventory_sale(str(_quote.get("kind", "")), str(_quote.get("target_id", "")), str(_quote.get("quote_token", "")))
	_sale_layer.hide()
	_quote.clear()
	if bool(result.get("success", false)):
		cancel_trade("sale")
		_feedback_message("已出售，获得 %d 金币。" % int(result.get("gold_gained", 0)), true)
	else: show_error(str(result.get("reason", "")))


func _show_tooltip(content: String) -> void:
	if _sale_layer.visible: return
	var tooltip_size := Vector2(minf(310, main_panel.size.x - 24), 0)
	_tooltip_text.size.x = maxf(tooltip_size.x - 24, 1)
	_tooltip_text.text = content
	tooltip_size.y = minf(float(_tooltip_text.get_content_height()) + 24, main_panel.size.y - 24)
	var point := get_global_mouse_position() - main_panel.global_position + Vector2(14, 14)
	point.x = clampf(point.x, 12, main_panel.size.x - tooltip_size.x - 12)
	point.y = clampf(point.y, 12, main_panel.size.y - tooltip_size.y - 12)
	_place(_tooltip, Rect2(point, tooltip_size))
	_tooltip.show()


func _feedback_message(message: String, success: bool) -> void:
	_feedback.text = message
	FinanceUIStyle.label(_feedback, 12, FinanceUIStyle.GREEN if success else Color("e1a184"))
	if get_viewport().get_visible_rect().size.y < 480:
		_summary.hide()
		_place(_feedback, Rect2(20, 32, main_panel.size.x - 40, 18))
		_feedback.show()
		_notice_timer.start()


func handle_back_request() -> bool:
	if not visible or flow == null or flow.get_current_state() != MainFlowCoordinator.STATE_FINANCE_POPUP:
		return false
	if _sale_layer.visible:
		_sale_layer.hide()
	else:
		_tooltip.hide()
		flow.request_esc_overlay()
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.is_action_pressed("ui_cancel") and handle_back_request():
		get_viewport().set_input_as_handled()


func _label(caption: String, parent: Control, font_size: int, color: Color) -> Label:
	var control := WrappedTooltipLabel.new()
	control.text = caption
	FinanceUIStyle.label(control, font_size, color)
	parent.add_child(control)
	return control


func _button(caption: String, parent: Control) -> Button:
	var control := Button.new()
	control.text = caption
	control.custom_minimum_size.y = 28
	FinanceUIStyle.button(control)
	parent.add_child(control)
	return control


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
