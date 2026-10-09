extends Node

var checks := 0
var failures := 0
var flow: MainFlowCoordinator
var manager: WaveManager
var popup: FinancePopup
var capture_dir := ""


func _ready() -> void:
	L10n.set_locale("zh_CN", false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)


func frames(count: int = 4) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	_test_rules()
	await _test_live_flow()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await get_tree().create_timer(0.3).timeout
	print("GOBLIN_TRADE_COMPLETE checks=%d failures=%d" % [checks, failures])
	await frames()
	get_tree().quit(1 if failures else 0)


func _test_rules() -> void:
	var trades := GoblinTradeSystem.new()
	check(trades.reward_amounts(3, 150) == {"principal": 160, "gold": 100}, "early reward example")
	check(trades.reward_amounts(10, 400) == {"principal": 280, "gold": 160}, "middle reward example")
	check(trades.reward_amounts(18, 1000) == {"principal": 420, "gold": 250}, "late reward example")
	check(trades.reward_amounts(18, 1000000) == trades.reward_amounts(18, 1000), "high income cannot exceed wave cap")
	var bounded := true
	for wave in range(1, 21):
		for income in [0, 50, 200, 1000, 100000]:
			var r := trades.reward_amounts(wave, income)
			bounded = bounded and r.gold < r.principal and r.principal <= 150 + 15 * wave and r.gold >= 100
	check(bounded, "cash is smaller than principal throughout the run")
	trades.sample_enemies(3, 100)
	check(trades.finish_combat(100).struggling, "large surviving crowd triggers pressure")
	trades.sample_enemies(3, 0)
	check(not trades.finish_combat(100).struggling, "old crowd outside the rolling window is ignored")
	trades.sample_enemies(0.1, 100)
	check(not trades.finish_combat(100).struggling, "last-frame spawn spike is not a full crowd window")
	trades.begin_combat()
	trades.record_damage(10, 4, 10)
	trades.record_damage(4, 3, 10)
	trades.record_health(5, 10)
	trades.record_damage(5, 4, 10)
	check(trades.low_health_episodes == 1, "remaining under half and tiny heals do not farm episodes")
	for i in 2:
		trades.record_health(6, 10)
		trades.record_damage(6, 4, 10)
	check(trades.finish_combat(100).struggling, "three distinct low-health episodes trigger pressure without a crowd")
	var c := {"wave": 3, "earned": 150, "has_next_wave": true, "gold": 100, "principal": 500, "sanity": 120, "struggling": true, "principal_relic": true}
	var candidates := trades.eligible_offers(c)
	check(candidates.size() == 4 and candidates.any(func(x): return x.id == "interest_pact"), "all eligible ordinary and crisis offers share the pool")
	check(candidates.any(func(x): return x.id == "principal_advance"), "principal relics preserve advance eligibility")
	c.gold = 1
	c.principal = 3
	check(trades.eligible_offers(c).size() == 2, "tiny deposit excludes ratio offers while retaining advance and interest")
	c.struggling = false
	c.gold = 300
	c.principal = 0
	check(trades.eligible_offers(c).size() == 2, "high sanity and spendable wealth can both qualify")
	c.sanity = 100
	check(trades.eligible_offers(c).size() == 2, "starting sanity qualifies for ordinary interest offers")
	c.sanity = 64
	trades.prepare(c)
	check(trades.offer.id == "spending_money", "lower sanity still allows eligible spending money")
	var token := str(trades.offer.token)
	c.gold = 1000
	trades.prepare(c)
	check(trades.offer.token == token, "reopening cannot reroll the offer")
	trades.cancel()
	trades.prepare(c)
	check(trades.offer.is_empty(), "cancelled offer cannot return this preparation")
	trades.accepted_waves.spending_money = 3
	c.wave = 5
	check(trades.eligible_offers(c).is_empty(), "same offer skips two following preparations")
	c.wave = 6
	check(trades.eligible_offers(c).size() == 1, "offer returns after cooldown")
	for id in ["principal_advance", "cash_price", "spending_money"]:
		var cooling := GoblinTradeSystem.new()
		cooling.accepted_waves[id] = 5
		var visit := {"wave": 6, "has_next_wave": true, "gold": 100, "principal": 150, "sanity": 0, "struggling": true}
		for wave in [6, 7, 8]:
			visit.wave = wave
			check(cooling.eligible_offers(visit).any(func(x): return x.id == id) == (wave == 8), "two-visit cooldown boundary " + id + " wave=" + str(wave))
	c.has_next_wave = false
	check(trades.eligible_offers(c).is_empty(), "no deal after the final wave")
	var empty_roll := ShopOfferGenerator.new().roll_paid_offers({"common": 100}, {"relic": 100}, [], 3, 1, [], "epic")
	check(empty_roll.is_empty(), "missing eligible epic fails instead of promising a false guarantee")
	var guaranteed_pool := [{"offer_id": "relic:relic_guarding_heart_copper_mirror", "offer_type": "relic", "target_id": "relic_guarding_heart_copper_mirror", "rarity": "epic"}]
	var guaranteed_roll := ShopOfferGenerator.new().roll_paid_offers({"epic": 0}, {"relic": 100}, guaranteed_pool, 3, 1, [], "epic")
	check(guaranteed_roll.size() == 1 and guaranteed_roll[0].rarity == "epic", "guarantee overrides luck gate but retains stock eligibility")
	_test_broader_eligibility()


func _test_broader_eligibility() -> void:
	var trades := GoblinTradeSystem.new()
	var c := {"wave": 1, "has_next_wave": true, "gold": 0, "principal": 500, "sanity": 100, "struggling": false}
	check(trades.eligible_offers(c).any(func(x): return x.id == "interest_pact"), "ordinary saver with empty wallet qualifies at starting sanity")
	c.sanity = 65
	check(trades.eligible_offers(c).size() == 1, "interest pact qualifies at the new 65 sanity boundary")
	c.sanity = 64
	check(trades.eligible_offers(c).is_empty(), "sanity below 65 cannot offer an interest pact")
	c.gold = 50
	c.principal = 100
	check(trades.eligible_offers(c).any(func(x): return x.id == "spending_money"), "50 wallet and 100 principal qualify for spending money")
	c.principal = 101
	check(trades.eligible_offers(c).is_empty(), "spending money respects its expanded principal ratio")
	c.principal = 0
	c.gold = 49
	check(trades.eligible_offers(c).is_empty(), "spending money still requires 50 gold")
	c.gold = 50
	c.can_bank = false
	check(trades.eligible_offers(c).is_empty(), "expanded spending offer still requires usable banking")
	c.can_bank = true
	c.struggling = true
	check(trades.eligible_offers(c).any(func(x): return x.id == "strong_refresh"), "50 gold can now qualify for strong refresh")
	c.epic_available = false
	check(not trades.eligible_offers(c).any(func(x): return x.id == "strong_refresh"), "expanded strong refresh still requires an epic candidate")
	c.gold = 60
	c.principal = 100
	check(trades.eligible_offers(c).any(func(x): return x.id == "cash_price"), "100 principal and 60 wallet qualify for cash trade")
	c.principal = 99
	check(not trades.eligible_offers(c).any(func(x): return x.id == "cash_price"), "cash trade retains its minimum principal boundary")
	c.principal = 100
	c.gold = 67
	check(not trades.eligible_offers(c).any(func(x): return x.id == "cash_price"), "cash trade retains its 1.5 principal ratio boundary")
	trades.record_damage(10, 4, 10)
	var pressure := trades.finish_combat(100)
	check(pressure.trade_struggling and not pressure.struggling, "one low-health episode enables trades without changing challenge pressure")
	var challenges := WaveChallengeSystem.new()
	challenges.finish_combat(pressure)
	check(not challenges.pressure.struggling, "wave challenges retain their own pressure behavior")
	trades.begin_combat()
	trades.sample_enemies(3, 19)
	check(not trades.finish_combat(100).trade_struggling, "crowd below 20 percent does not trigger trades")
	trades.sample_enemies(3, 20)
	pressure = trades.finish_combat(100)
	check(pressure.trade_struggling and not pressure.struggling, "20 percent crowd enables trades before challenge pressure")
	trades.begin_combat()
	trades.sample_enemies(3, 7)
	check(not trades.finish_combat(10).trade_struggling, "small difficulty still requires at least eight enemies")
	trades.sample_enemies(3, 8)
	check(trades.finish_combat(10).trade_struggling, "eight enemies qualify at the minimum crowd threshold")


func offer_only(id: String) -> Dictionary:
	var trades := manager.goblin_trades
	var definitions: Array = trades.config.trades
	trades.config.trades = [trades.definition(id)]
	trades.preparation_wave = -1
	trades.prepare({"wave": flow.current_wave_index + 1, "earned": manager.collected_gold_this_wave, "has_next_wave": true,
		"gold": manager.current_gold, "principal": manager.finance_system.principal, "sanity": manager.player.get_stat("humanity"), "struggling": true})
	trades.config.trades = definitions
	popup.configure(flow.get_preparation_payload())
	popup.interest_arrival.skip()
	if popup.trade_presentation != null:
		popup.trade_presentation.sound_enabled = false
		popup.trade_presentation.seek(20)
	return trades.offer.duplicate(true)


func advance_preparation() -> void:
	flow.close_finance_popup()
	if flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
		flow.decide_wave_challenge(str(flow._bound_wave_manager.wave_challenges.offer.token), false)
	manager.set_process(false)
	flow.finish_current_wave()
	await frames(12)
	popup.interest_arrival.skip()


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(5)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func capture_offer(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	var presentation := popup.trade_presentation
	# Freeze a real animation frame with both the spoken line and terms visible.
	presentation.set_process(false)
	presentation.seek(4.7)
	await capture(name)
	presentation.seek(20)
	presentation.set_process(true)


func capture_refresh_animation() -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	var directory := capture_dir.path_join("refresh_frames")
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 48:
		popup._process(0.1)
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(directory.path_join("%03d.png" % frame))


func check_offer_layout(has_detail: bool, name: String) -> void:
	await frames(6)
	var trade := popup.trade_presentation
	check(trade._detail.visible == has_detail, name + " shows supplementary text only when present")
	check(trade._body_scroll.get_rect().end.y <= trade._yes.position.y - 5 and trade._yes.get_rect().end.y <= trade._card.size.y, name + " keeps readable terms separate from action buttons")
	if has_detail:
		check(absf(trade._detail.position.y - trade._body.get_rect().end.y - 8) < 1, name + " keeps white and green text eight pixels apart")
	if not popup._compact:
		check(trade._body_scroll.size.y >= trade._terms.size.y and trade._body_scroll.size.y - trade._terms.size.y < 3, name + " fits complete text without unused vertical space")


func _test_live_flow() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start live game")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(260, "test")
	for i in 3:
		manager.player.restore_full_health()
		# Cross half health even after the player's base health was rebalanced.
		manager.player.take_damage(ceili(manager.player.get_stat("max_hp") * 0.6), "enemy_test")
	check(manager.goblin_trades.low_health_episodes == 3, "actual health damage signal records three episodes")
	flow.finish_current_wave()
	await frames(12)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	check(not manager.goblin_trades.offer.is_empty() and popup.trade_presentation.is_active(), "combat telemetry automatically opens a live trade")
	check(manager.goblin_trades.pressure_snapshot.struggling, "wave-end healing does not erase pressure snapshot")
	var pending_token := str(manager.goblin_trades.offer.token)
	manager.apply_gold_delta(-manager.current_gold, "test")
	check(not flow.request_shop_refresh().success and str(manager.goblin_trades.offer.token) == pending_token, "failed refresh retains the live offer token")
	manager.apply_gold_delta(260, "test")
	check(flow.request_shop_refresh().success and manager.goblin_trades.offer.is_empty() and not popup.trade_presentation.is_active(), "successful refresh cancels the live offer and its UI")
	check(not flow.accept_goblin_trade(pending_token).success, "offer cancelled by refresh cannot be accepted with a stale token")
	manager.apply_gold_delta(260 - manager.current_gold, "test")
	var offer := offer_only("strong_refresh")
	check(offer.body == "存入 260 金币，获得 1 次免费的强力刷新", "all-in offer displays the requested concrete amount and free refresh")
	await check_offer_layout(true, "strong refresh")
	var detailed_card_height := popup.trade_presentation._card.size.y
	await capture_offer("01_deposit_offer")
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await check_offer_layout(true, "small strong refresh")
	await capture_offer("01_small_deposit_offer")
	popup.trade_presentation._body_scroll.scroll_vertical = 1000
	await frames()
	var detail_rect := popup.trade_presentation._detail.get_global_rect()
	var scroll_rect := popup.trade_presentation._body_scroll.get_global_rect()
	check(detail_rect.intersects(scroll_rect) and detail_rect.end.y <= scroll_rect.end.y + 1, "small window can scroll to the full epic guarantee")
	await capture_offer("01_small_deposit_scrolled")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(8)
	popup.trade_presentation.seek(0)
	check(not popup.trade_presentation._yes.disabled, "can accept before goblin finishes speaking")
	popup.trade_presentation._yes.pressed.emit()
	check(manager.current_gold == 0 and manager.finance_system.principal == 260, "accept deposits instead of destroying the gold")
	check(manager.finance_system.manual_operation_used and flow.has_strong_refresh(), "deposit consumes bank allowance and awards persistent refresh")
	check(not popup.trade_presentation.is_active(), "accepted card releases its layout space")
	check(not flow.accept_goblin_trade(str(offer.token)).success, "cannot accept the same offer twice")
	check(not flow.submit_finance_operation("withdraw", 10).success, "cannot withdraw during the accepting preparation")
	check(popup._refresh.tr(popup._refresh.text) == "强力刷新 · 免费" and not popup._refresh.disabled, "free colorful refresh is usable with zero gold")
	await capture("02_refresh_ready")
	await capture_refresh_animation()
	flow.close_finance_popup()
	if flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
		flow.decide_wave_challenge(str(flow._bound_wave_manager.wave_challenges.offer.token), false)
	manager.apply_gold_delta(50, "test")
	flow.request_shared_reward_shop_popup(2, "test")
	var reward_refresh := flow.request_shop_refresh()
	check(reward_refresh.success and reward_refresh.cost > 0 and flow.has_strong_refresh(), "free reward shop cannot consume the finance refresh token")
	flow.close_shared_reward_shop_popup()
	flow.finish_current_wave()
	await frames(12)
	check(flow.has_strong_refresh() and not manager.finance_system.manual_operation_used, "next automatic shelf preserves refresh and restores banking")
	check(manager.finance_system.principal == 260, "next wave never automatically refunds the deposit")
	check(flow.submit_finance_operation("withdraw", 100).success and manager.finance_system.principal == 160, "player can manually withdraw next preparation")
	check(flow.has_strong_refresh(), "ordinary banking cannot cancel earned refresh")
	var loadout := flow._bound_loadout
	flow._bound_loadout = null
	var gold_before := manager.current_gold
	check(not flow.request_shop_refresh().success and flow.has_strong_refresh() and manager.current_gold == gold_before, "unavailable epic retains token and gold")
	flow._bound_loadout = loadout
	GoblinTradeSystem.apply_stat(manager.player, "test", "luck", -250)
	var luck_before := manager.player.get_stat("luck")
	var refreshed := flow.request_shop_refresh()
	check(refreshed.success and refreshed.cost == 0 and not flow.has_strong_refresh(), "manual paid-shop refresh consumes token once for free")
	check(flow._preparation_offers.any(func(x): return x.offer_type == "relic" and x.rarity == "epic"), "purple RELIC guaranteed with zero effective luck")
	check(manager.current_gold == gold_before and manager.player.get_stat("luck") == luck_before, "bonus luck is temporary and wallet remains unchanged")
	manager.player.remove_runtime_modifiers_by_source("goblin_trade", "test")
	await capture("03_epic_guarantee")
	await advance_preparation()
	manager.finance_system.deposit(1000, true, "test")
	manager.current_gold = 20
	GoblinTradeSystem.apply_stat(manager.player, "income_test", "currency_gain_percent", 200)
	offer = offer_only("cash_price")
	var sanity := manager.player.get_stat("humanity")
	var luck := manager.player.get_stat("luck")
	check(offer.body == "金币 + %d，本次关闭银行，理智-5，幸运-2" % int(offer.amount), "cash offer displays the revised terms")
	await check_offer_layout(false, "cash price")
	await capture_offer("04_cash_offer")
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames(8)
	await check_offer_layout(false, "small cash price")
	await capture_offer("04_small_cash_offer")
	check(popup.portrait.is_visible_in_tree() and popup.trade_presentation._body_scroll.size.y > 0, "small window retains banker and scrollable long terms")
	popup.trade_presentation._yes.pressed.emit()
	check(manager.current_gold == 20 + int(offer.amount) and manager.collected_gold_this_wave == 0, "cash gift ignores combat income and currency multipliers")
	var luck_cost := manager.player.modifier_stack.get_all_modifiers("luck").any(func(x): return x.id == "goblin_cash_price_luck" and x.value == -2)
	check(manager.player.get_stat("humanity") == sanity - 5 and manager.player.get_stat("luck") == maxf(0, luck - 2) and luck_cost, "cash deal retains revised costs even when effective luck hits its existing zero floor")
	check(not manager.finance_system.deposit(1).success and not manager.finance_system.withdraw(1).success, "bank restriction blocks direct APIs too")
	check(not popup._bank_form.visible and popup._receipt.tr(popup._receipt.text).contains("关闭"), "locked bank explains its restriction")
	popup._select_tab("bank")
	await capture("05_small_bank_locked")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(8)
	await capture("05_cash_accepted")
	popup._select_tab("shop")
	await advance_preparation()
	check(not manager.finance_system.trade_deposit_blocked and not manager.finance_system.trade_withdraw_blocked, "bank restrictions expire on next preparation")
	check(manager.player.get_stat("humanity") == sanity - 5 and manager.player.modifier_stack.get_all_modifiers("luck").any(func(x): return x.id == "goblin_cash_price_luck" and x.value == -2), "cash stat costs remain after the bank reopens")
	manager.finance_system.withdraw(manager.finance_system.principal)
	manager.current_gold = 300
	offer = offer_only("spending_money")
	await check_offer_layout(false, "spending money")
	await capture_offer("06_spending_offer")
	popup.trade_presentation._yes.pressed.emit()
	check(manager.current_gold == 400 and popup._deposit.disabled, "spending gift credits exactly 100 and greys deposit")
	await capture("07_spending_accepted")
	manager.finance_system.deposit(20, true, "test")
	check(manager.finance_system.withdraw(20).success and not manager.finance_system.deposit(1).success, "spending deal allows withdrawals and automatic gifts")
	await advance_preparation()
	GoblinTradeSystem.apply_stat(manager.player, "sanity_test", "humanity", 120 - manager.player.get_stat("humanity"))
	var rate := manager.finance_system.get_interest_rate()
	offer = offer_only("interest_pact")
	await check_offer_layout(false, "interest pact")
	await capture_offer("08_interest_offer")
	popup.trade_presentation._yes.pressed.emit()
	check(manager.goblin_trades.interest_pact and is_equal_approx(manager.finance_system.get_interest_rate(), rate + 3), "interest deal adds three percentage points")
	check(manager.player.get_stat("humanity") == 120, "contract has no immediate sanity debit")
	await capture("09_interest_accepted")
	await advance_preparation()
	check(manager.player.get_stat("humanity") == 119 and manager.finance_system.principal == 0, "wave end debits sanity even without principal")
	if not capture_dir.is_empty(): popup.economy_log.set_open(true)
	await capture("10_interest_next_wave")
	popup.economy_log.set_open(false)
	manager.goblin_trades.settle_wave(manager.current_wave_index + 1, manager.player, manager.finance_system)
	check(manager.player.get_stat("humanity") == 119, "same wave cannot debit the contract twice")
	offer = offer_only("interest_pact")
	check(not offer.is_empty(), "high sanity permits another pact next preparation")
	popup.trade_presentation._yes.pressed.emit()
	check(manager.goblin_trades.interest_pact_count == 2 and is_equal_approx(manager.finance_system.get_interest_rate(), rate + 6), "second pact stacks the interest bonus")
	check(manager.player.get_stat("humanity") == 119 and manager.goblin_trades.interest_sanity_paid == 1, "another pact preserves already paid sanity and has no immediate debit")
	check(popup._summary.tooltip_text.is_empty() and int(popup.payload.get("interest_pact_terms", {}).get("count", 0)) == 2, "stacked contracts retain live terms without a finance summary tooltip")
	check(not flow.accept_goblin_trade(str(offer.token)).success and manager.goblin_trades.interest_pact_count == 2, "repeated callback cannot accept the second pact again")
	await capture("10_interest_stacked")
	await advance_preparation()
	check(manager.player.get_stat("humanity") == 117 and manager.goblin_trades.interest_sanity_paid == 3, "two contracts debit two sanity on the following wave")
	manager.goblin_trades.settle_wave(manager.current_wave_index + 1, manager.player, manager.finance_system)
	check(manager.player.get_stat("humanity") == 117, "stacked contracts still settle only once per wave")
	manager.player.add_relic("relic_guarding_heart_copper_mirror")
	await advance_preparation()
	check(manager.player.get_stat("humanity") == 116, "sanity regeneration offsets one of the two ongoing costs")
	manager.player.add_relic("relic_high_yield_contract")
	manager.player.add_relic("relic_coin_heart")
	offer = offer_only("principal_advance")
	await check_offer_layout(false, "principal advance")
	check(popup.trade_presentation._card.size.y < detailed_card_height, "short trade shrinks its card compared to detailed refresh terms")
	await capture_offer("11_principal_offer")
	var before_principal := manager.finance_system.principal
	var before_hp := manager.player.get_stat("max_hp")
	var before_wave := manager.current_wave_index
	var reentry := {"blocked": false}
	var on_closed := func(state: String):
		if state == MainFlowCoordinator.STATE_FINANCE_POPUP:
			reentry.blocked = not flow.submit_finance_operation("deposit", 1).success and not flow.submit_enchantment_operation("detach", "weapon_void_blade", "missing").success
	flow.modal_closed.connect(on_closed)
	popup.trade_presentation._yes.pressed.emit()
	flow.modal_closed.disconnect(on_closed)
	check(manager.finance_system.principal == before_principal + int(offer.amount), "advance credits dynamically calculated principal")
	check(manager.player.get_stat("max_hp") == before_hp + floorf(float(manager.finance_system.principal) / 100) - floorf(float(before_principal) / 100), "principal gift immediately updates principal-backed combat stats")
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and manager.current_wave_index == before_wave + 1, "advance directly starts the next wave")
	check(reentry.blocked and not popup.visible, "no intermediate opportunity to bank or adjust enchantments")
	check(not manager.finance_system.has_deposited_before_current_wave, "gift principal is not a qualifying manual deposit")
	check(manager.economy_journal.entries.any(func(x): return x.kind == "goblin_trade"), "journal records accepted deals and ongoing cost")
	await capture("12_principal_battle")
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection() and not manager.goblin_trades.interest_pact and manager.goblin_trades.accepted_waves.is_empty(), "new run clears contracts tokens offers and cooldowns")
	game.queue_free()
	await frames()
