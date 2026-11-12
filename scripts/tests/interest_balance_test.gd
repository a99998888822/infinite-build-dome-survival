extends Node
## Measures the real interest path under the retired snowball rules:
## dividend tickets roll independently (10% each, at most eight copies), the
## compound tome grows at most once per wave, and the periodic clock adds one
## settlement instead of stacking one per copy.
##
## Usage: --headless --path . --scene res://scenes/tests/interest_balance_test.tscn

const WAVES := 12
const START_PRINCIPAL := 1_000_000
const DIVIDEND_MAX_MULTIPLIER := 9   # eight hits -> 1 + 8

var checks := 0
var failures := 0
var game: GameRoot
var manager: WaveManager
var finance: BattleFinanceSystem


func _ready() -> void:
	_run.call_deferred()


func frames(count := 5) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + note)
	else:
		print("PASS " + note)


func report(line: String) -> void:
	print("MEASURE " + line)


func _run() -> void:
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(10)
	check(flow.confirm_character_selection(), "battle starts")
	await frames(20)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	while flow.get_current_state() == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
		flow.close_shared_reward_shop_popup()
		await frames(4)
	finance = manager.finance_system

	# Full interest build, at the new caps.
	for _copy in range(8):
		manager.player.add_relic("relic_dividend_check")
	for _copy in range(8):
		manager.player.add_relic("relic_compound_interest_tome")
	for _copy in range(2):
		manager.player.add_relic("relic_periodic_dividend_clock")
	manager.player.add_relic("relic_perpetual_annuity_scroll")
	check(manager.player.get_relic_count("relic_dividend_check") == 8, "eight dividend tickets are owned")
	check(not manager.player.add_relic("relic_dividend_check"), "dividend tickets stop at the eight-copy cap")
	check(manager.player.get_relic_count("relic_compound_interest_tome") == 8, "eight compound tomes are owned")
	check(not manager.player.add_relic("relic_compound_interest_tome"), "compound tomes stop at the eight-copy cap")

	finance.principal = START_PRINCIPAL
	var total_interest := 0
	var max_multiplier := 1
	var max_settles := 0
	for wave in range(1, WAVES + 1):
		finance.begin_wave(wave)
		var rate_start := finance.get_interest_rate()
		var results := finance.process_wave_end_settlements()
		var wave_gain := 0
		var settles := 0
		for result in results:
			if bool(result.get("success", false)) and int(result.get("gain", 0)) > 0:
				wave_gain += int(result.get("gain", 0))
				settles += 1
			max_multiplier = maxi(max_multiplier, int(result.get("dividend_multiplier", 1)))
		var growth := finance.get_interest_rate() - rate_start
		report("wave %2d settles=%d gain=%d rate=%.1f%% growth=+%.1f principal=%d" % [
			wave, settles, wave_gain, finance.get_interest_rate(), growth, finance.principal])
		# At most one rate growth per wave, whatever the settlement count is.
		check(growth <= 1.7, "tome grows at most once per wave (wave %d)" % wave)
		check(settles <= 3, "at most three settlements per wave (wave %d)" % wave)
		max_settles = maxi(max_settles, settles)
		total_interest += wave_gain
		# all_in: every point of interest is auto-deposited back into principal.
		if wave_gain > 0:
			finance.deposit(wave_gain)

	check(max_multiplier <= DIVIDEND_MAX_MULTIPLIER, "dividend multiplier never exceeds x9")
	report("TOTAL interest=%d rate=%.1f%% principal=%d max_dividend=×%d max_settles=%d" % [
		total_interest, finance.get_interest_rate(), finance.principal, max_multiplier, max_settles])

	# Interest no longer buys Talent Points; the settlement only reads waves, kills,
	# damage and survival time.
	var drained := {"waves": WAVES, "kills": 0, "damage": 0, "seconds": 0.0}
	var without_interest := RunSettlement.build(drained, true, "1")
	var with_interest: Dictionary = drained.duplicate(true)
	with_interest["interest"] = total_interest
	with_interest["gold"] = 50000000
	var rich := RunSettlement.build(with_interest, true, "1")
	report("SETTLE interest=%d ignored=%s base=%d" % [
		total_interest, str(without_interest.camp_currency == rich.camp_currency), without_interest.base_camp_currency])
	check(without_interest.camp_currency == rich.camp_currency, "interest and gold never buy talent points")
	check(without_interest.contributions[3] == 0, "the harness records no survival time, so that share stays zero")

	print("INTEREST_BALANCE_COMPLETE checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await frames()
	get_tree().quit(0 if failures == 0 else 1)
