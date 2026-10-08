extends Node
## Real preparation entry, scene frame alignment, and rendered trade interaction.

var checks := 0
var failures := 0
var capture_dir := ""
var popup: FinancePopup
var flow: MainFlowCoordinator
var manager: WaveManager


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	get_tree().create_timer(75).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)


func frames(count: int = 8) -> void:
	for i in count: await get_tree().process_frame


func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start live run")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(20 - manager.current_gold, "test")
	flow.finish_current_wave()
	await frames(12)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	check(str(manager.goblin_trades.offer.get("id", "")) == "interest_pact", "starting sanity with only 20 gold opens a live interest offer")
	check(popup.trade_presentation != null and popup.trade_presentation.is_active(), "offer reaches the scene UI")
	await capture("entry")
	popup.interest_arrival.skip()
	for i in 3:
		manager.goblin_loans.record_attempt(manager.finance_system, manager.run_statistics)
	flow.dismiss_goblin_loan()
	await frames()
	check(popup.loan_presentation._strip.is_visible_in_tree(), "actual loan quote exposes the loan strip")
	if popup.trade_presentation != null:
		popup.trade_presentation.sound_enabled = false
		popup.trade_presentation.seek(20)
		check(popup.trade_presentation._card.is_visible_in_tree(), "live trade remains visible after receipt and loan close")
	for resolution in [Vector2i(1152, 648), Vector2i(1536, 864), Vector2i(1000, 540)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		await frames(12)
		await verify_scene(str(resolution.x))
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	await frames()
	var hud := game.find_child("HUD", true, false) as BattleHud
	hud._set_drawer_open(true, false)
	await frames(12)
	await verify_scene("drawer")
	hud._set_drawer_open(false, false)
	popup.economy_log.set_open(false)
	await frames()
	await verify_scene("drawer_closed")
	if popup.trade_presentation != null:
		var button := popup.trade_presentation._no
		var point := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		get_viewport().push_input(motion, true)
		await frames()
		var hovered := get_viewport().gui_get_hovered_control()
		print("TRADE_HOVER ", hovered.get_path() if hovered != null else "none", " button=", button.get_global_rect())
		check(hovered == button, "trade button is reachable by pointer in the real scene")
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = point
			get_viewport().push_input(click, true)
			await frames(2)
		check(manager.goblin_trades.offer.is_empty() and not popup.trade_presentation.is_active(), "pointer rejection closes the actual offer")
	check(popup._summary.tooltip_text.is_empty(), "finance summary has no hover tooltip")
	for card in popup.shop_grid._pool:
		check(card.buy_button.tooltip_text.is_empty(), "purchase buttons have no hover tooltip")
	await verify_tooltips(hud)
	for resolution in [Vector2i(1152, 648), Vector2i(1536, 864), Vector2i(1000, 540)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		await frames(12)
		var actual_waist := popup.portrait.position + BankCounterPortrait.WAIST_CONTACT * (popup.portrait.size.x / 128.0)
		check(absf(actual_waist.y - 356.0 * resolution.y / 648.0) < 1.0, "portrait waist follows the wooden tabletop at " + str(resolution))
		await capture("counter_%d" % resolution.x)
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	await frames(12)
	for i in 3:
		await next_preparation(80)
		check(not manager.goblin_trades.offer.is_empty() and popup.trade_presentation._card.is_visible_in_tree(), "healthy 80-gold preparation %d now has a live ordinary trade" % i)
		popup.trade_presentation._no.pressed.emit()
	manager.finance_system.deposit(160, true, "test")
	await next_preparation(80)
	check(str(manager.goblin_trades.offer.get("id", "")) in ["spending_money", "interest_pact"] and popup.trade_presentation._card.is_visible_in_tree(), "80 gold and 160 principal still allow ordinary trades")
	await capture("saver_trade")
	popup.trade_presentation._no.pressed.emit()
	await next_preparation(20, true)
	check(manager.goblin_trades.pressure_snapshot.trade_struggling and not manager.goblin_trades.pressure_snapshot.struggling, "one actual low-health episode qualifies for a trade independently of challenge pressure")
	check(str(manager.goblin_trades.offer.get("id", "")) in ["principal_advance", "cash_price", "interest_pact"] and popup.trade_presentation._card.is_visible_in_tree(), "pressure and ordinary trades share the eligible live pool")
	await capture("crisis_trade")
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	print("FINANCE_SCENE_REGRESSION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func verify_tooltips(hud: BattleHud) -> void:
	for index in 8:
		manager.player.item_inventory.add_item_from_base("scroll_lightning", "tooltip_test")
	popup.workbench.refresh()
	popup._select_tab("enchant")
	hud._set_drawer_open(true, false)
	await frames(12)
	var card := popup.workbench._inventory.get_child(0) as EnchantmentInventoryCard
	for entry in popup.workbench._inventory.get_children():
		if entry is EnchantmentInventoryCard and entry._inspect.get_global_rect().get_center().x > card._inspect.get_global_rect().get_center().x:
			card = entry
	popup._enchant_scroll.ensure_control_visible(card)
	await frames()
	var point := card._inspect.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await frames()
	print("TOOLTIP_HOVER point=", point, " hovered=", get_viewport().gui_get_hovered_control(), " card=", card.get_global_rect())
	check(get_viewport().gui_get_hovered_control() == card._inspect, "actual enchantment magnifier remains reachable with drawer open")
	check(popup._tooltip.is_visible_in_tree() and not popup._tooltip_text.text.is_empty(), "real magnifier hover displays enchantment details")
	var tooltip_layer := popup._tooltip.get_parent() as GameTooltipLayer
	check(tooltip_layer != null and tooltip_layer.layer > hud.layer, "enchantment tooltip renders above the attribute drawer CanvasLayer")
	check(get_viewport().get_visible_rect().encloses(popup._tooltip.get_global_rect()), "enchantment tooltip stays within the viewport")
	var tooltip_rect := popup._tooltip.get_global_rect()
	var expected_x := point.x + 14 if point.x + 14 + tooltip_rect.size.x <= get_viewport().get_visible_rect().size.x - 12 else point.x - tooltip_rect.size.x - 14
	var expected_y := clampf(point.y + 14, 12, get_viewport().get_visible_rect().size.y - tooltip_rect.size.y - 12)
	print("TOOLTIP_LAYOUT pointer_event=", popup._tooltip_mouse_position, " rect=", tooltip_rect, " expected=", Vector2(expected_x, expected_y))
	check(absf(tooltip_rect.position.x - expected_x) < 1 and absf(tooltip_rect.position.y - expected_y) < 1, "tooltip stays next to the magnifier after final text layout, flipping only at viewport edges")
	check(popup._tooltip.modulate.a == 1, "tooltip appears after its wrapping width and height settle")
	await capture("enchantment_tooltip_drawer")
	popup.main_panel.hide()
	check(not tooltip_layer.visible and not popup._tooltip.visible, "hiding source panel immediately dismisses its tooltip")
	popup.main_panel.show()
	check(tooltip_layer.visible and not popup._tooltip.visible, "reopening source panel does not resurrect stale tooltip")
	popup._show_tooltip(card._build_tooltip())
	var finance_layer := popup.get_canvas_layer_node()
	finance_layer.hide()
	check(not tooltip_layer.visible and not popup._tooltip.visible, "hiding ancestor CanvasLayer dismisses nested tooltip layer")
	finance_layer.show()
	check(tooltip_layer.visible and not popup._tooltip.visible, "restoring ancestor layer keeps stale tooltip dismissed")
	var anchor: Control = hud._stat_name_labels["armor"]
	hud._show_stat_tooltip(anchor, "armor")
	await frames()
	check(hud._stat_tooltip_panel != null and hud._stat_tooltip_panel.get_parent() is GameTooltipLayer, "attribute explanations use the same foreground tooltip layer")
	await capture("attribute_tooltip")
	hud._hide_stat_tooltip()
	popup._show_tooltip(card._build_tooltip())
	flow.request_battle_utility("settings")
	await frames()
	check(not tooltip_layer.visible and not popup._tooltip.visible, "opening settings dismisses finance tooltips")
	flow.close_battle_utility()
	await frames()
	check(not popup._tooltip.visible, "returning from settings has no stale finance tooltip")
	popup._select_tab("shop")
	hud._set_drawer_open(false, false)
	await frames()


func next_preparation(gold: int, struggling: bool = false) -> void:
	flow.close_finance_popup()
	if flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
		flow.decide_wave_challenge(str(manager.wave_challenges.offer.token), false)
	manager.set_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(gold - manager.current_gold, "test")
	if struggling:
		manager.player.restore_full_health()
		# Cross the low-health threshold even when character health is rebalanced.
		manager.player.take_damage(ceili(manager.player.get_stat("max_hp") * 0.6), "enemy_test")
	flow.finish_current_wave()
	await frames(12)
	popup.interest_arrival.skip()
	await frames()


func verify_scene(label: String) -> void:
	var bank := popup._scene_bank_back.get_global_rect()
	var footer := popup._scene_footer_back.get_global_rect()
	var loan := popup.loan_presentation._strip.get_global_rect()
	popup.economy_log.set_open(true)
	await frames()
	var log_rect := popup.economy_log.panel.get_global_rect()
	print("FRAME_RECTS ", label, " bank=", bank, " footer=", footer, " loan=", loan, " log=", log_rect)
	check(absf(bank.position.x - footer.position.x) < 1, label + " bank and footer outer edges align")
	check(absf(bank.position.x - loan.position.x) < 1, label + " bank and loan outer edges align")
	check(absf(bank.position.x - log_rect.position.x) < 1, label + " bank and expanded log outer edges align")
	check(absf(footer.end.x - loan.end.x) < 1, label + " footer and loan right edges align")
	await capture(label + "_log")
	popup.economy_log.set_open(false)
	await frames()
	if popup.trade_presentation != null:
		var card := popup.trade_presentation._card.get_global_rect()
		check(get_viewport().get_visible_rect().encloses(card) and card.end.y <= bank.position.y, label + " live trade fits above banking form")
	await capture(label + "_trade")
