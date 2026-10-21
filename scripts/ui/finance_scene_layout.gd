extends RefCounted
class_name FinanceSceneLayout
## Short-scroll bank artwork, with live content and drawer-safe bounds.

const BANK_FORM_HEIGHT := 200.0


static func supports(size: Vector2) -> bool:
	return size.x >= 1000 and size.y >= 540


static func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


static func arrange(ui) -> void:
	var viewport: Vector2 = ui.get_viewport_rect().size
	var sx := viewport.x / 1920.0
	var sy := viewport.y / 1080.0
	var bank_x := roundf(57 * sx)
	var bank_w := 340 * sx
	# Give the bank's former 170 pixels to both workspaces; retain the 80px gap.
	var work_x := roundf(bank_x + bank_w + 80 * sx)
	var right := minf(1580 * sx, minf(viewport.x - 60, ui._safe_rect.end.x))
	var work_w := maxf(260, right - work_x)
	var loan_space: float = ui.loan_presentation.reserved_height()
	var footer_y := viewport.y - 80 - loan_space
	var content_bottom := minf(973 * sy, footer_y - 23)
	place(ui.main_panel, Rect2(Vector2.ZERO, viewport))
	ui._compact = false
	ui._bank_header.hide()
	var actor_size := Vector2.ONE * roundf(388.8 * minf(sx, sy))
	# Align the current portrait's waist with the wooden counter's back edge.
	# Using its body anchor keeps the torso from floating above the tabletop.
	var waist := Vector2(326.666667 * sx, 593.333333 * sy)
	place(ui.portrait, Rect2((waist - BankCounterPortrait.WAIST_CONTACT * (actor_size.x / 128.0)).round(), actor_size))
	ui.portrait.show()
	ui._title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui._title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FinanceUIStyle.label(ui._title, 40, Color("45352d"))
	ui._title.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	ui._title.add_theme_constant_override("shadow_offset_x", 0)
	ui._title.add_theme_constant_override("shadow_offset_y", 0)
	place(ui._title, Rect2(970 * sx, 187 * sy, 383 * sx, 60 * sy))
	ui._summary.hide()
	place(ui._tabs, Rect2(work_x, 353 * sy, work_w, 50))
	var content_y := 353 * sy + 63
	var content_h := maxf(80, content_bottom - content_y)
	place(ui._enchant_scroll, Rect2(work_x + 20, content_y + 20, work_w - 40, maxf(40, content_h - 40)))
	ui.workbench.custom_minimum_size.y = 460
	place(ui._scene_enchant_back, Rect2(work_x, content_y, work_w, content_h))
	place(ui._shop, Rect2(work_x, content_y, work_w, content_h))
	# Keep the stock count on the painted front rim, clear of the loan footer.
	var stock_y := minf(900 * sy, footer_y - 70)
	place(ui.shop_grid, Rect2(0, 0, work_w, maxf(40, stock_y - content_y - 12)))
	place(ui._stock, Rect2(0, roundf(stock_y) - ui._shop.position.y, work_w - 233, 47))
	ui._stock.show()
	place(ui._refresh, Rect2(work_w - 227, stock_y - content_y - 1, 227, 50))
	# All left-column frames share one pixel-aligned edge at every resolution.
	var bank_y := 650 * sy
	# Amount previews can contain many principal-dependent stat changes. Keep
	# the frame stable while the existing scroll container reveals that content.
	var bank_h := minf(BANK_FORM_HEIGHT, maxf(44, footer_y - bank_y - 10))
	place(ui._scene_bank_back, Rect2(bank_x, bank_y, bank_w, bank_h))
	place(ui._bank, Rect2(bank_x + 12, bank_y + 10, bank_w - 24, maxf(24, bank_h - 20)))
	place(ui._scene_footer_back, Rect2(bank_x, footer_y, right - bank_x, 67))
	var feedback_x := bank_x + 127
	place(ui._feedback, Rect2(feedback_x, footer_y + 13, maxf(100, right - feedback_x - 263), 40))
	ui._feedback.show()
	place(ui.start_button, Rect2(right - 250, footer_y + 10, 240, 47))
	place(ui.economy_log, Rect2(Vector2.ZERO, viewport))
	ui.economy_log.apply_finance_layout(Rect2(bank_x, 357 * sy, right - bank_x, footer_y - 367 * sy), Rect2(bank_x + 10, footer_y + 10, 93, 47))
	# A temporary trade sits above the form. Its scrollable terms and choices
	# never displace the banking or next-wave controls below the counter.
	if ui.trade_presentation != null and ui.trade_presentation.is_active():
		var height: float = minf(ui.trade_presentation.get_preferred_height(bank_w), bank_y - 82)
		ui.trade_presentation.arrange(Rect2(bank_x, bank_y - height - 12, bank_w, height), ui.portrait.get_rect(), Rect2(Vector2.ZERO, viewport))
	var sale_size := Vector2(minf(560, right - 48), minf(440, viewport.y - 112))
	place(ui._sale_box, Rect2((viewport - sale_size) * 0.5, sale_size))
	ui.interest_arrival.arrange(viewport, Vector2(88, 56), Rect2(16, 56, viewport.x - 32, viewport.y - 112))
	# The loan presenter insets its strip by 20 on each side of the supplied rect.
	ui.loan_presentation.arrange(Rect2(bank_x - 20, 0, right - bank_x + 40, viewport.y))
	if ui._active_tab == "bank": ui._active_tab = "shop"
	ui._select_tab(ui._active_tab)
