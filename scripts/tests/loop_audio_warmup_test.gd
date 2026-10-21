extends Node
const PATH := "res://assets/audio/sfx/combat/copper_lamp_loop.wav"
const LOOP = preload("res://scripts/audio/gameplay_loop.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func make_loop() -> Dictionary:
	var source := load(PATH) as AudioStreamWAV
	var loop := LOOP.new()
	add_child(loop)
	loop.configure(source, -16.0, "CombatSFX")
	return {"loop": loop, "source": weakref(source)}

func wait_for_audio_mix() -> void:
	# Mixing uses wall time even when a review accelerates simulation frames.
	var until := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame

func run() -> void:
	CampProgression.begin_transient_session()
	set_physics_process(true)
	var original := make_loop()
	check(original.source.get_ref() == null and not ResourceLoader.has_cached(PATH), "a private playback copy alone does not retain the original source")
	original.loop.free()
	var cursor := AudioManager._sfx_cursor
	var times := AudioManager._last_sfx_time_ms.duplicate(true)
	var audio_rng := AudioManager._combat_rng.state
	var children := AudioManager.get_child_count()
	seed(20261021)
	var expected := randf()
	seed(20261021)
	AudioManager.prepare_weapon_loop_sfx()
	check(ResourceLoader.has_cached(PATH), "entry keeps the loop source resident")
	check(AudioManager._prepared_loop_streams.size() == 1 and AudioManager._prepared_loop_streams.has(PATH), "preparation follows the configured spray path")
	check(AudioManager.get_child_count() == children and AudioManager._sfx_cursor == cursor and AudioManager._last_sfx_time_ms == times, "preparation creates no voices and changes no playback cooldowns")
	check(AudioManager._sfx_players.all(func(voice): return not voice.playing and voice.stream == null), "preparation does not start playback")
	check(randf() == expected and AudioManager._combat_rng.state == audio_rng, "preparation preserves combat and audio RNG")
	var source: AudioStreamWAV = AudioManager._prepared_loop_streams[PATH]
	AudioManager.prepare_weapon_loop_sfx()
	check(AudioManager._prepared_loop_streams.size() == 1 and load(PATH) == source, "repeated entry and later casts reuse the same source")
	var first := make_loop()
	var second := make_loop()
	check(first.source.get_ref() == source and second.source.get_ref() == source, "both casts resolve the resident resource")
	check(first.loop.stream != source and second.loop.stream != source and first.loop.stream != second.loop.stream, "each cast retains an independent looping stream")
	check(source.loop_mode == AudioStreamWAV.LOOP_DISABLED, "source is never changed to loop")
	check(first.loop.stream.data == source.data and first.loop.stream.format == source.format and first.loop.stream.mix_rate == source.mix_rate and first.loop.stream.stereo == source.stereo, "playback preserves the exact audio data and format")
	check(first.loop.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and first.loop.stream.loop_begin == 0 and first.loop.stream.loop_end == roundi(source.get_length() * source.mix_rate), "compressed audio loops over its complete sample range")
	check(first.loop.volume_db == -16.0 and first.loop.bus == "CombatSFX", "spray gain and bus stay unchanged")
	first.loop.set_active(true)
	second.loop.set_active(true)
	await wait_for_audio_mix()
	check(first.loop.playing and second.loop.playing, "two owners can play independently")
	first.loop.set_active(false)
	check(not first.loop.playing and second.loop.playing, "stopping one owner leaves the other running")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	second.loop.set_active(true)
	check(not second.loop.playing, "pause stops the active loop")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	second.loop.set_active(true)
	check(second.loop.playing, "an active owner can resume after pause")
	await wait_for_audio_mix()
	second.loop.set_active(false)
	await wait_for_audio_mix()
	first.loop.free()
	second.loop.free()
	check(ResourceLoader.has_cached(PATH) and AudioManager._prepared_loop_streams[PATH] == source, "disposing casts keeps the next cast ready")
	original.clear()
	first.clear()
	second.clear()
	source = null
	await get_tree().create_timer(0.2, true, false, true).timeout
	CampProgression.end_transient_session()
	print("LOOP_AUDIO_WARMUP checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
