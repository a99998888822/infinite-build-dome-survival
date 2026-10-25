extends Node
## Disposable directing harness: live evacuation, pickups, buyout and combat.
const HAMMER := "weapon_earth_hammer"
const DAGGER := "weapon_camp_dagger"
const FPS := 60
var take := "night"
var output_dir := ""
var session: RecordingSession
var battle: BattleRoot
var player: PlayerController
var controller: ActiveCombatController
var phase: NightEvacuation
var popup: FinancePopup
var camera: Camera2D
var origin := Vector2.ZERO
var aim := Vector2.ZERO
var frame := -1
var total := 600
var hitstop_end := -1
var failures: Array[String] = []
var enemies: Array[EnemyController] = []
var offer: Dictionary = {}
var kills := 0
var report := {"fps": FPS, "events": [], "samples": [], "enemy_damage": [], "staged": true,
	"controls": "right-click move, number key select, left-click cast", "sfx_percent": 100, "bgm_percent": 0}


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--take="): take = arg.trim_prefix("--take=")
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
	if take not in ["night", "sale", "cost"] or output_dir.is_empty() or not "--transient-session" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	total = 600 if take == "night" else (480 if take == "sale" else 210)
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	seed(10252026)
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
	config.merge({"wave": 1 if take == "night" else 6, "gold": 12, "principal": 0,
		"level": 10, "countdown": 0, "hud": true, "relics": [],
		"weapons": [{"id": HAMMER, "level": 3 if take == "night" else 5,
			"attachments": [] if take == "night" else ["scroll_multishot", "scroll_electric_spark", "scroll_wisdom"]},
			{"id": DAGGER, "level": 1, "attachments": []}]}, true)
	report.config = config
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		await _finish()
		return
	check(session.begin(), "Could not start recording session")
	battle = session.battle
	player = battle.player
	controller = battle.active_controller
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	controller.set_process(false)
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	if take == "night":
		await _prepare_night()
	else:
		await _prepare_sale()
		if take == "cost" and failures.is_empty():
			popup.trade_presentation._yes.pressed.emit()
			await frames(5)
			_verify_sale()
			popup._request_next_wave()
			await frames(3)
			if session.flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
				session.flow.decide_wave_challenge(str(battle.wave_manager.wave_challenges.offer.token), false)
			await frames(35)
			await _prepare_cost()
	if not failures.is_empty():
		await _finish()
		return
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
		if take == "night": _night_beat()
		elif take == "sale": _sale_beat()
		else: _cost_beat()
		if take != "sale":
			_point(aim)
			controller._update_indicator()
			controller._update_cursor_icon()
			battle.hud._refresh_wave_display()
			_update_bar()
		if frame % 15 == 0:
			var sample := {"frame": frame, "hp": player.current_hp, "gold": battle.wave_manager.current_gold,
				"position": [player.global_position.x, player.global_position.y], "kills": kills}
			if phase != null:
				sample.merge({"distance_to_shelter": phase.distance_to_shelter(), "night": phase.night_progress(), "elapsed": phase.elapsed})
			report.samples.append(sample)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame % 60 == 0 or frame in [89, 139, 329, 340, 385] or frame == total - 1:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	if take == "night":
		check(phase.active and phase.extracted_count == 0, "Player must choose to stay outside shelter")
		check(battle.wave_manager.current_gold > int(report.gold_start), "The detour must collect real gold")
		var nearest := INF
		for row in report.samples: nearest = minf(nearest, row.distance_to_shelter)
		check(nearest < 45 and phase.distance_to_shelter() > nearest + 200, "Approach and reversal must be visible")
		check(phase.night_progress() > 0.95, "Night should fully descend")
	elif take == "sale": _verify_sale()
	else:
		check(battle.loadout.weapon_instances.size() == 1 and battle.loadout.weapon_instances[0].weapon_id == DAGGER, "Only the fallback weapon remains")
		check(not report.enemy_damage.is_empty() and kills == 0, "The fallback must hit enemies without clearing the crowd")
	check(player.is_alive(), "Player must remain alive in these pickups")
	await _finish()


func _camera(at: Vector2, zoom: float) -> void:
	if camera == null:
		camera = Camera2D.new()
		player.get_parent().add_child(camera)
	camera.global_position = at
	camera.zoom = Vector2.ONE * zoom
	camera.make_current()


func _clean_hud() -> void:
	for node in [battle.hud.stats_drawer, battle.hud._weapon_damage_meter, battle.hud._performance_line,
		battle.hud._economy_log_layer, battle.hud.exp_panel, battle.hud._wave_toast]:
		if is_instance_valid(node): node.hide()
	battle.hud.set_process(false)


func _prepare_night() -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	phase = battle.wave_manager.evacuation
	phase.rng.seed = 432101
	battle.wave_manager.wave_time_left = 0
	phase.begin()
	origin = phase.ring_center
	player.global_position = origin + Vector2(350, 230)
	player._clear_move_input()
	phase.previous_foot = phase.foot_position()
	_camera(origin + Vector2(225, 50), 1.15)
	# Stage the initial scattered pursuers before the first recorded frame.
	phase.active = false
	battle.wave_manager.cleanup_active = false
	battle.wave_manager.wave_time_left = 1.0
	var points := [Vector2(855, 110), Vector2(940, 240), Vector2(820, -85), Vector2(1005, 30),
		Vector2(1010, 450), Vector2(1110, 270), Vector2(1070, -110), Vector2(970, -230)]
	for point in points: _spawn(origin + point)
	phase.active = true
	battle.wave_manager.cleanup_active = true
	battle.wave_manager.wave_time_left = 0.0
	for i in 12:
		battle.wave_manager.spawn_exp_orb(1, origin + Vector2(545 + i * 12, 225 + sin(i * 1.7) * 20))
	await frames(25)
	_clean_hud()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	phase.elapsed = 0.0
	report.shelter = [origin.x, origin.y]
	report.initial_pursuers = enemies.size()
	aim = origin + Vector2(660, 180)


func _night_beat() -> void:
	# Actual evacuation clock, spawn rules and reward processing run at 60 Hz.
	var camera_t := smoothstep(240.0, 450.0, float(frame))
	camera.global_position = origin + Vector2(225, lerpf(50, 180, camera_t))
	battle.wave_manager._process(1.0 / FPS)
	if frame == 0: _move(origin + Vector2(220, 105))
	if frame == 135:
		_event("turn_back_for_coins")
		_move(origin + Vector2(525, 218))
	if frame == 240:
		aim = _nearest_enemy()
		_key(KEY_1)
	if frame == 260: _cast()
	if frame == 300: _move(origin + Vector2(550, 395))
	if frame == 380: _move(origin + Vector2(430, 470))
	if frame == 435:
		aim = _nearest_enemy()
		_key(KEY_2)
	if frame == 450: _cast()
	if frame == 475: _move(origin + Vector2(290, 450))
	if frame == 540: _move(origin + Vector2(245, 345))


func _prepare_sale() -> void:
	# Rehearsal telemetry represents a comfortable completed wave. The offer,
	# valuation, eligibility, removal of the bundle and payment stay production.
	var manager := battle.wave_manager
	manager.wave_challenges.sample_health(8.0, player.current_hp, int(player.get_stat("max_hp")))
	manager._on_enemy_damage_received(HAMMER, 900)
	manager._on_enemy_damage_received(DAGGER, 30)
	session.flow.finish_current_wave()
	await frames(22)
	popup = session.game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.visible, "Bank should be visible")
	if popup == null: return
	popup.interest_arrival.skip()
	manager.goblin_trades._rng.seed = 10252026
	for attempt in 64:
		if str(manager.goblin_trades.offer.get("id", "")) == "weapon_buyout": break
		manager.goblin_trades.preparation_wave = -1
		session.flow._prepare_goblin_trade()
	popup.configure(session.flow.get_preparation_payload())
	popup._select_tab("enchant")
	popup.workbench._select_weapon(HAMMER)
	await frames(12)
	offer = manager.goblin_trades.offer.duplicate(true)
	check(str(offer.get("id", "")) == "weapon_buyout", "Real buyout must be eligible")
	check(str(offer.get("weapon_id", "")) == HAMMER, "Offer must target the strongest weapon")
	if failures.size() > 0: return
	popup.trade_presentation.set_process(false)
	popup.trade_presentation.seek(0.0)
	popup.portrait.set_process(false)
	popup._tooltip.hide()
	get_viewport().gui_release_focus()
	report.offer = offer
	report.before_weapons = battle.loadout.weapon_instances.map(func(w): return w.weapon_id)
	report.eligibility_fixture = {"observed_seconds": 8, "damage": manager.weapon_damage_this_wave.duplicate()}


func _sale_beat() -> void:
	var presentation := popup.trade_presentation
	# Leave the authentic speech visible during the short hesitation.
	if frame < 330: presentation.seek(minf(float(frame) / FPS, 4.65))
	popup.portrait._elapsed = float(frame) / FPS
	popup.portrait.expression = 0 if frame < 45 else (3 if frame < 330 else 4)
	popup.portrait.queue_redraw()
	if frame == 285: _ui_point(presentation._no.get_global_rect().get_center())
	if frame == 310: _ui_point(presentation._yes.get_global_rect().get_center())
	if frame == 330:
		_ui_click(presentation._yes)
		_event("accept_buyout", {"amount": offer.amount})
	if frame == 345:
		popup.workbench.refresh()
		popup.workbench._select_weapon(DAGGER)


func _verify_sale() -> void:
	check(battle.loadout.get_weapon_instance(HAMMER) == null, "Hammer must actually be sold")
	check(battle.loadout.weapon_instances.size() == 1, "Keep only one fallback weapon")
	check(battle.wave_manager.goblin_trades.accepted_waves.has("weapon_buyout"), "Accepted buyout must be recorded")
	check(battle.wave_manager.current_gold == 12 + int(offer.amount), "Exact quoted gold must arrive")
	check(player.item_inventory.get_available_items().is_empty(), "The sold enchantments must also leave inventory")
	report.sold_bundle = true
	report.after_weapons = battle.loadout.weapon_instances.map(func(w): return w.weapon_id)


func _prepare_cost() -> void:
	check(session.flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "After sale the next wave must start")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	player.global_position = Vector2(0, -190)
	player._clear_move_input()
	origin = player.global_position
	_camera(origin + Vector2(70, -20), 1.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87123
	for point in [Vector2(155, 5), Vector2(210, -65), Vector2(220, 80)]: _spawn(origin + point)
	for i in 15:
		var theta := rng.randf_range(-1.6, 1.6)
		_spawn(origin + Vector2.RIGHT.rotated(theta) * rng.randf_range(280, 450))
	await frames(15)
	_clean_hud()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	aim = _nearest_enemy()


func _cost_beat() -> void:
	if frame == 0:
		_move(origin + Vector2(-45, 30))
		_key(KEY_1)
	if frame == 65:
		aim = _nearest_enemy()
		_cast()
	if frame == 90: _move(origin + Vector2(-160, 80))
	if frame == 155: _move(origin + Vector2(-270, 15))


func _spawn(point: Vector2) -> void:
	var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", point)
	check(enemy != null, "Could not stage pursuer")
	if enemy != null:
		enemies.append(enemy)
		enemy.died.connect(func(_enemy, _drop, _position): kills += 1)
		enemy.damage_received.connect(func(source: String, amount: int):
			report.enemy_damage.append({"frame": frame, "source": source, "amount": amount, "remaining": enemy.current_hp}))


func _nearest_enemy() -> Vector2:
	var target := player.global_position + Vector2(200, 0)
	var closest := INF
	for enemy in EnemyRegistry.get_registered_enemies():
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		var distance: float = enemy.global_position.distance_squared_to(player.global_position)
		if distance < closest:
			closest = distance
			target = enemy.global_position
	return target


func _event(action: String, data := {}) -> void:
	data.merge({"frame": frame, "action": action}, true)
	report.events.append(data)


func _point(target: Vector2) -> void:
	var world := player.get_viewport()
	controller._has_pointer_position = true
	controller._pointer_position = (world.get_canvas_transform() * target) * get_viewport().get_visible_rect().size / world.get_visible_rect().size


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	for pressed in [true, false]:
		event.pressed = pressed
		controller._unhandled_input(event)
	_event("key", {"keycode": code})


func _click(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = controller._pointer_position
	for pressed in [true, false]:
		event.pressed = pressed
		controller._input(event)
		controller._unhandled_input(event)
	_event("click", {"button": button})


func _move(target: Vector2) -> void:
	_point(target)
	_click(MOUSE_BUTTON_RIGHT)
	_event("move", {"target": [target.x, target.y]})


func _cast() -> void:
	_point(aim)
	var weapon := controller.selected_weapon
	check(weapon != null and battle.loadout.active_casting.can_cast(weapon), "Weapon must be ready")
	_click(MOUSE_BUTTON_LEFT)
	_event("cast")


func _ui_point(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	get_viewport().push_input(event, true)


func _ui_click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	_ui_point(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)


func _update_bar() -> void:
	for i in battle.loadout.weapon_instances.size():
		var weapon := battle.loadout.weapon_instances[i]
		var state := battle.loadout.active_casting.state_for(weapon)
		battle.hud.combat_bar.update_slot(i, float(state.remaining), float(state.total), bool(state.executing), controller.selected_weapon == weapon)


func _on_hitstop(tier: int, _count: int) -> void:
	if not CombatHitFeedback._owns_pause: return
	hitstop_end = frame + ceili(CombatHitFeedback.HITSTOP_SECONDS[tier] * FPS)
	CombatHitFeedback.hitstop_until_usec = Time.get_ticks_usec() + 3600000000


func _finish() -> void:
	report.merge({"take": take, "frames": total, "failures": failures, "kills": kills}, true)
	if player != null:
		report.hp_end = player.current_hp
		report.gold_end = battle.wave_manager.current_gold
	report.audio = {"sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),
		"bgm_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), "bgm_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM"))}
	FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("GREED_PROMO_DONE ", take, " failures=", failures.size(), " kills=", kills)
	CombatHitFeedback.clear()
	for voice in AudioManager._sfx_players:
		voice.stop()
		voice.stream = null
	enemies.clear()
	if is_instance_valid(session): await session.dispose()
	await frames(5)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
