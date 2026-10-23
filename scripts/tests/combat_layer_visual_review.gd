extends "res://scripts/tests/combat_effect_depth_test.gd"
## Actual battlefield/art counterpart to the solid-color occlusion assertions.

func _check_gpu(id: String) -> void:
	if id != "-120": return
	effect_host.hide()
	enemy.hide()
	battle.hud.hide()
	for node in ground.roots.get_children():
		if node.name == "SortedCombatVisual": node.hide()
	var cast: Array[EnemyController] = []
	for point in [Vector2(-120,0),Vector2(65,0),Vector2(245,0),Vector2(-290,0)]:
		var actor := battle.wave_manager.spawn_enemy("enemy_mutated_grub",point)
		actor.process_mode = Node.PROCESS_MODE_ALWAYS
		actor.set_physics_process(false)
		actor.current_hp = 10000
		cast.append(actor)
	cast[0].apply_burning(20,1,"review")
	cast[1].apply_freeze(20)
	cast[3].apply_light(20)
	preload("res://scripts/effects/element_reaction_visual.gd").spawn(cast[2],"conduct",cast[2].global_position,{"follow":weakref(cast[2])})
	await frames()
	preload("res://scripts/effects/enemy_status_visual_queue.gd").flush()
	for actor in cast: actor.get_node("EnemyStatusVisual").set_process(false)
	FIRE.clock.set_process(false)
	FIRE.clock.advance(0.24)
	var camera := battle.player.get_node("Camera2D") as Camera2D
	camera.global_position = Vector2(0,-50)
	camera.zoom = Vector2.ONE*1.6
	camera.reset_smoothing()
	camera.force_update_scroll()
	battle.player.global_position = cast[0].global_position + Vector2(0,5) - ground.foot_offset
	ground._update_area()
	check(ground.proxy.global_position.y > cast[0].global_position.y,"review player feet are in front of burning actor")
	var first := await _image()
	DirAccess.make_dir_recursive_absolute(output)
	first.save_png(output.path_join("status_player_in_front.png"))
	battle.player.global_position = cast[0].global_position + Vector2(0,-5) - ground.foot_offset
	ground._update_area()
	check(ground.proxy.global_position.y < cast[0].global_position.y,"review player feet are behind burning actor")
	var second := await _image()
	second.save_png(output.path_join("status_player_behind.png"))
	check(cast[0].get_node("EnemyStatusVisual")._flame_visual.actor_local,"actual battlefield flame stays attached to its actor")
	check(cast[1].get_node("EnemyStatusVisual")._body_ice.z_index == 0,"actual battlefield ice shell stays inside its actor sorting group")
	# Drain the extra live actors before the inherited frozen fixture teardown.
	for actor in cast:
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.queue_free()
	cast.clear()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	await get_tree().create_timer(0.3).timeout
