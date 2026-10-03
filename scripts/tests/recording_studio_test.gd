extends Node

var checks := 0
var failures := 0
var capture_dir := ""
var studio: RecordingStudio


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ", message)


func frames(count := 4) -> void:
	for _frame in count: await get_tree().process_frame


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event)
	await frames()


func _run() -> void:
	check(CampProgression._transient_session_active, "isolated before testing")
	var save_before := FileAccess.get_file_as_bytes(CampProgression.SAVE_PATH) if FileAccess.file_exists(CampProgression.SAVE_PATH) else PackedByteArray()
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	studio = load("res://scenes/debug/recording_studio.tscn").instantiate() as RecordingStudio
	add_child(studio)
	await frames(8)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	await frames(8)
	check(studio.get_config() == RecordingSession.default_config(), "form round trip preserves weapon attachments and balances")
	check(studio.columns.columns == 2, "desktop layout uses two columns")
	check(studio.form.get_child(0).size.x >= 140, "field labels retain readable width")
	await capture("studio_1280")
	get_window().size = Vector2i(640, 360)
	get_window().content_scale_size = Vector2i(640, 360)
	await frames(8)
	check(studio.columns.columns == 1, "small window uses one scrollable column")
	check(Rect2(Vector2.ZERO, Vector2(640,360)).encloses(studio.start_button.get_global_rect()), "start button stays inside small window")
	await capture("studio_640")
	get_window().size = Vector2i(1280,720)
	get_window().content_scale_size = Vector2i(1280,720)
	await frames(8)
	for preset in RecordingSession.presets().values(): check(RecordingSession.validate(preset).is_empty(), "builtin preset is valid")
	studio.storage_path = "user://recording_studio_tests/%d.json" % Time.get_ticks_usec()
	studio.preset_name.text = "test_capture"
	studio._save_preset()
	studio.user_presets.clear()
	studio._load_saved_presets()
	var saved: Dictionary = studio.user_presets.get("test_capture", {})
	check(not saved.is_empty() and RecordingSession.validate(saved).is_empty(), "saved preset survives JSON reload")
	if not saved.is_empty(): studio.set_config(saved)
	check(studio.get_config() == RecordingSession.default_config(), "saved preset restores the same form values")
	DirAccess.remove_absolute(studio.storage_path)
	var invalid := RecordingSession.default_config()
	invalid.wave = 21
	check(not RecordingSession.validate(invalid).is_empty(), "reject missing wave")
	invalid = RecordingSession.default_config()
	invalid.weapons[0].level = 1
	check(not RecordingSession.validate(invalid).is_empty(), "reject excess slots at low rarity")
	invalid.weapons[0].attachments = ["scroll_pierce"]
	check(not RecordingSession.validate(invalid).is_empty(), "reject incompatible spear piercing")
	invalid = RecordingSession.default_config()
	invalid.relics = [{"id": "relic_coin_heart", "count": 2}]
	check(not RecordingSession.validate(invalid).is_empty(), "reject relic stack overflow")
	invalid = RecordingSession.default_config()
	invalid.weapons.append(invalid.weapons[0].duplicate(true))
	check(not RecordingSession.validate(invalid).is_empty(), "reject duplicate weapons")
	var config := RecordingSession.default_config()
	config.countdown = 0
	config.weapons.append({"id": "weapon_void_blade", "level": 3, "attachments": ["scroll_ice"]})
	studio.set_config(config)
	check(studio.get_config() == config, "preset switching preserves changed numeric values")
	studio.start_button.pressed.emit()
	for _frame in 60:
		await frames(1)
		if not studio.busy: break
	check(not studio.screen.visible, "start button enters scene")
	var session := studio.session
	if session.battle == null:
		check(false, "battle created: " + studio.status.text)
		get_tree().quit(1)
		return
	var manager := session.battle.wave_manager
	check(manager.current_wave_index == 4 and session.flow.current_wave_index == 4, "both coordinators start at requested fifth wave")
	check(manager.player_level == 10, "requested player level")
	check(manager.current_gold == 200 and manager.finance_system.principal == 1000, "exact starting cash and bank principal")
	check(manager.player.get_stat("armor") == 20, "principal relic produces real armor")
	check(session.battle.loadout.get_weapon_instances().size() == 2, "multiple configured weapons")
	check(session.battle.loadout.get_weapon_instance("weapon_nightwatch_spear").level == 3, "weapon upgraded before attachments")
	var bow := session.battle.loadout.get_weapon_instance("weapon_void_blade")
	check(bow.get_attached_item_instances().size() == 1 and bow.has_effect("ice"), "explicit attachments replace character default lightning")
	await key(KEY_F7)
	var time_before := manager.wave_time_left
	await frames(12)
	check(session.paused and manager.wave_time_left == time_before, "F7 freezes combat clock")
	await key(KEY_F9)
	check(not session.battle.hud.visible, "F9 hides HUD")
	await key(KEY_F9)
	await key(KEY_F7)
	check(not session.paused and manager.wave_time_left < time_before, "F7 resumes combat")
	var enemy := manager.spawn_enemy("enemy_mutated_grub", session.battle.player.global_position + Vector2(100,0))
	check(enemy != null, "production enemies can spawn")
	await frames(30)
	await capture("combat")
	await key(KEY_F8)
	check(studio.screen.visible and session.game == null, "F8 disposes scene and returns to config")
	check(EnemyRegistry.get_registered_enemies().is_empty(), "return removes enemies")
	config.entry = "bank"
	config.gold = 0
	await studio._start(config)
	check(session.flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP and not session.battle.wave_manager.running, "bank entry does not start enemies")
	check(session.battle.wave_manager.current_gold == 0 and session.battle.wave_manager.finance_system.principal == 1000, "bank entry preserves balances")
	await frames(8)
	await capture("bank")
	var withdrawal := session.flow.submit_finance_operation("withdraw", 200)
	check(bool(withdrawal.get("success", false)), "bank supports actual withdrawal")
	check(session.battle.wave_manager.current_gold == 200 and session.battle.player.get_stat("armor") == 16, "withdrawal exchanges principal armor for spending cash")
	await key(KEY_F6)
	for _frame in 60:
		await frames(1)
		if not studio.busy: break
	check(session.battle.wave_manager.current_gold == 0 and session.battle.wave_manager.finance_system.principal == 1000, "F6 restores original config rather than mutated bank state")
	await studio.return_to_studio()
	config.character = "character_capitalist"
	config.wave = 20
	config.gold = 321
	config.principal = 777
	config.sanity_delta = -20
	config.erosion_delta = 30
	config.entry = "combat"
	config.weapons = [{"id": "weapon_rentier_purse", "level": 3, "attachments": []}]
	await studio._start(config)
	check(session.battle.player.character_id == "character_capitalist", "selected character initialized")
	check(session.battle.player.get_relic_ids().size() >= 5, "capitalist innate relics retained")
	check(session.battle.wave_manager.current_wave_index == 19, "final wave starts directly")
	check(session.battle.wave_manager.current_gold == 321 and session.battle.wave_manager.finance_system.principal == 777, "configured balances supersede character acquisition gifts")
	check(session.battle.player.get_stat("humanity") == 80 and session.battle.player.get_stat("divinity") == 30, "sanity and erosion adjustments reach real player stats")
	session.flow.present_battle_result(false, {"reason": "test", "gold": 321})
	await frames(8)
	var save_after := FileAccess.get_file_as_bytes(CampProgression.SAVE_PATH) if FileAccess.file_exists(CampProgression.SAVE_PATH) else PackedByteArray()
	check(save_before == save_after, "result cannot change formal save bytes")
	await studio.return_to_studio()
	studio.queue_free()
	await frames(4)
	print("RECORDING_STUDIO_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
