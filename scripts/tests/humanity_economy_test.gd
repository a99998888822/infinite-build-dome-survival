extends Node

var failures := 0
var checks := 0
var capture_dir := ""


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count: int = 5) -> void:
	for _i in count: await get_tree().process_frame


func set_stat(player: PlayerController, stat: String, value: float) -> void:
	player.add_runtime_modifier({"id": "economy_test_" + stat, "source_type": "test", "source_id": "economy_test", "stat": stat, "target_scope": "player", "operation": "override", "value": value, "duration": -1, "priority": 1000, "stack_rule": "replace_same_source"})


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))


func _run() -> void:
	CampProgression.begin_transient_session()
	for humanity in [150.0, 100.0, 50.0, 0.0, -100.0, -300.0]:
		var m := HumanityEconomy.get_multipliers(humanity)
		check(float(m.purchase) >= 1 and float(m.sale) > 0 and float(m.interest) > 0, "valid economics at " + str(humanity))
	check(HumanityEconomy.get_multipliers(150) == HumanityEconomy.get_multipliers(100), "above 100 preserves original economics")
	var fifty := HumanityEconomy.get_multipliers(50)
	check(is_equal_approx(float(fifty.purchase), 1.1), "50 sanity purchase +10 percent")
	check(is_equal_approx(float(fifty.sale), 1.0 / 1.1), "50 sanity sale -9.09 percent")
	check(is_equal_approx(float(fifty.interest), 2.0 / 3.0), "50 sanity interest -33.33 percent")
	check(HumanityEconomy.describe(50) == "理智 50：购买价格 +10%，出售收益 −9.1%，利息收益 −33.3%。", "requested Chinese hover text")
	check(float(HumanityEconomy.get_multipliers(-300).interest) < float(HumanityEconomy.get_multipliers(-100).interest), "negative sanity keeps worsening")
	var offer := {"shop_price_basis": 19.3, "shop_cost": 20}
	HumanityEconomy.reprice_offer(offer, 50)
	check(offer.shop_cost == 22 and offer.shop_cost_without_humanity == 20, "purchase rounds once after all multipliers")
	HumanityEconomy.reprice_offer(offer, 50)
	check(offer.shop_cost == 22, "refresh does not compound surcharge")
	HumanityEconomy.reprice_offer(offer, 100)
	check(offer.shop_cost == 20, "recovery restores neutral price")
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var window := get_tree().root
	window.gui_embed_subwindows = true
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1152, 648)
	window.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	var start: Array[String] = ["weapon_void_blade"]
	flow.enter_battle_selection("character_void_hunter", start)
	await frames()
	check(flow.confirm_character_selection(), "start actual game")
	await frames()
	var player := flow.get_bound_player()
	var hud := game.find_child("HUD", true, false) as BattleHud
	var manager := hud._wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(2000, "test")
	flow.finish_current_wave()
	await frames(15)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	check(flow.current_state == flow.STATE_FINANCE_POPUP, "actual preparation phase")
	var generation := int(flow.get_preparation_payload().offer_generation)
	var ids: Array = popup.shop_grid.offers.map(func(entry): return str(entry.offer_id))
	set_stat(player, "humanity", 50)
	await frames(8)
	check(int(flow.get_preparation_payload().offer_generation) == generation, "sanity change retains generation")
	check(popup.shop_grid.offers.map(func(entry): return str(entry.offer_id)) == ids, "sanity change retains shelf identities")
	check(popup._economy.text == HumanityEconomy.describe(50), "finance text reflects actual sanity")
	hud._refresh_stats_drawer()
	var sanity_label: Label = hud._stat_name_labels.get("humanity")
	check(sanity_label.tooltip_text.contains(HumanityEconomy.describe(50)), "attribute hover has live economic text")
	for entry in popup.shop_grid.offers:
		check(int(entry.shop_cost) == ceili(float(entry.shop_price_basis) * 1.1), "actual shelf uses live prices")
	var stale_offer: Dictionary = popup.shop_grid.offers[0].duplicate(true)
	set_stat(player, "humanity", -100)
	await frames()
	var before_gold := manager.get_current_gold()
	var stale_result := flow.submit_shop_purchase(stale_offer, "shop")
	check(not bool(stale_result.success) and stale_result.reason == "shop_price_changed", "stale purchase rejected")
	check(manager.get_current_gold() == before_gold, "rejected quote does not charge")
	set_stat(player, "humanity", 50)
	await frames()
	flow.get_bound_loadout().try_buy_weapon("weapon_plasma_cannon")
	var quote := flow.get_inventory_sale_quote("weapon", "weapon_plasma_cannon")
	check(int(quote.total) == floori(float(quote.total_without_humanity) / 1.1), "weapon sale uses sanity")
	set_stat(player, "humanity", 0)
	await frames()
	check(not bool(flow.submit_inventory_sale("weapon", "weapon_plasma_cannon", str(quote.quote_token)).success), "stale sale quote rejected")
	var finance := manager.finance_system
	set_stat(player, "humanity", 50)
	set_stat(player, "interest_rate", 10)
	finance.principal = 600
	finance.interest_remainder = 0
	check(finance.get_estimated_interest() == 40, "600 principal and 10 percent predicts 40")
	var settlement := finance.settle_interest()
	check(settlement.gain == 40 and settlement.nominal_gain == 60 and is_equal_approx(float(settlement.humanity_loss), 20), "actual payout and explanation match")
	check(finance.principal == 640, "net payout enters principal")
	set_stat(player, "humanity", -100)
	var accumulated := 0
	finance.interest_remainder = 0
	for _i in 3:
		finance.principal = 1
		accumulated += int(finance.settle_interest().gain)
	check(accumulated == 1 and finance.interest_remainder < 0.000001, "fractional payouts accumulate instead of rounding away penalty")
	set_stat(player, "humanity", 150)
	finance.principal = 1
	check(finance.settle_interest().gain == 1, "normal sanity retains original ceil payout")
	set_stat(player, "humanity", 50)
	finance.principal = 500
	finance.prepare_wave(3)
	for id in ["relic_steel_vault", "relic_quant_trading", "relic_hostile_takeover", "relic_merger_reorg"]:
		player.add_relic(id)
	await frames()
	var rng_state := finance._rng.state
	var original_principal := finance.principal
	var preview := flow.get_bank_stat_preview("withdraw", 100)
	check(preview.contains("500 → 400") and preview.contains("护甲"), "withdrawal exposes lost principal attributes")
	check(finance.principal == original_principal and finance._rng.state == rng_state and not finance.manual_operation_used, "preview does not mutate principal RNG or operation allowance")
	popup.configure(flow.get_preparation_payload())
	popup._choose_bank_action("withdraw")
	popup.amount_input.text = "100"
	popup.amount_input.text_changed.emit("100")
	await frames()
	check(popup._bank_preview.visible and popup._bank_preview.text.contains("500 → 400"), "withdrawal preview appears in bank")
	check(popup._summary.tooltip_text.contains("理智损耗"), "interest value explains reduction")
	await capture("01_finance_humanity_50")
	if not capture_dir.is_empty():
		hud._set_drawer_open(true, false)
		hud.stats_scroll.ensure_control_visible(sanity_label)
		await frames(8)
		var motion := InputEventMouseMotion.new()
		motion.position = sanity_label.get_global_rect().get_center()
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		await get_tree().create_timer(0.9).timeout
		await capture("04_humanity_hover")
		motion = InputEventMouseMotion.new()
		motion.position = Vector2(4, 4)
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		await frames()
	popup._select_tab("enchant")
	popup._open_sale("weapon", "weapon_plasma_cannon")
	check(popup._sale_text.text.contains("理智损耗"), "sale dialog explains reduction")
	await capture("02_sale_humanity_50")
	popup._sale_layer.hide()
	popup._select_tab("shop")
	for dimensions in [Vector2i(960, 540), Vector2i(640, 360)]:
		window.size = dimensions
		window.content_scale_size = dimensions
		await frames(15)
		popup._select_tab("bank")
		check(popup._bank.visible and popup._economy.visible, "compact bank preserves sanity explanation " + str(dimensions))
		check(popup.start_button.get_global_rect().end.y <= window.size.y, "next wave button fits " + str(dimensions))
		popup._bank.ensure_control_visible(popup.bank_confirm)
		await frames()
		check(popup._bank.get_global_rect().encloses(popup.bank_confirm.get_global_rect()), "bank confirmation remains reachable " + str(dimensions))
		await capture("03_bank_" + str(dimensions.x))
	var item := player.item_inventory.add_item_from_base("scroll_fire", "test")
	var item_id := str(item.get("item_instance_id", ""))
	var item_quote := flow.get_inventory_sale_quote("enchantment", item_id)
	check(int(item_quote.total) == floori(float(item_quote.total_without_humanity) / 1.1), "enchantment quote applies sanity reduction")
	before_gold = manager.get_current_gold()
	var item_sale := flow.submit_inventory_sale("enchantment", item_id, str(item_quote.quote_token))
	check(bool(item_sale.success) and manager.get_current_gold() == before_gold + int(item_quote.total), "enchantment sale pays the displayed reduced amount")
	check(player.item_inventory.find_item(item_id).is_empty(), "successful sale removes exactly the sold enchantment")
	# Select a known candidate so a random relic's on-acquire gold cannot mask payment.
	var candidates := ShopOfferGenerator.new().build_shop_candidate_pool(flow._build_shop_context())
	var test_purchase: Dictionary = {}
	for candidate in candidates:
		if str(candidate.get("target_id", "")) == "relic_amulet_of_humanity":
			test_purchase = candidate
			break
	check(not test_purchase.is_empty(), "sanity-price purchase candidate exists")
	if not test_purchase.is_empty():
		test_purchase["offer_id"] = "economy_purchase_test"
		flow._active_shop_offers[test_purchase.offer_id] = test_purchase
		before_gold = manager.get_current_gold()
		var relic_count := player.get_relic_count("relic_amulet_of_humanity")
		var paid_cost := int(test_purchase.shop_cost)
		var bought := flow.submit_shop_purchase(test_purchase, "shop")
		check(bool(bought.success) and manager.get_current_gold() == before_gold - paid_cost, "successful purchase charges the sanity-adjusted price")
		check(player.get_relic_count("relic_amulet_of_humanity") == relic_count + 1, "paid purchase delivers its relic")
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("HUMANITY_ECONOMY_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(failures)
