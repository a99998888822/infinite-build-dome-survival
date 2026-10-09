extends Node
## Exercises production challenge UI, real drops, enemy targeting and settlement.
var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var ui: WaveChallengePopup


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	get_tree().create_timer(170).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)


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


func offer(id: String) -> Dictionary:
	flow.current_wave_index = -1
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "real run starts " + id)
	await frames(10)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	if id == "capital_custody":
		manager.player.add_relic("relic_coin_heart")
		manager.finance_system.deposit(5000, true, "fixture")
	if id != "business_expansion": manager.goblin_trades.low_health_episodes = 3
	manager.wave_challenges.sample_health(8, manager.player.current_hp, int(manager.player.get_stat("max_hp")))
	if id == "fleeting_fortune":
		manager.wave_challenges.begin_combat()
		var survivor := manager.spawn_enemy("enemy_mutated_grub", manager.player.global_position + Vector2(450, 0))
		survivor.set_physics_process(false)
		manager.wave_challenges.advance_enemy_lifetimes(10)
		manager.cleanup_active = true
		manager.cleanup_time_left = 0
	flow.finish_current_wave()
	await frames(18)
	var bank := game.find_child("FinancePopup", true, false) as FinancePopup
	bank.interest_arrival.skip()
	# Restrict only the review candidate pool; all eligibility and effects stay live.
	manager.wave_challenges.config.challenges = [WaveChallengeSystem.new().definition(id)]
	flow.close_finance_popup()
	await frames(8)
	ui = game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	check(flow.current_state == flow.STATE_WAVE_CHALLENGE and str(ui.proposal.get("id", "")) == id, "eligible offer reaches real modal " + id)
	ui.presentation.set_process(false)
	ui.presentation.sound_enabled = false
	ui.presentation.seek(4.0)
	return ui.proposal.duplicate(true)


func offer_captures(name: String) -> void:
	check(ui.presentation._title.visible and ui.presentation._seal.visible and ui.presentation._seal.texture != null, "challenge header and icon retained")
	await capture(name)
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames(10)
	check(ui.presentation._yes.get_global_rect().end.y < 360 and ui._back.get_global_rect().end.y < 360, "small viewport keeps decisions reachable")
	await capture(name + "_small")
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames(10)


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
	await _test_expansion()
	await _test_gold()
	await _test_vault()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	print("CHALLENGE_EXPANSION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_rules() -> void:
	var c := WaveChallengeSystem.new()
	c.pressure = {"comfortable": true}
	check(c.eligible_offers({}, {"remaining_waves": 2}).any(func(x): return x.id == "business_expansion"), "comfortable expansion eligibility")
	check(not c.eligible_offers({}, {"remaining_waves": 1}).any(func(x): return x.id == "business_expansion"), "expansion needs a future wave for its permanent cost")
	c.accepted.business_expansion = 1
	check(c.eligible_offers({}, {"remaining_waves": 5}).any(func(x): return x.id == "business_expansion"), "expansion can return in the same run")
	c.pressure = {"struggling": true, "enemy_spawned_count": 10, "cleanup_timed_out": true, "cleanup_remaining_enemies": 1, "average_enemy_lifetime": 9.99}
	check(not c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "cleanup leftovers alone do not qualify below ten-second average")
	c.pressure.average_enemy_lifetime = 10.0
	check(c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "cleanup leftovers qualify at ten-second average boundary")
	c.pressure.cleanup_timed_out = false
	check(not c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "early wave finish cannot count as cleanup timeout")
	c.pressure.cleanup_timed_out = true
	c.pressure.cleanup_remaining_enemies = 0
	check(not c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "finishing all enemies before deadline excludes the challenge")
	c.pressure.cleanup_remaining_enemies = 1
	c.pressure.struggling = false
	check(not c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "cleanup terms retain high-pressure requirement")
	c.pressure.struggling = true
	check(not c.eligible_offers({}, {"principal": 1999}).any(func(x): return x.id == "capital_custody"), "custody requires high capital")
	var counts := {}
	c._rng.seed = 9102026
	for i in 600:
		c.prepared_wave = -1
		var proposal := c.prepare(3, {}, {"principal": 5000})
		counts[proposal.id] = int(counts.get(proposal.id, 0)) + 1
	check(counts.size() == 4 and counts.values().all(func(x): return x > 90 and x < 220), "all eligible challenges share uniform pool")
	_test_enemy_lifetimes()


func _test_enemy_lifetimes() -> void:
	var c := WaveChallengeSystem.new()
	c.record_enemy_spawn(1)
	c.record_enemy_spawn(1)
	c.advance_enemy_lifetimes(5)
	c.record_enemy_death(1)
	c.record_enemy_death(1)
	c.record_enemy_spawn(2)
	c.advance_enemy_lifetimes(15)
	c.finish_combat({"struggling": true}, true, 1)
	check(c.pressure.enemy_spawned_count == 2 and is_equal_approx(c.pressure.average_enemy_lifetime, 10), "all spawned enemies average dead five seconds and surviving fifteen seconds exactly once")
	check(c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "mixed killed and surviving population reaches actual trigger")
	c.finish_combat({"struggling": true}, true, 1)
	check(is_equal_approx(c.pressure.average_enemy_lifetime, 10), "reading final lifetime snapshot cannot accumulate it twice")
	c.begin_combat()
	c.finish_combat({"struggling": true}, true, 0)
	check(c.pressure.enemy_spawned_count == 0 and c.pressure.average_enemy_lifetime == 0 and not c.eligible_offers({}).any(func(x): return x.id == "fleeting_fortune"), "new wave clears lifetime data and empty population cannot qualify")


func _test_expansion() -> void:
	var proposal := await offer("business_expansion")
	if str(proposal.get("id", "")) != "business_expansion": return
	await offer_captures("01_expansion_offer")
	await click(ui.presentation._yes)
	var boosted := manager.calculate_spawn_interval(1200)
	manager.wave_challenges.spawn_frequency_bonus = 0
	var original := manager.calculate_spawn_interval(1200)
	manager.wave_challenges.spawn_frequency_bonus = 0.2
	check(is_equal_approx(boosted, original / 1.2), "frequency changes interval rather than batch count")
	var principal := manager.finance_system.principal
	flow.finish_current_wave()
	await frames(18)
	check(manager.finance_system.principal == principal + 150, "survival pays 150 once")
	manager.process_wave_end_settlements()
	check(manager.finance_system.principal == principal + 150 and manager.wave_challenges.spawn_frequency_bonus == 0.2, "reward is idempotent and frequency survives settlement")
	var c := manager.wave_challenges
	c.pressure = {"comfortable": true}
	var repeated := c.prepare(3, {}, {"remaining_waves": 3})
	check(str(repeated.get("id", "")) == "business_expansion" and c.decide(str(repeated.token), true, manager.player, manager.finance_system), "second expansion in the same run can be offered and accepted")
	check(is_equal_approx(c.spawn_frequency_bonus, 0.4), "repeated expansion adds another twenty percentage points")
	var repeated_principal := manager.finance_system.principal
	c.settle_wave(3, manager.player, manager.finance_system)
	c.settle_wave(3, manager.player, manager.finance_system)
	check(manager.finance_system.principal == repeated_principal + 150, "second expansion pays its own survival reward only once")


func _test_gold() -> void:
	var proposal := await offer("fleeting_fortune")
	if str(proposal.get("id", "")) != "fleeting_fortune": return
	await offer_captures("02_fortune_offer")
	await click(ui.presentation._yes)
	manager.set_process(false)
	var player := manager.player
	player.set_physics_process(false)
	flow._bound_loadout.set_process(false)
	manager.apply_gold_delta(-manager.current_gold, "fixture")
	GoblinTradeSystem.apply_stat(player, "fractional_fixture", "currency_gain_percent", 23.45)
	var orb := manager.spawn_exp_orb(1, player.global_position + Vector2(100, 0))
	check(orb.gold_multiplier == 1.5 and orb.gold_lifetime == 2.0, "production drop receives wave-only terms")
	orb.collect()
	check(is_equal_approx(manager.get_precise_gold(), 1.85), "1.5 times 1.2345 keeps two decimals, no whole-coin ceiling")
	await frames()
	var expired := manager.spawn_exp_orb(1, player.global_position + Vector2(130, 20))
	expired.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	expired._physics_process(3)
	check(not expired.gold_expired, "pause freezes expiration")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	expired.advance_gold_clock(2.01)
	check(expired.gold_expired and not expired.collected_once, "expired coin keeps its experience pickup")
	var exp_before := manager.current_exp
	expired.collect()
	check(manager.current_exp == exp_before + 1 and is_equal_approx(manager.get_precise_gold(), 1.85), "expired pickup grants experience only")
	for i in 7:
		var display := manager.spawn_exp_orb(1, player.global_position + Vector2(90 + i * 18, 50))
		display.set_physics_process(false)
		if i % 2 == 0: display.advance_gold_clock(2.01)
	await capture("03_fortune_combat")
	manager.collect_all_exp_orbs()
	var before_settle := manager.get_precise_gold()
	manager.record_wave_income()
	check(manager.current_gold == ceili(before_settle) and manager.pickup_gold_remainder_cents == 0, "wave income rounds the combined total only once")
	var paid := manager.current_gold
	manager.record_wave_income()
	check(manager.current_gold == paid, "repeated settlement cannot round twice")
	manager.wave_challenges.active.clear()
	manager.drop_reward_system.begin_wave(99)
	var ordinary := manager.spawn_exp_orb(1, player.global_position + Vector2(100, 0))
	check(ordinary.gold_multiplier == 1 and ordinary.gold_lifetime == 0, "next wave drops lose temporary terms")
	ordinary.collect()
	check(is_equal_approx(manager.get_precise_gold(), paid + 1.23), "ordinary bonus drops also retain cents")
	manager.settle_pickup_gold(false)
	check(manager.current_gold == paid + 1 and manager.pickup_gold_remainder_cents == 0, "unfinished wave cannot claim rounding bonus")
	# Collecting experience can open a real reward modal; finish it before a new run.
	while flow.current_state == flow.STATE_SHARED_REWARD_SHOP_POPUP:
		flow.close_shared_reward_shop_popup()
		await frames()


func _test_vault() -> void:
	for destroy in [false, true]:
		var proposal := await offer("capital_custody")
		if str(proposal.get("id", "")) != "capital_custody": return
		check(int(proposal.stake) == 500 and int(proposal.bonus) == 150, "stake and reward are locked before presentation")
		if not destroy: await offer_captures("04_custody_offer")
		var principal := manager.finance_system.principal
		var manual := manager.finance_system.manual_operation_used
		await click(ui.presentation._yes)
		manager.set_process(false)
		manager.player.set_physics_process(false)
		var vault := manager.challenge_vault
		check(is_instance_valid(vault) and manager.finance_system.principal == principal - 500, "acceptance deducts principal and spawns official vault")
		if not is_instance_valid(vault): return
		check(vault.max_hp == int(manager.player.get_stat("max_hp")) * 3 and vault.armor == manager.player.get_stat("armor"), "vault snapshots triple post-deduction maximum health and same armor")
		check(manager.finance_system.manual_operation_used == manual, "custody does not use a bank action")
		var hp := vault.current_hp
		var attackers: Array[EnemyController] = []
		for i in 6:
			var enemy := manager.spawn_enemy("enemy_mutated_grub", vault.global_position + Vector2(80 + 12 * i, 15))
			enemy.set_physics_process(false)
			attackers.append(enemy)
		check(attackers.filter(func(x): return x.challenge_target == vault).size() == 2, "only part of the crowd targets the vault")
		var attacker := attackers[2]
		attacker.global_position = vault.global_position + Vector2(38, 0)
		attacker._process_contact_damage()
		check(vault.current_hp < hp, "hostile contact damages the vault")
		var at := vault.global_position
		await frames()
		check(vault.global_position == at, "vault remains stationary")
		if destroy:
			vault.take_enemy_damage(100000)
			check(not vault.alive and not manager.wave_challenges.vault_intact, "destruction records contract failure")
		else:
			await capture("05_vault_defense")
		flow.finish_current_wave()
		await frames(18)
		var expected := principal - 500 if destroy else principal + 150
		check(manager.finance_system.principal == expected, "custody settlement destruction=" + str(destroy))
		manager.process_wave_end_settlements()
		check(manager.finance_system.principal == expected, "custody settlement cannot repeat")
