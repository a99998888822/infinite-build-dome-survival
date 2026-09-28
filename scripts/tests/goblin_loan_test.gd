extends Node

var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var popup: FinancePopup
var ui: GoblinLoanPresentation
var live_completed := false


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",message)


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func fixture(rate := 5.0, principal := 0) -> Dictionary:
	var p := PlayerController.new()
	p.auto_initialize_on_ready=false
	add_child(p)
	p.initialize_from_character("character_void_hunter")
	p.set_physics_process(false)
	p.add_runtime_modifier({"id":"loan_test_rate","source_type":"test","source_id":"loan","target_scope":"player","stat":"interest_rate","operation":Modifier.OPERATION_ADD_FLAT,"value":rate-5,"duration":-1,"stack_rule":Modifier.STACK_RULE_REPLACE_SAME_SOURCE})
	var wallet := {"value":0,"fail":false}
	var finance := BattleFinanceSystem.new()
	finance.initialize(p,func(): return int(wallet.value),func(delta: int,_reason: String):
		if wallet.fail or int(wallet.value)+delta<0: return false
		wallet.value+=delta
		return true)
	p.relic_added.connect(finance.on_relic_added)
	finance.principal=principal
	finance.begin_wave(1)
	finance.prepare_wave(2)
	finance._emit_changed()
	return {"player":p,"finance":finance,"wallet":wallet}


func offer(bank: BattleFinanceSystem, wave := 2) -> GoblinLoanSystem:
	var loans := GoblinLoanSystem.new()
	loans.prepare(wave)
	var stats := RunStatistics.new()
	for i in 3: loans.record_attempt(bank,stats)
	return loans


func _rules() -> void:
	var f := fixture()
	var bank: BattleFinanceSystem = f.finance
	var loans := GoblinLoanSystem.new()
	var stats := RunStatistics.new()
	loans.prepare(2)
	check(not loans.record_attempt(bank,stats) and not loans.record_attempt(bank,stats),"two unavailable attempts stay silent")
	var rng_before := bank._rng.state
	check(loans.record_attempt(bank,stats),"third attempt creates a quote")
	check(loans.quote.options.map(func(x):return x.due)==[140,260,600],"approved three base repayment amounts")
	check(bank._rng.state==rng_before and bank.principal==0 and f.wallet.value==0,"quote projection does not mutate wallet principal or live randomness")
	var frozen := loans.quote.duplicate(true)
	loans.dismiss()
	for i in 6: check(not loans.record_attempt(bank,stats),"dismissed quote never auto opens again")
	check(loans.reopen() and loans.quote==frozen,"manual reopen retains identical quote")
	var token := str(loans.quote.token)
	check(not loans.accept("stale",2,bank,stats).success and not loans.accept(token,3,bank,stats).success,"stale token and invalid index cannot credit money")
	f.wallet.fail=true
	check(not loans.accept(token,2,bank,stats).success and loans.debt.is_empty() and f.wallet.value==0,"failed credit rolls back the loan")
	f.wallet.fail=false
	check(loans.accept(token,2,bank,stats).success and f.wallet.value==500 and loans.debt.due==600,"accept credits exact cash and creates next-wave debt")
	check(not loans.accept(token,2,bank,stats).success and f.wallet.value==500,"double acceptance cannot issue a second loan")
	check(stats.snapshot().accepted==1 and stats.snapshot().refused==0 and stats.snapshot().gold==0,"dismiss then accept counts once and loan is not earned gold")
	check(bank.apply_finance_operation("deposit",500).success and bank.principal==500,"borrowed cash can be deposited normally")
	check(loans.settle_wave(1,bank).is_empty(),"borrowing preparation cannot repay before the next wave")
	bank.begin_wave(2)
	bank.process_wave_end_settlements()
	check(f.wallet.value==25,"borrowed principal earns ordinary interest")
	var result := loans.settle_wave(2,bank)
	check(result.action=="rollover" and loans.debt.due==720 and f.wallet.value==25 and bank.principal==500,"insufficient balance remains untouched and whole debt compounds")
	loans.settle_wave(2,bank)
	check(loans.debt.due==720,"same-wave callback cannot compound twice")
	loans.settle_wave(3,bank)
	check(loans.debt.due==864,"second missed deadline compounds on the full outstanding amount")
	check(not loans.repay(bank).success,"manual repayment requires the full current debt")
	f.wallet.value=864
	check(loans.repay(bank).success and f.wallet.value==0 and bank.principal==500,"manual repayment debits current debt without touching principal")
	check(not loans.can_offer(),"cannot repay and refinance in one bank visit")
	loans.prepare(4)
	check(loans.can_offer(),"new preparation may offer another loan after repayment")
	check(GoblinLoanSystem.compound(196,40)==275,"fractional compound debt rounds upward")
	check(GoblinLoanSystem.compound(GoblinLoanSystem.MAX_DEBT,100)>0,"extreme debt cannot overflow into negative cash")
	loans.reset()
	check(loans.debt.is_empty() and loans.quote.is_empty() and loans.preparation_wave==-1,"new run resets the entire loan state")
	f.player.free()

	var rich := fixture(5,100000)
	var rich_quote := offer(rich.finance)
	check(rich_quote.quote.options.map(func(x):return x.due)==[140,260,600],"large original principal alone does not inflate loan cost")
	rich.player.free()
	var high := fixture(30,1000)
	var high_quote := offer(high.finance)
	check(high_quote.quote.options[2].due==700 and high_quote.quote.options[2].adjusted,"existing 30 percent return raises the large loan to 40 percent")
	var locked := high_quote.quote.duplicate(true)
	high.player.add_relic("relic_perpetual_annuity_scroll")
	high_quote.dismiss()
	high_quote.reopen()
	check(high_quote.quote==locked,"buying another interest relic cannot reprice an existing quote")
	high.finance.manual_operation_used=true
	var used_quote := offer(high.finance)
	check(used_quote.quote.options.map(func(x):return x.due)==[140,260,600],"used bank action cannot inflate quote with an unavailable deposit")
	high.finance.manual_operation_used=false
	high.finance.trade_deposit_blocked=true
	high.finance.trade_withdraw_blocked=true
	var blocked_quote := offer(high.finance)
	check(blocked_quote.quote.options.map(func(x):return x.due)==[140,260,600],"closed bank is respected by price projection")
	blocked_quote.accept(str(blocked_quote.quote.token),0,high.finance,RunStatistics.new())
	check(not high.finance.apply_finance_operation("deposit",100).success and not high.finance.apply_finance_operation("withdraw",100).success,"accepting a loan preserves existing bank restrictions")
	high.player.free()
	var extra := fixture(14,1000)
	extra.player.add_relic("relic_perpetual_annuity_scroll")
	var expected: float = extra.finance.project_next_wave_interest(500,true)-extra.finance.project_next_wave_interest(0,false)
	check(expected==140,"extra settlement is included in projected incremental interest")
	extra.player.add_relic("relic_periodic_dividend_clock")
	extra.finance.wave_counter=2
	extra.finance.prepare_wave(3)
	var periodic: float = extra.finance.project_next_wave_interest(500,true)-extra.finance.project_next_wave_interest(0,false)
	check(periodic==210,"periodic payment is counted only on its due wave")
	extra.player.add_relic("relic_dividend_check")
	var random_state: int = extra.finance._rng.state
	check(extra.finance.project_next_wave_interest(500,true)-extra.finance.project_next_wave_interest(0,false)>periodic,"dividend chance contributes its expected bonus")
	check(extra.finance._rng.state==random_state,"projection never rolls live dividend randomness")
	extra.player.add_relic("relic_compound_interest_tome")
	var before: Dictionary = extra.finance.get_state_snapshot()
	var humanity_before: float = extra.player.get_stat("humanity")
	extra.finance.project_next_wave_interest(500,true)
	check(extra.finance.get_state_snapshot()==before and extra.player.get_stat("humanity")==humanity_before,"projecting rate growth cannot alter live finance or sanity")
	extra.player.free()
	var conditional := fixture(5,1000)
	conditional.player.add_relic("relic_high_yield_contract")
	var condition_gain: float = conditional.finance.project_next_wave_interest(100,true)-conditional.finance.project_next_wave_interest(0,false)
	check(condition_gain==71,"deposit-triggered bonus on existing principal is counted")
	conditional.player.free()


func _run() -> void:
	CampProgression.begin_transient_session()
	_rules()
	await _live()
	check(live_completed,"all live assertions reached without a script interruption")
	if is_instance_valid(game): game.queue_free()
	AudioManager.stop_bgm()
	await frames(8)
	print("GOBLIN_LOAN_COMPLETE checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)


func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position=button.get_global_rect().get_center()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames()


func _wallet(amount: int) -> void:
	manager.apply_gold_delta(amount-manager.current_gold,"test")
	flow._notify_preparation_changed()


func _live() -> void:
	game=load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene=game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.size=Vector2i(1152,768)
	get_tree().root.content_scale_size=Vector2i(1152,768)
	flow=game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(),"live game starts")
	await frames()
	manager=flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.finance_system.deposit(800,true,"test")
	flow.finish_current_wave()
	await frames(12)
	popup=game.find_child("FinancePopup",true,false) as FinancePopup
	ui=popup.loan_presentation
	popup.interest_arrival.stop()
	_wallet(0)
	await frames()
	var card: PreparationOfferCard
	for candidate: PreparationOfferCard in popup.shop_grid._pool:
		if candidate.is_visible_in_tree() and candidate.buy_button.disabled and flow.get_offer_unavailable_reason(candidate.offer)=="insufficient_gold":
			card=candidate
			break
	check(card!=null,"live shop has a disabled unaffordable button")
	if card==null: return
	var ledger_before := manager.economy_journal.entries.size()
	popup._sale_layer.show()
	popup._observe_disabled_purchase(card.buy_button.get_global_rect().get_center())
	popup._sale_layer.hide()
	check(manager.goblin_loans.clicks==0,"covered purchase button is not observed")
	await _click(card.buy_button)
	await _click(card.buy_button)
	check(manager.goblin_loans.clicks==2 and not ui.is_active(),"real disabled mouse clicks are silently counted")
	await _click(card.buy_button)
	check(ui.is_active() and manager.goblin_loans.debt.is_empty(),"third click opens instantly without accidental acceptance")
	check(manager.current_gold==0 and manager.economy_journal.entries.size()==ledger_before,"click observation never buys or creates journal spam")
	check(not ui._cards[0].button.disabled and not ui._cards[2].button.disabled,"all loan choices enabled before typing finishes")
	var quote := manager.goblin_loans.quote.duplicate(true)
	check(not flow.submit_finance_operation("withdraw",1).success and not flow.submit_shop_purchase(card.offer,"shop").success and not flow.request_shop_refresh().success,"background money actions cannot bypass the loan modal")
	ui.elapsed=2
	ui._seek()
	await capture("loan_live_popup")
	await _click(ui._decline)
	check(not ui.is_active() and ui.reopen.visible,"dismiss creates the bottom reopen entry")
	for i in 3: await _click(card.buy_button)
	check(not ui.is_active(),"more failed purchases cannot automatically reopen")
	await _click(ui.reopen)
	check(ui.is_active() and manager.goblin_loans.quote==quote,"reopen shows the same three contracts")
	var camp_before := CampProgression.get_camp_currency()
	await _click(ui._cards[2].button)
	check(manager.current_gold==500 and manager.goblin_loans.debt.due==600 and ui.state=="borrowed","actual choice credits cash and renders outstanding loan")
	check(manager.goblin_trades.offer.is_empty() and not ui.is_active(),"accepting loan cancels the unaccepted entrance trade")
	check(manager.run_statistics.combat_gold==0 and CampProgression.get_camp_currency()==camp_before,"loan cash does not count as combat income or camp currency")
	check(not flow.accept_goblin_loan(str(quote.token),2).success and manager.current_gold==500,"repeated live submission cannot pay twice")
	check(flow.submit_finance_operation("deposit",500).success and manager.finance_system.principal==1300,"live borrowed money can be deposited")
	await frames()
	await capture("loan_live_bank")
	get_tree().root.size=Vector2i(640,360)
	get_tree().root.content_scale_size=Vector2i(640,360)
	await frames(8)
	check(popup.main_panel.get_global_rect().encloses(ui._strip.get_global_rect()) and ui._strip.get_global_rect().position.y>=popup.start_button.get_global_rect().end.y,"small loan bar remains below navigation within bank border")
	await capture("loan_live_small")
	get_tree().root.size=Vector2i(1152,768)
	get_tree().root.content_scale_size=Vector2i(1152,768)
	await frames()
	flow.close_finance_popup()
	if flow.current_state==flow.STATE_WAVE_CHALLENGE: flow.decide_wave_challenge(str(manager.wave_challenges.offer.token),false)
	await frames()
	check(not ui.is_visible_in_tree() and flow.current_state==flow.STATE_WAVE_COMBAT,"loan HUD hides during combat")
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.player.add_relic("relic_perpetual_annuity_scroll")
	_wallet(470)
	# Principal 1300 yields 65 twice. Only the second payment reaches 600.
	manager.wave_challenges.active=manager.wave_challenges.definition("all_in").duplicate(true)
	manager.wave_challenges.active.wave=manager.current_wave_index+1
	flow.finish_current_wave()
	await frames(12)
	check(manager.goblin_loans.debt.is_empty() and manager.goblin_loans.last_settlement.action=="paid","automatic repayment waits for ALL interest payments")
	check(manager.current_gold==0 and manager.finance_system.principal==1400,"repayment occurs before all-in transfer and its principal reward")
	check(manager.run_statistics.interest==170 and manager.run_statistics.combat_gold==0,"gross earned interest survives repayment and transfers")
	var gold_before := manager.current_gold
	manager.process_wave_end_settlements()
	check(manager.current_gold==gold_before,"wave settlement replay cannot charge again")
	popup.interest_arrival.stop()
	# Another loan, then two unpaid waves, then manual redemption.
	for candidate: PreparationOfferCard in popup.shop_grid._pool:
		if candidate.is_visible_in_tree() and flow.get_offer_unavailable_reason(candidate.offer)=="insufficient_gold":
			card=candidate
			break
	for i in 3: await _click(card.buy_button)
	check(ui.is_active(),"new preparation can trigger a new quote")
	await _click(ui._decline)
	check(ui.reopen.visible,"new quote replaces last-wave paid notice and keeps its reopen entry")
	await _click(ui.reopen)
	await _click(ui._cards[0].button)
	_wallet(0)
	flow.close_finance_popup()
	if flow.current_state==flow.STATE_WAVE_CHALLENGE: flow.decide_wave_challenge(str(manager.wave_challenges.offer.token),false)
	await frames()
	manager.set_process(false)
	manager.clear_enemies()
	# With principal removed in the fixture, no income can repay the loan.
	manager.finance_system.principal=0
	manager.finance_system._emit_changed()
	flow.finish_current_wave()
	await frames(12)
	check(manager.current_gold==0 and manager.goblin_loans.debt.due==196,"live insufficient payment rolls 140 into 196 without taking money")
	popup.interest_arrival.stop()
	_wallet(196)
	check(not ui.repay.disabled,"manual payoff becomes available when the wallet is sufficient")
	await _click(ui.repay)
	check(manager.goblin_loans.debt.is_empty() and manager.current_gold==0 and ui.state=="paid","small repay button clears current compounded debt")
	# An outstanding obligation never changes the death settlement formula.
	manager.goblin_loans.debt={"amount":500,"due":720,"due_wave":20,"rate_percent":20,"rollovers":1}
	var expected := RunSettlement.build(manager.run_statistics.snapshot(),false)
	manager.player.take_damage(99999,"loan_test")
	await frames(12)
	check(flow.current_battle_summary.camp_currency==expected.camp_currency and not ui.is_visible_in_tree(),"death ignores outstanding debt and hides the loan UI")
	check(manager.economy_journal.entries.any(func(x):return str(x.get("kind",""))=="loan"),"loan activity is written to the bank journal")
	flow.confirm_battle_result()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames()
	flow.confirm_character_selection()
	await frames()
	manager=flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	check(manager.goblin_loans.debt.is_empty() and manager.goblin_loans.quote.is_empty(),"real new adventure clears previous obligations")
	manager.current_wave_index=DataRegistry.get_table("waves").size()-1
	flow.current_wave_index=manager.current_wave_index
	manager.finance_system.current_wave_number=manager.current_wave_index+1
	manager.goblin_loans.debt={"amount":500,"due":720,"due_wave":manager.current_wave_index+1,"rate_percent":20,"rollovers":1}
	manager.finance_system.deposit(1000,true,"test")
	manager.add_exp_and_gold(0,100)
	var balance := CampProgression.get_camp_currency()
	flow.finish_current_wave()
	await frames(16)
	var victory_expected := RunSettlement.build(manager.run_statistics.snapshot(),true)
	check(flow.current_victory and not manager.goblin_loans.debt.is_empty() and flow.current_battle_summary.camp_currency==victory_expected.camp_currency and CampProgression.get_camp_currency()==balance+int(victory_expected.camp_currency),"victory pays normal camp currency despite remaining debt")
	live_completed=true


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))==OK,"capture "+name)
