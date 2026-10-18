extends "res://scripts/tests/reaction_block_visual_review.gd"
## Real production game, captured by Godot MovieWriter including its mixed audio.
const FPS := 30
var sound_events: Array = []
var clip_frame := 0
var recording := false

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	AudioManager.combat_sfx_played.connect(func(cue, path):
		if recording: sound_events.append({"time": float(Engine.get_process_frames()-clip_frame)/FPS, "cue": cue, "path": path}))
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	for entry: Dictionary in cases:
		if not only.is_empty() and str(entry.id) != only: continue
		await _setup(entry)
		Engine.max_fps = 0
		caption.get_parent().hide()
		game.get_node("UiRoot/MainMenuUIController").hide()
		battle.hud._set_drawer_open(false, false)
		AudioManager.stop_bgm()
		AudioManager.stop_combat_sfx()
		for bus in ["Master", "SFX", "CombatSFX"]:
			var index := AudioServer.get_bus_index(bus)
			AudioServer.set_bus_mute(index, false)
			AudioServer.set_bus_volume_db(index, 0)
		if entry.id == "reflection":
			for enemy in enemies:
				enemy.apply_wet(8.0, 0.8)
				enemy.apply_light(8.0)
		if entry.has("weapon"):
			weapon = WeaponInstance.new()
			weapon.initialize(str(entry.weapon), player)
			weapon.principal_getter = Callable(battle.loadout, "get_current_principal")
			battle.loadout.weapon_instances.append(weapon)
			weapon.active_cooldown_ms = 350
		if entry.id == "walk":
			for enemy in enemies:
				enemy.hide()
				enemy.collision_layer = 0
				enemy.collision_mask = 0
			player.camera_2d.position_smoothing_enabled = false
		await frames(6)
		clip_frame = Engine.get_process_frames()
		recording = true
		sound_events.clear()
		var action_index := 0
		var loop_events: Array = []
		var last_loops: Dictionary = {}
		while Engine.get_process_frames()-clip_frame < int(float(entry.seconds)*FPS):
			await get_tree().process_frame
			current_time = float(Engine.get_process_frames()-clip_frame)/FPS
			while action_index < entry.actions.size() and current_time >= float(entry.actions[action_index].time):
				var action: Dictionary = entry.actions[action_index]
				if action.has("move"):
					player.set_mobile_move_direction(Vector2(float(action.move[0]), float(action.move[1])))
				else: _cast(action)
				action_index += 1
			var loops: Array = [player.walk_audio]
			for lamp in get_tree().get_nodes_in_group("copper_lamps"):
				if is_instance_valid(lamp.spray_audio): loops.append(lamp.spray_audio)
			for audio in loops:
				var key: int = audio.get_instance_id()
				if bool(last_loops.get(key, false)) != audio.playing:
					var loop_source := "walk" if audio == player.walk_audio else "spray"
					loop_events.append({"time": current_time, "playing": audio.playing, "source": loop_source})
				last_loops[key] = audio.playing
		recording = false
		var row := {"id": entry.id, "start_frame": clip_frame, "end_frame": Engine.get_process_frames(), "fps": FPS, "sounds": sound_events.duplicate(true), "loops": loop_events, "casts": cast_records.duplicate(true), "damage_count": hit_records.size(), "fixture": "Production battle, durable stationary targets, scripted cast/movement inputs; native MovieWriter video and audio; BGM off"}
		summary.append(row)
		FileAccess.open(output.path_join(str(entry.id)+".json"), FileAccess.WRITE).store_string(JSON.stringify(row, "\t"))
		print("REAL_AUDIO_CAPTURE ",entry.id," frames=",row.end_frame-row.start_frame," sounds=",sound_events.size())
		await _cleanup()
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	get_tree().quit(1 if failures else 0)
