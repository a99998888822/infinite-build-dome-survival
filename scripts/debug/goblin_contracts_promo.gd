extends "res://scripts/debug/greed_promo.gd"
## Disposable staging only. Loans, contracts, AI, damage and input stay live.
var challenge: WaveChallengePopup
var shop_card: PreparationOfferCard
var purchase: Dictionary = {}
var wolf: UnderworldWolf
var vault: ChallengeVault
var finger: TextureRect
var finger_point := Vector2.ZERO
var finger_press := -100
var finger_button: Button
var challenge_frame := -1
var vault_min_hp := 9999
var rescue_cast := false


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--take="): take = arg.trim_prefix("--take=")
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
	if take not in ["debt_bank", "debt_fight", "vault_offer", "vault_rescue"] or output_dir.is_empty() or not "--transient-session" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	total = {"debt_bank": 510, "debt_fight": 300, "vault_offer": 240, "vault_rescue": 360}[take]
	_run.call_deferred()


func _run() -> void:
	seed(10262026)
	get_tree().node_added.connect(func(node: Node):
		if node is CavernPopulationBackdrop: node.population_seed = 20261024)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	CombatSettings.set_option("show_hints", false, false)
	for id in [HAMMER, DAGGER]: CombatSettings.set_weapon_auto_cast(id, false, false)
	for bus in [AudioManager.BUS_MASTER, AudioManager.BUS_SFX]:
		AudioManager.set_bus_volume(bus, 100, false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), false)
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 0, false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_BGM), true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"entry": "bank", "wave": 4, "gold": 0, "principal": 2000 if take.begins_with("vault") else 0,
		"level": 10, "countdown": 0, "hud": true, "relics": [],
		"weapons": [{"id": HAMMER, "level": 5, "attachments": ["scroll_water", "scroll_ice"]},
			{"id": DAGGER, "level": 1, "attachments": []}]}, true)
	report.config = config
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		await _finish()
		return
	check(session.begin(), "Bank session must start")
	battle = session.battle
	player = battle.player
	controller = battle.active_controller
	battle.wave_manager.set_process(false)
	controller.set_process(false)
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	await frames(24)
	popup = session.game.find_child("FinancePopup", true, false) as FinancePopup
	challenge = session.game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	check(popup != null and popup.visible and challenge != null, "Production finance/challenge UI must exist")
	if not failures.is_empty():
		await _finish()
		return
	popup.interest_arrival.skip()
	session.flow.cancel_goblin_trade()
	popup.configure(session.flow.get_preparation_payload())
	popup._select_tab("shop")
	await frames(10)
	if take.begins_with("debt"):
		for card: PreparationOfferCard in popup.shop_grid._pool:
			if card.is_visible_in_tree() and card.buy_button.disabled and session.flow.get_offer_unavailable_reason(card.offer) == "insufficient_gold" and int(card.offer.get("shop_cost", 9999)) <= 500:
				shop_card = card
				break
		check(shop_card != null, "A real unaffordable shop offer must be visible")
		if shop_card != null:
			purchase = shop_card.offer.duplicate(true)
			report.purchase = purchase
		if take == "debt_fight" and failures.is_empty():
			for i in 3:
				_ui_click(shop_card.buy_button)
				await frames(2)
			check(popup.loan_presentation.is_active(), "Third failed purchase must open loan")
			_ui_click(popup.loan_presentation._cards[2].button)
			await frames(3)
			_verify_loan()
			_buy_item()
			await frames(3)
			_open_contract("debt_hunter")
			await frames(5)
			_ui_click(challenge.presentation._yes)
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			await frames(5)
			await _prepare_debt_fight()
	else:
		_open_contract("capital_custody")
		await frames(6)
		if take == "vault_rescue":
			_ui_click(challenge.presentation._yes)
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			await frames(5)
			await _prepare_vault_rescue()
	if not failures.is_empty():
		await _finish()
		return
	_make_finger()
	popup._tooltip.hide()
	get_viewport().gui_release_focus()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for voice in AudioManager._sfx_players: voice.stop()
	CombatHitFeedback.feedback_started.connect(_on_hitstop)
	report.gold_start = battle.wave_manager.current_gold
	report.hp_start = player.current_hp
	report.start_frame = Engine.get_frames_drawn()
	for i in total:
		frame = i
		if hitstop_end >= 0 and frame >= hitstop_end:
			CombatHitFeedback.hitstop_until_usec = 0
			hitstop_end = -1
		match take:
			"debt_bank": _debt_bank_beat()
			"debt_fight": _debt_fight_beat()
			"vault_offer": _vault_offer_beat()
			"vault_rescue": _vault_rescue_beat()
		_update_finger()
		if take in ["debt_fight", "vault_rescue"]:
			_point(aim)
			controller._update_indicator()
			controller._update_cursor_icon()
			battle.hud._refresh_wave_display()
			_update_bar()
		if frame % 5 == 0: _sample()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame % 30 == 0 or frame == total - 1:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	check(player.is_alive(), "Player must survive")
	check(str(battle.wave_manager.wave_challenges.active.get("id", "")) == ("debt_hunter" if take.begins_with("debt") else "capital_custody"), "The shown contract must actually be accepted")
	if take.begins_with("debt"):
		check(int(battle.wave_manager.goblin_loans.debt.get("due", 0)) == 600, "Live debt remains 600 before the target is defeated")
	else:
		check(battle.wave_manager.finance_system.principal == 1800, "Real contract must stake 200 principal")
	if take == "vault_rescue":
		check(is_instance_valid(vault) and vault.alive, "Vault must survive the rescue")
		check(kills > 0 and not report.enemy_damage.is_empty(), "Defense must damage and kill real attackers")
		check(phase.extracted_count == 0 and phase.active, "Player must remain outside to defend the stake")
		report.vault_min_hp = vault_min_hp
		report.vault_max_hp = vault.max_hp
	report.contract = battle.wave_manager.wave_challenges.active.duplicate(true)
	report.principal_end = battle.wave_manager.finance_system.principal
	await _finish()


func _open_contract(id: String) -> void:
	var system := battle.wave_manager.wave_challenges
	var definition := system.definition(id)
	if id == "debt_hunter": definition.boss_templates = ["enemy_underworld_wolf"]
	else: system.pressure = {"struggling": true, "observed_seconds": 8.0, "low_health_seconds": 6.0}
	# Restrict only this transient shot's candidate pool; eligibility stays live.
	system.config.challenges = [definition]
	session.flow.close_finance_popup()
	check(session.flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE, "Eligible contract must reach production modal")
	check(str(challenge.proposal.get("id", "")) == id, "Correct contract must be presented")
	challenge.presentation.set_process(false)
	challenge.presentation.seek(0.0)
	challenge_frame = frame
	report.offer = challenge.proposal.duplicate(true)
	report.eligibility_fixture = {"candidate": id, "pressure": system.pressure.duplicate(true)}
	get_viewport().gui_release_focus()


func _verify_loan() -> void:
	check(battle.wave_manager.current_gold == 500, "Borrowing must credit exactly 500 real gold")
	check(int(battle.wave_manager.goblin_loans.debt.get("due", 0)) == 600, "Borrowing must create real 600 debt")
	_event("borrow_500", {"debt": 600, "gold": battle.wave_manager.current_gold})


func _find_purchase_card() -> PreparationOfferCard:
	for card: PreparationOfferCard in popup.shop_grid._pool:
		if card.is_visible_in_tree() and str(card.offer.get("offer_id", "")) == str(purchase.get("offer_id", "")): return card
	return null


func _buy_item() -> void:
	var card := _find_purchase_card()
	check(card != null and not card.buy_button.disabled, "Borrowed gold must make the same purchase affordable")
	if card != null:
		_ui_click(card.buy_button)
		_event("purchase", {"offer": purchase, "gold_after": battle.wave_manager.current_gold})


func _debt_bank_beat() -> void:
	if frame in [12, 42, 72]: _cue(shop_card.buy_button, 12)
	if frame == 88: check(popup.loan_presentation.is_active(), "Third real disabled click must reveal loan")
	if frame == 182: _cue(popup.loan_presentation._cards[2].button, 18)
	if frame == 204: _verify_loan()
	if frame == 224:
		var card := _find_purchase_card()
		check(card != null, "Purchased offer must remain visible")
		if card != null: _cue(card.buy_button, 16)
	if frame == 245:
		check(battle.wave_manager.current_gold == 500 - int(purchase.shop_cost), "Shop must deduct exact quoted price")
		_event("purchase", {"gold_after": battle.wave_manager.current_gold})
	if frame == 270: _cue(popup.start_button, 15)
	if frame == 285:
		# The real button can display an unused-item notice; this purchase is a
		# weapon/relic, and the ordinary close method runs the same transition.
		var system := battle.wave_manager.wave_challenges
		var definition := system.definition("debt_hunter")
		definition.boss_templates = ["enemy_underworld_wolf"]
		system.config.challenges = [definition]
	if frame == 288:
		check(session.flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE, "Start button must open debt challenge")
		challenge.presentation.set_process(false)
		challenge.presentation.seek(0)
		challenge_frame = frame
		report.offer = challenge.proposal.duplicate(true)
	if frame >= 288 and frame < 495: challenge.presentation.seek(minf((frame - challenge_frame) / 60.0, 4.6))
	if frame == 477: _cue(challenge.presentation._yes, 18)
	if frame == 496:
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		_event("accept_debt_challenge")


func _vault_offer_beat() -> void:
	challenge.presentation.seek(minf(frame / 60.0, 4.6))
	if frame == 207: _cue(challenge.presentation._yes, 18)
	if frame == 226:
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		_event("stake_principal", {"before": 2000, "after": battle.wave_manager.finance_system.principal})


func _prepare_debt_fight() -> void:
	for enemy in EnemyRegistry.get_registered_enemies():
		if enemy.has_meta("debt_challenge_target"): wolf = enemy as UnderworldWolf
		else: enemy.queue_free()
	check(wolf != null, "Production challenge must spawn the marked wolf")
	if wolf == null: return
	origin = Vector2(0, -150)
	player.global_position = origin + Vector2(-190, 80)
	player._clear_move_input()
	wolf.global_position = origin + Vector2(250, -50)
	wolf.state = "spawn"
	wolf.state_time = 0
	wolf.sprite.hide()
	_camera(origin + Vector2(20, -10), 1.4)
	for point in [Vector2(370, 90), Vector2(420, -180), Vector2(540, 180), Vector2(-80, -280)]: _spawn(origin + point)
	await frames(15)
	_clean_hud()
	aim = wolf.global_position
	report.wolf_max_hp = wolf.current_hp
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)


func _debt_fight_beat() -> void:
	if frame == 0: _move(origin + Vector2(-130, 70))
	if frame == 70:
		aim = wolf.global_position
		_key(KEY_1)
	if frame == 94: _cast()
	if frame == 124: _move(origin + Vector2(-200, 245))
	if frame == 195: _move(origin + Vector2(-350, 150))
	if frame == 240: _move(origin + Vector2(-340, -30))


func _prepare_vault_rescue() -> void:
	vault = battle.wave_manager.challenge_vault
	check(vault != null and vault.alive, "Real accepted stake must spawn vault")
	if vault == null: return
	for enemy in EnemyRegistry.get_registered_enemies(): enemy.queue_free()
	await frames(2)
	phase = battle.wave_manager.evacuation
	phase.rng.seed = 432101
	battle.wave_manager.wave_time_left = 0
	phase.begin()
	origin = phase.ring_center
	player.global_position = origin + Vector2(350, 230)
	player._clear_move_input()
	phase.previous_foot = phase.foot_position()
	vault.global_position = origin + Vector2(510, 205)
	_camera(origin + Vector2(280, 100), 1.2)
	phase.active = false
	battle.wave_manager.cleanup_active = false
	battle.wave_manager.wave_time_left = 1
	battle.wave_manager._vault_attacker_counter = 0
	for point in [Vector2(790, 60), Vector2(835, 330), Vector2(510, -30), Vector2(920, -35), Vector2(980, 390), Vector2(990, 260), Vector2(1060, 60), Vector2(1030, 485), Vector2(1130, 200)]: _spawn(origin + point)
	phase.active = true
	battle.wave_manager.cleanup_active = true
	battle.wave_manager.wave_time_left = 0
	await frames(15)
	_clean_hud()
	phase.elapsed = 0
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	aim = vault.global_position + Vector2(130, 0)
	report.shelter = [origin.x, origin.y]
	report.vault_position = [vault.global_position.x, vault.global_position.y]


func _vault_rescue_beat() -> void:
	battle.wave_manager._process(1.0 / FPS)
	vault_min_hp = mini(vault_min_hp, vault.current_hp)
	if frame == 0: _move(origin + Vector2(220, 105))
	if frame == 112:
		_event("turn_back_to_defend_principal")
		_move(origin + Vector2(415, 245))
	if frame == 160:
		aim = vault.global_position + Vector2(20, -8)
		_key(KEY_1)
	if frame == 182:
		_cast()
		rescue_cast = true
	if frame == 230: _move(origin + Vector2(475, 340))
	if frame == 275:
		aim = _nearest_enemy()
		_key(KEY_2)
	if frame == 288: _cast()
	if frame == 315: _move(origin + Vector2(400, 310))


func _sample() -> void:
	var data := {"frame": frame, "hp": player.current_hp, "gold": battle.wave_manager.current_gold, "principal": battle.wave_manager.finance_system.principal,
		"position": [player.global_position.x, player.global_position.y], "kills": kills}
	if wolf != null:
		data.wolf_state = wolf.state
		data.wolf_hp = wolf.current_hp
	if vault != null:
		data.vault_hp = vault.current_hp
		data.distance_to_shelter = phase.distance_to_shelter()
		data.attackers = []
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.is_alive() and enemy.challenge_target == vault:
				data.attackers.append({"distance": enemy.global_position.distance_to(vault.global_position), "hp": enemy.current_hp})
	report.samples.append(data)


func _make_finger() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	finger = TextureRect.new()
	finger.texture = preload("res://assets/ui/icons/cast_manual.svg")
	finger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	finger.size = Vector2(64, 64)
	finger.self_modulate = Color("ddbe79")
	finger.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finger.hide()
	layer.add_child(finger)


func _cue(button: Button, delay: int) -> void:
	finger_button = button
	finger_point = button.get_global_rect().get_center()
	finger_press = frame + delay


func _update_finger() -> void:
	var age := frame - finger_press
	finger.visible = age >= -20 and age < 22
	if not finger.visible: return
	var amount := 1.0 - 0.18 * clampf(1.0 - absf(age / 7.0), 0, 1)
	finger.scale = Vector2.ONE * amount
	finger.position = finger_point - Vector2(27.2, 8) * amount + Vector2(0, maxf(0, -age) * 0.5)
	finger.modulate.a = minf(clampf((age + 20) / 8.0, 0, 1), clampf((22 - age) / 8.0, 0, 1))
	if age == 0 and is_instance_valid(finger_button):
		_ui_click(finger_button)
		_event("finger_press", {"button": finger_button.text})


func _finish() -> void:
	for presentation in [challenge.presentation if challenge != null else null, popup.loan_presentation if popup != null else null]:
		if presentation != null:
			presentation.set_process(false)
			presentation._audio.stop()
			presentation._audio.stream = null
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	# Release decoder playback before disposing the transient game at fast FPS.
	await frames(3)
	OS.delay_msec(180)
	await super._finish()
