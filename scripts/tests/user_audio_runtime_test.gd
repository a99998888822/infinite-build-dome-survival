extends "res://scripts/tests/pixel_combat_effect_test.gd"

func _run() -> void:
	await setup([Vector2(110, 0)])
	var player := load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	host.add_child(player)
	await frames()
	var walk_start := player.position
	player.set_mobile_move_direction(Vector2.RIGHT)
	await get_tree().create_timer(0.12).timeout
	check(player.walk_audio.playing and player.position.x > walk_start.x, "actual walking starts the movement loop")
	check(player.WALK_AUDIO.loop_mode == AudioStreamWAV.LOOP_DISABLED, "loop configuration never mutates the shared WAV")
	check(player.walk_audio.stream.loop_end == roundi(player.WALK_AUDIO.get_length() * player.WALK_AUDIO.mix_rate), "compressed footsteps loop over the complete sample duration")
	player.set_mobile_move_direction(Vector2.ZERO)
	await frames()
	check(not player.walk_audio.playing, "idle stops movement audio")
	player.set_mobile_move_direction(Vector2.RIGHT)
	await frames()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames()
	check(not player.walk_audio.playing, "pause stops footsteps")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()
	check(player.walk_audio.playing, "new walking after pause resumes audio")
	player.set_physics_process(false)
	await frames()
	check(not player.walk_audio.playing, "disabled character processing cannot leave a loop running")
	player.set_mobile_move_direction(Vector2.ZERO)
	player.set_physics_process(true)
	weapon = WeaponInstance.new()
	weapon.initialize("weapon_copper_lamp", player)
	var lamp := CopperLamp.new()
	host.add_child(lamp)
	lamp.initialize(weapon)
	lamp.externally_driven = true
	lamp.manual_control = true
	lamp.burst_active = true
	var plasma_heard: Array = []
	AudioManager.combat_sfx_played.connect(func(cue, _path):
		if cue == "plasma_hit": plasma_heard.append(cue))
	await get_tree().create_timer(0.6).timeout
	check(lamp.firing and lamp.spray_audio.playing, "spray continues beyond the short sample length")
	check(lamp.spray_audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "spray repeats as one loop")
	var spray_source := load(str(weapon.weapon_data.spray_loop_sfx)) as AudioStreamWAV
	check(lamp.spray_audio.stream.loop_end == roundi(spray_source.get_length() * spray_source.mix_rate), "compressed spray loops over the complete sample duration")
	check(enemies[0].current_hp < 10000 and plasma_heard.is_empty(), "lamp damages targets without replaying plasma contacts")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames()
	check(not lamp.spray_audio.playing, "pause stops spray audio")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()
	check(lamp.spray_audio.playing, "active burst resumes one spray loop after pause")
	await get_tree().create_timer(1.4).timeout
	check(not lamp.firing and not lamp.spray_audio.playing, "burst completion stops the loop")
	lamp.cooling = 0
	lamp.heat = 0
	lamp.burst_active = true
	await frames()
	check(lamp.spray_audio.playing, "second burst starts sound again")
	lamp.cancel()
	check(not lamp.spray_audio.playing, "cancelling spray stops audio immediately")
	await frames()
	lamp = CopperLamp.new()
	host.add_child(lamp)
	lamp.initialize(weapon)
	lamp.externally_driven = true
	lamp.burst_active = true
	await frames()
	player.alive = false
	await frames()
	check(not is_instance_valid(lamp), "owner death frees the spray and its audio")
	check(DataRegistry.get_record("weapons", "weapon_mutant_tentacle").hit_sfx != DataRegistry.get_record("weapons", "weapon_meteor_flail").hit_sfx, "tentacle has its own supplied impact")
	check(DataRegistry.get_record("weapons", "weapon_earth_hammer").hit_sfx == DataRegistry.get_record("weapons", "weapon_meteor_flail").hit_sfx, "hammer and flail share the supplied heavy impact")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	print("USER_AUDIO_RUNTIME_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
