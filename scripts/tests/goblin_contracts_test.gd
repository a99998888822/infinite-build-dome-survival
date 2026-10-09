extends Node
## Uses real finance/challenge screens and combat. Only starting state/pool are fixtures.
var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var bank: FinancePopup
var challenge: WaveChallengePopup


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	get_tree().create_timer(220).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "GPU " + name)


func click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)


func fixture(id: String) -> Dictionary:
	flow.reset_flow()
	await frames(2)
	flow.current_wave_index = -1
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "real run starts " + id)
	await frames(10)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	flow._bound_loadout.set_process(false)
	manager.clear_enemies()
	manager.current_wave_index = 5
	flow.current_wave_index = 5
	var interest := GoblinTradeSystem.new().definition("interest_pact").duplicate(true)
	interest.minimum_sanity = 999999
	manager.goblin_trades.config.trades = [interest]
	manager.wave_challenges.config.challenges = []
	var trade := id in ["preferred_customer", "capital_protection"]
	if trade:
		manager.goblin_trades.config.trades.append(GoblinTradeSystem.new().definition(id))
		manager.apply_gold_delta(900, "fixture")
		manager.finance_system.deposit(5000, true, "fixture")
		manager.goblin_trades.low_health_episodes = 3
		manager.wave_challenges.sample_health(10, 2 if id == "capital_protection" else 10, 10)
	else:
		manager.wave_challenges.config.challenges = [WaveChallengeSystem.new().definition(id)]
		manager.wave_challenges.sample_health(8, 6, 10)
	flow.finish_current_wave()
	await frames(20)
	bank = game.find_child("FinancePopup", true, false) as FinancePopup
	check(flow.current_state == flow.STATE_FINANCE_POPUP, "fixture reaches real finance phase")
	bank.interest_arrival.skip()
	bank._select_tab("shop")
	if not trade:
		if id == "debt_hunter":
			make_debt()
			# Deterministic art review; production keeps both templates in the pool.
			manager.wave_challenges.config.challenges[0].boss_templates = ["enemy_underworld_wolf"]
		flow.close_finance_popup()
		await frames(10)
		challenge = game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	var presentation := bank.trade_presentation if trade else challenge.presentation
	var proposal: Dictionary = manager.goblin_trades.offer if trade else manager.wave_challenges.offer
	check(str(proposal.get("id", "")) == id, "production eligibility selects " + id)
	if proposal.is_empty(): return {}
	presentation.set_process(false)
	presentation.sound_enabled = false
	presentation.seek(4.0)
	check(presentation._title.visible and presentation._seal.visible and presentation._seal.texture != null, "title and icon visible " + id)
	check(presentation._speech_text.text == str(proposal.speech) and presentation._body.text == str(proposal.body), "visible Chinese matches configured and resolved text " + id)
	return proposal.duplicate(true)


func make_debt() -> void:
	var loans := manager.goblin_loans
	for i in 3: loans.record_attempt(manager.finance_system, manager.run_statistics)
	check(not loans.quote.is_empty(), "real loan quote created")
	if loans.quote.is_empty(): return
	var result := loans.accept(str(loans.quote.token), 2, manager.finance_system, manager.run_statistics)
	check(bool(result.get("success", false)) and int(loans.debt.get("due", 0)) > 0, "real loan debt exists")


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(12)
	flow = game.get_main_flow_coordinator()
	_test_rules()
	await _test_customer()
	await _test_protection()
	await _test_overtime()
	await _test_debt()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	print("GOBLIN_CONTRACTS_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_rules() -> void:
	var trades := GoblinTradeSystem.new()
	var context := {"wave": 6, "has_next_wave": true, "gold": 150, "principal": 2000, "sanity": 70, "shelf_median": 50, "high_pressure": true, "remaining_waves": 3}
	check(trades.eligible_offers(context).any(func(x): return x.id == "preferred_customer"), "customer inclusive thresholds")
	for change in [{"gold": 149}, {"principal": 1999}, {"sanity": 69}, {"remaining_waves": 2}, {"high_pressure": false}, {"shelf_median": 51}]:
		var invalid := context.duplicate(true)
		invalid.merge(change, true)
		check(not trades.eligible_offers(invalid).any(func(x): return x.id == "preferred_customer"), "customer rejects " + str(change))
	trades.accepted_waves.preferred_customer = 1
	check(not trades.eligible_offers(context).any(func(x): return x.id == "preferred_customer"), "permanent customer contract does not stack")
	context.minimum_health_ratio = 0.25
	check(trades.eligible_offers(context).any(func(x): return x.id == "capital_protection"), "quarter health enables protection")
	context.minimum_health_ratio = 0.26
	context.low_health_seconds = 9.99
	check(not trades.eligible_offers(context).any(func(x): return x.id == "capital_protection"), "ordinary high pressure insufficient for protection")
	context.low_health_seconds = 10.0
	check(trades.eligible_offers(context).any(func(x): return x.id == "capital_protection"), "ten seconds low health enables protection")
	var c := WaveChallengeSystem.new()
	check(not c.eligible_offers({}).any(func(x): return x.id == "paid_overtime"), "missing telemetry is not medium pressure")
	c.pressure = {"observed_seconds": 5, "struggling": false, "comfortable": false}
	check(c.eligible_offers({}).any(func(x): return x.id == "paid_overtime"), "observed medium pressure qualifies")
	c.pressure.struggling = true
	check(not c.eligible_offers({}).any(func(x): return x.id == "paid_overtime"), "high pressure excludes overtime")
	c.pressure = {"observed_seconds": 5, "comfortable": true}
	check(not c.eligible_offers({}).any(func(x): return x.id == "paid_overtime"), "low pressure excludes overtime")
	check(c.eligible_offers({}, {"debt_due": 600, "debt_id": "test"}).any(func(x): return x.id == "debt_hunter"), "debt alone qualifies at low pressure")
	check(not c.eligible_offers({}, {"debt_due": 0, "debt_id": "test"}).any(func(x): return x.id == "debt_hunter"), "zero debt excludes boss challenge")


func _test_customer() -> void:
	var offer := await fixture("preferred_customer")
	if offer.is_empty(): return
	await capture("01_customer_offer")
	var prices := {}
	for item in flow.get_preparation_payload().offers: prices[item.offer_id] = float(item.shop_price_basis)
	var refresh := flow.get_shop_refresh_cost()
	await click(bank.trade_presentation._yes)
	check(manager.goblin_trades.accepted_waves.has("preferred_customer"), "click accepts customer trade")
	for item in flow.get_preparation_payload().offers:
		check(is_equal_approx(float(item.shop_price_basis), float(prices[item.offer_id]) * 0.85), "current shelf repriced by fifteen percent")
	check(flow.get_shop_refresh_cost() == refresh, "contract does not discount refresh fees")
	GoblinTradeSystem.apply_stat(manager.player, "discount_fixture", "shop_price_percent", 8)
	check(is_equal_approx(StatDefinitions.calculate_shop_price_multiplier(flow._get_shop_discount_layers()), 0.85 * 0.92), "separate discounts multiply")
	var item: Dictionary = {}
	for candidate in flow.get_preparation_payload().offers:
		if flow.get_offer_unavailable_reason(candidate).is_empty():
			item = candidate.duplicate(true)
			break
	check(not item.is_empty(), "an actual shelf item is available")
	if not item.is_empty():
		var gold := manager.current_gold
		check(bool(flow.submit_shop_purchase(item, "shop").success), "real paid purchase succeeds")
		check(manager.current_gold == gold - int(item.shop_cost) and manager.goblin_trades.customer_sanity_paid == 2, "pays quoted price and charges sanity once")
		check(not bool(flow.submit_shop_purchase(item, "shop").success) and manager.goblin_trades.customer_sanity_paid == 2, "duplicate purchase does not tax sanity")
	var sanity := manager.player.get_stat("humanity")
	check(bool(flow.request_shop_refresh().success) and manager.player.get_stat("humanity") == sanity, "refresh has no purchase sanity cost")
	GoblinTradeSystem.apply_stat(manager.player, "low_sanity_fixture", "humanity", -100)
	manager.goblin_trades.record_paid_purchase(manager.player)
	check(manager.goblin_trades.customer_sanity_paid == 4, "contract remains active below entry sanity")
	await capture("02_customer_accepted")


func _test_protection() -> void:
	var offer := await fixture("capital_protection")
	if offer.is_empty(): return
	check(str(offer.body).contains("5本金") and not str(offer.body).contains("{单价}"), "unit price resolves without changing original template")
	await capture("03_protection_offer")
	await click(bank.trade_presentation._yes)
	var f := manager.finance_system
	check(is_equal_approx(f.mitigate_health_damage(100), 100), "accepted protection does not activate in shop")
	flow.close_finance_popup()
	await frames(8)
	manager.set_process(false)
	manager.player.set_physics_process(false)
	flow._bound_loadout.set_process(false)
	var p := manager.player
	GoblinTradeSystem.apply_stat(p, "hp_fixture", "max_hp", 1000)
	GoblinTradeSystem.apply_stat(p, "armor_fixture", "armor", -p.get_stat("armor"))
	p.heal(2000)
	p.current_shield = 0
	p._invincibility_timer = 0
	var hp := p.current_hp
	var principal := f.principal
	p.take_damage(100)
	check(p.current_hp == hp - 70 and f.principal == principal - 150, "actual hit loses 70 HP and 150 principal")
	p._invincibility_timer = 1
	p.take_damage(100)
	check(f.principal == principal - 150, "invincibility does not consume capital")
	p._invincibility_timer = 0
	p.current_shield = 20
	p.take_damage(20)
	check(p.current_hp == hp - 70 and f.principal == principal - 150, "normal shield absorbs without capital cost")
	hp = p.current_hp
	principal = f.principal
	for i in 10: p.take_damage(1)
	check(p.current_hp == hp - 7 and f.principal == principal - 15, "ten small hits preserve thirty percent and exact cumulative price")
	f.principal = 50
	f._emit_changed()
	hp = p.current_hp
	p.take_damage(100)
	check(p.current_hp == hp - 90 and f.principal == 0 and bool(f.capital_protection.exhausted), "insufficient principal buys only affordable damage reduction")
	f.deposit(1000, true, "fixture")
	hp = p.current_hp
	p.take_damage(100)
	check(p.current_hp == hp - 100 and f.principal == 1000, "restored capital does not restart exhausted protection")
	p.add_relic("relic_bankruptcy_reorg")
	f.principal = 50
	f._emit_changed()
	f.arm_capital_protection(manager.current_wave_index + 1, 0.3, 5)
	p.take_damage(100)
	check(f.principal > 0 and bool(f.capital_protection.exhausted), "bankruptcy recovery cannot reactivate the same contract")
	f.end_capital_protection(manager.current_wave_index + 1)
	check(f.capital_protection.is_empty(), "wave end clears all protection terms")
	p.add_relic("relic_coin_heart")
	p.add_relic("relic_steel_vault")
	f.principal = 2050
	f._emit_changed()
	var armor := p.get_stat("armor")
	var max_hp := p.get_stat("max_hp")
	f.arm_capital_protection(manager.current_wave_index + 1, 0.3, 5)
	p.take_damage(100)
	check(p.get_stat("armor") < armor and p.get_stat("max_hp") < max_hp, "capital spending updates principal-linked defense and health")
	await capture("04_protection_combat")


func _test_overtime() -> void:
	var offer := await fixture("paid_overtime")
	if offer.is_empty(): return
	check(int(offer.gold_reward) == 170, "wave seven pays 170 gold")
	await capture("05_overtime_offer")
	await click(challenge.presentation._yes)
	manager.set_process(false)
	flow._bound_loadout.set_process(false)
	var contract := manager.wave_challenges.active.duplicate(true)
	for id in ["enemy_mutated_grub", "enemy_elite_rusher", "enemy_underworld_wolf"]:
		manager.wave_challenges.active.clear()
		var base := manager.spawn_enemy(id, manager.player.global_position + Vector2(300, 0))
		manager.wave_challenges.active = contract.duplicate(true)
		var enhanced := manager.spawn_enemy(id, manager.player.global_position + Vector2(350, 0))
		base.set_physics_process(false)
		enhanced.set_physics_process(false)
		check(absf(enhanced.get_stat("max_hp") - base.get_stat("max_hp") * 1.3) <= 1.0, "thirty percent HP applies to " + id)
		check(enhanced.get_stat("melee_damage") == base.get_stat("melee_damage"), "overtime does not change attack " + id)
	var gold := manager.current_gold
	var result := manager.wave_challenges.settle_wave(7, manager.player, manager.finance_system)
	check(int(result.get("gold_bonus", 0)) == 170 and manager.current_gold == gold + 170, "survival grants direct gold once")
	manager.wave_challenges.settle_wave(7, manager.player, manager.finance_system)
	check(manager.current_gold == gold + 170 and manager.wave_challenges.enemy_modifiers(8).is_empty(), "no duplicate payout or next-wave HP carryover")


func _test_debt() -> void:
	var offer := await fixture("debt_hunter")
	if offer.is_empty(): return
	var due := int(offer.debt_due)
	check(str(offer.body).count(str(due)) == 2, "same locked debt amount fills both placeholders")
	await capture("06_debt_offer")
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames(12)
	check(challenge.presentation._yes.get_global_rect().end.y < 360 and challenge._back.get_global_rect().end.y < 360, "long boss contract remains operable at small size")
	await capture("07_debt_offer_small")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(12)
	await click(challenge.presentation._yes)
	manager.set_process(false)
	manager.player.set_physics_process(false)
	flow._bound_loadout.set_process(false)
	var target := instance_from_id(int(manager.wave_challenges.active.get("target_instance", 0))) as EnemyController
	check(target != null and manager.get_living_enemy_count() == 1, "extra target spawns immediately at wave start")
	if target == null: return
	target.set_physics_process(false)
	var base := manager.spawn_enemy(str(offer.boss_template), manager.player.global_position + Vector2(220, 0))
	base.set_physics_process(false)
	for stat in ["max_hp", "armor", "melee_damage", "ranged_damage", "element_damage"]:
		var factor := 3.0 if stat == "max_hp" else 2.0
		check(absf(target.get_stat(stat) - base.get_stat(stat) * factor) <= 1.0, "boss multiplier " + stat)
	check(is_equal_approx(target.body_scale_multiplier, 1.1) and is_equal_approx(target.get_node("CollisionShape2D").scale.x, 1.1), "body and collision scale together")
	check(manager.get_miniboss_spawn_snapshot().spawned == 0, "target does not spend ordinary miniboss quota")
	if target is UnderworldWolf:
		# Let the real spawn warning complete so the official sprite is visible.
		target.set_physics_process(true)
		base.set_physics_process(true)
		await get_tree().create_timer(float(target.profile.spawn_seconds) + 0.1).timeout
		target.set_physics_process(false)
		base.set_physics_process(false)
		check(target.sprite.is_visible_in_tree() and base.sprite.is_visible_in_tree(), "both official boss sprites visible after real spawn sequence")
	target.global_position = manager.player.global_position + Vector2(160, -5)
	base.global_position = manager.player.global_position + Vector2(330, 15)
	await capture("08_debt_boss_combat")
	base.take_damage(1000000, "fixture")
	check(int(manager.goblin_loans.debt.get("due", 0)) == due, "ordinary boss kill does not repay contract")
	target.take_damage(1000000, "fixture")
	check(manager.goblin_loans.debt.is_empty() and bool(manager.wave_challenges.active.get("debt_resolved", false)), "target death clears debt immediately before wave settlement")
	manager.wave_challenges.resolve_debt_target(7, false, manager.goblin_loans, manager.finance_system)
	check(manager.goblin_loans.debt.is_empty(), "timeout after success cannot create new debt")
	await frames(8)
	await fixture("debt_hunter")
	var penalty := int(manager.wave_challenges.offer.get("debt_amount", 0))
	await click(challenge.presentation._yes)
	manager.set_process(false)
	manager.player.set_physics_process(false)
	flow._bound_loadout.set_process(false)
	manager.apply_gold_delta(-manager.current_gold, "fixture")
	var rate := float(manager.goblin_loans.debt.rate_percent)
	manager.cleanup_active = true
	manager.cleanup_time_left = 0
	flow.finish_current_wave()
	await frames(20)
	var expected := GoblinLoanSystem.compound(penalty * 2, rate)
	check(int(manager.goblin_loans.debt.get("due", 0)) == expected, "cleanup timeout adds penalty before normal loan rollover")
	manager.process_wave_end_settlements()
	check(int(manager.goblin_loans.debt.get("due", 0)) == expected, "repeated settlement cannot add a second penalty")
	await fixture("debt_hunter")
	var c := manager.wave_challenges
	var locked := c.offer.duplicate(true)
	manager.finance_system.grant_trade_gold(int(manager.goblin_loans.debt.due))
	check(bool(manager.goblin_loans.repay(manager.finance_system).success), "debt can be repaid before accepting")
	check(not c.decide(str(locked.token), true, manager.player, manager.finance_system, manager.goblin_loans), "repaid debt invalidates prior challenge")
	check(c.prepare(7, {}, {"debt_due": 0, "debt_id": ""}).is_empty(), "reopening cannot reroll an invalidated debt challenge")
