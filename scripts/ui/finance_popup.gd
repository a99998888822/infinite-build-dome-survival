extends Control
class_name FinancePopup

const BOARD: Texture2D = preload("res://assets/ui/finance/finance_board.png")
var flow: MainFlowCoordinator
var payload: Dictionary = {}
var main_panel: Panel
var portrait: BankCounterPortrait
var shop_grid: VirtualShopGrid
var workbench: EnchantmentWorkbench
var amount_input: LineEdit
var bank_confirm: Button
var start_button: Button
var _title: Label
var _summary: Label
var _bank: ScrollContainer
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
	var generation := int(payload.get("offer_generation", 0))
	var new_shelf := generation != _generation
	_generation = generation
	if new_shelf:
		shop_grid.set_offers(payload.get("offers", []), true)
	else:
		shop_grid.refresh_availability()
	_summary.text = "金币 %d　│　本金 %d　│　利率 %.1f%%　│　预计利息 +%d" % [int(payload.get("gold", 0)), int(payload.get("principal", 0)), float(payload.get("interest_rate", 0)), int(payload.get("estimated_interest", 0))]
	_refresh_bank()
	var remaining := 0
	for offer in shop_grid.offers:
		if not bool(offer.get("purchased", false)): remaining += 1
	_stock.text = "剩余 %d / %d 件" % [remaining, shop_grid.offers.size()]
	_refresh.text = "刷新 · %d 金币" % int(payload.get("refresh_cost", 0))
	_refresh.disabled = int(payload.get("gold", 0)) < int(payload.get("refresh_cost", 0))
	workbench.refresh()
	if new_shelf:
		var settled := 0
		for result in payload.get("settlement_results", []): settled += int(result.get("gain", 0))
		_feedback.text = "本波结息 +%d 本金 · 准备完成后开始下一波" % settled if settled > 0 else "准备完成后，点击开始下一波。"
		FinanceUIStyle.label(_feedback, 12, FinanceUIStyle.MUTED)


func show_popup() -> void:
	_sale_layer.hide()
	_tooltip.hide()
	show()
	_layout()


func hide_popup() -> void:
	hide()
	_sale_layer.hide()
	_tooltip.hide()
	if flow != null: flow.clear_stat_preview()


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
	_title = _label("理财·购买·附魔", main_panel, 22, FinanceUIStyle.TEXT)
	_summary = _label("", main_panel, 13, FinanceUIStyle.GOLD)
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bank = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.scroll(_bank)
	main_panel.add_child(_bank)
	var bank_body := VBoxContainer.new()
	bank_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_body.add_theme_constant_override("separation", 8)
	_bank.add_child(bank_body)
	var motto := _label("哥布林银行 · 每波限办一次", bank_body, 13, FinanceUIStyle.GOLD)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait = BankCounterPortrait.new()
	portrait.custom_minimum_size.y = 132
	bank_body.add_child(portrait)
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
	_build_sale_dialog()
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", FinanceUIStyle.box("17231cf5", "98956a", 12))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 20
	main_panel.add_child(_tooltip)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.scroll_active = false
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.add_theme_font_size_override("normal_font_size", 12)
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
	var bank_width := 226.0
	var work_x := 20.0 if _compact else 20.0 + bank_width + 16.0
	var work_w := w - work_x - 20.0
	_place(_tabs, Rect2(work_x, body_y, work_w, 28 if short_window else 30))
	var content_y := body_y + (34.0 if short_window else 40.0)
	var content_h := maxf(24, body_bottom - content_y)
	_place(_bank, Rect2(20, content_y if _compact else body_y, w - 40 if _compact else bank_width, content_h if _compact else body_bottom - body_y))
	_place(_shop, Rect2(work_x, content_y, work_w, content_h))
	_place(_enchant_scroll, Rect2(work_x, content_y, work_w, content_h))
	workbench.custom_minimum_size.y = 296
	_place(shop_grid, Rect2(0, 0, work_w, maxf(16, content_h if short_window else content_h - 38)))
	_place(_stock, Rect2(144 if short_window else 0, content_h + 8 if short_window else content_h - 30, maxf(40, work_w - 286) if short_window else maxf(40, work_w - 140), 28))
	_place(_refresh, Rect2(0 if short_window else work_w - 136, content_h + 8 if short_window else content_h - 30, 136, 28))
	_place(_feedback, Rect2(20, h - 50, maxf(50, w - 188), 38))
	_feedback.visible = not short_window
	_summary.show()
	_place(start_button, Rect2(w - 154, h - 38 if short_window else h - 50, 134, 30 if short_window else 36))
	var sale_size := Vector2(minf(420, w - 32), minf(360, h - 32))
	_place(_sale_box, Rect2((Vector2(w, h) - sale_size) * 0.5, sale_size))
	if not _compact and _active_tab == "bank": _active_tab = "shop"
	_select_tab(_active_tab)


func _select_tab(tab: String) -> void:
	_active_tab = tab
	_bank.visible = not _compact or tab == "bank"
	_shop.visible = tab == "shop"
	_enchant_scroll.visible = tab == "enchant"
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.visible = key != "bank" or _compact
		FinanceUIStyle.tab(button, key == tab)
	if _tooltip != null: _tooltip.hide()
	if flow != null: flow.clear_stat_preview()


func _refresh_bank() -> void:
	var locked := bool(payload.get("manual_operation_used", false))
	_bank_form.visible = not locked
	_receipt.visible = locked
	if locked:
		var last: Dictionary = payload.get("last_manual_operation", {})
		_receipt.text = "本波已%s %d 金币\n下波可再次办理存取。" % ["存入" if str(last.get("action", "")) == "deposit" else "取出", int(last.get("amount", 0))]
	_choose_bank_action(_bank_action)
	_contract.text = "每波只能存或取一次。\n买卖与附魔不受此限制。"
	if bool(payload.get("requires_deposit_for_interest", false)):
		_contract.text = "存款契约：%d / %d\n%s" % [int(payload.get("wave_start_deposit_amount", 0)), int(payload.get("deposit_requirement", 0)), "已满足本波结息条件" if bool(payload.get("has_deposited_before_current_wave", false)) else "本波存入达到要求后才可结息"]


func _choose_bank_action(action: String) -> void:
	_bank_action = action
	FinanceUIStyle.button(_deposit, action == "deposit")
	FinanceUIStyle.button(_withdraw, action == "withdraw")
	bank_confirm.text = "确认存入" if action == "deposit" else "确认取出"
	_withdraw.disabled = int(payload.get("principal", 0)) <= 0
	_update_bank_confirm()


func _bank_amount_error() -> String:
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


func _submit_bank() -> void:
	if flow == null: return
	var error := _bank_amount_error()
	if not error.is_empty():
		show_error(error)
		return
	var result := flow.submit_finance_operation(_bank_action, amount_input.text.strip_edges().to_int())
	if bool(result.get("success", false)):
		portrait.react(_bank_action, int(result.get("amount", 0)), int(result.get("source_balance_before", 0)))
		_feedback_message("存取已完成。仍可购买、出售和配置附魔。", true)
	else: show_error(str(result.get("reason", "")))


func _buy(offer: Dictionary) -> void:
	if flow == null: return
	var result := flow.submit_shop_purchase(offer, "shop")
	if bool(result.get("success", false)): _feedback_message("已购买：" + str(offer.get("display_name", "")), true)
	else: show_error(str(result.get("reason", "")))


func _refresh_shop() -> void:
	if flow == null: return
	var result := flow.request_shop_refresh()
	if bool(result.get("success", false)): _feedback_message("货架已刷新。", true)
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
	if bool(result.get("success", false)): _feedback_message("已出售，获得 %d 金币。" % int(result.get("gold_gained", 0)), true)
	else: show_error(str(result.get("reason", "")))


func _show_tooltip(content: String) -> void:
	if _sale_layer.visible: return
	_tooltip_text.text = content
	var tooltip_size := Vector2(minf(310, main_panel.size.x - 24), minf(240, main_panel.size.y - 24))
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
	var control := Label.new()
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
