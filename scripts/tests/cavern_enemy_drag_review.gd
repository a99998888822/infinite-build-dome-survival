extends Node
## Regression review: production AI and physics tick naturally. Stage spawn positions
## and cooldowns; disable wave/weapon noise and player damage for paired trials.
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var ground: CavernPopulationBackdrop
var output := "res://temp/artifacts/reviews/cavern_enemy_drag_fix"
var report: Dictionary = {"trials":{}}
var samples: Array = []
var caption: Label
var status: Label
var review_layer: CanvasLayer
var capture_index := 0
var failed := false

class ChallengeProbe extends Node2D:
	var alive := true
	func take_enemy_damage(_damage: int) -> void:
		pass

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func pair(point: Vector2) -> Array:
	return [point.x,point.y]

func check(ok: bool, message: String) -> void:
	if not ok: failed = true
	print("PASS " if ok else "FAIL ", message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1600,900)
	get_tree().root.content_scale_size = Vector2i.ZERO
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",[])
	await frames(6)
	check(flow.confirm_character_selection(),"production battle opened")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	player = battle.player
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernPopulationBackdrop
	check(ground != null and ground.initialized,"production curved darkness boundary active")
	if ground == null:
		get_tree().quit(1)
		return
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	make_overlay()
	report.setup = {"window":pair(Vector2(get_tree().root.size)),"camera_zoom":pair(player.camera_2d.zoom),
		"world_viewport":pair(player.get_viewport_rect().size),"production_ai":true,
		"review_changes":["staged spawn positions and initial cooldowns","wave and weapon ticking disabled","player invincibility"]}
	await grub_trial(false)
	await grub_trial(true)
	await wolf_trial(false)
	await wolf_trial(true)
	await wolf_trial(true,true)
	var control: Dictionary = report.trials.wolf_stationary
	var moving: Dictionary = report.trials.wolf_down
	check(float(control.breath_distance)<0.01,"stationary control: wolf does not move during breath")
	check(float(moving.breath_distance)<0.01,"original reproduction: wolf remains stationary throughout breath")
	check(int(moving.frozen_breath_timer_frames)==0,"original reproduction: breath timer never stalls")
	var crossing: Dictionary = report.trials.wolf_down_from_charge
	check(int(crossing.dark_breath_frames)>5,"earlier player movement crosses the reduced dark edge during breath")
	check(float(crossing.breath_distance)<0.01 and int(crossing.frozen_breath_timer_frames)==0,"crossing darkness preserves wolf position and breath timing")
	check(float(crossing.flame_origin_error)<0.01,"rendered flame and damage origin remain aligned")
	check(int(report.trials.grub_down.entry_frames)>10,"ordinary enemy crosses the reduced dark edge during review")
	check(float(report.trials.grub_down.max_chase_error)<0.01,"ordinary enemy path matches a control with no darkness query")
	await verify_attack_visibility()
	await verify_displacement_lock()
	await capture_landscape()
	report.samples = samples
	report.failed = failed
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAVERN_ENEMY_DRAG_REPORT ",JSON.stringify(report.trials))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await frames(5)
	print("CAVERN_ENEMY_DRAG_COMPLETE failed=",failed)
	get_tree().quit(1 if failed else 0)

func reset() -> void:
	battle.wave_manager.clear_battle_entities()
	player.set_mobile_move_direction(Vector2.ZERO)
	player._clear_move_input()
	var push := player.get_node_or_null("EnemyKnockback") as PlayerEnemyKnockback
	if push != null: push.cancel()
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player._invincibility_timer = 99.0
	player._sync_camera()
	player.camera_2d.force_update_scroll()
	await frames(6)

func grub_trial(down: bool) -> void:
	await reset()
	var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub",Vector2(-230,-125)) as EnemyController
	# Same world/target/input, with only the scenery query disconnected.
	var control := battle.wave_manager.spawn_enemy("enemy_mutated_grub",enemy.global_position) as EnemyController
	control._cavern_scenery = null
	control.hide()
	var max_chase_error := 0.0
	var start := enemy.global_position
	var label := "grub_down" if down else "grub_stationary"
	caption.text = "问题 1：黑暗边缘的普通怪物 · " + ("玩家向下移动" if down else "玩家站定对照")
	var entry_frames := 0
	var first_entry: Dictionary = {}
	player.set_mobile_move_direction(Vector2.DOWN if down else Vector2.ZERO)
	for i in 180:
		await get_tree().process_frame
		var row := sample(enemy,label,i)
		max_chase_error = maxf(max_chase_error,enemy.global_position.distance_to(control.global_position))
		if row.entry:
			entry_frames += 1
			if first_entry.is_empty(): first_entry = row.duplicate()
		status.text = "正常追击位移：(%+.1f, %+.1f)　黑暗区域：%s\n与无黑暗边界的追击对照偏差：%.2f" % [enemy.position.x-start.x,enemy.position.y-start.y,"进入" if row.entry else "外部",max_chase_error]
		if down and i%4==0: await capture(label)
	player.set_mobile_move_direction(Vector2.ZERO)
	report.trials[label] = {"start":pair(start),"end":pair(enemy.global_position),"player_end":pair(player.global_position),
		"entry_frames":entry_frames,"first_entry":first_entry,"max_chase_error":max_chase_error}

func wolf_trial(down: bool, from_charge := false) -> void:
	await reset()
	var wolf := battle.wave_manager.spawn_enemy("enemy_underworld_wolf",Vector2(-100,-65)) as UnderworldWolf
	# Skip only the spawn wait; skill range, charge, fire and movement are real.
	wolf.transition("chase",&"idle")
	wolf.sprite.visible = true
	wolf.breath_cooldown = 0.0
	wolf.leap_cooldown = 99.0
	var label := "wolf_down" if down else "wolf_stationary"
	if from_charge: label = "wolf_down_from_charge"
	caption.text = "问题 2：冥狼喷射期间 · " + ("玩家向下移动" if down else "玩家站定对照")
	for i in 120:
		if wolf.state=="breath": break
		await get_tree().process_frame
		if from_charge and wolf.state=="breath_charge": player.set_mobile_move_direction(Vector2.DOWN)
		sample(wolf,label+"_charge",i)
		status.text = "冥狼状态：%s　计时：%.3f 秒\n%s" % [wolf.state,wolf.state_time,"从蓄力开始下移，覆盖缩小后的黑暗边界" if from_charge else "等待正常蓄力结束，再开始玩家下移"]
		if down and i%4==0: await capture(label)
	check(wolf.state=="breath",label+": natural charge enters breath")
	var start := wolf.global_position
	var last_position := start
	var last_state := wolf.state
	var last_time := wolf.state_time
	var breath_distance := 0.0
	var frozen_frames := 0
	var entry_frames := 0
	var dark_breath_frames := 0
	var flame_origin_error := 0.0
	var first_recover_frame := -1
	var first_drag: Dictionary = {}
	player.set_mobile_move_direction(Vector2.DOWN if down else Vector2.ZERO)
	for i in 180:
		await get_tree().process_frame
		var row := sample(wolf,label,i)
		if wolf.state=="breath" and last_state=="breath":
			var distance := wolf.global_position.distance_to(last_position)
			breath_distance += distance
			if is_equal_approx(last_time,wolf.state_time): frozen_frames += 1
			if distance>0.01 and first_drag.is_empty(): first_drag = row.duplicate()
		if wolf.state=="breath":
			if row.entry: dark_breath_frames += 1
			flame_origin_error = maxf(flame_origin_error,wolf.flame.global_position.distance_to(wolf.breath_origin))
		if wolf.state=="breath_recover" and first_recover_frame<0: first_recover_frame = i
		if row.entry: entry_frames += 1
		last_position = wolf.global_position
		last_state = wolf.state
		last_time = wolf.state_time
		status.text = "冥狼状态：%s　阶段计时：%.3f 秒\n喷射中累计真实位移：%.1f　黑暗区域：%s" % [wolf.state,wolf.state_time,breath_distance,"进入" if row.entry else "外部"]
		if down and i%4==0: await capture(label)
	player.set_mobile_move_direction(Vector2.ZERO)
	check(first_recover_frame>=88 and first_recover_frame<=90,label+": breath ends at the configured 1.5 seconds")
	report.trials[label] = {"start":pair(start),"end":pair(wolf.global_position),"player_end":pair(player.global_position),
		"breath_distance":breath_distance,"frozen_breath_timer_frames":frozen_frames,"entry_frames":entry_frames,
		"dark_breath_frames":dark_breath_frames,"flame_origin_error":flame_origin_error,"first_recover_frame":first_recover_frame,
		"final_state":wolf.state,"final_state_time":wolf.state_time,"first_drag":first_drag}

func sample(enemy: EnemyController, label: String, frame: int) -> Dictionary:
	var screen: Vector2 = ground.world_to_ui*enemy.global_position
	var row := {"trial":label,"frame":frame,"physics_frame":Engine.get_physics_frames(),
		"player":pair(player.global_position),"enemy":pair(enemy.global_position),"velocity":pair(enemy.velocity),
		"screen":pair(screen),"threshold":ground.horizon.reveal_at(screen.x)+16.0,
		"entry":not ground.get_darkness_entry_direction(enemy.global_position).is_zero_approx(),
		"camera":pair(player.camera_2d.global_position)}
	if enemy is UnderworldWolf:
		row.state = enemy.state
		row.state_time = enemy.state_time
		row.flame_visible = enemy.flame.visible
		row.flame = pair(enemy.flame.global_position)
		row.breath_origin = pair(enemy.breath_origin)
	samples.append(row)
	return row

func verify_attack_visibility() -> void:
	await reset()
	player.set_physics_process(false)
	var bat := battle.wave_manager.spawn_enemy("enemy_echo_bat",Vector2(-120,-40)) as EchoBat
	var wolf := battle.wave_manager.spawn_enemy("enemy_underworld_wolf",Vector2(-120,-40)) as UnderworldWolf
	var knight := battle.wave_manager.spawn_enemy("enemy_elite_rusher",Vector2(-120,-40)) as EliteRusher
	for enemy: EnemyController in [bat,wolf,knight]: enemy.set_physics_process(false)
	bat.cooldown = 0.0
	wolf.transition("chase",&"idle")
	wolf.sprite.show()
	wolf.breath_cooldown = 0.0
	wolf.leap_cooldown = 0.0
	knight.skill_state = "chase"
	knight._cooldown = 0.0
	# Camera-only movement isolates the mask from actual player/enemy positions.
	player.camera_2d.offset = Vector2(0,320)
	player.camera_2d.force_update_scroll()
	await frames(3)
	check(not bat.is_in_visible_combat_area(),"camera-only test really places monsters behind darkness")
	check(not bat.begin_attack() and not wolf.begin_skill("breath") and not wolf.begin_skill("leap") and not knight.start_dash(),"hidden enemies cannot begin untelegraphed attacks")
	var before := bat.global_position
	bat._physics_process(1.0/60.0)
	check(bat.skill_state=="move" and bat.global_position.x>before.x and bat.velocity.y>0,"hidden bat follows the player diagonally, not the screen edge")
	player.camera_2d.offset = Vector2.ZERO
	player.camera_2d.force_update_scroll()
	await frames(3)
	check(bat.begin_attack() and wolf.begin_skill("breath") and knight.start_dash(),"visible enemies still start all normal special attacks")
	player.camera_2d.offset = Vector2(0,320)
	player.camera_2d.force_update_scroll()
	await frames(3)
	var fixed := true
	for enemy: EnemyController in [bat,wolf,knight]:
		before = enemy.global_position
		enemy._physics_process(0.1)
		fixed = fixed and enemy.global_position.is_equal_approx(before)
	check(fixed and bat.skill_state=="charge" and wolf.state=="breath_charge" and knight.skill_state=="windup","camera-only movement preserves active windups and their world positions")
	player.camera_2d.offset = Vector2.ZERO
	player.set_physics_process(true)

func verify_displacement_lock() -> void:
	await reset()
	player.set_physics_process(false)
	var wolf := battle.wave_manager.spawn_enemy("enemy_underworld_wolf",Vector2(-120,-30)) as UnderworldWolf
	wolf.set_physics_process(false)
	wolf.transition("chase",&"idle")
	wolf.sprite.show()
	wolf.breath_cooldown = 0.0
	wolf.leap_cooldown = 99.0
	check(wolf.begin_skill("breath"),"displacement review enters real breath windup")
	var target := ChallengeProbe.new()
	add_child(target)
	target.position = Vector2(500,500)
	wolf.challenge_target = target
	var hole := BlackHoleEffect.new()
	add_child(hole)
	hole.set_process(false)
	hole.global_position = wolf.global_position+Vector2(80,0)
	hole._duration = 10.0
	hole._targets.append(wolf)
	var anchor := wolf.global_position
	var hp := wolf.current_hp
	var max_distance := 0.0
	var max_speed := 0.0
	var phases: Dictionary = {}
	for i in 200:
		if not wolf.is_movement_locked(): break
		phases[wolf.state] = true
		wolf.apply_knockback(Vector2.DOWN,450.0,0.3)
		wolf.take_damage(1,"breath_lock_review",false,Vector2.RIGHT)
		wolf._apply_contact_knockback()
		hole._process(1.0/60.0)
		max_distance = maxf(max_distance,wolf.global_position.distance_to(anchor))
		max_speed = maxf(max_speed,wolf.velocity.length())
		wolf._physics_process(1.0/60.0)
		max_distance = maxf(max_distance,wolf.global_position.distance_to(anchor))
	check(phases.size()==3 and wolf.state=="chase","windup, breath and recovery finish even with a challenge target")
	check(max_distance<0.01 and max_speed<0.01,"knockback, hit recoil, contact recoil and black hole cannot move a breathing wolf")
	check(wolf.current_hp<hp,"movement lock still allows incoming damage")
	wolf.challenge_target = null
	wolf.apply_knockback(Vector2.RIGHT,450.0,0.3)
	check(wolf.velocity.x>0 and wolf._knockback_timer>0,"knockback becomes available after breath recovery")
	hole._process(1.0/60.0)
	check(wolf.global_position.x>anchor.x,"black hole pull resumes after recovery")
	report.displacement_lock = {"phases":phases.keys(),"maximum_distance":max_distance,"maximum_speed":max_speed,"damage_taken":hp-wolf.current_hp}
	hole.free()
	target.free()
	player.set_physics_process(true)

func capture_landscape() -> void:
	await reset()
	player.set_physics_process(false)
	player.global_position = Vector2.ZERO
	player._sync_camera()
	player.camera_2d.force_update_scroll()
	review_layer.hide()
	# Let floating damage labels from the displacement checks finish fading.
	await frames(75)
	var horizon := ground.horizon as CavernPitHorizon
	check(is_equal_approx(horizon.far_height(),103.0*horizon.art_scale*0.8),"far panorama height is eighty percent of the original")
	var previous_width := horizon.panorama.get_width()*horizon.art_scale*.5
	check(is_equal_approx(horizon.far_period(),previous_width*0.8),"far panorama width is eighty percent of the original")
	check(is_equal_approx(horizon.far_period()/horizon.far_height(),float(horizon.panorama.get_width())/horizon.panorama.get_height()),"far panorama preserves the source aspect ratio")
	check(horizon.reveal_end()<133.0*horizon.art_scale,"central dark/reveal band remains smaller than the original")
	check(horizon.ground_fade_end()<171.0*horizon.art_scale,"ground and decoration fade follow the reduced dark band")
	check(is_equal_approx(horizon.reveal_at(40),horizon.reveal_at(1560)),"reduced side shadows remain balanced")
	var ruins_fit := true
	for entry: Dictionary in horizon.entries:
		ruins_fit = ruins_fit and entry.root.y-horizon.ruin_display_size(entry.index).y*entry.scale>=0.0
	check(ruins_fit,"distant ruins fit the shorter band without top clipping")
	report.landscape = {"far_height":horizon.far_height(),"previous_far_height":103.0*horizon.art_scale,
		"far_width":horizon.far_period(),"previous_far_width":previous_width,
		"center_reveal":horizon.reveal_end(),"previous_center_reveal":133.0*horizon.art_scale,
		"ground_fade_end":horizon.ground_fade_end(),"side_reveal":horizon.reveal_at(40)}
	await capture("battle_1600")

func make_overlay() -> void:
	var layer := CanvasLayer.new()
	review_layer = layer
	layer.layer = 100
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(900,100)
	panel.size = Vector2(660,128)
	panel.color = Color(0.02,0.03,0.05,0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	caption = Label.new()
	caption.position = Vector2(914,110)
	caption.add_theme_font_size_override("font_size",22)
	layer.add_child(caption)
	status = Label.new()
	status.position = Vector2(914,148)
	status.add_theme_font_size_override("font_size",20)
	layer.add_child(status)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output.path_join("%s_%04d.png" % [label,capture_index]))
	capture_index += 1
