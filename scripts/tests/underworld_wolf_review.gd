extends Node
## Production scenes, wave spawner and real damage; only review inputs are staged.
const WOLF = preload("res://scenes/enemy/underworld_wolf.tscn")
class MixWaveManager extends WaveManager:
	var rolls := 0
	func _miniboss_variant_roll() -> float:
		var result := 0.25 if rolls % 2 == 0 else 0.75
		rolls += 1
		return result

var capture_runtime := false
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var wolf: UnderworldWolf
var checks := 0
var failures := 0
var captures := ""
var interactive := false
var caption: Label
var status: Label
var samples: Array = []
var seen: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): captures = arg.trim_prefix("--capture-dir=")
		if arg == "--interactive": interactive = true
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)


func frames(count: int = 3) -> void:
	for i in count: await get_tree().process_frame


func reset(wolf_pos: Vector2, player_pos: Vector2) -> void:
	var push := player.get_node_or_null("EnemyKnockback")
	if push != null: push.cancel()
	if is_instance_valid(wolf): wolf.free()
	player.global_position = player_pos
	player.alive = true
	player.current_hp = int(player.get_stat("max_hp"))
	player.current_shield = 0
	player._invincibility_timer = 0
	player.sprite.modulate = Color.WHITE
	if capture_runtime:
		wolf = battle.wave_manager.spawn_enemy("enemy_underworld_wolf", wolf_pos)
	else:
		wolf = WOLF.instantiate()
		wolf.auto_initialize_on_ready = false
		player.get_parent().add_child(wolf)
		wolf.initialize("enemy_underworld_wolf", player)
	wolf.push_controller.set_physics_process(false)
	wolf.push_controller.impulse_count = 0
	wolf.push_controller.total_distance = 0
	wolf.global_position = wolf_pos
	wolf.set_physics_process(false)
	wolf.transition("chase", &"idle")
	wolf.sprite.visible = true
	wolf.leap_cooldown = 99
	wolf.breath_cooldown = 99
	await frames()


func step(count: int, movement := Vector2.ZERO) -> void:
	for i in count:
		await get_tree().physics_frame
		player.move_and_collide(movement/60.0)
		player._update_walk_animation(movement,1.0/60.0)
		if not is_zero_approx(movement.x):
			player.facing_right = movement.x > 0
			player.visual_anchor.scale.x = absf(player.visual_anchor.scale.x)*(1 if player.facing_right else -1)
		player._invincibility_timer = maxf(0,player._invincibility_timer-1.0/60.0)
		wolf._physics_process(1.0/60.0)
		wolf.push_controller._physics_process(1.0/60.0)
		seen[str(wolf.animation)+":"+str(wolf.animation_index)] = true
		await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = not interactive
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",[])
	await frames(4)
	check(flow.confirm_character_selection(),"real main battle opened")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.hud.set_process(false)
	player = battle.player
	player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	await frames()
	if interactive:
		await reset(Vector2(-260,0),Vector2(100,0))
		wolf.leap_cooldown = 2
		wolf.breath_cooldown = 1.5
		wolf.set_physics_process(true)
		wolf.push_controller.set_physics_process(true)
		player.set_physics_process(true)
		battle.active_controller.enabled = true
		make_overlay()
		caption.text = "独立试玩 · 使用当前战斗操作移动与攻击"
		status.text = "正式场景与素材 · 已加入小 Boss 刷新池"
		return
	await validate()
	await validate_production()
	if not captures.is_empty() and DisplayServer.get_name() != "headless" and failures == 0:
		capture_runtime = true
		DirAccess.make_dir_recursive_absolute(captures)
		make_overlay()
		await capture_storyboard()
		var file := FileAccess.open(captures.path_join("samples.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(samples,"\t"))
	print("UNDERWORLD_WOLF_COMPLETE checks=%d failures=%d captures=%d" % [checks,failures,samples.size()])
	get_tree().quit(1 if failures else 0)


func validate() -> void:
	check(DataRegistry.get_load_errors().is_empty(),"production configuration validates")
	check(DataRegistry.has_record("enemies","enemy_underworld_wolf"),"wolf registered as a production enemy")
	await reset(Vector2(-350,0),Vector2(100,0))
	await step(65)
	check(wolf.global_position.x > -250,"candidate moves through real physics")
	var all_move := true
	for i in 7: all_move = all_move and seen.has("move:"+str(i))
	check(all_move,"all seven movement poses rendered")
	check(wolf.get_stat("max_hp") == 720 and wolf.get_stat("armor") == 6,"tripled independent wolf health loaded")
	check(wolf.enemy_data.display_name == "幽焰冥狼","updated display name")
	var registered := wolf.FRAME_TRANSFORMS.size() == 21
	for record: Dictionary in wolf.FRAME_TRANSFORMS.values():
		registered = registered and (is_equal_approx(record.sprite_scale,0.8192) or is_equal_approx(record.sprite_scale,1.024))
	check(registered,"all 21 frames retain approved source-space registration in exported resources")
	var collider := wolf.get_node("CollisionShape2D") as CollisionShape2D
	check(is_equal_approx(collider.shape.radius,18.4) and is_equal_approx(collider.shape.height,60.8),"body collider shrinks with visual")
	wolf.transition("spawn", &"idle")
	check(wolf.take_damage(20) == 0,"spawn grace rejects damage")
	await step(46)
	check(wolf.state == "chase","spawn grace ends")
	await reset(Vector2(-200,0),Vector2(60,0))
	wolf.leap_cooldown = 0
	check(wolf.begin_skill("leap"),"leap accepts medium range")
	var hp := player.current_hp
	await step(53)
	check(wolf.state == "leap_charge" and player.current_hp == hp,"0.9 second windup has no damage")
	var locked: Vector2 = wolf.locked_point
	var time: float = wolf.state_time
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await step(10)
	check(is_equal_approx(wolf.state_time,time),"pause freezes skill and warning")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	await step(1)
	check(wolf.state == "leap","leap starts at configured timing")
	await step(36,Vector2(0,-260))
	check(wolf.locked_point.is_equal_approx(locked) and wolf.global_position.distance_to(locked) < 1,"leap lands at locked position without homing")
	check(wolf.state == "land" and player.current_hp == hp,"sidestep avoids landing damage")
	await step(44)
	check(wolf.state == "chase" and wolf.leap_cooldown > 5.9,"landing and recovery complete before cooldown")
	await reset(Vector2(-200,0),Vector2(60,0))
	wolf.leap_cooldown = 0
	wolf.begin_skill("leap")
	hp = player.current_hp
	await step(89)
	check(player.current_hp == hp,"no air or charge contact damage")
	await step(1)
	check(player.current_hp == hp-18 and wolf.damage_events == 1,"landing applies exactly 18 damage once")
	check(wolf.push_controller.impulse_count == 1,"quake starts one real knockback impulse")
	var landed_position := player.global_position
	await step(5)
	check(wolf.state == "recover" and wolf.animation == &"idle","landing switches to idle within 0.083 seconds")
	await step(33)
	check(player.global_position.distance_to(landed_position) > 35,"quake pushes player more than 35 world units")
	check(player.current_hp == hp-18 and wolf.damage_events == 1,"landing recovery does not repeat damage")
	await reset(Vector2(-120,0),Vector2(20,0))
	wolf.breath_cooldown = 0
	check(wolf.begin_skill("breath"),"ranged target starts breath")
	var lamp := DataRegistry.get_record("weapons","weapon_copper_lamp")
	check(is_equal_approx(wolf.profile.breath_range,float(lamp.attack_range)*2),"breath reach is twice the initial copper lamp reach")
	check(is_equal_approx(wolf.profile.breath_cone_degrees,float(lamp.lamp_cone_degrees)),"breath keeps copper lamp cone angle")
	hp = player.current_hp
	await step(53)
	check(player.current_hp == hp and wolf.state == "breath_charge" and not wolf.flame.visible,"0.9 second warning precedes flame and damage")
	await step(1)
	check(player.current_hp == hp-6 and wolf.breath_hits == 1 and wolf.flame.visible,"first flame pulse deals six damage")
	var pushed_position := player.global_position
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await step(10)
	check(player.global_position.is_equal_approx(pushed_position),"pause also freezes knockback")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	await step(30)
	check(player.current_hp == hp-12 and wolf.breath_hits == 2,"second flame pulse at 0.5 seconds")
	await step(30)
	check(player.current_hp == hp-18 and wolf.breath_hits == 3,"third flame pulse at 1.0 seconds")
	await step(28)
	check(wolf.breath_hits == 3 and wolf.damage_events == 3 and player.current_hp == hp-18,"continued exposure cannot cause a fourth hit")
	check(wolf.push_controller.impulse_count == 3 and player.global_position.distance_to(pushed_position)>30,"each successful flame hit pushes player")
	await step(3)
	check(not wolf.flame.visible and wolf.state == "breath_recover" and wolf.animation == &"idle","flame ends and returns to idle recovery")
	await reset(Vector2(-120,0),Vector2(20,0))
	wolf.breath_cooldown = 0
	wolf.begin_skill("breath")
	var aim: Vector2 = wolf.breath_direction
	hp = player.current_hp
	await step(45,Vector2(0,-180))
	await step(95)
	check(player.current_hp == hp and wolf.breath_hits == 0,"sidestep avoids all flame pulses")
	check(wolf.breath_direction.is_equal_approx(aim),"flame direction stays locked after warning")
	await reset(Vector2(-120,0),Vector2(20,0))
	wolf.breath_cooldown = 0
	wolf.begin_skill("breath")
	player._invincibility_timer = 5
	await step(140)
	check(wolf.breath_hits == 0 and wolf.push_controller.impulse_count == 0,"invulnerable target receives neither damage nor knockback")
	await reset(Vector2(-120,0),Vector2(20,0))
	wolf.breath_cooldown = 0
	wolf.begin_skill("breath")
	player.global_position = wolf.breath_origin + wolf.breath_direction*260
	await step(140)
	check(wolf.breath_hits == 0,"beyond cone radius is safe")
	await reset(Vector2(-120,0),Vector2(20,0))
	wolf.breath_cooldown = 0
	wolf.begin_skill("breath")
	await step(56)
	wolf.take_damage(99999,"flame_death")
	check(not wolf.flame.visible and not wolf.floor_art.visible,"death removes flame and warning immediately")
	await reset(Vector2(-200,0),Vector2(60,0))
	wolf.leap_cooldown = 0
	wolf.begin_skill("leap")
	wolf.apply_lightning_stun(1)
	await step(10)
	check(wolf.state_time == 0,"reduced stun pauses warning instead of cancelling it")
	await step(10)
	check(wolf.state_time > 0,"skill resumes after control resistance")
	var before: int = wolf.current_hp
	var dealt: int = wolf.take_damage(20,"review_hit")
	check(dealt > 0 and wolf.current_hp == before-dealt,"candidate receives real player-side damage")
	wolf.take_damage(99999,"review_lethal")
	check(not wolf.alive and wolf.state == "dead" and not wolf.floor_art.visible,"death clears warnings immediately")
	await frames(20)
	await reset(Vector2(-500,0),Vector2(60,0))
	wolf.leap_cooldown = 0
	check(not wolf.begin_skill("leap"),"out of range leap rejected")
	wolf.global_position = Vector2(20,0)
	check(not wolf.begin_skill("leap"),"point blank leap rejected")
	await reset(Vector2(220,0),Vector2.ZERO)
	wolf.breath_cooldown = 0
	check(wolf.begin_skill("breath") and wolf.sprite.flip_h and wolf.breath_direction.x < 0,"left-facing flame uses the mirrored mouth and correct range")
	# All 21 sources are present in runtime SpriteFrames, including landing 10.
	var unique: Dictionary = {}
	var correct_size := true
	for action in wolf.FRAMES.get_animation_names():
		for i in wolf.FRAMES.get_frame_count(action):
			var tex: AtlasTexture = wolf.FRAMES.get_frame_texture(action,i)
			unique[str(tex.atlas.get_instance_id())+str(tex.region)] = true
			correct_size = correct_size and tex.region.size == Vector2(128,128)
	check(unique.size() == 21,"all 21 source poses mapped into nine runtime animations")
	check(correct_size,"all runtime atlas regions are exactly 128 by 128")
	wolf.transition("chase", &"idle")
	wolf.sprite.flip_h = false
	wolf.animate(0)
	var right_offset: Vector2 = wolf.sprite.position
	check(wolf.sprite.scale.is_equal_approx(Vector2.ONE*0.8192),"approved idle grid uses original four-source-pixel cells")
	wolf.sprite.flip_h = true
	wolf.animate(0)
	check(wolf.sprite.position.is_equal_approx(Vector2(-right_offset.x,right_offset.y)),"left-facing pixel pose mirrors registration around shared foot anchor")


func make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	game.add_child(layer)
	for rect in [Rect2(20,18,1240,80),Rect2(20,610,1240,90)]:
		var panel := ColorRect.new()
		panel.position = rect.position
		panel.size = rect.size
		panel.color = Color(0.045,0.065,0.10,0.94)
		layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(42,26)
	title.add_theme_font_size_override("font_size",25)
	title.text = "幽焰冥狼 · 正式资源实机审阅"
	layer.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(43,64)
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.modulate = Color("a2c8dc")
	subtitle.text = "128×128 / 21 帧  ·  已加入小 Boss 刷新池  ·  正式数值成长与掉落  ·  幽蓝喷焰 / 震地击退"
	layer.add_child(subtitle)
	caption = Label.new()
	caption.position = Vector2(42,620)
	caption.add_theme_font_size_override("font_size",23)
	layer.add_child(caption)
	status = Label.new()
	status.position = Vector2(43,659)
	status.add_theme_font_size_override("font_size",17)
	status.modulate = Color("b7cddd")
	layer.add_child(status)


func validate_production() -> void:
	if is_instance_valid(wolf): wolf.free()
	var manager := MixWaveManager.new()
	player.get_parent().add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager._difficulty.spawn_count = 1.0
	manager.current_wave_index = 0
	manager.current_wave = {"id":"wolf_mix_review", "duration_seconds":30, "spawn_groups":[
		{"enemy_id":"enemy_mutated_grub", "spawn_interval_ms":1200, "count_per_spawn":1}]}
	manager.wave_time_left = 25
	var counts := {"enemy_elite_rusher":0, "enemy_underworld_wolf":0}
	for i in 100:
		var id := manager._select_miniboss_variant("enemy_elite_rusher")
		counts[id] += 1
	check(counts.enemy_elite_rusher == 50 and counts.enemy_underworld_wolf == 50,"weighted miniboss pool selects both types equally")
	check(manager.calculate_miniboss_expected_count(1,200) == 0 and manager.calculate_miniboss_expected_count(20,200) == 3,"shared first-wave exclusion and three-miniboss cap preserved")
	manager.rolls = 1
	manager._elite_spawn_deadline = 15
	manager._elite_spawn_schedule.assign([0.0])
	manager.spawn_timers_ms.assign([0.0])
	manager._process_spawn_timers(0)
	var spawned: Array = manager.get_children().filter(func(n: Node): return n is EnemyController)
	check(spawned.size() == 1 and spawned[0] is UnderworldWolf and manager._elite_spawned_count == 1 and manager._elite_spawn_schedule.is_empty(),"real spawn timer uses one reserved elite slot for the wolf")
	for enemy in spawned: enemy.free()
	manager.spawn_timers_ms.assign([0.0])
	manager._process_spawn_timers(0)
	spawned = manager.get_children().filter(func(n: Node): return n is EnemyController)
	check(spawned.size() == 1 and spawned[0].enemy_data.enemy_type == "normal","ordinary spawn remains ordinary once elite slot is consumed")
	for enemy in spawned: enemy.free()
	manager.rolls = 0
	manager._challenge_elite_schedule.assign([5.0,5.0])
	manager._challenge_elite_planned = 2
	manager._difficulty.enemy_limit = 0
	manager._process_spawn_timers(0)
	spawned = manager.get_children().filter(func(n: Node): return n is EnemyController)
	check(spawned.size() == 2 and spawned[0] is EliteRusher and spawned[1] is UnderworldWolf and manager._challenge_elite_spawned == 2,"challenge adds exactly two elites through the same mixed pool even at crowd cap")
	for enemy in spawned: enemy.free()
	var knight := manager.spawn_enemy("enemy_elite_rusher",Vector2(-500,0))
	check(knight is EliteRusher,"explicit knight spawns keep their requested identity")
	knight.free()
	manager._wave_erosion_pressure = manager.calculate_enemy_erosion_pressure(0)
	var cold := manager.spawn_enemy("enemy_underworld_wolf",Vector2(-120,0)) as UnderworldWolf
	cold.set_physics_process(false)
	check(cold.current_hp == 576 and cold.get_stat("ranged_damage") == 3 and cold.get_stat("element_damage") == 8,"normal difficulty scales tripled HP and both skill damage stats")
	manager.current_wave_index = 4
	manager._wave_erosion_pressure = manager.calculate_enemy_erosion_pressure(100)
	var hot := manager.spawn_enemy("enemy_underworld_wolf",Vector2(-120,0)) as UnderworldWolf
	hot.set_physics_process(false)
	check(hot.current_hp > cold.current_hp and hot.current_hp == int(hot.get_stat("max_hp")) and hot.get_stat("ranged_damage") > cold.get_stat("ranged_damage") and hot.get_stat("element_damage") > cold.get_stat("element_damage"),"wave and erosion growth reaches HP, flame and quake through production spawner")
	cold.free()
	player.global_position = Vector2(20,0)
	player.current_hp = int(player.get_stat("max_hp"))
	player._invincibility_timer = 0
	player.current_shield = 0
	hot.transition("chase", &"idle")
	hot.breath_cooldown = 0
	hot.begin_skill("breath")
	var before := player.current_hp
	hot.try_breath_pulse()
	check(before-player.current_hp == roundi(hot.get_stat("ranged_damage")),"actual flame hit consumes scaled production damage")
	hot.push_controller.cancel()
	player._invincibility_timer = 0
	before = player.current_hp
	hot.area_damage(player.global_position,float(hot.profile.leap_radius),roundi(hot.get_stat("element_damage")))
	check(before-player.current_hp == roundi(hot.get_stat("element_damage")),"actual quake hit consumes scaled production damage")
	player.alive = true
	player.current_hp = int(player.get_stat("max_hp"))
	var kills := manager.run_statistics.kills
	hot.take_damage(999999,"weapon_copper_lamp")
	hot._die("duplicate")
	check(manager.run_statistics.kills == kills+1 and int(manager.run_statistics.monsters.get("enemy_underworld_wolf",0)) == 1 and hot.get_drop_table_id() == "drop_elite_enemy","wolf kill enters settlement and elite reward pipeline exactly once")
	check(not hot.flame.visible and not hot.floor_art.visible and hot.push_controller.remaining == 0,"death removes flame, warning and owned player impulse immediately")
	hot.free()
	manager.free()
	await frames(4)
	await reset(Vector2(-200,0),Vector2(60,0))
	wolf.leap_cooldown = 0
	wolf.begin_skill("leap")
	await step(58)
	check(wolf.get_collision_exceptions().has(player),"leap temporarily excludes the player body")
	wolf.fade_out_and_free()
	check(not wolf.get_collision_exceptions().has(player) and not wolf.floor_art.visible and not wolf.flame.visible and not wolf.alive,"wave cleanup clears airborne collision exception and every skill visual")
	wolf.free()
	await reset(Vector2(-120,0),Vector2(20,0))
	var other := WOLF.instantiate() as UnderworldWolf
	other.auto_initialize_on_ready = false
	player.get_parent().add_child(other)
	other.initialize("enemy_underworld_wolf",player)
	other.set_physics_process(false)
	wolf.push_controller.impulse(wolf,Vector2.RIGHT,160,0.18)
	wolf.push_controller.impulse(other,Vector2.LEFT,160,0.18)
	check(wolf.push_controller == other.push_controller and player.get_collision_exceptions().has(other) and not player.get_collision_exceptions().has(wolf),"multiple wolves share one player impulse and release obsolete exceptions")
	wolf.fade_out_and_free()
	check(other.push_controller.remaining > 0,"cleaning another wolf cannot cancel the current attacker's impulse")
	other.free()
	check(player.get_node("EnemyKnockback").remaining == 0,"freeing impulse owner stops residual player movement")
	wolf.free()
	for pair in [["breath_max_hits",4], ["breath_tick_ms",0], ["leap_duration_ms",-1], ["breath_cone_degrees",180], ["leap_max_range",1]]:
		var profile: Dictionary = DataRegistry.get_record("enemies","enemy_underworld_wolf").wolf_profile
		profile[pair[0]] = pair[1]
		var validator := DataValidator.new()
		validator._validate_wolf_profile(profile,"wolf_profile")
		check(not validator.errors.is_empty(),"reject invalid wolf profile: "+str(pair[0]))
	await frames(4)


func capture_storyboard() -> void:
	await capture_comparison()
	var captions := ["01 / 正式场景与 128 像素移动循环", "02 / 扑跃：侧移躲避，落地 0.08 秒后回到 idle", "03 / 震地命中：按当前难度结算伤害，并击退玩家", "04 / 幽蓝喷焰：最多 3 次伤害，每次命中均击退", "05 / 喷焰方向锁定：提前侧移可完全躲开"]
	var names := {"chase":"追击", "leap_charge":"扑跃蓄力 0.9 秒", "leap":"腾空 0.6 秒", "land":"落地冲击", "recover":"idle 收招", "breath_charge":"扇形预警 0.9 秒", "breath":"幽蓝火焰喷吐", "breath_recover":"idle 收招"}
	var lengths: Array[int] = [58,55,55,72,72]
	for chapter in 5:
		if chapter == 0: await reset(Vector2(-250,0),Vector2(230,0))
		elif chapter < 3: await reset(Vector2(-180,0),Vector2(100,0))
		else: await reset(Vector2(-150,0),Vector2(40,0))
		caption.text = captions[chapter]
		for frame in lengths[chapter]:
			var time: float = frame*0.05
			if frame == 10 and chapter > 0:
				if chapter < 3:
					wolf.leap_cooldown = 0
					wolf.begin_skill("leap")
				else:
					wolf.breath_cooldown = 0
					wolf.begin_skill("breath")
			var movement := Vector2.ZERO
			if chapter == 1 and time >= .95 and time < 1.75: movement = Vector2(0,-180)
			if chapter == 4 and time >= .8 and time < 1.5: movement = Vector2(0,-190)
			await step(3,movement)
			if chapter > 0 and time > 2.7:
				wolf.leap_cooldown = 99
				wolf.breath_cooldown = 99
			player.camera_2d.global_position = Vector2(40,15) if chapter >= 3 else Vector2(0,-45)
			player.camera_2d.offset = Vector2.ZERO
			player.camera_2d.zoom = Vector2.ONE*(1.35 if chapter >= 3 else 1.6)
			player.camera_2d.reset_smoothing()
			player.camera_2d.force_update_scroll()
			for path in ["HUD","BattleTopBar","BattleTopBarBackground"]:
				var ui := battle.get_node_or_null(path) as CanvasLayer
				if ui != null: ui.hide()
			battle.hud._economy_log_layer.hide()
			battle.active_controller._cursor_layer.hide()
			status.text = "%s    ·    玩家生命 %d / %d    ·    火焰命中 %d / 3    ·    动画 %s" % [names.get(wolf.state,wolf.state),player.current_hp,int(player.get_stat("max_hp")),wolf.breath_hits,wolf.animation]
			await RenderingServer.frame_post_draw
			var picture := get_tree().root.get_texture().get_image()
			var filename := "frame_%03d.png" % samples.size()
			check(picture.save_png(captures.path_join(filename)) == OK,"capture "+filename)
			if frame == (39 if chapter >= 3 else 43): picture.save_png(captures.get_base_dir().path_join("chapter_%d.png" % chapter))
			samples.append({"file":filename,"chapter":chapter,"time":time,"state":wolf.state,"hp":player.current_hp,"animation":wolf.animation,"frame":wolf.animation_index,"position":[wolf.global_position.x,wolf.global_position.y],"player_position":[player.global_position.x,player.global_position.y],"locked":[wolf.locked_point.x,wolf.locked_point.y],"flame_hits":wolf.breath_hits,"knockbacks":wolf.push_controller.impulse_count})


func capture_comparison() -> void:
	# Let transient damage labels from the preceding validation expire.
	await get_tree().create_timer(0.8).timeout
	await reset(Vector2(0,0),Vector2(220,0))
	var previous = battle.wave_manager.spawn_enemy("enemy_elite_rusher", Vector2(-230,0))
	previous.set_physics_process(false)
	previous.global_position = Vector2(-230,0)
	previous.skill_state = "chase"
	previous._set_animation(&"idle")
	previous.sprite.visible = true
	caption.text = "正式小 Boss / 左：钢甲骑士    中：幽焰冥狼    右：玩家"
	status.text = "两种小 Boss 等概率出现 · 共用刷新配额 · 普通怪仍为幼体与蝙蝠"
	player.camera_2d.global_position = Vector2(0,-45)
	player.camera_2d.zoom = Vector2.ONE*1.6
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	for path in ["HUD","BattleTopBar","BattleTopBarBackground"]:
		var ui := battle.get_node_or_null(path) as CanvasLayer
		if ui != null: ui.hide()
	battle.hud._economy_log_layer.hide()
	battle.active_controller._cursor_layer.hide()
	await frames(4)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(captures.get_base_dir().path_join("size_comparison.png")) == OK,"size comparison GPU screenshot")
	previous.free()
