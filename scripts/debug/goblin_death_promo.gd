extends Node
## Ending pickups from the production settlement, isolated from saved progress.
const FPS := 60
const TOTAL := 240
var take := "followed"
var output_dir := ""
var failures: Array[String] = []
var session: RecordingSession
var panel: RunSettlementPanel
var report := {"fps": FPS, "frames": TOTAL, "sfx_percent": 100, "bgm_percent": 0,
	"staged": true, "presentation_start_seconds": 3.85, "samples": []}


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--take="): take = arg.trim_prefix("--take=")
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
	if take not in ["followed", "refused"] or output_dir.is_empty() or not "--transient-session" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)


func _run() -> void:
	seed(10282026)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.combat_guide_seen = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	for bus in [AudioManager.BUS_MASTER, AudioManager.BUS_SFX]:
		AudioManager.set_bus_volume(bus, 100, false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), false)
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 0, false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_BGM), true)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"entry": "bank", "wave": 4, "level": 10, "gold": 200, "principal": 1000,
		"countdown": 0, "relics": [], "weapons": [{"id": "weapon_earth_hammer", "level": 5, "attachments": []}]}, true)
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		await _finish()
		return
	check(session.begin(), "Open the real preparation flow")
	await frames(24)
	session.flow.cancel_goblin_trade()
	var manager := session.battle.wave_manager
	manager.set_process(false)
	manager.run_statistics.reset()
	# The lead-in is staging, excluded from the requested ending clips.
	manager.wave_challenges.pressure = {"struggling": true, "observed_seconds": 8.0, "low_health_seconds": 6.0}
	manager.wave_challenges.config.challenges = [manager.wave_challenges.definition("extra_elites")]
	session.flow.close_finance_popup()
	await frames(6)
	var challenge := session.game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	check(challenge != null and challenge.visible, "A real eligible challenge must be presented")
	if failures.is_empty():
		_click(challenge.presentation._yes if take == "followed" else challenge.presentation._no)
	await frames(8)
	var stats := manager.run_statistics.snapshot()
	check(stats.has_advice and bool(stats.followed) == (take == "followed"), "Native choice history must select the requested reaction")
	report.advice = stats
	# Trigger death before filming; only the resulting native settlement is shown.
	session.battle.player.take_damage(999999, "promo_ending_setup")
	await frames(12)
	panel = session.game.find_child("BattleResultPanel", true, false) as RunSettlementPanel
	check(panel != null and panel.visible, "Death must open the production settlement")
	check(str(session.flow.current_battle_summary.get("reaction", "")) == "death_" + take, "Settlement must choose the matching taunt")
	if not failures.is_empty():
		await _finish()
		return
	report.receipt = session.flow.current_battle_summary.duplicate(true)
	panel.set_process(false)
	panel.stop_audio()
	panel.seek(float(report.presentation_start_seconds))
	panel._last_stage = 3
	panel._voice_started = false
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for voice in AudioManager._sfx_players: voice.stop()
	get_viewport().gui_release_focus()
	report.speech = panel._speech_label.text
	report.reaction_row = panel._reaction_row
	report.voice_path = panel._voice_path
	report.start_frame = Engine.get_frames_drawn()
	for frame in TOTAL:
		panel._process(1.0 / FPS)
		if frame % 15 == 0:
			report.samples.append({"frame": frame, "seconds": panel._elapsed,
				"speech_visible": panel._speech.visible, "characters": panel._speech_label.visible_characters,
				"portrait_frame": (panel._portrait.texture as AtlasTexture).region.position.x})
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame % 30 == 0 or frame == TOTAL - 1:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	check(panel._speech.visible and panel._speech_label.visible_characters >= panel._speech_label.text.length(), "Complete taunt must remain readable at the end")
	check(panel._reaction_row == (0 if take == "followed" else 1), "Native expression row must match the choice")
	report.portrait_rect = _rect(panel._portrait.get_global_rect())
	report.speech_rect = _rect(panel._speech.get_global_rect())
	report.card_rect = _rect(panel._card.get_global_rect())
	await _finish()


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _finish() -> void:
	report.take = take
	report.failures = failures
	report.audio = {"sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),
		"bgm_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")),
		"bgm_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM"))}
	FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	if panel != null:
		panel.stop_audio()
		panel._cue.stream = null
		panel._voice.stream = null
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	CombatHitFeedback.clear()
	if is_instance_valid(session): await session.dispose()
	await frames(5)
	CampProgression.end_transient_session()
	print("GOBLIN_DEATH_DONE ", take, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
