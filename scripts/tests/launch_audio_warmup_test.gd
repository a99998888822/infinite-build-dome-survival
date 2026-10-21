extends Node
var checks := 0
var failures := 0
const PATH := "res://assets/audio/sfx/combat/grenade_launch_01.wav"

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	CampProgression.begin_transient_session()
	var cursor := AudioManager._sfx_cursor
	var times := AudioManager._last_sfx_time_ms.duplicate(true)
	var audio_rng := AudioManager._combat_rng.state
	var child_count := AudioManager.get_child_count()
	seed(20261021)
	var expected := randf()
	seed(20261021)
	check(not ResourceLoader.has_cached(PATH), "launch sound starts unloaded")
	AudioManager.prepare_weapon_launch_sfx()
	check(ResourceLoader.has_cached(PATH), "preparation keeps the launch resource resident")
	var prepared := AudioManager._prepared_launch_streams
	check(prepared.size() == 1 and prepared.has(PATH), "two configured weapons share one launch resource")
	check(AudioManager._sfx_cursor == cursor and AudioManager._last_sfx_time_ms == times, "preparation preserves voice cursor and cooldowns")
	check(AudioManager._sfx_players.all(func(voice): return not voice.playing and voice.stream == null), "preparation neither assigns voices nor plays sound")
	check(AudioManager.get_child_count() == child_count, "preparation creates no audio nodes")
	check(randf() == expected and AudioManager._combat_rng.state == audio_rng, "preparation preserves both random streams")
	var stream: AudioStream = prepared[PATH]
	AudioManager.prepare_weapon_launch_sfx()
	check(prepared.size() == 1 and prepared[PATH] == stream, "repeated entry reuses the same resource")
	var data := DataRegistry.get_record("weapons", "weapon_hand_cannon")
	check(str(data.launch_sfx) == PATH and load(str(data.launch_sfx)) == stream, "later-acquired hand cannon shares the prepared sound")
	var voice: AudioStreamPlayer = AudioManager._sfx_players[cursor]
	check(AudioManager.play_sfx_path(PATH, 100, "grenade_launch", -3.0), "unchanged playback entry accepts the first launch")
	check(voice.playing and voice.stream == stream and voice.volume_db == -3.0, "launch uses the same sound and requested gain")
	check(not AudioManager.play_sfx_path(PATH, 100, "grenade_launch"), "duplicate launch still respects its time gate")
	check(not AudioManager.play_sfx_path("res://assets/audio/sfx/combat/ice_01.wav"), "disabled sounds stay disabled")
	for i in AudioManager._sfx_players.size(): AudioManager.play_sfx_path(PATH)
	var reused: AudioStreamPlayer = AudioManager._sfx_players[AudioManager._sfx_cursor]
	var ui_path := "res://assets/audio/sfx/ui/stats_chain_open.wav"
	check(AudioManager.play_sfx_path(ui_path) and reused.stream.resource_path == ui_path and is_zero_approx(reused.volume_db), "ordinary UI sound still resets pooled voice gain")
	# Rapid pool reuse enqueues playback on the audio thread. Let it consume
	# those requests before stopping, so teardown does not race pending starts.
	await get_tree().create_timer(0.1, true, false, true).timeout
	for node: AudioStreamPlayer in AudioManager._sfx_players: node.stop(); node.stream = null
	# Let stopped voices leave the audio mix before the test process exits.
	await get_tree().create_timer(0.1, true, false, true).timeout
	CampProgression.end_transient_session()
	print("LAUNCH_AUDIO_WARMUP checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
