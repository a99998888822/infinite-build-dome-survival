extends Node
## Exercise the PC bank composition with readable phone controls.

var checks := 0
var failures := 0
var popup: FinancePopup
var flow: MainFlowCoordinator
var capture_dir := ""
var resolution := Vector2i(1920, 1080)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()
	get_tree().create_timer(100).timeout.connect(func(): get_tree().quit(99))


func capture(page: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(12)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(image.get_size() == resolution and image.save_png(capture_dir.path_join(page + ".png")) == OK, "capture " + page)


func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + note)


func frames(count: int = 6) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	get_tree().root.borderless = true
	get_tree().root.size = resolution
	MobileProfile.apply_to_window(get_tree().root)
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start live run")
	await frames()
	var manager := flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(20 - manager.current_gold, "test")
	manager.finance_system.deposit(100, true, "test")
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.set_process(false)
	flow.finish_current_wave()
	await frames(14)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.is_visible_in_tree(), "bank popup opens")
	if popup == null:
		_finish()
		return
	await capture("01_arrival")
	check(popup.interest_arrival.is_active(), "real interest receipt opens")
	check(get_viewport().get_visible_rect().encloses(popup.interest_arrival._card.get_global_rect()), "interest receipt fits phone viewport")
	popup.interest_arrival.skip()
	if popup.trade_presentation.is_active():
		check(not popup.trade_presentation._speech.get_global_rect().intersects(popup._tabs.get_global_rect()), "banker speech clears workspace tabs")
	if popup.trade_presentation.is_active(): popup.trade_presentation.seek(20)
	await capture("02_shop_trade")
	popup.cancel_trade("review")

	var viewport := get_tree().root.get_visible_rect()
	var expect_popup := not FinanceSceneLayout.supports(viewport.size)
	check(not expect_popup, "phone retains the PC bank scene composition")
	check(viewport.encloses(popup.get_global_rect()), "popup stays inside the viewport")
	check(popup.scene_background.is_visible_in_tree() and popup.portrait.is_visible_in_tree() and popup._scene_bank_back.is_visible_in_tree(), "PC background counter and bank form restored")
	check(popup._bank.get_global_rect().end.x < popup._shop.get_global_rect().position.x, "bank and workspace stay in separate PC columns")
	check(popup._shop.get_global_rect().end.x < (game.find_child("HUD", true, false) as BattleHud).stats_drawer.global_position.x, "workspace clears stats drawer")
	check(not MobileProfile.is_mobile() or popup.amount_input.get_theme_font_size("font_size") >= 20, "bank amount is readable on phone")
	check(not MobileProfile.is_mobile() or popup.shop_grid._columns == 3, "phone shop displays three columns")

	# Every interactive anchor has to be on screen and tappable.
	for control in [popup.start_button, popup._tabs, popup.shop_grid, popup._refresh]:
		var button := control as Control
		check(button != null and button.is_visible_in_tree(), "control visible: " + ("start" if button == null else str(button.name)))
		if button != null:
			check(viewport.encloses(button.get_global_rect()), "control inside the viewport: " + str(button.name))

	# A phone has no room for text that overflows its own panel.
	var clipped: Array[String] = []
	for node in popup.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.is_visible_in_tree() or label.text.is_empty():
			continue
		if label.get_combined_minimum_size().x > label.size.x + 1.0:
			clipped.append("%s(%s)" % [label.name, label.text.left(12)])
	check(clipped.is_empty(), "no label overflows its box: " + ", ".join(clipped))
	await capture("03_shop")
	var hud := game.find_child("HUD", true, false) as BattleHud
	check(not hud._finance_economy_back.get_global_rect().intersects(hud.encyclopedia_button.get_global_rect()), "finance balance frame clears ESC button")
	var initial_height := popup.shop_grid._card_height
	for iteration in 6:
		popup.shop_grid.refresh_availability()
		await frames(4)
	check(is_equal_approx(initial_height, popup.shop_grid._card_height) and popup.shop_grid._card_height <= 320, "phone shelf height stays bounded across repeated binds")
	for card in popup.shop_grid._pool:
		if card.visible:
			check(card.size.y <= 320 and card.buy_button.size.y <= 80, "shop card and purchase button remain compact")

	# The enchantment tab shares the popup; its workbench has to fit as well.
	popup._select_tab("enchant")
	for i in 12: flow.get_bound_player().item_inventory.add_item_from_base("scroll_lightning", "mobile_review")
	popup.workbench.refresh()
	await frames(8)
	check(popup.workbench.is_visible_in_tree(), "workbench visible on the enchant tab")
	check(viewport.encloses(popup._enchant_scroll.get_global_rect()), "enchantment scroll stays inside the viewport")
	var enchant_clipped := 0
	for node in popup.workbench.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.is_visible_in_tree() or label.text.is_empty():
			continue
		if label.get_combined_minimum_size().x > label.size.x + 1.0:
			enchant_clipped += 1
	check(enchant_clipped == 0, "no workbench label overflows its box (%d)" % enchant_clipped)
	check(not MobileProfile.is_mobile() or EnchantmentInventoryCard.caption_font_size() >= 20, "weapon and enchantment captions enlarged")
	await capture("04_enchant")
	popup._enchant_scroll.scroll_vertical = 100000
	await frames()
	check(popup._enchant_scroll.get_global_rect().encloses(popup.workbench._apply.get_global_rect()), "enchantment actions remain reachable by scrolling")
	await capture("05_enchant_actions")
	popup._select_tab("shop")
	popup.amount_input.text = "5"
	popup.amount_input.text_changed.emit("5")
	var principal_before := manager.finance_system.principal
	popup.bank_confirm.pressed.emit()
	await frames()
	check(manager.finance_system.principal == principal_before + 5, "PC deposit control changes real principal")
	await capture("06_deposit")
	for i in 3: manager.goblin_loans.record_attempt(manager.finance_system, manager.run_statistics)
	popup.configure(flow.get_preparation_payload())
	flow.reopen_goblin_loan()
	await frames()
	check(popup.loan_presentation.is_active(), "PC loan quote still opens")
	check(viewport.encloses(popup.loan_presentation._box.get_global_rect()), "loan quote fits phone viewport")
	await capture("07_loan")
	flow.dismiss_goblin_loan()
	await frames()

	_finish()


func _finish() -> void:
	print("MOBILE_BANK_TEST checks=%d failures=%d mobile=%s" % [checks, failures, MobileProfile.is_mobile()])
	get_tree().quit(1 if failures else 0)
