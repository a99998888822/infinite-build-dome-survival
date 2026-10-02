extends Node

var checks := 0
var failures := 0
var flow: MainFlowCoordinator
var manager: WaveManager
var game: GameRoot
var ui: WaveChallengePopup
var capture_dir := ""
var completed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count: int = 5) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	_test_rules()
	await _test_flow()
	check(completed, "live test reached all final assertions without script errors")
	print("WAVE_CHALLENGE_COMPLETE checks=%d failures=%d" % [checks, failures])
	await frames()
	get_tree().quit(1 if failures else 0)


func _test_rules() -> void:
	var c := WaveChallengeSystem.new()
	var base := {"offense": 100.0, "durability": 100.0}
	check(c.eligible_offers(base).is_empty(), "missing telemetry and baseline cannot manufacture eligibility")
	c.preparation_baseline = base.duplicate()
	check(c.eligible_offers(base).size() == 2, "small preparation gain alone qualifies for both risky offers")
	check(c.eligible_offers({"offense": 116.0, "durability": 100.0}).is_empty(), "significant offense gain excludes low-gain trigger")
	check(c.eligible_offers({"offense": 100.0, "durability": 120.0}).is_empty(), "defensive investment counts as combat improvement")
	c.sample_health(6, 4, 10)
	c.finish_combat({"enemy_threshold": 15, "remaining_average": 0})
	check(c.pressure.struggling and not c.pressure.comfortable, "prolonged low health is pressure without repeated crossings")
	check(c.eligible_offers({"offense": 200.0}).size() == 2, "previous struggle still qualifies after shopping (OR condition)")
	c.begin_combat()
	c.sample_health(8, 10, 10)
	c.finish_combat({"enemy_threshold": 15, "remaining_average": 2, "low_health_episodes": 0})
	check(c.pressure.comfortable, "sustained safe health and low remaining crowd classify comfort")
	check(c.eligible_offers(base).size() == 3, "comfort and low gain enter same weighted pool")
	check(c.eligible_offers({"offense": 150.0, "durability": 100.0}).size() == 1, "comfortable improved build gets only all-in offer")
	c.begin_combat()
	c.sample_health(8, 10, 10)
	c.record_health(4, 10)
	c.finish_combat({"enemy_threshold": 15, "remaining_average": 0})
	check(not c.pressure.comfortable, "a brief dangerous hit prevents false comfortable classification")
	c.pressure = {"struggling": true}
	check(c.prepare(1, base).is_empty(), "no first-wave challenge")
	var proposal := c.prepare(2, base)
	check(not proposal.is_empty() and c.prepare(2, {"offense": 999}).token == proposal.token, "same visit has fixed offer despite build changes")
	c.reset()
	check(c.active.is_empty() and c.offer.is_empty() and c.totals.is_empty() and c.pressure.is_empty(), "reset clears all run-owned challenge state")


func _force_kind(id: String) -> void:
	var definition := manager.wave_challenges.definition(id)
	if definition.is_empty(): definition = WaveChallengeSystem.new().definition(id)
	manager.wave_challenges.config.challenges = [definition]
	manager.wave_challenges.pressure = {"struggling": id != "all_in", "comfortable": id == "all_in"}


func _end_wave() -> void:
	flow.finish_current_wave()
	await frames(14)
	var finance := game.find_child("FinancePopup", true, false) as FinancePopup
	finance.interest_arrival.skip()
	check(flow.current_state == flow.STATE_FINANCE_POPUP, "completed wave returns to preparation")


func _open(id: String) -> void:
	_force_kind(id)
	flow.close_finance_popup()
	_check_header_layout("first layout")
	await frames()
	_check_header_layout("settled layout")
	check(flow.current_state == flow.STATE_WAVE_CHALLENGE and ui.visible and not manager.running, "next-wave action opens paused challenge")
	check(not ui.presentation._yes.disabled and not ui.presentation._no.disabled and ui.presentation._body.visible_characters == -1, "terms and both choices ready immediately")


func _check_header_layout(stage: String) -> void:
	var title := ui.presentation._title.get_global_rect()
	var body := ui.presentation._body_scroll.get_global_rect()
	check(title.size.y <= 28 and title.end.y + 12 <= body.position.y, "challenge header clear of terms: " + stage)


func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	ui.presentation.set_process(false)
	ui.presentation.seek(4.6)
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)
	ui.presentation.set_process(true)


func _click_button(button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await frames()


func _test_flow() -> void:
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "real first wave starts")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	ui = game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	check(not ui.visible and manager.wave_challenges.prepared_wave == -1, "first wave bypasses challenge UI")
	manager.wave_challenges.sample_health(8, manager.player.current_hp, int(manager.player.get_stat("max_hp")))
	await _end_wave()
	check(manager.wave_challenges.pressure.comfortable, "live wave-end preserves comfortable telemetry")
	await _open("extra_elites")
	var token := str(ui.proposal.token)
	var gold := manager.current_gold
	check(not flow.submit_finance_operation("deposit", 1).success and not flow.request_shop_refresh().success, "bank and shop actions cannot bypass challenge modal")
	check(not flow.decide_wave_challenge("stale", true) and manager.current_gold == gold, "stale choice rejected without effects")
	await _capture("01_extra_elites")
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames()
	check(ui.portrait.get_rect().position.y >= 0 and ui._back.get_rect().end.y <= 360 and ui.presentation._card.get_rect().end.x <= 640, "compact screen keeps portrait card and navigation inside viewport")
	_check_header_layout("compact viewport")
	check((ui.get_parent() as CanvasLayer).layer > (game.find_child("HUD", true, false) as BattleHud).layer, "challenge sits above the stats drawer on every screen size")
	await _capture("04_compact")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	flow.request_battle_utility("settings")
	check(not ui.visible and flow.current_state == flow.STATE_BATTLE_UTILITY, "settings can suspend challenge")
	flow.close_battle_utility()
	check(ui.visible and flow.current_state == flow.STATE_WAVE_CHALLENGE, "settings resumes same challenge")
	flow.return_from_wave_challenge()
	check(flow.current_state == flow.STATE_FINANCE_POPUP and not ui.visible, "return to bank preserves paused preparation")
	flow.close_finance_popup()
	check(str(ui.proposal.token) == token, "returning to bank cannot reroll")
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames()
	await _click_button(ui.presentation._no)
	check(flow.current_state == flow.STATE_WAVE_COMBAT and not ui.visible and manager._challenge_elite_planned == 0, "normal start declines without extra elites")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	check(not flow.decide_wave_challenge(token, true), "declined offer cannot be accepted later")
	await _end_wave()
	await _open("extra_elites")
	ui.presentation._yes.pressed.emit()
	check(manager._challenge_elite_planned == 2 and manager.running, "acceptance schedules exactly two extra elites")
	var base_planned := manager._elite_planned_count
	var saved_limit: Variant = manager._difficulty.enemy_limit
	manager._difficulty.enemy_limit = 0
	manager.wave_time_left = float(manager.current_wave.duration_seconds) * 0.8
	manager._process_spawn_timers(0)
	check(manager._challenge_elite_spawned == 1, "first elite spawns early even at population cap")
	manager.wave_time_left = float(manager.current_wave.duration_seconds) * 0.6
	manager._process_spawn_timers(0)
	manager._process_spawn_timers(0)
	check(manager._challenge_elite_spawned == 2 and manager._elite_planned_count == base_planned, "second elite is additive and cannot spawn twice")
	manager._difficulty.enemy_limit = saved_limit
	check(EnemyRegistry.get_registered_enemies().size() == 2, "extra quota creates two real miniboss entities")
	manager._difficulty.enemy_limit = 1
	manager.spawn_timers_ms.fill(0)
	manager._process_spawn_timers(0)
	check(EnemyRegistry.get_registered_enemies().size() == 3, "challenge elites do not consume normal spawn capacity")
	manager._difficulty.enemy_limit = saved_limit
	await _end_wave()
	await _open("rising_tide")
	await _capture("02_rising_tide")
	var erosion := manager.player.get_stat("divinity")
	var interest := manager.finance_system.get_interest_rate()
	var luck := manager.player.get_stat("luck")
	var principal := manager.finance_system.principal
	ui.presentation._yes.pressed.emit()
	check(manager.player.get_stat("divinity") == erosion + 20 and manager.finance_system.get_interest_rate() == interest + 1, "tide grants exact permanent erosion and percentage-point interest")
	check(manager.player.get_stat("luck") == luck + 10 and manager.finance_system.principal == principal + 100, "tide grants exact luck and principal")
	check(manager._wave_erosion_pressure.erosion >= erosion + 20 and manager._challenge_elite_planned == 0, "accepted erosion affects next wave snapshot; extra elite contract expires")
	await _end_wave()
	await _open("rising_tide")
	ui.presentation._yes.pressed.emit()
	check(manager.player.get_stat("divinity") == erosion + 40 and manager.finance_system.get_interest_rate() == interest + 2, "repeated tide offers accumulate rather than replace bonuses")
	await _end_wave()
	await _open("all_in")
	await _capture("03_all_in")
	principal = manager.finance_system.principal
	luck = manager.player.get_stat("luck")
	ui.presentation._yes.pressed.emit()
	check(manager.finance_system.principal == principal and manager.player.get_stat("luck") == luck, "all-in reward waits until wave completion")
	manager.apply_gold_delta(260, "test")
	manager.finance_system.deposit(100, true, "test")
	check(manager.add_relic("relic_perpetual_annuity_scroll"), "enable real extra interest settlement")
	manager.finance_system.trade_deposit_blocked = true
	manager.finance_system.manual_operation_used = true
	gold = manager.current_gold
	principal = manager.finance_system.principal
	flow.finish_current_wave()
	await frames(14)
	var results := manager.finance_system.last_settlement_results
	check(results.size() == 2, "both ordinary and annuity interest settle before transfer")
	var total_interest := 0
	for result in results: total_interest += int(result.gain)
	check(manager.current_gold == 0 and manager.finance_system.principal == principal + gold + total_interest + 100, "full wallet plus all interest transfers before bonus, despite old bank restriction")
	check(manager.player.get_stat("luck") == luck + 10 and manager.wave_challenges.active.is_empty(), "completion grants luck once and clears contract")
	var report := InterestArrivalReport.build({"settlement_results": results})
	check(bool(report.get("auto_deposit", false)) and report.total == total_interest, "receipt distinguishes transferred interest and principal rewards")
	principal = manager.finance_system.principal
	manager.process_wave_end_settlements()
	check(manager.finance_system.principal == principal and manager.current_gold == 0 and manager.player.get_stat("luck") == luck + 10, "duplicate wave settlement cannot repeat interest transfer or rewards")
	var finance_ui := game.find_child("FinancePopup", true, false) as FinancePopup
	check(finance_ui.interest_arrival._caption.text == "利息已转入本金", "actual receipt accurately identifies destination")
	finance_ui.interest_arrival.skip()
	check(flow.submit_finance_operation("withdraw", 50).success and manager.current_gold == 50, "next bank visit allows manual redemption")
	# Actual upgraded weapon and principal damage are included without rolling crits.
	var before := WaveChallengeSystem.combat_snapshot(manager.player, flow._bound_loadout)
	flow._bound_loadout.upgrade_weapon("weapon_void_blade")
	var after := WaveChallengeSystem.combat_snapshot(manager.player, flow._bound_loadout)
	check(float(after.offense) > float(before.offense), "weapon upgrade changes deterministic combat estimate")
	flow._bound_loadout.equip_weapon("weapon_rentier_purse")
	before = WaveChallengeSystem.combat_snapshot(manager.player, flow._bound_loadout)
	manager.finance_system.deposit(10000, true, "test")
	after = WaveChallengeSystem.combat_snapshot(manager.player, flow._bound_loadout)
	check(float(after.offense) > float(before.offense), "principal-backed weapon strength contributes to estimate")
	# No combat completion reward after death, even if settlement is requested explicitly.
	var c := manager.wave_challenges
	c.active = WaveChallengeSystem.new().definition("all_in")
	c.active.wave = 999
	manager.player.alive = false
	principal = manager.finance_system.principal
	check(c.settle_wave(999, manager.player, manager.finance_system).is_empty() and manager.finance_system.principal == principal and c.active.is_empty(), "death cancels the pending deposit and bonus")
	flow.reset_flow()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "new run initializes")
	manager = flow._bound_wave_manager
	ui = game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	check(manager.wave_challenges.active.is_empty() and manager.wave_challenges.totals.is_empty() and manager.player.get_stat("divinity") == 0, "new run removes challenge counters and modifiers")
	manager.set_process(false)
	manager.player.set_physics_process(false)
	# Existing immediate-start bank trade intentionally bypasses another decision.
	await _end_wave()
	var trades := manager.goblin_trades
	trades.offer = trades.definition("principal_advance").duplicate(true)
	trades.offer.amount = 200
	trades.offer.token = "legacy-direct-start"
	check(flow.accept_goblin_trade("legacy-direct-start").success and flow.current_state == flow.STATE_WAVE_COMBAT and not ui.visible, "principal advance preserves its promised direct start")
	manager.current_wave_index = DataRegistry.get_table("waves").size() - 2
	flow.current_wave_index = manager.current_wave_index
	await _end_wave()
	await _open("all_in")
	ui.presentation._yes.pressed.emit()
	manager.apply_gold_delta(80, "test")
	principal = manager.finance_system.principal
	gold = manager.current_gold
	flow.finish_current_wave()
	await frames(14)
	total_interest = 0
	for result in manager.finance_system.last_settlement_results: total_interest += int(result.gain)
	check(flow.current_state == flow.STATE_BATTLE_RESULT and not ui.visible and manager.finance_system.principal == principal + gold + total_interest + 100, "final-wave all-in pays before victory without another bank or challenge")
	manager.running = false
	manager.clear_battle_entities()
	completed = true
