extends "res://scripts/tests/player_actions_live_review.gd"
## Production battle, production cast paths and a normal 1x camera.
var stages: Array[Dictionary] = []

func _aimed_cast(id: String, aim: Vector2) -> void:
	var weapon := loadout.get_weapon_instance(id)
	check(weapon != null, "weapon exists " + id)
	if weapon == null:
		return
	var before := player.global_position
	var ok := loadout.cast_weapon(weapon, before + aim * 145.0)
	check(ok, "production cast " + id)
	casts.append({"frame":frame_index,"weapon":id,"success":ok,"action":player.action_animator.current_clip,
		"aim":[aim.x,aim.y],"before":[before.x,before.y],"after":[player.global_position.x,player.global_position.y]})

func _motion_stage(label: String, seconds: float, move: Vector2, aim: Vector2, events: Dictionary) -> void:
	var ids: Array = []
	for id: String in events.values():
		if not ids.has(id):
			ids.append(id)
	_equip(ids)
	player.action_animator.reset()
	player._set_facing(aim.x > 0.0)
	for i in targets.size():
		targets[i].global_position = player.global_position + aim * (150 + i * 40) + Vector2(0,45)
	title.text = label
	var start := frame_index
	for i in roundi(seconds * 30.0):
		player.set_mobile_move_direction(move)
		if events.has(i):
			_aimed_cast(events[i], aim)
		loadout.active_casting.tick(1.0 / 30.0)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		var animator := player.action_animator
		if animator.action in ["attack", "move_attack", "jump_forward", "jump_backward"]:
			check(player.facing_right == (aim.x > 0.0), "action retains actual aim direction")
		var key := "%s:%d" % [animator.current_clip,animator.current_frame]
		coverage[key] = int(coverage.get(key,0)) + 1
		subtitle.text = "%s  %02d/%02d · 正常镜头 1× · 原速" % [animator.current_clip,animator.current_frame+1,animator._count(animator.current_clip)]
		var screen := player.sprite.get_global_transform_with_canvas() * Vector2.ZERO
		timeline.append({"frame":frame_index,"stage":stages.size(),"clip":animator.current_clip,"cell":animator.current_frame,
			"x":player.position.x,"y":player.position.y,"screen_x":screen.x,"screen_y":screen.y,
			"facing_right":player.facing_right,"texture":player.sprite.texture.resource_path})
		if DisplayServer.get_name() != "headless":
			check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % frame_index)) == OK, "capture viewport")
		frame_index += 1
	stages.append({"label":label,"first":start,"count":frame_index-start})
	print("NEW_MOTION_STAGE ", label, " frames=",frame_index-start)

func _run() -> void:
	CampProgression.begin_transient_session()
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	check(flow.confirm_character_selection(), "enter production battle")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames(4)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	check(player.action_animator.enabled, "new strips loaded from production manifest")
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	loadout.set_active_combat_enabled(true)
	player.camera_2d.zoom = Vector2.ONE
	player.modifier_stack.set_base_stat("max_hp",1000)
	player.restore_full_health()
	for i in 2:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub",player.global_position+Vector2(150+i*40,45))
		enemy.set_physics_process(false)
		enemy.current_hp = 100000
		targets.append(enemy)
	loadout.weapon_fired.connect(func(id: String,count: int): launches.append({"frame":frame_index,"weapon":id,"count":count}))
	check(DisplayServer.get_name() == "headless" or not capture_dir.is_empty(), "capture directory provided")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	_overlay()
	await _motion_stage("01 向右移动 → 移动攻击 → 移动",3.0,Vector2(0.3,0),Vector2.RIGHT,{21:"weapon_void_blade"})
	await _motion_stage("02 向左移动 → 移动攻击 → 移动",3.0,Vector2(-0.3,0),Vector2.LEFT,{21:"weapon_void_blade"})
	await _motion_stage("03 待机 → 后跳 → 待机",3.2,Vector2.ZERO,Vector2.RIGHT,{18:"weapon_hand_cannon"})
	await _motion_stage("04 移动 → 后跳 → 移动",3.2,Vector2(-0.3,0),Vector2.RIGHT,{18:"weapon_hand_cannon"})
	await _motion_stage("05 移动攻击 → 后跳 → 移动",4.2,Vector2(0.25,0),Vector2.RIGHT,{18:"weapon_void_blade",51:"weapon_hand_cannon"})
	await _motion_stage("06 前跳 · 保留原确认素材",1.8,Vector2(0.2,0),Vector2.RIGHT,{12:"weapon_dash_blade"})
	await _motion_stage("07 向后移动、向前开火 · 朝向核对",2.0,Vector2(-0.3,0),Vector2.RIGHT,{15:"weapon_void_blade"})
	player.set_mobile_move_direction(Vector2.ZERO)
	for enemy in targets:
		damage_total += maxi(0,100000-enemy.current_hp)
	for clip in ["move_attack","jump_backward"]:
		for cell in player.action_animator._count(clip):
			check(coverage.has("%s:%d" % [clip,cell]), "new frame rendered " + clip + ":" + str(cell))
	check(casts.size()==8, "eight real weapon casts recorded")
	check(damage_total>0, "production damage recorded")
	var report := {"valid":failures.is_empty(),"failures":failures,"frames":frame_index,"fps":30,"coverage":coverage,
		"stages":stages,"timeline":timeline,"casts":casts,"weapon_fired":launches,"damage_total":damage_total,
		"new_frames":19,"camera_zoom":1,"sprite_scale":player.sprite.scale.x,
		"review_fixtures":{"stationary_enemies":2,"enemy_hp":100000,"player_hp":1000,"random_spawns":false}}
	if not capture_dir.is_empty():
		FileAccess.open(capture_dir.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	print("NOVICE_NEW_ACTIONS_COMPLETE frames=",frame_index," casts=",casts.size()," valid=",failures.is_empty())
	get_tree().quit(0 if failures.is_empty() else 1)
