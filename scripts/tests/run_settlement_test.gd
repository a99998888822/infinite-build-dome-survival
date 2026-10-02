extends Node

class FailingSave:
	extends "res://autoloads/camp_progression.gd"
	func save_state() -> bool: return false

var checks := 0
var failures := 0
var completed := false
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	_rules()
	await _live()
	check(completed, "all live assertions reached")
	if is_instance_valid(game): game.queue_free()
	AudioManager.stop_bgm()
	await frames()
	print("RUN_SETTLEMENT_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _rules() -> void:
	var config := RunSettlement.configuration()
	for value in config.formula.values(): check(float(value) > 0, "positive settlement formula coefficient")
	var last_time := -1.0
	for time in config.presentation.stage_times:
		check(float(time) > last_time, "ordered animation stages")
		last_time = float(time)
	for reaction in config.reactions:
		var voice_path := str(config.reactions[reaction].get("voice_path", "")).strip_edges()
		check(voice_path.is_empty() or ResourceLoader.exists(voice_path, "AudioStream"), "optional voice configured " + reaction)
	var s := RunStatistics.new()
	check(s.record_kill(10, "enemy_mutated_grub") and not s.record_kill(10, "enemy_mutated_grub"), "duplicate death counted once")
	s.record_kill(11, "enemy_elite_rusher")
	s.record_combat_gold(500)
	s.record_combat_gold(-300)
	s.complete_wave(1)
	s.complete_wave(1)
	s.complete_wave(2)
	s.record_interest({"event_id": "a", "success": true, "gain": 50})
	s.record_interest({"event_id": "a", "success": true, "gain": 50})
	s.record_interest({"event_id": "b", "success": true, "gain": 25})
	s.record_interest({"event_id": "c", "success": false, "gain": 100})
	check(s.kills == 2 and s.monsters.size() == 2 and s.combat_gold == 500 and s.interest == 75 and s.completed_waves == 2, "independent cumulative counters and event deduplication")
	s.decide_advice("trade", "unseen", true)
	check(not s.snapshot().has_advice, "unshown advice never contributes a decision")
	s.show_advice("trade", "1")
	s.show_advice("trade", "1")
	s.decide_advice("trade", "1", true)
	s.decide_advice("trade", "1", false)
	s.show_advice("challenge", "1")
	s.decide_advice("challenge", "1", false)
	check(s.snapshot().accepted == 1 and s.snapshot().refused == 1 and not s.snapshot().followed, "trade and challenge namespaced, ties use last decision")
	s.show_advice("trade", "2")
	s.decide_advice("trade", "2", true)
	check(s.snapshot().followed, "majority accepted selects followed reaction")
	var frozen := s.freeze()
	s.record_kill(12, "enemy_mutated_grub")
	s.record_combat_gold(999)
	s.complete_wave(3)
	s.record_interest({"event_id": "late", "success": true, "gain": 500})
	check(s.snapshot() == frozen, "frozen result rejects late combat and finance events")
	var before_id := s.run_id
	s.reset()
	check(s.run_id != before_id and s.kills == 0 and s.interest == 0 and not s.frozen and not s.snapshot().has_advice, "new run resets all statistics and identity")
	var example := {"kills": 1800, "gold": 2500, "waves": 8, "interest": 1600, "has_advice": true, "followed": true}
	var report := RunSettlement.build(example, false)
	check(report.camp_currency == 497 and report.reaction == "death_followed", "reviewed death example awards 497")
	example.interest = 40000
	report = RunSettlement.build(example, false)
	check(report.camp_currency == 625 and report.interest_capped and report.interest == 40000, "only camp contribution capped, actual interest intact")
	example.followed = false
	check(RunSettlement.build(example, true).camp_currency == 625 and RunSettlement.build(example, true).reaction == "victory_refused", "victory and obedience do not multiply payout")
	check(RunSettlement.build({}, false).camp_currency == 0 and RunSettlement.build({}, false).reaction == "", "zero income and no advice produce no accusation")
	var balance := CampProgression.get_camp_currency()
	check(CampProgression.apply_final_settlement(497, "test-receipt"), "receipt stored successfully")
	check(CampProgression.apply_final_settlement(497, "test-receipt") and CampProgression.get_camp_currency() == balance + 497, "duplicate persisted receipt never pays twice")
	check(not CampProgression.apply_final_settlement(999, "test-receipt"), "conflicting amount for claimed run rejected")
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(CampProgression.get_state()))
	var migrated: Dictionary = CampProgression._merge_state(CampProgression._build_default_state(), round_trip)
	check(migrated.run_settlements["test-receipt"] == 497, "settlement IDs survive save serialization and migration")
	var failed := FailingSave.new()
	failed.state = failed._build_default_state()
	check(not failed.apply_final_settlement(100, "failed") and failed.get_camp_currency() == 0 and not failed.state.get("run_settlements", {}).has("failed"), "failed persistence rolls back currency and receipt")
	failed.free()


func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()


func _live() -> void:
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames()
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "real first wave started")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.add_exp_and_gold(0, 500)
	var combat_gold := manager.collected_gold_this_wave
	var enemy := manager.spawn_enemy("enemy_mutated_grub", Vector2(5000, 5000))
	manager._on_enemy_died(enemy, "drop_basic_enemy", enemy.position)
	manager._on_enemy_died(enemy, "drop_basic_enemy", enemy.position)
	check(manager.run_statistics.kills == 1, "real enemy callback deduplicates drops and kills")
	manager.collect_all_exp_orbs()
	combat_gold = manager.collected_gold_this_wave
	manager.finance_system.deposit(200)
	var first := manager.finance_system.settle_interest("test")
	var second := manager.finance_system.settle_interest("test")
	var earned := int(first.gain) + int(second.gain)
	manager._on_interest_settled(first)
	manager.apply_gold_delta(100, "goblin_trade")
	manager.apply_gold_delta(100, "sale")
	check(earned > 0 and first.event_id != second.event_id and manager.run_statistics.interest == earned, "same-wave interest payments have unique event IDs, replay ignored")
	check(manager.run_statistics.combat_gold == combat_gold, "interest, gifts, sales and deposits excluded from combat gold")
	var pact := manager.goblin_trades.definition("interest_pact")
	pact.minimum_sanity = 0
	manager.goblin_trades.config.trades = [pact]
	flow.finish_current_wave()
	await frames(18)
	check(manager.run_statistics.completed_waves == 1 and flow.current_state == flow.STATE_FINANCE_POPUP, "completed wave counted after absorption and interest")
	var token := str(manager.goblin_trades.offer.get("token", ""))
	check(not token.is_empty() and flow.accept_goblin_trade(token).success, "visible bank advice accepted")
	check(manager.run_statistics.snapshot().accepted == 1 and not flow.accept_goblin_trade(token).success, "one valid decision for bank advice")
	flow.close_finance_popup()
	await frames()
	check(flow.current_state == flow.STATE_WAVE_CHALLENGE, "challenge is shown before next wave")
	token = str(manager.wave_challenges.offer.token)
	flow.return_from_wave_challenge()
	flow.close_finance_popup()
	check(manager.wave_challenges.offer.token == token and manager.run_statistics.snapshot().refused == 0, "return and reopen preserve pending advice")
	flow.decide_wave_challenge(token, false)
	check(manager.run_statistics.snapshot().refused == 1 and not manager.run_statistics.snapshot().followed, "normal start counts one challenge refusal")
	manager.add_exp_and_gold(0, 30)
	var late_enemy := manager.spawn_enemy("enemy_elite_rusher", Vector2(6000, 6000))
	var interest_before_death := manager.run_statistics.interest
	var gold_before_death := manager.run_statistics.combat_gold
	var balance := CampProgression.get_camp_currency()
	manager.player.take_damage(999999, "settlement_test")
	manager._on_enemy_died(late_enemy, "drop_basic_enemy", late_enemy.position)
	manager._on_exp_orb_collected(null, 0, 500)
	await frames(10)
	var report := flow.current_battle_summary.duplicate(true)
	check(flow.current_state == flow.STATE_BATTLE_RESULT and report.paid and manager.run_statistics.frozen, "death freezes and persists receipt before presentation")
	check(report.kills == 2 and report.waves == 1 and report.interest == interest_before_death and report.gold == gold_before_death, "same-frame kills included, incomplete wave and uncollected gold excluded")
	check(report.reaction == "death_refused" and CampProgression.get_camp_currency() == balance + int(report.camp_currency), "live taunt and four-factor currency payout")
	flow.present_battle_result(true, {"gold": 999999})
	check(flow.current_battle_summary == report and CampProgression.get_camp_currency() == balance + int(report.camp_currency), "duplicate outcome cannot change frozen result or award again")
	var ui := game.find_child("BattleResultPanel", true, false) as RunSettlementPanel
	check(ui != null and ui.visible and not ui.back_button.disabled, "new result UI and return action immediately available")
	var current_portraits := ["res://assets/sprites/enemies/combat/enemy_gloom_mite_idle.png", "res://assets/sprites/enemies/iron_knight/knight_idle.png"]
	check(ui._monster_nodes.size() == 2, "both defeated enemy types have portraits")
	for monster in ui._monster_nodes:
		check(monster.icon.texture.resource_path in current_portraits, "settlement reuses the current combat idle texture")
	check((ui.get_parent() as CanvasLayer).layer > 31, "result covers combat header and journal overlay")
	ui.sound_enabled = false
	ui.set_process(false)
	ui.sound_enabled = true
	ui.seek(0)
	for i in 5:
		ui._process(0.56 if i == 0 else (0.8 if i < 4 else 0.9))
		check(ui._last_stage == i and ui._cue.stream.resource_path.ends_with("stage_%d.wav" % (i + 1)), "stage sound and counter advance " + str(i + 1))
	ui._process(0.8)
	var voice_ok := not ui._voice.playing and ui._voice.stream == null if ui._voice_path.is_empty() else ui._voice.stream != null and ui._voice.stream.resource_path == ui._voice_path
	check(ui._voice_started and voice_ok and ui._speech.visible, "optional goblin audio respects configuration while dialogue stays visible")
	ui.sound_enabled = false
	ui.skip()
	check(not ui._cue.playing and not ui._voice.playing and ui._total_value.text == "+ " + ui._number(int(report.camp_currency)), "skip finishes every number and cancels queued audio")
	ui.present(report)
	check(ui._skipped and ui._elapsed == 20, "same receipt presentation does not restart animation")
	await _capture_variants(ui)
	ui.present(report)
	ui.back_button.grab_focus()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	space = space.duplicate()
	space.pressed = false
	Input.parse_input_event(space)
	await frames()
	check(ui._skipped and flow.current_state == flow.STATE_BATTLE_RESULT, "space skips with return focused without leaving result")
	ui.report.clear()
	ui.present(report)
	await click_at(ui._title.get_global_rect().get_center())
	check(ui._skipped, "blank-area pointer input skips presentation")
	await click_at(ui.back_button.get_global_rect().get_center())
	check(flow.current_state == flow.STATE_START_PAGE and not ui.visible and not ui._voice.playing, "return closes result and stops its sounds")
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	flow.confirm_character_selection()
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	check(manager.run_statistics.kills == 0 and manager.run_statistics.interest == 0 and manager.run_statistics.run_id != report.run_id, "next run starts with fresh statistics")
	# Jump the test fixture to the final combat to exercise its real settlement ordering.
	manager.current_wave_index = DataRegistry.get_table("waves").size() - 1
	flow.current_wave_index = manager.current_wave_index
	manager.finance_system.current_wave_number = manager.current_wave_index + 1
	manager.finance_system.deposit(1000, true, "test")
	manager.add_exp_and_gold(0, 100)
	manager.wave_challenges.active = manager.wave_challenges.definition("all_in")
	manager.wave_challenges.active.wave = manager.current_wave_index + 1
	flow.finish_current_wave()
	await frames(16)
	check(flow.current_victory and flow.current_battle_summary.interest > 0 and manager.current_gold == 0 and manager.finance_system.principal > 1100, "final-wave interest and all-in transfer finish before victory receipt")
	check(flow.current_battle_summary.gold == 100 and flow.current_battle_summary.waves == 1, "fixture counts actual completed waves and earnings despite empty victory wallet")
	completed = true


func _capture_variants(ui: RunSettlementPanel) -> void:
	var sample := {"kills": 1800, "gold": 2500, "waves": 8, "interest": 1600, "has_advice": true, "monsters": {"enemy_mutated_grub": 1782, "enemy_elite_rusher": 18}}
	for victory in [false, true]:
		for followed in [true, false]:
			sample.run_id = str(victory) + str(followed)
			sample.followed = followed
			var receipt := RunSettlement.build(sample, victory)
			receipt.paid = true
			ui.present(receipt)
			ui.skip()
			check(ui._speech_label.text == str(RunSettlement.configuration().reactions[receipt.reaction].speech), "exact goblin text " + receipt.reaction)
			await _capture(ui, receipt.reaction)
	for bounds in [Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(1024, 576), Vector2i(900, 600), Vector2i(640, 360), Vector2i(360, 640)]:
		get_tree().root.size = bounds
		get_tree().root.content_scale_size = bounds
		await frames()
		check(ui.get_global_rect().encloses(ui.back_button.get_global_rect()) and ui._portrait.visible and ui._scroll.get_global_rect().end.y <= ui.back_button.get_global_rect().position.y, "compact/portrait keeps goblin and navigation, scroll excludes footer " + str(bounds))
		check(not ui._scroll.get_v_scroll_bar().visible and not ui._scroll.get_h_scroll_bar().visible, "settlement fits one screen without scrolling " + str(bounds))
		check(ui._scroll.get_global_rect().encloses(ui._total.get_global_rect()) and ui._scroll.get_global_rect().encloses(ui._desk.get_global_rect()), "total and goblin desk fit above the footer " + str(bounds))
		for row in ui._rows:
			check(ui._scroll.get_global_rect().encloses(row.panel.get_global_rect()), "settlement row fits " + str(bounds))
		await _capture(ui, "layout_%dx%d" % [bounds.x, bounds.y])
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	await frames()


func _capture(_ui: RunSettlementPanel, name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "captured " + name)
