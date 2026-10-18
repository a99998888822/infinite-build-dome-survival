extends "res://scripts/tests/reaction_block_visual_review.gd"
## Task-owned review: production casts / UI, transient save, silent private desktop.
var sound_events: Array = []
var sound_players: Array = []
var sound_positions: Dictionary = {}
var recording := false
var clip_start := 0
var popup: FinancePopup

func _run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	AudioManager.combat_sfx_played.connect(_sound)
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	for entry: Dictionary in cases:
		if not only.is_empty() and str(entry.id) != only: continue
		await _setup(entry)
		Engine.max_fps = 60
		caption.get_parent().hide()
		game.get_node("UiRoot/MainMenuUIController").hide()
		battle.hud._set_drawer_open(false, false)
		if entry.id == "reflection":
			for enemy in enemies:
				enemy.apply_wet(5.0, 0.8)
				enemy.apply_light(5.0)
		if entry.has("weapon"):
			weapon = WeaponInstance.new()
			weapon.initialize(str(entry.weapon), player)
			weapon.principal_getter = Callable(battle.loadout, "get_current_principal")
			battle.loadout.weapon_instances.append(weapon)
			weapon.active_cooldown_ms = 350
		if entry.get("ui", "") in ["bank_deposit", "bank_withdraw", "trade", "interest"]:
			var manager := battle.wave_manager
			manager.apply_gold_delta(2000, "review_fixture")
			manager.finance_system.deposit(1000, true, "review_fixture")
			game.get_main_flow_coordinator().finish_current_wave()
			await frames(15)
			popup = game.find_child("FinancePopup", true, false) as FinancePopup
			popup.interest_arrival.skip()
			popup._select_tab("shop")
		await frames(6)
		var directory := output.path_join(str(entry.id))
		DirAccess.make_dir_recursive_absolute(directory)
		sound_events.clear()
		sound_positions.clear()
		sound_players.clear()
		_find_players(get_tree().root)
		clip_start = Time.get_ticks_usec()
		recording = true
		var stamps: Array = []
		var images: Array[Image] = []
		var action_index := 0
		var next_capture := 0.0
		while float(Time.get_ticks_usec()-clip_start)/1e6 < float(entry.get("seconds", 4.0)):
			await get_tree().process_frame
			current_time = float(Time.get_ticks_usec()-clip_start)/1e6
			while action_index < entry.actions.size() and current_time >= float(entry.actions[action_index].time):
				if entry.has("ui"): _ui_action(str(entry.ui), action_index)
				else: _cast(entry.actions[action_index])
				action_index += 1
			_poll_players()
			if not no_capture and DisplayServer.get_name() != "headless" and current_time >= next_capture:
				await RenderingServer.frame_post_draw
				var frame := get_tree().root.get_texture().get_image()
				if not entry.has("ui"):
					frame = frame.get_region(Rect2i(250, 100, 720, 490))
				else:
					frame.resize(960, 540, Image.INTERPOLATE_LANCZOS)
				images.append(frame)
				stamps.append(float(Time.get_ticks_usec()-clip_start)/1e6)
				next_capture = current_time + 1.0/16.0
		recording = false
		for index in images.size(): images[index].save_png(directory.path_join("%04d.png" % index))
		var row := {"id":entry.id,"frames":stamps,"sounds":sound_events.duplicate(true),"fixture":"Production runtime; fixed durable targets and scripted inputs; no live audio recording"}
		FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(row,"\t"))
		summary.append(row)
		print("SFX_CAPTURE ",entry.id," frames=",images.size()," events=",sound_events.size())
		await _cleanup()
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	CampProgression.end_transient_session()
	get_tree().quit(0)

func _sound(cue: String, path: String) -> void:
	if recording:
		sound_events.append({"time":float(Time.get_ticks_usec()-clip_start)/1e6,"cue":cue,"path":path})

func _find_players(node: Node) -> void:
	if node is AudioStreamPlayer: sound_players.append(node)
	for child in node.get_children(): _find_players(child)

func _poll_players() -> void:
	for audio in sound_players:
		if not is_instance_valid(audio) or audio.bus in ["BGM", "CombatSFX"]: continue
		var key: int = audio.get_instance_id()
		if not audio.playing or audio.stream == null:
			sound_positions.erase(key)
			continue
		var path: String = audio.stream.resource_path
		var pos: float = audio.get_playback_position()
		var before: Dictionary = sound_positions.get(key,{})
		if before.is_empty() or before.path != path or pos < float(before.pos):
			sound_events.append({"time":float(Time.get_ticks_usec()-clip_start)/1e6,"path":path,"gain_db":audio.volume_db,"pitch":audio.pitch_scale})
		sound_positions[key] = {"path":path,"pos":pos}

func _ui_action(kind: String, index: int) -> void:
	if kind == "drawer":
		battle.hud._set_drawer_open(index == 0, true)
	elif kind in ["bank_deposit", "bank_withdraw"]:
		popup._choose_bank_action(kind.trim_prefix("bank_"))
		popup.amount_input.text = "100"
		popup._submit_bank()
	elif kind == "trade":
		var trade := battle.wave_manager.goblin_trades.definition("interest_pact")
		popup.present_trade(str(trade.get("speech", "")), str(trade.get("body", "")))
	elif kind == "interest":
		var receipt := InterestArrivalReport.build({"combat_gold_earned":120,"settlement_results":[{"success":true,"settlement_id":"sfx_review","wave_number":1,"principal_before":1000,"interest_rate":8,"interest_rate_after":8,"base_gain":80,"nominal_gain":160,"gain":160,"source":"wave_end","dividend_double_triggered":true,"dividend_multiplier":2}]})
		popup.interest_arrival.present(receipt)
	elif kind == "settlement":
		game.get_node("UiRoot/MainMenuUIController").show()
		battle.wave_manager.run_statistics.record_combat_gold(1200)
		battle.wave_manager.run_statistics.complete_wave(1)
		player._invincibility_timer = 0
		player.take_damage(999999,"review")
