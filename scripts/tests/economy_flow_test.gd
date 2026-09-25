extends Node

var checks := 0
var failures := 0
var capture_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count: int = 3) -> void:
	for i in count: await get_tree().process_frame


func make_manager() -> WaveManager:
	var p := PlayerController.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.initialize_from_character("character_void_hunter")
	p.set_physics_process(false)
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(p)
	return manager


func dispose(manager: WaveManager) -> void:
	var p := manager.player
	manager.free()
	p.free()


func journal_contains(manager: WaveManager, text: String) -> bool:
	return manager.economy_journal.entries.any(func(entry): return str(entry.text).contains(text))


func _run() -> void:
	CampProgression.begin_transient_session()
	_test_cash_interest()
	_test_conditions_and_journal()
	_test_pricing()
	await _test_live_ui()
	CampProgression.end_transient_session()
	print("ECONOMY_FLOW_COMPLETE checks=%d failures=%d" % [checks, failures])
	await frames()
	get_tree().quit(1 if failures else 0)


func _test_cash_interest() -> void:
	var m := make_manager()
	var bank := m.finance_system
	m.player.add_relic("relic_coin_heart")
	m.player.add_relic("relic_golden_sarcophagus")
	bank.deposit(999, true)
	var hp := m.player.get_stat("max_hp")
	var before := m.current_gold
	var result := bank.settle_interest()
	check(result.success and result.gain == 50 and m.current_gold == before + 50, "ordinary interest credits gold")
	check(bank.principal == 999 and m.player.get_stat("max_hp") == hp and not bank.get_principal_revive_state().available, "cash payout cannot cross principal health or coffin tiers")
	check(result.destination == "gold" and result.principal_after == 999 and result.gold_after == m.current_gold, "settlement reports destination and balances")
	check(m.collected_gold_this_wave == 0, "interest never counts as combat income")
	m.player.add_relic("relic_compound_interest_tome")
	m.player.add_relic("relic_perpetual_annuity_scroll")
	m.player.add_relic("relic_periodic_dividend_clock")
	bank.begin_wave(1)
	bank.begin_wave(2)
	bank.begin_wave(3)
	before = m.current_gold
	var batch := bank.process_wave_end_settlements()
	check(batch.size() == 3 and batch[0].gain == 60 and batch[1].gain == 62 and batch[2].gain == 64, "extra settlements use unchanged principal and growing rate")
	check(m.current_gold == before + 186 and bank.principal == 999 and is_equal_approx(bank.get_interest_rate(), 6.6), "all three cash payouts still grow the tome")
	check(journal_contains(m, "复利宝典") and journal_contains(m, "有效利率") and journal_contains(m, "永续年金") and journal_contains(m, "周期分红钟"), "journal explains growth and each extra settlement source")
	var preview_player := m.player.create_stat_preview_copy()
	var preview := bank.create_preview_copy(preview_player)
	var entries_before := m.economy_journal.entries.size()
	before = m.current_gold
	preview.settle_interest()
	check(m.current_gold == before and bank.principal == 999 and m.economy_journal.entries.size() == entries_before, "preview settlement cannot credit real wallet or append real logs")
	preview_player.free()
	dispose(m)
	m = make_manager()
	bank = m.finance_system
	bank.deposit(1000, true)
	m.player.add_relic("relic_dividend_check")
	var probe := RandomNumberGenerator.new()
	for seed_value in range(100):
		probe.seed = seed_value
		if probe.randf() < 0.2:
			bank._rng.seed = seed_value
			break
	result = bank.settle_interest()
	check(result.gain == 100 and result.dividend_double_triggered and m.current_gold == 100 and bank.principal == 1000, "double dividend multiplies gold without reinvesting")
	check(journal_contains(m, "2 倍结算"), "journal names the actual dividend multiplier")
	var reentrant := {"reason": ""}
	m.gold_changed.connect(func(_gold): reentrant.reason = bank.settle_interest().reason)
	bank.settle_interest()
	check(reentrant.reason == "settlement_busy", "wallet callbacks cannot double-settle reentrantly")
	dispose(m)
	m = make_manager()
	bank = m.finance_system
	m.player.add_relic("relic_compound_interest_tome")
	bank.deposit(100, true)
	bank.interest_remainder = 0.3
	bank._gold_delta_applier = func(_amount, _reason): return false
	result = bank.settle_interest()
	check(not result.success and result.gain == 0 and bank.principal == 100 and bank.interest_rate_bonus == 0 and is_equal_approx(bank.interest_remainder, 0.3), "failed gold credit preserves principal carry and growth")
	check(journal_contains(m, "金币入账失败"), "failed payout is explained without claiming income")
	dispose(m)


func _test_conditions_and_journal() -> void:
	var m := make_manager()
	var bank := m.finance_system
	bank.settle_interest()
	check(journal_contains(m, "无本金"), "zero-principal settlement has a truthful reason")
	m.player.add_relic("relic_high_yield_contract")
	m.player.add_relic("relic_piggy_bank")
	m.start_next_wave()
	m.running = false
	check(journal_contains(m, "猪猪存钱罐") and journal_contains(m, "仍按原利率结息"), "journal covers principal gifts and unmet contract without blocking ordinary interest")
	m.add_exp_and_gold(0, 450)
	bank.apply_finance_operation("deposit", 200)
	var count := m.economy_journal.entries.size()
	bank.apply_finance_operation("withdraw", 1)
	check(m.economy_journal.entries.size() == count, "failed repeated bank action does not produce a transaction log")
	bank.settle_interest()
	m.apply_gold_delta(-10, "shop_purchase")
	m.apply_gold_delta(10, "weapon_sale")
	check(m.collected_gold_this_wave == 450, "withdrawals sales spending gifts and interest never contaminate wave earnings")
	m.record_wave_income()
	m.record_wave_income()
	check(m.economy_journal.entries.filter(func(entry): return entry.kind == "wave_income").size() == 1 and journal_contains(m, "450 金币"), "one completed-wave summary reports combat earnings")
	check(journal_contains(m, "存入 200 金币") and not journal_contains(m, "购买") and not journal_contains(m, "出售"), "journal records banking and excludes buy/sell actions")
	m.start_next_wave()
	m.running = false
	check(m.collected_gold_this_wave == 0 and m.collected_exp_this_wave == 0, "new wave resets both collection counters")
	bank.apply_finance_operation("withdraw", 50)
	check(journal_contains(m, "取出 50 金币"), "withdrawal is recorded")
	m.add_exp_and_gold(0, 7)
	m.record_wave_income(false)
	check(journal_contains(m, "7 金币（本波未完成）"), "death can retain a partial wave income summary")
	m.player.initialize_from_character("character_void_hunter")
	m.initialize(m.player)
	check(m.economy_journal.entries.size() == 1 and m.economy_journal.entries[0].kind == "initial", "new run clears old journal and retains starting finances")
	for i in 305: m.economy_journal.append({"wave": 1, "kind": "test", "text": str(i)})
	check(m.economy_journal.entries.size() == 300 and m.economy_journal.entries[-1].text == "304", "journal bounds memory while retaining newest events")
	dispose(m)


func _test_pricing() -> void:
	var context := {"shop_wave_number": 10, "paid_purchase_count": 10, "wave_gold_earned": 400, "humanity": 50, "shop_price_discounts": [20]}
	for kind in ["relic", "new_weapon"]:
		var offer := {"offer_type": kind, "shop_base_price": 25}
		ShopPricing.apply(offer, context)
		check(offer.price_breakdown == {"base": 25, "wave": 18, "purchases": 10, "income": 2, "wave_number": 10, "purchase_count": 10, "wave_gold": 400}, "pricing has separate wave purchase and minor income components: " + kind)
		check(offer.shop_cost == 49 and offer.shop_cost_without_humanity == 44, "discount and sanity multiply once after growth: " + kind)
		for i in 3: ShopPricing.apply(offer, context)
		check(offer.shop_cost == 49, "repeated quote refresh never compounds growth: " + kind)
		check(HumanityEconomy.purchase_tooltip(offer).contains("本波收入 2"), "price tooltip exposes income contribution")
	var offer := {"offer_type": "relic", "shop_base_price": 25}
	for earned in [0, 199, 200, 1000000]:
		var raw := {"wave_gold_earned": earned}
		ShopPricing.apply(offer, raw)
		check(offer.shop_cost == 25 + mini(earned / 200, 2), "income fee boundaries and ten-percent cap at " + str(earned))
	offer = {"offer_type": "weapon_upgrade", "shop_base_price": 20}
	ShopPricing.apply(offer, context)
	check(offer.shop_cost == 18 and offer.price_breakdown.wave == 0 and offer.price_breakdown.income == 0 and offer.price_breakdown.purchases == 0, "weapon upgrades retain old basis with ordinary discounts and sanity")


func seed_offers(flow: MainFlowCoordinator, ids: Array[String]) -> Array:
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool(flow._build_shop_context())
	var offers: Array = []
	flow._active_shop_offers.clear()
	flow._active_shop_offer_ids.clear()
	for id in ids:
		for candidate in pool:
			if candidate.target_id == id:
				var offer: Dictionary = candidate.duplicate(true)
				offer.offer_id = "economy_test_" + str(offers.size())
				offers.append(offer)
				flow._active_shop_offers[offer.offer_id] = offer
				flow._active_shop_offer_ids.append(offer.offer_id)
				break
	flow._preparation_offers = offers
	flow._shop_generation += 1
	flow._notify_preparation_changed()
	return offers


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(4)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func _test_live_ui() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	await frames(10)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "actual game starts")
	await frames()
	var hud := game.find_child("HUD", true, false) as BattleHud
	var m := hud._wave_manager
	m.set_process(false)
	m.clear_enemies()
	m.add_exp_and_gold(0, 440)
	m.player.add_relic("relic_piggy_bank")
	m.player.add_relic("relic_high_yield_contract")
	m.finance_system.deposit(1000, true)
	flow.finish_current_wave()
	await frames(15)
	check(flow.submit_finance_operation("deposit", 50).success, "deposit is accepted through the actual preparation flow")
	flow.close_finance_popup()
	await frames()
	m.add_exp_and_gold(0, 220)
	check(m.current_wave_index == 1 and m.finance_system.current_wave_number == 2 and m.finance_system.has_deposited_before_current_wave, "prepared deposit activates contract in the correct wave")
	var log := hud._economy_log
	check(not log.panel.visible and log.toggle_button.is_visible_in_tree(), "bottom-left journal starts collapsed")
	log.toggle_button.pressed.emit()
	await frames()
	check(log.panel.visible and log.log_text.text.contains("利息") and log.log_text.text.contains("存入 50"), "toggle opens real transaction history")
	await capture("01_combat_log")
	flow.finish_current_wave()
	await frames(15)
	check(flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "actual finance screen opens")
	check(flow._build_shop_context().shop_wave_number == 2 and flow._build_shop_context().wave_gold_earned == 220 and m.finance_system.current_wave_number == 3, "preparation prices use the completed wave and its combat earnings")
	var finance := game.find_child("FinancePopup", true, false) as FinancePopup
	log = finance.economy_log
	log.toggle_button.pressed.emit()
	check(log.toggle_button.is_visible_in_tree() and log.panel.is_visible_in_tree() and not hud._economy_log.toggle_button.is_visible_in_tree(), "finance journal replaces the floating HUD journal inside the finance frame")
	var before_count := flow._paid_purchase_count
	var offers := seed_offers(flow, ["relic_worn_hemostatic_cloth", "relic_load_iron_bracer"])
	check(offers.size() == 2, "seed two genuine configured offers")
	var stale: Dictionary = offers[1].duplicate(true)
	var before_log := m.economy_journal.entries.size()
	check(flow.submit_shop_purchase(offers[0].duplicate(true), "shop").success and flow._paid_purchase_count == before_count + 1, "only successful paid acquisition advances purchase counter")
	check(m.economy_journal.entries.size() == before_log, "ordinary relic purchase does not generate a buy/sell log")
	check(offers[1].shop_cost == int(stale.shop_cost) + 1, "remaining shelf reprices after purchase without rerolling")
	var wallet := m.current_gold
	var rejected := flow.submit_shop_purchase(stale, "shop")
	check(not rejected.success and rejected.reason == "shop_price_changed" and m.current_gold == wallet and flow._paid_purchase_count == before_count + 1, "stale quote is rejected without payment or count growth")
	check(flow.submit_shop_purchase(offers[1].duplicate(true), "shop").success, "updated quote can be purchased")
	before_count = flow._paid_purchase_count
	offers = seed_offers(flow, ["weapon_plasma_cannon"])
	check(not offers.is_empty() and flow.submit_shop_purchase(offers[0].duplicate(true), "shop").success and flow._paid_purchase_count == before_count + 1, "new weapon participates in cumulative paid purchase growth")
	before_count = flow._paid_purchase_count
	flow._set_state(MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP)
	offers = seed_offers(flow, ["relic_worn_hemostatic_cloth"])
	check(flow.submit_shop_purchase(offers[0].duplicate(true), "free").success and flow._paid_purchase_count == before_count, "free rewards do not grow paid-purchase prices")
	flow._set_state(MainFlowCoordinator.STATE_FINANCE_POPUP)
	seed_offers(flow, ["relic_flyer_ad", "relic_steel_vault", "relic_dividend_check"])
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 360)]:
		get_tree().root.size = viewport_size
		get_tree().root.content_scale_size = viewport_size
		await frames(6)
		log.set_open(true)
		await frames()
		var bounds := finance.main_panel.get_global_rect()
		check(bounds.encloses(log.panel.get_global_rect()) and bounds.encloses(log.toggle_button.get_global_rect()) and not log.toggle_button.get_global_rect().intersects(finance._refresh.get_global_rect()) and not log.toggle_button.get_global_rect().intersects(finance.start_button.get_global_rect()), "journal fits finance frame and leaves footer controls accessible " + str(viewport_size))
		await capture("02_finance_log_" + str(viewport_size.x))
	log.toggle_button.pressed.emit()
	check(not log.panel.visible, "journal closes without changing finance state")
	await capture("03_collapsed")
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	flow.close_finance_popup()
	m.add_exp_and_gold(0, 37)
	m.player.take_damage(999999, "economy_log_test")
	await frames(6)
	log = hud._economy_log
	log.set_open(true)
	check(flow.current_state == MainFlowCoordinator.STATE_BATTLE_RESULT and log.toggle_button.is_visible_in_tree() and journal_contains(m, "37 金币（本波未完成）"), "death result retains the journal and partial-wave earnings")
	await capture("04_result_log")
	game.queue_free()
	await frames(5)
