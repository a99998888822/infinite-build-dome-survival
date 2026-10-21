extends Node
## Production bank shortcuts and purchased-card geometry, with isolated progress.

var checks := 0
var failures := 0
var output := ""
var game: GameRoot
var flow: MainFlowCoordinator
var popup: FinancePopup
var manager: WaveManager

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(99))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func frames(count := 10) -> void:
	for i in count: await get_tree().process_frame

func capture(id: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png(output.path_join(id + ".png"))

func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	seed(20102026)
	get_window().size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames()
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "start production battle")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.player.set_physics_process(false)
	manager.player.add_relic("relic_finance_manager")
	manager.apply_gold_delta(12345, "layout_review")
	flow.finish_current_wave()
	await frames(25)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("layout_review")
	popup._select_tab("shop")
	await frames()
	check(popup.visible, "production finance opens")
	for relic in ["relic_steel_vault", "relic_coin_heart", "relic_golden_rangefinder"]:
		check(manager.player.add_relic(relic), "add principal-dependent preview: " + relic)
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = dimensions
		await frames()
		popup.amount_input.text = ""
		popup._choose_bank_action("deposit")
		await frames()
		var initial := popup._scene_bank_back.get_global_rect()
		await capture("bank_before_all_%d" % dimensions.x)
		for caption in ["1/4", "1/2", "ui.common.all"]:
			var button: Button
			for node in popup._bank_form.find_children("*", "Button", true, false):
				if node.text == caption: button = node
			check(button != null, "bank shortcut exists: " + caption)
			button.pressed.emit()
			await frames()
			check(popup._scene_bank_back.get_global_rect().is_equal_approx(initial), "bank frame remains stable after " + caption + " at " + str(dimensions))
			check(popup._bank_preview.visible, "principal preview remains available")
		check(popup.amount_input.text.to_int() == manager.get_current_gold(), "all selects the available balance")
		check(popup._bank_preview.text.split("\n").size() >= 4, "long preview includes all affected principal stats")
		print("BANK_GEOMETRY before=", initial, " after=", popup._scene_bank_back.get_global_rect(), " form=", popup._bank_form.size)
		await capture("bank_after_all_%d" % dimensions.x)
		popup._bank.ensure_control_visible(popup.bank_confirm)
		await frames()
		check(popup._bank.get_global_rect().grow(1).encloses(popup.bank_confirm.get_global_rect()), "confirmation is reachable inside bank scroll")
		popup.amount_input.text = "999999999999"
		popup._update_bank_confirm()
		await frames()
		check(popup.bank_confirm.disabled and popup._scene_bank_back.get_global_rect().is_equal_approx(initial), "invalid amount cannot resize the bank")
	get_window().size = Vector2i(1920, 1080)
	await frames()
	var relic_offer := {}
	for attempt in 10:
		for offer: Dictionary in popup.shop_grid.offers:
			if offer.offer_type == "relic": relic_offer = offer; break
		if not relic_offer.is_empty(): break
		flow.request_shop_refresh()
		await frames()
	check(not relic_offer.is_empty(), "paid shelf contains a purchasable relic")
	popup._buy(relic_offer)
	await frames()
	check(bool(relic_offer.get("purchased", false)), "real purchase marks the relic bought")
	for locale in ["zh_CN", "en"]:
		L10n.set_locale(locale, false)
		await frames(20)
		for card in popup.shop_grid._pool:
			if not card.visible: continue
			check(card._description.global_position.x - card.global_position.x >= 17, "description has left inset")
			check(card._price.global_position.x - card.global_position.x >= 17, "gold price has left inset")
			check(card.get_global_rect().grow(1).encloses(card.buy_button.get_global_rect()), "purchase button stays in its card")
			if card.buy_button.disabled and bool(card.offer.get("purchased", false)):
				var button := card.buy_button
				var face := button.get_theme_font("font")
				var width := face.get_string_size(button.tr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
				var style := button.get_theme_stylebox("disabled")
				check(button.size.x >= width + style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT), locale + " purchased caption is fully visible")
				check(button.alignment == HORIZONTAL_ALIGNMENT_CENTER and is_equal_approx(style.content_margin_left, style.content_margin_right), locale + " purchased caption has symmetric centering")
		await capture("purchased_card_" + locale)
	L10n.set_locale("zh_CN", false)
	popup.amount_input.text = str(manager.get_current_gold())
	popup._choose_bank_action("deposit")
	await frames()
	var deposited := manager.get_current_gold()
	var bank_rect := popup._scene_bank_back.get_global_rect()
	popup.bank_confirm.pressed.emit()
	await frames()
	check(manager.get_current_gold() == 0 and manager.finance_system.manual_operation_used, "all deposit commits normally")
	check(int(manager.finance_system.last_manual_operation.get("amount", 0)) == deposited, "deposit preserves the selected amount")
	check(popup._receipt.visible and popup._scene_bank_back.get_global_rect().is_equal_approx(bank_rect), "receipt keeps the same bank frame")
	await capture("bank_deposit_receipt")
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("FINANCE_CONTROLS_LAYOUT_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
