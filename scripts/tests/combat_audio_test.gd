extends "res://scripts/tests/pixel_combat_effect_test.gd"

var heard: Array[String] = []
var paths: Array[String] = []


func reset_audio() -> void:
	AudioManager.stop_combat_sfx()
	AudioManager._combat_last_ms.clear()
	AudioManager._combat_bursts.clear()
	heard.clear()
	paths.clear()


func _run() -> void:
	AudioManager.combat_sfx_played.connect(func(cue: String, path: String):
		heard.append(cue)
		paths.append(path))
	await setup([Vector2.ZERO, Vector2(30, 0)])
	reset_audio()
	var assets_valid := true
	var assets_count := 0
	for profile: Dictionary in AudioManager.COMBAT_LIBRARY.PROFILES.values():
		assets_valid = assets_valid and profile.streams.size() == 1
		for stream: AudioStreamWAV in profile.streams:
			assets_count += 1
			assets_valid = assets_valid and stream != null and stream.mix_rate == 48000 and not stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and stream.get_length() > 0.1
	check(assets_valid and assets_count == 25, "each cue imports one of 25 non-looping mono WAVs at 48 kHz")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("CombatSFX")) == "SFX", "combat follows existing SFX volume setting")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("CombatSFX")) == 2, "combat compressor and limiter installed")
	check(AudioManager.play_weapon_hit_sfx("weapon_void_blade"), "bow configured hit plays")
	check(not AudioManager.play_weapon_hit_sfx("weapon_void_blade"), "same-frame multiple arrows are merged")
	AudioManager._process(.075)
	check(AudioManager.play_weapon_hit_sfx("weapon_void_blade"), "bow accepts later impact")
	check(paths.size() == 2 and paths[0] == paths[1], "consecutive bow hits reuse one canonical asset")
	var bow_pitches: Array[float] = []
	for player: AudioStreamPlayer in AudioManager._combat_players:
		if player.playing and str(player.get_meta("cue_id", "")) == "wood_arrow":
			bow_pitches.append(player.pitch_scale)
	check(bow_pitches.size() == 2 and bow_pitches.all(func(pitch): return pitch >= 0.965 and pitch <= 1.035), "canonical bow retains small runtime pitch variation")
	check(not AudioManager.play_combat_sfx("unknown"), "unknown cue safely rejected")
	check(not AudioManager.play_weapon_hit_sfx("unknown_weapon"), "unknown weapon safely rejected")
	reset_audio()
	check(not AudioManager.play_enchantment_sfx("ice") and not AudioManager.play_reaction_sfx("freeze"), "ice and freeze are intentionally silent")
	check(not AudioManager.play_weapon_hit_sfx("weapon_kunyu_ritual_tome"), "tome sharing the ice cue has no hit audio")
	check(not AudioManager.play_sfx_path("res://assets/audio/sfx/combat/ice_01.wav") and not AudioManager.play_sfx_path("res://assets/audio/sfx/combat/reaction_freeze_01.wav"), "raw asset paths cannot bypass disabled sounds")
	var muted_impact := AudioManager.begin_combat_audio()
	check(not AudioManager.play_enchantment_sfx("ice") and not AudioManager.play_reaction_sfx("freeze"), "disabled cues are rejected inside contact batches")
	AudioManager.end_combat_audio()
	AudioManager.flush_combat_audio(true)
	check(heard.is_empty() and muted_impact.requests.is_empty() and AudioManager._pending_audio_impacts.is_empty() and AudioManager._combat_bursts.is_empty(), "disabled requests allocate no pending sounds or burst budget")
	check(not AudioManager._play_combat_sfx_now("ice") and not AudioManager._play_combat_sfx_now("reaction_freeze"), "immediate playback also rejects disabled cues")
	for cue in ["lightning", "water", "fire"]:
		check(AudioManager.play_combat_sfx(cue), "burst detail accepted: " + cue)
	check(not AudioManager.play_combat_sfx("wind"), "fourth simultaneous detail suppressed")
	check(AudioManager.play_combat_sfx("wood_arrow") and AudioManager.play_combat_sfx("electric_spark") and AudioManager.play_combat_sfx("light_sword"), "important impacts retain separate burst budget")
	var streams_before: Array[AudioStream] = []
	for player: AudioStreamPlayer in AudioManager._combat_players:
		if player.playing: streams_before.append(player.stream)
	AudioManager.play_combat_sfx("explosion")
	var streams_after: Array[AudioStream] = []
	for player: AudioStreamPlayer in AudioManager._combat_players:
		if player.playing: streams_after.append(player.stream)
	check(streams_before == streams_after, "overflow does not cut or replace ongoing tails")
	reset_audio()
	for cue: String in AudioManager.COMBAT_LIBRARY.PROFILES:
		AudioManager._process(.07)
		AudioManager.play_combat_sfx(cue)
	var active_count := 0
	for player: AudioStreamPlayer in AudioManager._combat_players:
		if player.playing: active_count += 1
	check(active_count == 12, "dense mixed battle is capped at twelve simultaneous voices")
	reset_audio()
	for i in range(12):
		AudioManager._process(.56)
		AudioManager.play_combat_sfx("black_hole")
	check(heard.count("black_hole") == 1, "long cue cannot stack beyond voice limit")
	reset_audio()
	check(AudioManager.play_combat_sfx("electric_spark"), "ordinary thunder starts")
	AudioManager._process(.12)
	check(not AudioManager.play_combat_sfx("reaction_conduct_strike"), "reaction variant cannot bypass thunder cooldown")
	AudioManager._process(.15)
	check(AudioManager.play_combat_sfx("reaction_conduct_strike"), "later wet thunder can overlap the first tail")
	AudioManager._process(.27)
	check(AudioManager.play_combat_sfx("reaction_thunder_fire_strike"), "fire thunder shares the third landing voice")
	AudioManager._process(.27)
	check(not AudioManager.play_combat_sfx("electric_spark") and heard.size() == 3, "all thunder variants share a three-voice cap without stealing tails")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	check(not AudioManager.play_combat_sfx("electric_spark"), "pause suppresses new combat sounds")
	AudioManager._process(.5)
	check(AudioManager._combat_players.all(func(p): return not p.playing), "pause clears ongoing combat tails")
	check(AudioManager.play_sfx_path("res://assets/audio/sfx/ui/stats_chain_open.wav"), "UI sound remains usable while battle is paused")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	AudioManager._process(.5)
	check(AudioManager._combat_players.all(func(p): return not p.playing), "unpause does not replay old sounds")
	for player: AudioStreamPlayer in AudioManager._sfx_players: player.stop()

	# Exercise the actual effect clocks and scheduler, not just the sound API.
	await setup([Vector2.ZERO])
	reset_audio()
	var spark := spawn_effect("electric_spark")
	await frames()
	check(heard.count("spark_charge") == 1 and not heard.has("electric_spark"), "spark initially charges without landing sound")
	spark.call("_process", .49)
	check(not heard.has("electric_spark"), "no lightning impact before half-second delay")
	spark.call("_process", .02)
	await frames()
	check(heard.count("electric_spark") == 1 and enemies[0].current_hp < 10000, "spark impact and actual landing damage coincide")
	spark.call("_process", .05)
	check(heard.count("electric_spark") == 1, "spark aftermath does not replay impact")
	await setup([Vector2.ZERO])
	reset_audio()
	var sword := spawn_effect("light_sword")
	await frames()
	sword.call("_process", .70)
	check(not heard.has("light_sword"), "sword descent is not an impact")
	sword.call("_process", .03)
	AudioManager.flush_combat_audio(true)
	check(heard.count("light_sword") == 1 and enemies[0].current_hp == 9910, "sword sound coincides with landing")
	sword.call("_land")
	check(heard.count("light_sword") == 1, "sword landing stays idempotent")
	await setup([Vector2.ZERO, Vector2(30, 0)])
	reset_audio()
	weapon.weapon_id = "weapon_plasma_cannon"
	weapon.weapon_data = DataRegistry.get_record("weapons", weapon.weapon_id).duplicate(true)
	var plasma := ProjectileInstance.new()
	host.add_child(plasma)
	plasma.weapon = weapon
	plasma.damage_event = event
	plasma._process_plasma_tick(enemies)
	AudioManager.flush_combat_audio(true)
	check(heard.count("plasma_hit") == 1 and not heard.has("wood_arrow"), "multi-target plasma tick has one distinct contact cue")
	plasma._process_plasma_tick(enemies)
	AudioManager.flush_combat_audio(true)
	check(heard.count("plasma_hit") == 1 and enemies[0].current_hp == 9800, "audio cooldown never suppresses plasma damage")
	reset_audio()
	ElementReactionResolver.apply_element(enemies[0], "fire", {"parent": host, "original_damage": 100})
	ElementReactionResolver.apply_element(enemies[0], "water", {"parent": host, "original_damage": 100})
	AudioManager.flush_combat_audio(true)
	check(heard.count("reaction_steam") == 1, "real steam reaction dispatches its sound")
	reset_audio()
	ElementReactionResolver.apply_element(enemies[0], "ice", {"parent": host})
	ElementReactionResolver.apply_element(enemies[0], "water", {"parent": host})
	AudioManager.flush_combat_audio(true)
	check(not heard.has("reaction_freeze") and enemies[0].has_status("frozen"), "real freeze still applies its status without audio")
	reset_audio()
	ExplosionEffect.spawn(host, Vector2.ZERO, weapon, event, "", 1.8, 72, "thunder_fire")
	await frames()
	AudioManager.flush_combat_audio(true)
	check(heard.count("reaction_thunder_fire") == 1 and not heard.has("explosion"), "thunder-fire explosion uses only its combined cue")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.1).timeout
	print("COMBAT_AUDIO_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
