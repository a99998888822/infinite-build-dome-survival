extends RefCounted
class_name FinanceSceneLayout
## The approved 1152x648 composition, with live content and drawer-safe bounds.


static func supports(size: Vector2) -> bool:
	return size.x >= 1000 and size.y >= 540


static func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


static func arrange(ui) -> void:
	var viewport: Vector2 = ui.get_viewport_rect().size
	var sx := viewport.x / 1152.0
	var sy := viewport.y / 648.0
	var work_x := 378 * sx
	var right := minf(viewport.x - 36, ui._safe_rect.end.x)
	var work_w := maxf(260, right - work_x)
	var loan_space: float = ui.loan_presentation.reserved_height()
	var footer_y := viewport.y - 48 - loan_space
	var content_bottom := footer_y - 26
	place(ui.main_panel, Rect2(Vector2.ZERO, viewport))
	ui._compact = false
	ui._bank_header.hide()
	var actor_size := Vector2.ONE * 259.2 * 0.9 * minf(sx, sy)
	var hand := Vector2(187 * sx, 367.75 * sy)
	place(ui.portrait, Rect2(hand - BankCounterPortrait.HAND_CONTACT * (actor_size.x / 128.0), actor_size))
	ui.portrait.show()
	ui._title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui._title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FinanceUIStyle.label(ui._title, 24, Color("eee0b4"))
	ui._title.add_theme_color_override("font_shadow_color", Color("343428"))
	ui._title.add_theme_constant_override("shadow_offset_x", 2)
	ui._title.add_theme_constant_override("shadow_offset_y", 2)
	place(ui._title, Rect2(558 * sx, 75 * sy, 274 * sx, 46 * sy))
	place(ui._scene_summary_back, Rect2(work_x, 158 * sy, work_w + 6, 32))
	place(ui._summary, Rect2(work_x + 14, 158 * sy, work_w - 22, 32))
	FinanceUIStyle.label(ui._summary, 12, FinanceUIStyle.GOLD)
	ui._summary.show()
	place(ui._tabs, Rect2(work_x, 200 * sy, work_w, 30))
	var content_y := 200 * sy + 38
	var content_h := maxf(80, content_bottom - content_y)
	place(ui._enchant_scroll, Rect2(work_x + 12, content_y + 16, work_w - 18, maxf(24, content_h - 20)))
	ui.workbench.custom_minimum_size.y = 276
	place(ui._scene_enchant_back, Rect2(work_x, content_y + 4, work_w + 6, content_h + 4))
	place(ui._shop, Rect2(work_x, content_y + 4, work_w, content_h - 6))
	place(ui.shop_grid, Rect2(0, 0, work_w, maxf(40, content_h - 60)))
	# Keep the stock count on the painted front rim, clear of the loan footer.
	var stock_y := minf(531 * sy - 14, footer_y - 36)
	place(ui._stock, Rect2(0, roundf(stock_y) - ui._shop.position.y, work_w - 140, 28))
	ui._stock.show()
	place(ui._refresh, Rect2(work_w - 136, content_h - 44, 136, 30))
	# All left-column frames share one pixel-aligned edge at every resolution.
	var bank_x := roundf(34 * sx)
	var bank_w := 306 * sx
	var bank_y := 382 * sy
	var body: Control = ui._bank.get_child(0)
	var bank_h := minf(maxf(154, body.get_combined_minimum_size().y + 20), footer_y - bank_y - 10)
	place(ui._scene_bank_back, Rect2(bank_x, bank_y, bank_w, bank_h))
	place(ui._bank, Rect2(bank_x + 12, bank_y + 10, bank_w - 24, maxf(24, bank_h - 20)))
	place(ui._scene_footer_back, Rect2(bank_x, footer_y, right - bank_x, 40))
	var feedback_x := bank_x + 76
	place(ui._feedback, Rect2(feedback_x, footer_y + 8, maxf(100, right - feedback_x - 158), 24))
	ui._feedback.show()
	place(ui.start_button, Rect2(right - 150, footer_y + 6, 144, 28))
	place(ui.economy_log, Rect2(Vector2.ZERO, viewport))
	ui.economy_log.apply_finance_layout(Rect2(bank_x, 214 * sy, right - bank_x, footer_y - 220 * sy), Rect2(bank_x + 6, footer_y + 6, 56, 28))
	# A temporary trade sits above the form. Its scrollable terms and choices
	# never displace the banking or next-wave controls below the counter.
	if ui.trade_presentation != null and ui.trade_presentation.is_active():
		var height: float = minf(ui.trade_presentation.get_preferred_height(bank_w), bank_y - 82)
		ui.trade_presentation.arrange(Rect2(bank_x, bank_y - height - 12, bank_w, height), ui.portrait.get_rect(), Rect2(Vector2.ZERO, viewport))
	var sale_size := Vector2(minf(420, right - 48), minf(360, viewport.y - 112))
	place(ui._sale_box, Rect2((viewport - sale_size) * 0.5, sale_size))
	ui.interest_arrival.arrange(viewport, Vector2(88, 56), Rect2(16, 56, viewport.x - 32, viewport.y - 112))
	# The loan presenter insets its strip by 20 on each side of the supplied rect.
	ui.loan_presentation.arrange(Rect2(bank_x - 20, 0, right - bank_x + 40, viewport.y))
	if ui._active_tab == "bank": ui._active_tab = "shop"
	ui._select_tab(ui._active_tab)
