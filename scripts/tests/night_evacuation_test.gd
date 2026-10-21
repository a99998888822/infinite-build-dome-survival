extends Node
## Real entrance and transaction tests; --review captures the same production visuals.
var game: GameRoot
var flow: MainFlowCoordinator
var battle: BattleRoot
var manager: WaveManager
var player: PlayerController
var evacuation: NightEvacuation
var failures: Array[String] = []
var checks := 0
var review := false
var output := "res://artifacts/previews/night_evacuation_r01"

func _ready() -> void:
	WindowSettings._startup_applied = true
	get_tree().root.unfocusable = true
	review = "--review" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame

func boot() -> void:
	if flow != null:
		flow.enter_start_page()
		await frames(8)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(),"enter real battle")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.current_state==MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	manager = battle.wave_manager
	player = battle.player
	evacuation = manager.evacuation as NightEvacuation
	manager.set_process(false)
	battle.set_process(false)
	player.set_physics_process(false)
	manager.clear_enemies()
	await frames()
	evacuation.set_physics_process(false)

func move_foot(point: Vector2) -> void:
	player.global_position += point-evacuation.foot_position()
	evacuation.previous_foot = evacuation.foot_position()
	player._sync_camera()
	player.camera_2d.force_update_scroll()
	await frames()

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	evacuation.visual.refresh()
	(battle.hud as BattleHud)._refresh_wave_display()
	await frames(3)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN",false)
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	await boot()
	manager.wave_time_left = 0.0
	manager._process(.01)
	check(evacuation.active and manager.running,"zero enemies still require extraction")
	var view := player.get_viewport().get_canvas_transform().affine_inverse()*player.get_viewport_rect()
	check(not view.grow(79).intersects(Rect2(evacuation.bank_anchor-NightEvacuation.BANK_ANCHOR,NightEvacuation.BANK_SIZE)),"whole bunker starts outside camera")
	check(evacuation.placement_clear(evacuation.bank_anchor,evacuation.foot_position()),"spawn route and footprint clear future landmarks")
	var original_anchor := evacuation.bank_anchor
	var total := manager.get_living_enemy_count()
	manager._process(2.0)
	check(manager.get_living_enemy_count()==total,"initial orientation grace has no reinforcements")
	manager._process(12.0)
	check(manager.running and evacuation.active and evacuation.spawned_count>0,"ten seconds no longer forces finance; reinforcements spawn")
	check(evacuation.bank_anchor==original_anchor,"bunker stays fixed")
	var valid := true
	for enemy in EnemyRegistry.get_registered_enemies():
		enemy.set_physics_process(false)
		if enemy.get_meta("evacuation_enemy",false): valid = valid and evacuation.spawn_position_valid(enemy.global_position,bool(enemy.get_meta("evacuation_flanker",false)))
	check(valid,"reinforcements use rear pursuit or the rare far-bunker flank sector")
	var samples_valid := true
	for i in 100:
		var sample := evacuation.choose_spawn_position()
		if sample.is_finite(): samples_valid = samples_valid and evacuation.spawn_position_valid(sample)
	check(samples_valid,"sampled rear sector stays valid")
	var before_pause := evacuation.elapsed
	flow.request_esc_overlay()
	manager._process(50)
	check(evacuation.elapsed==before_pause,"Escape freezes pressure and night progression")
	flow.close_esc_overlay()
	flow.request_shared_reward_shop_popup(2)
	manager._process(50)
	check(evacuation.elapsed==before_pause,"reward popup freezes evacuation")
	flow.close_shared_reward_shop_popup()
	evacuation.elapsed = 50.0
	check(is_equal_approx(evacuation.reward_multiplier(),.5),"late reinforcements have half rewards after fifty seconds")
	var reward_actions: Array[Dictionary] = [{"type":"exp_orb","amount":1}]
	var first := evacuation.scale_reward_actions(reward_actions)
	var second := evacuation.scale_reward_actions(reward_actions)
	check(first.is_empty() and second.size()==1 and second[0].amount==1,"fractional rewards accumulate without rounding to full drops")
	for i in 100: manager._process(.3)
	check(manager.get_living_enemy_count()<=int(manager._difficulty.enemy_limit),"long overtime obeys enemy cap")
	check(EnemyRegistry.get_registered_enemies().any(func(e): return bool(e.get_meta("evacuation_hunter",false))),"prolonged overtime introduces announced hunters")
	check(manager.running and flow.current_state==MainFlowCoordinator.STATE_WAVE_COMBAT,"long overtime never auto-opens finance")
	manager.clear_enemies()
	await frames()
	manager._process(.01)
	check(evacuation.active,"clearing enemies during evacuation does not complete the wave")
	check(manager.spawn_enemy("enemy_mutated_grub",evacuation.ring_center)==null,"external spawns cannot bypass evacuation routing")
	check(not evacuation.contains_foot(evacuation.ring_center+Vector2(0,evacuation.ring_axes().y+2)),"outside visible circle is not sheltered")
	var finishes := [0]
	manager.wave_end_absorb_started.connect(func(_id): finishes[0] += 1)
	manager.spawn_exp_orb(2,evacuation.foot_position()+Vector2(450,-200))
	await move_foot(evacuation.ring_center+Vector2(0,evacuation.ring_axes().y-1))
	var hp := player.current_hp
	check(player.take_damage(99999,"same_frame_entry")==0 and player.current_hp==hp,"entry protects from damage in same frame")
	for i in 240:
		await get_tree().physics_frame
		if manager._finishing_wave_id.is_empty() and flow.current_state!=MainFlowCoordinator.STATE_WAVE_COMBAT: break
	await frames(6)
	check(finishes[0]==1 and not manager.running,"entry completes exactly once")
	check(flow.current_state==MainFlowCoordinator.STATE_FINANCE_POPUP,"successful entry opens actual finance")
	check(manager.collected_exp_this_wave>0,"successful entry collects existing earned drops")
	check(manager.wave_challenges.pressure.evacuated and not manager.wave_challenges.pressure.cleanup_timed_out,"extraction records success rather than cleanup timeout")
	manager.finish_current_wave()
	evacuation.complete_extraction()
	check(finishes[0]==1,"repeated entry cannot repeat settlement")
	flow.close_finance_popup()
	await frames(10)
	if flow.current_state==MainFlowCoordinator.STATE_WAVE_CHALLENGE:
		flow.decide_wave_challenge(str(manager.wave_challenges.offer.token),false)
		await frames(6)
	check(not evacuation.active and not player.evacuation_sheltered and not evacuation.visual.lit,"next wave resets shelter immunity and night")
	for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		await boot()
		manager.wave_time_left = 0
		manager._process(.01)
		await move_foot(evacuation.ring_center+direction*(evacuation.ring_axes()+Vector2(90,90)))
		check(not evacuation.try_enter_shelter() and manager.running,"outside ring stays in combat from "+str(direction))
		check(absi(evacuation.distance_to_shelter()-90)<=1,"guidance measures distance to ring from "+str(direction))
		player.keyboard_movement = false
		player.move_destination = player.global_position-direction*135
		player.has_move_destination = true
		player.set_physics_process(true)
		evacuation.set_physics_process(true)
		for i in 100:
			await get_tree().physics_frame
			if not manager.running: break
		await frames(20)
		check(not manager.running and flow.current_state==MainFlowCoordinator.STATE_FINANCE_POPUP,"normal movement crosses ring and enters finance from "+str(direction))
	await boot()
	manager.wave_time_left = 0
	manager._process(.01)
	player.take_damage(99999,"outside_shelter")
	await frames(15)
	check(flow.current_state==MainFlowCoordinator.STATE_BATTLE_RESULT and not player.evacuation_sheltered,"death outside bunker remains defeat")
	await boot()
	manager.current_wave_index = DataRegistry.get_table("waves").size()-1
	flow.current_wave_index = manager.current_wave_index
	manager.wave_time_left = 0
	manager._process(.01)
	await move_foot(evacuation.ring_center)
	evacuation.try_enter_shelter()
	await frames(20)
	check(flow.current_state==MainFlowCoordinator.STATE_BATTLE_RESULT and flow.battle_resolved,"final wave shelter triggers victory instead of finance")
	if review: await capture_review()
	flow.enter_start_page()
	await frames(8)
	CampProgression.end_transient_session()
	var report := {"checks":checks,"failures":failures,"review":review}
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("NIGHT_EVACUATION checks=",checks," failures=",failures.size())
	game.queue_free()
	await frames(8)
	get_tree().quit(0 if failures.is_empty() else 1)

func capture_review() -> void:
	await boot()
	await capture("00_wave")
	manager.wave_time_left = 0
	manager._process(.01)
	evacuation.elapsed = 5.0
	await capture("01_direction")
	# Walk toward the real generated location; no replacement artwork or light setup.
	await move_foot(evacuation.ring_center+Vector2(-380,100))
	evacuation.elapsed = 0
	await capture("02_daylight")
	evacuation.elapsed = 14
	await capture("03_dusk")
	evacuation.elapsed = 28
	for i in 175:
		manager._process(.2)
	# Let the real spawn warnings finish and the rear wave advance before freezing the review.
	await get_tree().create_timer(1.0).timeout
	for enemy in EnemyRegistry.get_registered_enemies(): enemy.set_physics_process(false)
	# Let the intentionally compressed spawn burst leave the FPS sampling window.
	await frames(45)
	var timings: Dictionary = {}
	for mask_enabled in [true,false]:
		evacuation.visual.night_rect.visible = mask_enabled
		await frames(8)
		var previous := Time.get_ticks_usec()
		var samples: Array[float] = []
		for i in 30:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now-previous)/1000.0)
			previous = now
		samples.sort()
		timings["night_overlay" if mask_enabled else "overlay_disabled"] = {"median_frame_ms":samples[15],"p90_frame_ms":samples[27],"enemies":manager.get_living_enemy_count()}
	evacuation.visual.night_rect.show()
	FileAccess.open(output.path_join("render_timing.json"),FileAccess.WRITE).store_string(JSON.stringify(timings,"\t"))
	await capture("04_night")
	await move_foot(evacuation.ring_center+Vector2(-evacuation.ring_axes().x-28,55))
	await capture("05_shelter")
	if "--motion" in OS.get_cmdline_user_args(): await capture_ring_motion()
	await move_foot(evacuation.ring_center)
	evacuation.try_enter_shelter()
	await frames(20)
	await capture("06_finance")

func capture_ring_motion() -> void:
	if DisplayServer.get_name()=="headless": return
	var directory := output.path_join("motion")
	DirAccess.make_dir_recursive_absolute(directory)
	var center: Vector2 = evacuation.visual.to_screen(evacuation.bank_anchor+Vector2(0,-50))
	var region := Rect2i(Vector2i(center)-Vector2i(390,260),Vector2i(780,520))
	var started := evacuation.elapsed
	for i in 60:
		evacuation.elapsed = started+float(i)/20.0
		evacuation.visual.refresh()
		await frames(2)
		await RenderingServer.frame_post_draw
		var frame := get_tree().root.get_texture().get_image().get_region(region)
		frame.save_png(directory.path_join("frame_%03d.png" % i))
	evacuation.elapsed = started
