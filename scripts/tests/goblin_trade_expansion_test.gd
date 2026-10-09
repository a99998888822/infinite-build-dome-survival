extends Node
## Real game/finance UI; only starting inventory, telemetry and offer pool are fixtures.

var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var popup: FinancePopup
var definitions: Array
var attached_id := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	get_tree().create_timer(180).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func fixture(id: String, candle := false) -> Dictionary:
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	flow.current_wave_index = -1
	if manager != null: manager.goblin_trades.config.trades = definitions
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "fixture starts real combat: " + id)
	await frames(6)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.current_wave_index = 5
	flow.current_wave_index = 5
	manager.goblin_trades.config.trades = definitions
	manager.goblin_trades._rng.seed = 10082026
	manager.wave_challenges.sample_health(8, manager.player.current_hp, int(manager.player.get_stat("max_hp")))
	manager.apply_gold_delta(-manager.current_gold, "fixture")
	if id == "exclusive_relic":
		manager.apply_gold_delta(900, "fixture")
		manager.goblin_trades.low_health_episodes = 3
	if id == "weapon_buyout":
		check(flow._bound_loadout.equip_weapon("weapon_plasma_cannon"), "second weapon equipped")
		var item := manager.player.item_inventory.add_item_from_base("scroll_fire", "fixture")
		attached_id = str(item.item_instance_id)
		check(flow._bound_loadout.attach_item_to_weapon("weapon_plasma_cannon", attached_id), "main weapon has an actual attached item")
		manager._on_enemy_damage_received("weapon_plasma_cannon", 900)
		manager._on_enemy_damage_received("weapon_void_blade", 100)
	if id == "sanity_buyback":
		manager.player.add_relic("relic_coin_heart")
		manager.player.add_relic("relic_hoarders_ring")
		manager.finance_system.deposit(10000, true, "fixture")
		GoblinTradeSystem.apply_stat(manager.player, "fixture_sanity", "humanity", -40 - manager.player.get_stat("humanity"))
		if candle: manager.player.add_relic("relic_reincarnation_hellfire_candle")
	flow.finish_current_wave()
	await frames(18)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	popup._select_tab("shop")
	# Pick the scenario under review from the real eligible pool. This is only
	# a review fixture; gameplay preparation never resets its prepared-wave guard.
	for attempt in 64:
		if str(manager.goblin_trades.offer.get("id", "")) == id: break
		manager.goblin_trades.preparation_wave = -1
		flow._prepare_goblin_trade()
	popup.configure(flow.get_preparation_payload())
	await frames(8)
	var offer := manager.goblin_trades.offer.duplicate(true)
	check(str(offer.get("id", "")) == id, "production preparation selects eligible offer: " + id)
	if not offer.is_empty():
		popup.trade_presentation.set_process(false)
		popup.trade_presentation.sound_enabled = false
		popup.trade_presentation.seek(4.0)
	return offer


func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await frames(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(6)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "GPU capture " + name)


func capture_sizes(name: String) -> void:
	await capture(name)
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames(12)
	var presentation := popup.trade_presentation
	check(presentation._body_scroll.size.y > 0 and presentation._yes.get_global_rect().end.y <= 360, "compact scroll and accept button remain reachable: " + name)
	await capture(name + "_small")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(12)


func hover_relic() -> void:
	# Locate the inline image, then let real pointer input open the native tooltip.
	var terms := popup.trade_presentation._relic_body
	var rect := terms.get_global_rect()
	for y in range(int(rect.position.y + 4), int(rect.end.y), 8):
		for x in range(int(rect.position.x + 4), int(rect.end.x), 8):
			if terms.get_tooltip(Vector2(x, y) - rect.position).is_empty(): continue
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(x, y)
			get_viewport().push_input(motion, true)
			await get_tree().create_timer(0.8).timeout
			await frames(5)
			return


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	flow = game.get_main_flow_coordinator()
	definitions = GoblinTradeSystem.new().config.trades.duplicate(true)
	_test_candidates()
	await _test_exclusive()
	await _test_buyout()
	await _test_sanity()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	game.queue_free()
	await frames(4)
	print("GOBLIN_EXPANSION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_candidates() -> void:
	var trades := GoblinTradeSystem.new()
	var c := {"wave": 6, "has_next_wave": true, "gold": 149, "principal": 0, "sanity": 50,
		"high_pressure": true, "shelf_median": 50, "epic_candidates": [{"target_id": "fixture"}]}
	check(not trades.eligible_offers(c).any(func(x): return x.id == "exclusive_relic"), "exclusive requires enough disposable gold")
	c.gold = 150
	check(trades.eligible_offers(c).any(func(x): return x.id == "exclusive_relic"), "exclusive accepts pressure and threshold boundary")
	c.shelf_median = 60
	check(not trades.eligible_offers(c).any(func(x): return x.id == "exclusive_relic"), "wealth threshold scales with actual shelf prices")
	c.gold = 0
	c.comfortable = true
	c.weapon_quotes = [{"amount": 100}]
	check(trades.eligible_offers(c).any(func(x): return x.id == "weapon_buyout"), "buyout is eligible after six completed waves")
	c.wave = 5
	check(not trades.eligible_offers(c).any(func(x): return x.id == "weapon_buyout"), "buyout cannot appear at five completed waves")
	c.wave = 6
	trades.accepted_waves.weapon_buyout = 1
	check(trades.eligible_offers(c).any(func(x): return x.id == "weapon_buyout"), "weapon buyout can return in the same run")
	c.gold = 299
	check(trades.eligible_offers(c).any(func(x): return x.id == "weapon_buyout"), "wave six allows buyout below 300 gold")
	c.gold = 300
	check(not trades.eligible_offers(c).any(func(x): return x.id == "weapon_buyout"), "buyout gold threshold is strictly less than completed waves times 50")
	c.wave = 7
	check(trades.eligible_offers(c).any(func(x): return x.id == "weapon_buyout"), "buyout threshold scales on the following completed wave")
	c = {"wave": 7, "has_next_wave": true, "sanity": 0, "principal": 2000, "interest_loss": 100, "interest_loss_ratio": 0.01, "sanity_quote": {"cost": 400, "gain": 50}}
	trades.accepted_waves.sanity_buyback = 6
	check(trades.eligible_offers(c).any(func(x): return x.id == "sanity_buyback"), "sanity buyback repeats and ignores lost-interest percentage")
	c.interest_loss = 99
	check(not trades.eligible_offers(c).any(func(x): return x.id == "sanity_buyback"), "sanity buyback retains absolute interest loss threshold")
	c = {"wave": 7, "has_next_wave": true, "gold": 200, "high_pressure": true, "epic_candidates": [{"target_id": "fixture"}]}
	trades.accepted_waves.exclusive_relic = 6
	check(not trades.eligible_offers(c).any(func(x): return x.id == "exclusive_relic"), "exclusive relic remains limited to one acceptance per run")
	c = {"wave": 2, "has_next_wave": true, "gold": 150, "principal": 250, "sanity": 100, "struggling": true, "can_bank": true, "epic_available": true}
	var candidates := trades.eligible_offers(c)
	check(candidates.size() == 5, "ordinary and crisis offers all enter one pool")
	var counts := {}
	for i in 1000:
		trades.preparation_wave = -1
		trades.prepare(c)
		var id := str(trades.offer.id)
		counts[id] = int(counts.get(id, 0)) + 1
	check(counts.size() == 5 and counts.values().all(func(x): return x > 120 and x < 280), "all five eligible offers sampled at uniform frequency")


func _test_exclusive() -> void:
	var offer := await fixture("exclusive_relic")
	if offer.is_empty(): return
	check(str(offer.body) == "立即免费获得这件随机史诗遗物[icon]，并将商店栏位削减成1个", "exclusive copy matches approved sentence exactly")
	flow._prepare_goblin_trade()
	check(manager.goblin_trades.offer == offer, "reopening preparation retains the exact relic and quote")
	await capture_sizes("01_exclusive_offer")
	await hover_relic()
	var tip := popup.trade_presentation._relic_body.active_tooltip
	check(is_instance_valid(tip) and tip.is_visible_in_tree() and (tip.get_child(0) as Label).text.contains(L10n.source(offer.relic.display_name)), "actual inline icon hover shows this relic's tooltip")
	check(not manager.goblin_trades.offer.is_empty(), "inspection does not cancel the trade")
	await capture("02_exclusive_tooltip")
	var leave := InputEventMouseMotion.new()
	leave.position = Vector2(600, 200)
	get_viewport().push_input(leave, true)
	await frames(3)
	check(not is_instance_valid(tip) or not tip.is_visible_in_tree(), "leaving the inline icon closes its tooltip")
	var removed_offer: Dictionary = flow._preparation_offers[1].duplicate(true)
	var retained_id := str(flow._preparation_offers[0].offer_id)
	var count := manager.player.get_relic_count(str(offer.relic.target_id))
	await click(popup.trade_presentation._yes)
	check(manager.player.get_relic_count(str(offer.relic.target_id)) == count + 1, "pointer acceptance grants the displayed relic")
	check(flow._preparation_offers.size() == 1 and str(flow._preparation_offers[0].offer_id) == retained_id and popup.shop_grid.offers.size() == 1, "current shelf immediately retains only its leftmost item")
	check(not flow.submit_shop_purchase(removed_offer, "shop").success, "removed shelf IDs cannot be bought through stale callbacks")
	check(not flow.accept_goblin_trade(str(offer.token)).success, "repeated acceptance cannot grant another relic")
	await capture("03_exclusive_accepted")
	manager.goblin_trades.strong_refresh = true
	check(flow.request_shop_refresh().success and flow._preparation_offers.size() == 1 and flow._preparation_offers[0].rarity == "epic" and flow._preparation_offers[0].offer_type == "relic", "strong refresh supplies exactly one guaranteed epic relic")
	await capture("04_single_slot_strong_refresh")
	check(flow.request_shop_refresh().success and flow._preparation_offers.size() == 1, "ordinary refresh remains one slot")
	flow.close_finance_popup()
	if flow.current_state == flow.STATE_WAVE_CHALLENGE:
		flow.return_from_wave_challenge()
		check(popup.shop_grid.offers.size() == 1, "returning from challenge does not restore slots")
		flow.close_finance_popup()
		flow.decide_wave_challenge(str(manager.wave_challenges.offer.token), false)
	manager.set_process(false)
	flow.request_shared_reward_shop_popup(2, "test")
	check(flow.current_state == flow.STATE_SHARED_REWARD_SHOP_POPUP and flow._active_shop_offers.size() >= 3, "free reward choices retain their normal slots")
	flow.close_shared_reward_shop_popup()
	flow.finish_current_wave()
	await frames(18)
	check(flow._preparation_offers.size() >= 3, "next preparation restores the normal shelf")
	offer = await fixture("exclusive_relic")
	if offer.is_empty(): return
	check(flow.request_shop_refresh().success and manager.goblin_trades.offer.is_empty(), "successful shop operation cancels the unaccepted exclusive offer")


func _test_buyout() -> void:
	var offer := await fixture("weapon_buyout")
	if offer.is_empty(): return
	check(str(offer.weapon_id) == "weapon_plasma_cannon" and int(offer.amount) > 0, "highest damage weapon and positive bundle price are selected")
	var service := InventoryTradeService.new()
	var weapon := flow._bound_loadout.get_weapon_instance(str(offer.weapon_id))
	var normal := int(service.quote_weapon(weapon, manager.player.get_stat("humanity")).total)
	normal += int(service.quote_item(manager.player.item_inventory.find_item(attached_id), manager.player.get_stat("humanity")).total)
	check(int(offer.amount) == normal * 10, "quote is ten times weapon plus enchantment resale value")
	await capture_sizes("05_weapon_buyout_offer")
	var gold := manager.current_gold
	await click(popup.trade_presentation._yes)
	check(manager.current_gold == gold + int(offer.amount) and not flow._bound_loadout.has_weapon(str(offer.weapon_id)), "acceptance pays once and removes main weapon")
	check(manager.player.item_inventory.find_item(attached_id).is_empty(), "sold enchantment does not return to backpack")
	check(flow._bound_loadout.get_weapon_instances().size() == 1 and not flow.accept_goblin_trade(str(offer.token)).success, "backup weapon remains and repeated payment is rejected")
	await capture("06_weapon_buyout_accepted")
	offer = await fixture("weapon_buyout")
	if offer.is_empty(): return
	check(flow.submit_enchantment_operation("detach", str(offer.weapon_id), attached_id).success, "actual attachment editing succeeds")
	check(manager.goblin_trades.offer.is_empty() and not flow.accept_goblin_trade(str(offer.token)).success, "editing target enchantments expires the fixed quote")
	check(flow.submit_enchantment_operation("attach", str(offer.weapon_id), attached_id).success and manager.goblin_trades.offer.is_empty(), "restoring the attachment cannot resurrect an expired offer")
	offer = await fixture("weapon_buyout")
	if offer.is_empty(): return
	check(not flow._bound_loadout.request_manual_detachment(str(offer.weapon_id), attached_id).is_empty(), "weapon strip direct attachment operation succeeds")
	check(manager.goblin_trades.offer.is_empty(), "weapon strip signals also expire the quote")


func _test_sanity() -> void:
	for candle in [false, true]:
		var offer := await fixture("sanity_buyback", candle)
		if offer.is_empty(): continue
		var before := manager.player.get_stat("humanity")
		var principal := manager.finance_system.principal
		var hp := manager.player.get_stat("max_hp")
		var manual := manager.finance_system.manual_operation_used
		var quoted: Dictionary = offer.sanity_quote
		print("SANITY_QUOTE candle=", candle, " before=", before, " quote=", quoted)
		check(int(quoted.cost) == ceili(principal * 0.2) and float(quoted.gain) > 0, "sanity quote charges a dynamic share of capital")
		# The ring returns 8 sanity when 10000 principal becomes 8000, unless blocked.
		check(is_equal_approx(before, -40) and is_equal_approx(float(quoted.recovery), 45 if candle else 41) and is_equal_approx(float(quoted.gain), 45 if candle else 49), "only paid recovery is halved; principal-derived sanity follows existing relic rules")
		var expected_after := before + float(quoted.gain)
		check(before == manager.player.get_stat("humanity") and principal == manager.finance_system.principal, "read-only quote does not change real sanity or capital")
		if candle: await capture_sizes("07_sanity_offer_with_candle")
		await click(popup.trade_presentation._yes)
		check(is_equal_approx(manager.player.get_stat("humanity"), expected_after) and is_equal_approx(expected_after, 5 if candle else 9), "halved paid restoration reaches exact quoted sanity, candle=" + str(candle))
		check(manager.finance_system.principal == principal - int(quoted.cost) and manager.player.get_stat("max_hp") < hp, "capital cost refreshes principal-derived combat attributes")
		check(manager.finance_system.manual_operation_used == manual, "paid sanity does not spend a manual banking action")
		manager.finance_system._emit_changed()
		check(is_equal_approx(manager.player.get_stat("humanity"), expected_after) and not flow.accept_goblin_trade(str(offer.token)).success, "attribute rebuild preserves purchased sanity and cannot pay twice")
		if candle:
			GoblinTradeSystem.apply_stat(manager.player, "ordinary_recovery", "humanity", 10)
			check(is_equal_approx(manager.player.get_stat("humanity"), expected_after), "candle continues blocking ordinary recovery after this exception")
			popup._select_tab("bank")
			await capture("08_sanity_accepted_with_candle")
		# Keep the actual first purchase modifier: a second payment must add to it.
		GoblinTradeSystem.apply_stat(manager.player, "second_wave_sanity_loss", "humanity", -100)
		var trades := manager.goblin_trades
		var second_before := manager.player.get_stat("humanity")
		var second_principal := manager.finance_system.principal
		var second_quote := GoblinSpecialTrades.sanity_quote(manager.player, manager.finance_system, trades.definition("sanity_buyback"))
		print("SANITY_REPEAT candle=", candle, " before=", second_before, " quote=", second_quote)
		check(is_equal_approx(second_before, -95 if candle else -91) and is_equal_approx(float(second_quote.recovery), 72.5 if candle else 66.5) and is_equal_approx(float(second_quote.gain), 72 if candle else 74), "repeat purchase retains fractional modifiers and existing integer-sanity rounding")
		check(is_equal_approx(manager.player.get_stat("humanity"), second_before), "repeat sanity preview does not mutate the first purchase")
		trades.prepare({"wave": trades.preparation_wave + 1, "has_next_wave": true, "sanity": second_before, "principal": second_principal, "interest_loss": 100, "sanity_quote": second_quote})
		check(str(trades.offer.get("id", "")) == "sanity_buyback", "second low-sanity wave can offer another purchase")
		var second_token := str(trades.offer.get("token", ""))
		var second_result := trades.accept(second_token, manager.player, manager.finance_system, flow._bound_loadout)
		check(bool(second_result.success) and is_equal_approx(manager.player.get_stat("humanity"), -23 if candle else -17) and is_equal_approx(manager.player.get_stat("humanity") - second_before, float(second_quote.gain)), "second purchase matches quoted net gain without replacing the first, candle=" + str(candle))
		check(manager.finance_system.principal == second_principal - int(second_quote.cost) and not trades.accept(second_token, manager.player, manager.finance_system, flow._bound_loadout).success, "repeat purchase deducts only its locked cost once")
