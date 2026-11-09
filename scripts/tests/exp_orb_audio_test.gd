extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
	print("PASS " if condition else "FAIL ", label)


func _run() -> void:
	var audio := root.get_node("AudioManager")
	audio.set_process(false)
	root.get_node("GameGlobal").set_runtime_flag("battle_runtime_paused", false)
	audio.reset_exp_orb_sfx()
	for index in range(9):
		check(audio._play_exp_orb_collect_at(1000 + index * 300), "stage plays %d" % (index + 1))
		check(audio._exp_orb_stage == index + 1, "correct stage %d" % (index + 1))
		var voice: AudioStreamPlayer = audio._sfx_players[(audio._sfx_cursor + 7) % 8]
		check(voice.stream.resource_path.ends_with("exp_orb_collect_%02d.wav" % (index + 1)), "approved resource selected")
		check(not audio._play_exp_orb_collect_at(1001 + index * 300), "same burst merged")
	check(audio._play_exp_orb_collect_at(3700) and audio._exp_orb_stage == 9, "ninth stage remains capped")
	check(audio._play_exp_orb_collect_at(4200) and audio._exp_orb_stage == 1, "500 ms gap resets pitch and gain")
	check(not audio._play_exp_orb_collect_at(4499), "299 ms cannot advance")
	check(audio._play_exp_orb_collect_at(4500) and audio._exp_orb_stage == 2, "300 ms advances")
	# Suppressed pickups refresh the timeout; no skipped stages after sparse pickups.
	check(not audio._play_exp_orb_collect_at(4700), "intermediate pickup merged")
	check(audio._play_exp_orb_collect_at(5100) and audio._exp_orb_stage == 3, "merged pickup keeps chain alive without catch-up")
	root.get_node("GameGlobal").set_runtime_flag("battle_runtime_paused", true)
	check(not audio._play_exp_orb_collect_at(5400) and audio._exp_orb_stage == 0, "pause resets chain")
	root.get_node("GameGlobal").set_runtime_flag("battle_runtime_paused", false)
	check(audio._play_exp_orb_collect_at(5401) and audio._exp_orb_stage == 1, "resume starts at first stage")
	quit(1 if failed else 0)
