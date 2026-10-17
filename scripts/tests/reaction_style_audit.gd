extends "res://scripts/tests/element_interaction_review.gd"
## Read-only visual audit of production reactions. Scripted impacts, not projectiles.
const AUDIT_CROP := Rect2i(700, 260, 720, 560)

func _run() -> void:
	if output.is_empty() or cases_path.is_empty():
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	DirAccess.make_dir_recursive_absolute(output)
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	for entry: Dictionary in cases:
		if not only.is_empty() and str(entry.id) != only: continue
		await _setup(entry)
		get_tree().root.size = Vector2i(1920, 1080)
		get_tree().root.content_scale_size = Vector2i(1920, 1080)
		Engine.max_fps = 60
		caption.get_parent().hide()
		player.camera_2d.reset_smoothing()
		player.camera_2d.force_update_scroll()
		await frames(8)
		var directory := output.path_join(entry.id)
		DirAccess.make_dir_recursive_absolute(directory)
		var row := await _audit_case(entry, directory)
		summary.append(row)
		FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(row, "\t"))
		print("REACTION_AUDIT_CASE ", entry.id, " passed=", row.passed)
		await _cleanup()
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "\t"))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("REACTION_AUDIT_COMPLETE cases=", summary.size(), " failures=", failures)
	get_tree().quit(1 if failures else 0)

func _audit_case(entry: Dictionary, directory: String) -> Dictionary:
	observations = {"cues": {}, "statuses": {}, "kinds": {}, "cue_events": {}, "cue_timeline": [], "particles_peak": 0, "cues_peak": 0, "tongues_peak": 0, "fire_radius_max": 0.0, "ice_radius_max": 0.0, "fire_radius_first": 0.0, "ice_radius_first": 0.0, "palettes": {}, "field_palettes": {}, "damage_labels": {}, "cancel_cleared": false, "conduct_followed": false, "conduct_patterns": {}, "conduct_duration": 0.0, "conduct_max_age": 0.0}
	observed_ids = {}
	var capture := not no_capture and DisplayServer.get_name() != "headless"
	var stamps: Array = []
	var images: Array[Image] = []
	var start := Time.get_ticks_usec()
	var next_capture := 0.0
	var action_index := 0
	while Time.get_ticks_usec() - start < 3800000:
		await get_tree().process_frame
		current_time = float(Time.get_ticks_usec() - start) / 1e6
		while action_index < entry.actions.size() and current_time >= float(entry.actions[action_index].time):
			_cast(entry.actions[action_index])
			action_index += 1
		_observe()
		if capture and current_time >= next_capture:
			await RenderingServer.frame_post_draw
			var frame := get_tree().root.get_texture().get_image().get_region(AUDIT_CROP)
			var name := "%04d.png" % stamps.size()
			images.append(frame)
			stamps.append({"file": name, "time": float(Time.get_ticks_usec() - start) / 1e6})
			next_capture = current_time + 0.05
	for index in images.size():
		images[index].save_png(directory.path_join(stamps[index].file))
	var passed: bool = action_index == entry.actions.size()
	for cue in entry.get("expect_cues", []): passed = passed and observations.cues.has(cue)
	for kind in entry.get("expect_kinds", []): passed = passed and observations.kinds.has(kind)
	for status in entry.get("expect_statuses", []): passed = passed and observations.statuses.has(status)
	if entry.has("expect_palette"): passed = passed and observations.palettes.has(str(int(entry.expect_palette)))
	if entry.get("expand", "") == "fire": passed = passed and observations.get("wind_expanded_fire", false)
	if entry.get("expand", "") == "ice": passed = passed and observations.get("wind_expanded_ice", false)
	if not passed: failures += 1
	return {"id": entry.id, "passed": passed, "scripted_production_impacts": true, "projectile_collision": false, "resolution": [1920, 1080], "crop": [700,260,720,560], "frames": stamps, "observations": observations}
