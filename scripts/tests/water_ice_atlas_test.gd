extends "res://scripts/tests/pixel_combat_effect_test.gd"

const CUE = preload("res://scripts/effects/element_reaction_visual.gd")


func _run() -> void:
	# Test the actual body edge, including the sprite's offset collision shape.
	await setup([Vector2.ZERO, Vector2.ZERO], {"radius": 96.0})
	for index in enemies.size():
		var shape := enemies[index].get_node("CollisionShape2D") as CollisionShape2D
		var radius: float = shape.shape.radius
		enemies[index].position = Vector2(45.696 + radius + (-2.0 if index == 0 else 2.0), 0) - shape.position
	await frames()
	var wave := spawn_effect("water_wave") as WaterWaveEffect
	check(is_equal_approx(wave._radius, 45.696), "approved water radius is 0.8 times 57.12")
	check(enemies[0].current_hp == 9955 and enemies[0].has_status("wet"), "inside reduced body edge receives immediate water damage and wet")
	check(enemies[1].current_hp == 10000 and not enemies[1].has_status("wet"), "outside reduced body edge receives no water hit")
	check(wave.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "water uses nearest sampling")
	wave._elapsed = wave._duration * 0.5
	check(wave._get_atlas_frame() == 25, "water frame follows normalized duration")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	wave._process(1.0)
	check(is_equal_approx(wave._elapsed, wave._duration * 0.5), "water PNG animation pauses")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	wave._process(wave._duration)
	check(wave.is_queued_for_deletion(), "water PNG expires on the original clock")

	await setup([Vector2(80, 0), Vector2(110, 0)], {"radius": 96.0})
	weapon.runtime_stats.damage_area_size = 100.0
	wave = spawn_effect("water_wave") as WaterWaveEffect
	check(is_equal_approx(wave._radius, 68.544), "area bonus scales the reduced water radius")
	check(enemies[0].current_hp == 9955 and enemies[1].current_hp == 10000, "area bonus preserves physical coverage")
	check(WaterWaveEffect.ATLASES.size() == 12, "all water phase and detail textures are preloaded")
	for texture in WaterWaveEffect.ATLASES:
		check(texture.get_size() == Vector2(896, 784), "water atlas is imported at its reviewed resolution")
	check(CUE.SHARD_ATLASES.size() == 4, "both shard kinds and detail tiers are preloaded")
	for index in CUE.SHARD_ATLASES.size():
		check(CUE.SHARD_ATLASES[index].get_size() == Vector2(896, 560 if index < 2 else 672), "shard atlas is imported at its reviewed resolution")

	for kind in ["freeze", "thaw"]:
		await setup([])
		CUE.spawn(host, kind, Vector2.ZERO)
		var cue = host.get_child(0)
		cue.set_process(false)
		var lifetime := 0.62 if kind == "freeze" else 0.72
		check(is_equal_approx(cue.duration, lifetime), kind + " retains its duration")
		check(cue.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, kind + " uses nearest sampling")
		CUE.spawn(host, kind, Vector2.ZERO)
		check(host.get_child_count() == 1, kind + " retains simultaneous cue merging")
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		cue._process(1.0)
		check(cue.elapsed == 0.0, kind + " PNG animation pauses")
		GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		cue._process(0.1)
		check(cue._get_atlas_frame() == 6, kind + " advances at 60 animation frames per second")
		cue._process(lifetime - 0.11)
		check(not cue.is_queued_for_deletion(), kind + " remains until its lifetime ends")
		cue._process(0.02)
		check(cue.is_queued_for_deletion(), kind + " expires without an extra animation tail")

	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	print("WATER_ICE_ATLAS_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
