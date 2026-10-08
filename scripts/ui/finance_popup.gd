extends Control
class_name FinancePopup

signal trade_cancelled(reason: String)
signal trade_choice_made(accepted: bool)

const BACKGROUND: Texture2D = preload("res://assets/ui/finance/finance_background.png")
var scene_background: TextureRect
var _scene_wide := false
var _scene_summary_back: Panel
var _scene_bank_back: Panel
var _scene_enchant_back: Panel
var _scene_footer_back: Panel
var flow: MainFlowCoordinator
var payload: Dictionary = {}
var main_panel: Panel
var economy_log: EconomyLogPanel
var portrait: BankCounterPortrait
var trade_presentation: GoblinTradePresentation
var interest_arrival: InterestArrivalPresentation
var loan_presentation: GoblinLoanPresentation
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
var _tooltip_layout_frames := 0
var _tooltip_mouse_position := Vector2.ZERO
var _active_tab := "shop"
var _bank_action := "deposit"
var _generation := -1
var _safe_rect := Rect2(16, 72, 800, 520)
var _compact := false
var _notice_timer: Timer
var _sale_icon: TextureRect
var _sale_items: HBoxContainer
var _live_trade_token := ""
var _refresh_glow := FinanceFrameSkin.box("selected", 6)
var _glow_time := 0.0
var _last_arrival_id := ""
var _arrival_pulse: Tween


func _ready() -> void:
	L10n.locale_changed.connect(_on_locale_changed)
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
	loan_presentation.flow = flow
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
	_summary.text = L10n.text("ui.bank.balance_summary") % [int(payload.get("gold", 0)), int(payload.get("principal", 0)), float(payload.get("interest_rate", 0)), int(payload.get("estimated_interest", 0))]
	var protection: Dictionary = payload.get("principal_revive", {})
	_principal_protection.visible = not protection.is_empty()
	if not protection.is_empty():
		_principal_protection.text = "%s: %s" % [L10n.source(protection.display_name), FinanceUIStyle.principal_revive_status(protection)]
		_principal_protection.tooltip_text = L10n.text("ui.bank.revival_tooltip") % [int(protection.principal_cost), HumanityEconomy.number(float(protection.health_percent))]
	_summary.tooltip_text = ""
	_refresh_bank()
	var remaining := 0
	for offer in shop_grid.offers:
		if not bool(offer.get("purchased", false)): remaining += 1
	_stock.text = L10n.text("ui.bank.shop.remaining") % [remaining, shop_grid.offers.size()]
	_refresh.text = L10n.text("ui.bank.shop.reroll_price") % int(payload.get("refresh_cost", 0))
	_refresh.disabled = int(payload.get("gold", 0)) < int(payload.get("refresh_cost", 0))
	FinanceUIStyle.bank_button(_refresh)
	if bool(payload.get("strong_refresh", false)):
		_refresh.text = "ui.bank.shop.power_reroll"
		_refresh.add_theme_stylebox_override("normal", _refresh_glow)
		_refresh.add_theme_stylebox_override("hover", _refresh_glow)
		_refresh.tooltip_text = "ui.bank.shop.power_reroll_tooltip"
	else:
		_refresh.tooltip_text = ""
		_refresh.remove_theme_color_override("font_hover_color")
	workbench.refresh()
	if new_shelf:
		var settled := 0
		for result in payload.get("settlement_results", []): settled += int(result.get("gain", 0))
		_feedback.text = L10n.text("ui.bank.interest_received") % settled if settled > 0 else "ui.bank.ready_hint"
		var settlements: Array = payload.get("settlement_results", [])
		if not settlements.is_empty() and settlements.back().has("challenge_settlement"):
			_feedback.text = "ui.bank.challenge_deposit_done"
		FinanceUIStyle.label(_feedback, 12, FinanceUIStyle.MUTED)
	_sync_interest_arrival()
	_sync_live_trade()
	loan_presentation.configure(payload.get("goblin_loan",{}))
	_layout()


func _sync_interest_arrival() -> void:
	var report := InterestArrivalReport.build(payload)
	if report.is_empty() or str(report.id).is_empty() or str(report.id) == _last_arrival_id: return
	_last_arrival_id = str(report.id)
	_tooltip.hide()
	interest_arrival.present(report)
	_layout()


func reset_interest_arrival() -> void:
	_last_arrival_id = ""
	interest_arrival.stop()


func _on_interest_arrived(amount: int) -> void:
	if _arrival_pulse != null and _arrival_pulse.is_valid(): _arrival_pulse.kill()
	_summary.modulate = Color("fff0a4")
	_arrival_pulse = create_tween()
	_arrival_pulse.tween_property(_summary, "modulate", Color.WHITE, 0.6)
	if bool(interest_arrival.report.get("auto_deposit", false)):
		_feedback.text = "ui.bank.challenge_deposit_done"
		FinanceUIStyle.label(_feedback, 12, FinanceUIStyle.GOLD)
		return
	if amount <= 0: return
	_feedback.text = L10n.text("ui.bank.interest_received") % amount
	var affordable: Dictionary = {}
	if flow != null:
		for offer: Dictionary in payload.get("offers", []):
			var cost := int(offer.get("shop_cost", 0))
			if cost > 0 and cost <= amount and cost > int(affordable.get("shop_cost", 0)) and flow.get_offer_unavailable_reason(offer).is_empty():
				affordable = offer
	if not affordable.is_empty():
		_feedback.text = L10n.text("ui.bank.interest_purchase_hint") % [amount, L10n.record_text(affordable, "display_name", "ui.bank.shop.product")]
	FinanceUIStyle.label(_feedback, 12, FinanceUIStyle.GOLD)


func _process(delta: float) -> void:
	if _tooltip != null and _tooltip.visible:
		_fit_tooltip(_tooltip_mouse_position)
		_tooltip_layout_frames = maxi(0, _tooltip_layout_frames - 1)
		_tooltip.modulate.a = 1.0 if _tooltip_layout_frames == 0 else 0.0
	if not visible or not bool(payload.get("strong_refresh", false)): return
	_glow_time += delta
	var color := Color.from_hsv(fmod(_glow_time * 0.18, 1.0), 0.55, 1.0)
	_refresh_glow.modulate_color = Color.WHITE.lerp(color, 0.22)
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
	present_trade(L10n.record_text(offer, "speech"), L10n.record_text(offer, "body"), L10n.record_text(offer, "detail"))
	trade_presentation.start_wave_on_accept = str(offer.id) == "principal_advance"
	trade_presentation._yes.tooltip_text = L10n.record_text(offer, "body")
	if not L10n.source(str(offer.detail)).is_empty():
		trade_presentation._yes.tooltip_text += "\n" + L10n.source(str(offer.detail))
	if str(offer.id) == "strong_refresh":
		trade_presentation._yes.tooltip_text += L10n.text("ui.bank.deposit_ownership_hint")
	trade_presentation.configure_offer(offer)
	_layout()


func show_popup() -> void:
	_sale_layer.hide()
	_tooltip.hide()
	show()
	_layout()
	if interest_arrival.is_active(): interest_arrival.grab_focus()


func hide_popup() -> void:
	interest_arrival.stop()
	cancel_trade("finance_closed")
	hide()
	_sale_layer.hide()
	_tooltip.hide()
	if flow != null: flow.clear_stat_preview()


func _sync_loan_visibility() -> void:
	if loan_presentation != null: loan_presentation.visible = is_visible_in_tree() and main_panel.is_visible_in_tree()


func present_trade(speech: String, body: String, detail: String = "") -> void:
	# Also used by the isolated visual review.
	if trade_presentation == null:
		trade_presentation = GoblinTradePresentation.new()
		trade_presentation.finance_skin = true
		trade_presentation.z_index = 31
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
	if reason in ["rejected", "accepted", "purchase", "sale", "deposit", "withdraw", "refresh", "resolved"]:
		interest_arrival.skip()
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
			_feedback_message(L10n.text("ui.bank.trade_accepted"), true)
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
	scene_background = TextureRect.new()
	scene_background.name = "BankSceneBackground"
	scene_background.texture = BACKGROUND
	scene_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scene_background)
	main_panel = Panel.new()
	main_panel.name = "MainPanel"
	main_panel.add_theme_stylebox_override("panel", FinanceFrameSkin.box())
	add_child(main_panel)
	_scene_summary_back = _scene_surface("slim")
	_scene_bank_back = _scene_surface("panel")
	_scene_enchant_back = _scene_surface("panel")
	_scene_footer_back = _scene_surface("slim")
	_title = _label("ui.bank.title", main_panel, 22, FinanceUIStyle.TEXT)
	_summary = _label("", main_panel, 13, FinanceUIStyle.GOLD)
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bank = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.bank_scroll(_bank)
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
	main_panel.add_child(portrait)
	_principal_protection = _label("", bank_body, 12, FinanceUIStyle.GOLD)
	_principal_protection.name = "PrincipalReviveStatus"
	_principal_protection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_principal_protection.mouse_filter = Control.MOUSE_FILTER_PASS
	_principal_protection.hide()
	_bank_form = VBoxContainer.new()
	_bank_form.add_theme_constant_override("separation", 6)
	bank_body.add_child(_bank_form)
	var actions := HBoxContainer.new()
	_bank_form.add_child(actions)
	_deposit = _button("ui.bank.deposit.tab", actions)
	_deposit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deposit.pressed.connect(_choose_bank_action.bind("deposit"))
	_withdraw = _button("ui.bank.withdraw.tab", actions)
	_withdraw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_withdraw.pressed.connect(_choose_bank_action.bind("withdraw"))
	amount_input = LineEdit.new()
	amount_input.placeholder_text = "ui.bank.amount_placeholder"
	amount_input.max_length = 12
	amount_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	amount_input.add_theme_font_size_override("font_size", 12)
	amount_input.add_theme_stylebox_override("normal", FinanceFrameSkin.box("input", 6))
	amount_input.add_theme_stylebox_override("read_only", FinanceFrameSkin.box("input", 6))
	amount_input.add_theme_color_override("font_color", FinanceUIStyle.TEXT)
	_bank_form.add_child(amount_input)
	amount_input.text_submitted.connect(func(_value): _submit_bank())
	var shortcuts := HBoxContainer.new()
	_bank_form.add_child(shortcuts)
	for portion in [0.25, 0.5, 1.0]:
		var quick := _button("ui.common.all" if portion == 1.0 else ("1/2" if portion == 0.5 else "1/4"), shortcuts)
		quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.pressed.connect(func():
			amount_input.text = str(floori(float(payload.get("gold" if _bank_action == "deposit" else "principal", 0)) * portion))
			_update_bank_confirm()
		)
	_bank_preview = _label("", _bank_form, 12, FinanceUIStyle.GOLD)
	_bank_preview.name = "PrincipalStatPreview"
	_bank_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bank_confirm = _button("ui.bank.deposit.confirm", _bank_form)
	bank_confirm.pressed.connect(_submit_bank)
	amount_input.text_changed.connect(func(_value): _update_bank_confirm())
	_receipt = _label("", bank_body, 14, FinanceUIStyle.GREEN)
	_receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract = _label("", bank_body, 12, FinanceUIStyle.MUTED)
	_contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	main_panel.add_child(_tabs)
	for entry in [["bank", "stat.principal.name"], ["shop", "ui.common.buy"], ["enchant", "ui.common.enchantments"]]:
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
	_refresh = _button("ui.common.reroll", _shop)
	_refresh.pressed.connect(_refresh_shop)
	_enchant_scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.bank_scroll(_enchant_scroll)
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
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_button = _button("ui.bank.next_wave", main_panel)
	FinanceUIStyle.bank_button(start_button, true)
	start_button.pressed.connect(func():
		if flow != null and not _sale_layer.visible: flow.close_finance_popup()
	)
	economy_log = EconomyLogPanel.new()
	economy_log.name = "FinanceLog"
	main_panel.add_child(economy_log)
	_build_sale_dialog()
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", FinanceFrameSkin.box("panel", 12))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 20
	GameTooltipLayer.for_owner(main_panel).add_child(_tooltip)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.scroll_active = false
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.add_theme_font_size_override("normal_font_size", 12)
	_tooltip_text.add_theme_constant_override("line_separation", 4)
	_tooltip.add_child(_tooltip_text)
	_tooltip.hide()
	interest_arrival = InterestArrivalPresentation.new()
	main_panel.add_child(interest_arrival)
	interest_arrival.arrived.connect(_on_interest_arrived)
	var loan_layer := CanvasLayer.new()
	loan_layer.name = "LoanLayer"
	loan_layer.layer = 32
	add_child(loan_layer)
	loan_presentation = GoblinLoanPresentation.new()
	loan_presentation.name = "GoblinLoanPresentation"
	loan_layer.add_child(loan_presentation)
	loan_presentation.error_requested.connect(show_error)
	visibility_changed.connect(_sync_loan_visibility)
	main_panel.visibility_changed.connect(_sync_loan_visibility)
	_sync_loan_visibility()


func _build_sale_dialog() -> void:
	_sale_layer = Control.new()
	_sale_layer.z_index = 40
	_sale_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel.add_child(_sale_layer)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.025, 0.04, 0.03, 0.88)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sale_layer.add_child(dimmer)
	_sale_box = PanelContainer.new()
	_sale_box.add_theme_stylebox_override("panel", FinanceFrameSkin.box("panel", 18))
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
	_label("ui.bank.sale.confirm", sale_heading, 20, FinanceUIStyle.GOLD)
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
	var cancel := _button("ui.common.cancel", actions)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): _sale_layer.hide())
	_sale_confirm = _button("ui.bank.sale.confirm", actions)
	_sale_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sale_confirm.pressed.connect(_confirm_sale)
	_sale_layer.hide()


func _scene_surface(kind: String) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", FinanceFrameSkin.box(kind))
	main_panel.add_child(panel)
	return panel


func _layout() -> void:
	_scene_wide = FinanceSceneLayout.supports(get_viewport_rect().size)
	portrait.background_counter = _scene_wide
	for panel in [_scene_summary_back, _scene_bank_back, _scene_enchant_back, _scene_footer_back]:
		panel.visible = _scene_wide
	if _scene_wide:
		main_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		FinanceSceneLayout.arrange(self)
		return
	main_panel.add_theme_stylebox_override("panel", FinanceFrameSkin.box())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_panel.position = _safe_rect.position
	main_panel.size = _safe_rect.size
	var w := main_panel.size.x
	var h := main_panel.size.y
	var loan_space := loan_presentation.reserved_height() if loan_presentation != null else 0.0
	var footer_bottom := h-loan_space
	_compact = w < 700
	var short_window := get_viewport().get_visible_rect().size.y < 480
	FinanceUIStyle.label(_title, 18 if short_window else 22)
	_place(_title, Rect2(20, 6 if short_window else 12, w - 40, 26 if short_window else 30))
	_place(_summary, Rect2(20, 32 if short_window else 46, w - 40, 18 if short_window else 22))
	var body_y := (46.0 if loan_space>0 and _compact else 54.0) if short_window else 78.0
	if short_window and loan_space>0 and _compact:
		_place(_title,Rect2(20,4,w-40,22))
		_place(_summary,Rect2(20,27,w-40,18))
	var body_bottom := footer_bottom - (46.0 if short_window else 60.0)
	var bank_width := clampf(w * 0.23, 112.0, 150.0) if _compact else 226.0
	var work_x := 20.0 + bank_width + (12.0 if _compact else 16.0)
	var work_w := w - work_x - 20.0
	if interest_arrival != null:
		var screen_rect := get_viewport().get_visible_rect()
		var center := screen_rect.get_center()
		# Symmetric margins keep the receipt centered without covering the HUD.
		var half_size := Vector2(minf(center.x - screen_rect.position.x - 16, main_panel.get_global_rect().end.x - center.x), center.y - main_panel.global_position.y)
		var receipt_rect := Rect2(center - half_size - main_panel.global_position, half_size * 2)
		interest_arrival.arrange(screen_rect.size, Vector2(88, 42 if short_window else 56), receipt_rect)
	_place(_tabs, Rect2(work_x, body_y, work_w, 28 if short_window else 30))
	var content_y := body_y + (34.0 if short_window else 40.0)
	var content_h := maxf(24, body_bottom - content_y)
	# Reserve a permanent banker column on every tab. Compact forms use the
	# right-hand workspace; wide forms scroll underneath the pinned portrait.
	var header_h := minf(200.0, maxf(70.0, (body_bottom - body_y) * (1.0 if _compact else 0.56)))
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
	_place(portrait, _bank_header.get_rect())
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
	_place(_feedback, Rect2(84, footer_bottom - 50, maxf(50, w - 252), 38))
	_feedback.visible = not short_window
	_summary.show()
	_place(start_button, Rect2(w - 154, footer_bottom - 38 if short_window else footer_bottom - 50, 134, 30 if short_window else 36))
	_place(economy_log, Rect2(Vector2.ZERO, main_panel.size))
	economy_log.apply_finance_layout(Rect2(20, body_y, w - 40, body_bottom - body_y), Rect2(20, start_button.position.y, 52, start_button.size.y))
	var sale_size := Vector2(minf(420, w - 32), minf(360, h - 32))
	_place(_sale_box, Rect2((Vector2(w, h) - sale_size) * 0.5, sale_size))
	if not _compact and _active_tab == "bank": _active_tab = "shop"
	_select_tab(_active_tab)
	if loan_presentation != null: loan_presentation.arrange(main_panel.get_global_rect())


func _select_tab(tab: String) -> void:
	_active_tab = tab
	_bank.visible = not _compact or tab == "bank"
	_bank_header.show()
	_scene_enchant_back.visible = _scene_wide and tab == "enchant"
	_shop.visible = tab == "shop"
	_enchant_scroll.visible = tab == "enchant"
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.visible = key != "bank" or _compact
		FinanceUIStyle.bank_tab(button, key == tab)
	if _tooltip != null: _tooltip.hide()
	if flow != null: flow.clear_stat_preview()


func _refresh_bank() -> void:
	var trade_locked := bool(payload.get("trade_withdraw_blocked", false))
	var locked := bool(payload.get("manual_operation_used", false)) or trade_locked
	_bank_form.visible = not locked
	_receipt.visible = locked
	if locked:
		var last: Dictionary = payload.get("last_manual_operation", {})
		_receipt.text = L10n.text("ui.bank.transaction_done") % [L10n.text("ui.bank.deposit.action" if str(last.get("action", "")) == "deposit" else "ui.bank.withdraw.action"), int(last.get("amount", 0))]
		if trade_locked: _receipt.text = "ui.bank.restriction.all"
	elif bool(payload.get("trade_deposit_blocked", false)):
		_receipt.show()
		_receipt.text = "ui.bank.restriction.deposit_only"
		_bank_action = "withdraw"
	_choose_bank_action(_bank_action)
	_contract.text = ""
	_contract.visible = bool(payload.get("has_high_yield_contract", false))
	if _contract.visible:
		var bonus := float(payload.get("deposit_bonus_rate", 0.0))
		var bonus_text := HumanityEconomy.number(bonus)
		var status := L10n.text("ui.bank.high_yield.fulfilled") % bonus_text if bool(payload.get("deposit_bonus_active", false)) else L10n.text("ui.bank.high_yield.requirement") % bonus_text
		_contract.text = L10n.text("ui.bank.high_yield.progress") % [int(payload.get("wave_start_deposit_amount", 0)), int(payload.get("deposit_requirement", 0)), status]


func _choose_bank_action(action: String) -> void:
	_bank_action = action
	FinanceUIStyle.bank_button(_deposit, action == "deposit")
	FinanceUIStyle.bank_button(_withdraw, action == "withdraw")
	bank_confirm.text = "ui.bank.deposit.confirm" if action == "deposit" else "确认取出"
	_withdraw.disabled = int(payload.get("principal", 0)) <= 0
	_deposit.disabled = bool(payload.get("trade_deposit_blocked", false))
	_deposit.tooltip_text = "ui.bank.restriction.no_deposit" if _deposit.disabled else ""
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
	if _scene_wide: _layout.call_deferred()


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
		_feedback_message(L10n.text("ui.bank.transaction_done_hint"), true)
	else: show_error(str(result.get("reason", "")))


func _buy(offer: Dictionary) -> void:
	if flow == null: return
	var result := flow.submit_shop_purchase(offer, "shop")
	if bool(result.get("success", false)):
		cancel_trade("purchase")
		_feedback_message(L10n.text("ui.bank.purchase_done_prefix") + L10n.record_text(offer, "display_name"), true)
	else: show_error(str(result.get("reason", "")))


func _on_locale_changed() -> void:
	if payload.is_empty() or not is_node_ready():
		return
	# Existing generation and arrival IDs prevent rerolls and replayed payouts.
	configure(payload)
	var offer: Dictionary = payload.get("goblin_trade", {})
	if not offer.is_empty():
		trade_presentation._speech_text.text = L10n.record_text(offer, "speech")
		trade_presentation._body.text = L10n.record_text(offer, "body")
		trade_presentation._yes.tooltip_text = L10n.record_text(offer, "body")


func _refresh_shop() -> void:
	if flow == null: return
	var result := flow.request_shop_refresh()
	if bool(result.get("success", false)):
		cancel_trade("refresh")
		_feedback_message(L10n.text("ui.bank.power_reroll_done") if bool(result.get("strong_refresh", false)) else L10n.text("ui.bank.reroll_done"), true)
	else: show_error(str(result.get("reason", "")))


func _open_sale(kind: String, id: String) -> void:
	_quote = flow.get_inventory_sale_quote(kind, id)
	if not bool(_quote.get("success", false)):
		show_error(str(_quote.get("reason", "")))
		return
	interest_arrival.skip()
	_tooltip.hide()
	_sale_icon.texture = FinanceUIStyle.item_icon(str(_quote.get("icon", "")))
	for child in _sale_items.get_children():
		_sale_items.remove_child(child)
		child.queue_free()
	_sale_items.visible = kind == "weapon" and not (_quote.get("returned_ids", []) as Array).is_empty()
	if _sale_items.visible:
		_label("ui.bank.return_to_inventory", _sale_items, 12, FinanceUIStyle.MUTED)
		for returned_id in _quote.get("returned_ids", []):
			var returned_item := flow.get_bound_player().item_inventory.find_item(str(returned_id))
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(30, 30)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = FinanceUIStyle.item_icon(str(returned_item.get("icon", "")))
			icon.tooltip_text = L10n.source(str(returned_item.get("display_name", "")))
			_sale_items.add_child(icon)
	var lines: Array[String] = ["[b]%s[/b]" % L10n.source(str(_quote.get("display_name", "")))]
	if kind == "weapon":
		lines.append(L10n.text("ui.bank.sale.weapon_breakdown") % [int(_quote.get("level", 1)), int(_quote.get("base_value", 0)), int(_quote.get("upgrade_value", 0))])
		if int(_quote.get("title_bonus", 0)) > 0: lines.append(L10n.text("ui.bank.sale.title_bonus") % [L10n.source(_quote.get("title", "")), int(_quote.get("title_bonus", 0))])
		var returned: Array[String] = []
		for item_name in _quote.get("returned_items", []): returned.append(L10n.source(item_name))
		lines.append(L10n.text("ui.bank.sale.returned_enchantments_prefix") + (", ".join(returned) if not returned.is_empty() else L10n.text("ui.common.none")))
	else:
		var detail := ItemInventoryCard.new()
		detail.item_instance = flow.get_bound_player().item_inventory.find_item(id)
		lines.append(detail._build_tooltip(false))
		detail.free()
	lines.append(HumanityEconomy.sale_tooltip(_quote))
	lines.append(L10n.text("ui.bank.sale.proceeds") % int(_quote.get("total", 0)))
	_sale_text.text = "\n\n".join(lines)
	_sale_text.scroll_to_line(0)
	_sale_confirm.text = L10n.text("ui.bank.sale.price") % int(_quote.get("total", 0))
	_sale_layer.show()
	_sale_confirm.grab_focus()


func _confirm_sale() -> void:
	if not _sale_layer.visible or _quote.is_empty(): return
	var result := flow.submit_inventory_sale(str(_quote.get("kind", "")), str(_quote.get("target_id", "")), str(_quote.get("quote_token", "")))
	_sale_layer.hide()
	_quote.clear()
	if bool(result.get("success", false)):
		cancel_trade("sale")
		_feedback_message(L10n.text("ui.enchantment.sale_done") % int(result.get("gold_gained", 0)), true)
	else: show_error(str(result.get("reason", "")))


func _show_tooltip(content: String) -> void:
	if _sale_layer.visible: return
	var viewport_size := get_viewport_rect().size
	var tooltip_size := Vector2(minf(310, viewport_size.x - 24), 0)
	_tooltip_text.size.x = maxf(tooltip_size.x - 24, 1)
	_tooltip_text.text = content
	_tooltip.size.x = tooltip_size.x
	# Keep the first wrapping/layout pass invisible instead of flashing at a corner.
	_tooltip_layout_frames = 2
	_tooltip.modulate.a = 0.0
	_tooltip.show()
	_fit_tooltip(_tooltip_mouse_position)


func _fit_tooltip(mouse: Vector2) -> void:
	if not _tooltip.visible: return
	var viewport_size := get_viewport_rect().size
	var tooltip_size := Vector2(minf(310, viewport_size.x - 24), minf(float(_tooltip_text.get_content_height()) + 24, viewport_size.y - 24))
	var point := mouse + Vector2(14, 14)
	if point.x + tooltip_size.x > viewport_size.x - 12:
		point.x = mouse.x - tooltip_size.x - 14
	point.x = clampf(point.x, 12, viewport_size.x - tooltip_size.x - 12)
	point.y = clampf(point.y, 12, viewport_size.y - tooltip_size.y - 12)
	_place(_tooltip, Rect2(point, tooltip_size))


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
	if loan_presentation.is_active():
		loan_presentation.dismiss_quote()
	elif interest_arrival.is_active():
		interest_arrival.skip()
	elif _sale_layer.visible:
		_sale_layer.hide()
	else:
		_tooltip.hide()
		flow.request_esc_overlay()
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and get_viewport_rect().has_point(event.position):
		# Use the pointer event that opens the tooltip, in viewport coordinates.
		_tooltip_mouse_position = event.position
	if event is InputEventKey and not event.echo and event.is_action_pressed("ui_cancel") and handle_back_request():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_observe_disabled_purchase(event.position)


func _observe_disabled_purchase(point: Vector2) -> void:
	if not is_visible_in_tree() or not main_panel.is_visible_in_tree() or flow == null or flow.get_current_state()!=MainFlowCoordinator.STATE_FINANCE_POPUP: return
	if _sale_layer.visible or loan_presentation.is_active() or interest_arrival.is_active() or not _shop.is_visible_in_tree(): return
	if economy_log.panel.visible and economy_log.panel.get_global_rect().has_point(point): return
	if not shop_grid.scroll.get_global_rect().has_point(point): return
	for card: PreparationOfferCard in shop_grid._pool:
		if card.is_visible_in_tree() and card.buy_button.disabled and card.buy_button.get_global_rect().has_point(point):
			if flow.record_loan_purchase_attempt(card.offer): get_viewport().set_input_as_handled()
			return


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
	FinanceUIStyle.bank_button(control)
	parent.add_child(control)
	return control


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
