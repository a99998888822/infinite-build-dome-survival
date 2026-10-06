extends Node
const TARGET = preload("res://scripts/tests/water_review_target.gd")
const SIZE := Vector2i(1152,648)
var output := ""
var spell := "lightning"
var variant := "original"
var capture := false
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var weapon: WeaponInstance
var enemies: Array[EnemyController] = []
var targets: Array[Vector2] = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--spell="): spell=arg.trim_prefix("--spell=")
		if arg.begins_with("--variant="): variant=arg.trim_prefix("--variant=")
		if arg=="--capture": capture=true
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	CombatSettings.set_option("wheelchair_mode",false,false)
	seed(10061206)
	game=load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene=game
	await frames(12)
	get_tree().root.unfocusable=true
	get_tree().root.size=SIZE
	get_tree().root.content_scale_size=SIZE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=120
	var flow:=game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames(4)
	assert(flow.confirm_character_selection())
	battle=(game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player=battle.player
	player.set_physics_process(false)
	player._invincibility_timer=9999
	player.modifier_stack.set_base_stat("load_capacity",1000)
	for old: WeaponInstance in battle.loadout.weapon_instances.duplicate():
		battle.loadout.remove_weapon(old.weapon_id)
	assert(battle.loadout.equip_weapon("weapon_void_blade"))
	weapon=battle.loadout.get_weapon_instance("weapon_void_blade")
	for previous in weapon.get_attached_item_instances():
		weapon.detach_item_instance(str(previous.item_instance_id))
	var item:=DataRegistry.get_record("augmentations","scroll_"+spell).duplicate(true)
	item.item_instance_id="appearance_"+spell
	item.base_item_id="scroll_"+spell
	assert(weapon.attach_item_instance(item))
	player.camera_2d.offset=Vector2(125,-25)
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	var host:=Node2D.new()
	player.get_parent().add_child(host)
	var offsets: Array[Vector2]=[Vector2(150,0),Vector2(275,-20),Vector2(250,90),Vector2(365,85),Vector2(110,120)]
	if spell=="electric_spark": offsets=[Vector2(185,0),Vector2(210,20),Vector2(205,-22),Vector2(290,85),Vector2(325,-50)]
	for offset in offsets:
		var enemy:=load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(TARGET)
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub",player)
		enemy.current_hp=10000
		enemy.global_position=player.global_position+offset
		enemies.append(enemy)
		targets.append(enemy.global_position)
	var layer:=CanvasLayer.new()
	layer.layer=90
	game.add_child(layer)
	var bg:=ColorRect.new()
	bg.position=Vector2(12,95)
	bg.size=Vector2(1115,46)
	bg.color=Color(0.02,0.03,0.025,0.9)
	layer.add_child(bg)
	var label:=Label.new()
	label.position=Vector2(22,101)
	label.add_theme_font_size_override("font_size",20)
	label.text=("电火花 · 连锁闪电" if spell=="lightning" else "落雷")+" | "+("正式效果" if variant=="original" else "审阅版 · 延长停留 / 减半喷溅 / 小辉光")
	layer.add_child(label)
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	await get_tree().create_timer(.5).timeout
	_check_contract()
	var raw: FileAccess
	if capture: raw=FileAccess.open(output.path_join("frames.rgb"),FileAccess.WRITE)
	var stamps: Array[float]=[]
	var paths: Dictionary={}
	var effects: Dictionary={}
	var cast_times: Array[float]=[]
	var next_capture:=0.0
	var particles_peak:=0
	var first_cast:=false
	var second_cast:=false
	var start:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<4600000:
		await get_tree().process_frame
		var elapsed:=float(Time.get_ticks_usec()-start)/1e6
		battle.loadout.tick(get_process_delta_time())
		if (not first_cast and elapsed>=.4) or (not second_cast and elapsed>=2.9):
			for i in enemies.size():
				enemies[i].global_position=targets[i]
				enemies[i].velocity=Vector2.ZERO
			assert(battle.loadout.cast_weapon(weapon,targets[0]))
			if not first_cast: first_cast=true
			else: second_cast=true
			cast_times.append(elapsed)
		var count:=0
		for source in get_tree().get_nodes_in_group("combat_particle_counters"):
			count+=source.get_active_particle_count()
			if source is LightningParticleEffect:
				effects[str(source.get_instance_id())]=true
				for pulse: Dictionary in source._path_pulses:
					var bolt: Node2D=pulse.bolt
					var id:=str(bolt.get_instance_id())
					if not paths.has(id):
						paths[id]={"first":elapsed,"last":elapsed,"alphas":[],"cells":bolt.cell_size,"builds":bolt.build_count,"rim_cells":bolt.rim_cells.size(),"echo":pulse.echoed,"points_hash":hash(bolt.points)}
					paths[id].last=elapsed
					if not paths[id].alphas.has(bolt.modulate.a): paths[id].alphas.append(bolt.modulate.a)
		particles_peak=maxi(particles_peak,count)
		if capture and elapsed>=next_capture:
			await RenderingServer.frame_post_draw
			var im:=get_tree().root.get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			raw.store_buffer(im.get_data())
			stamps.append(float(Time.get_ticks_usec()-start)/1e6)
			next_capture=elapsed+1.0/30.0
	if capture: raw.close()
	var damage:=0
	for enemy in enemies: damage+=10000-enemy.current_hp
	assert(cast_times.size()==2 and damage>0 and paths.size()>=4)
	var echoes:=0
	for p: Dictionary in paths.values():
		assert(p.cells==2 and p.builds==1)
		if variant=="candidate": assert(p.rim_cells==0)
		if p.echo: echoes+=1
	assert(echoes>=2)
	var result: Dictionary={"spell":spell,"variant":variant,"damage":damage,"casts":cast_times,"paths":paths,"effects":effects.size(),"particle_peak":particles_peak,"duration":4.6,"frame_stamps":stamps,"size":[SIZE.x,SIZE.y],"step_seconds":LightningParticleEffect.STEP_SECONDS,"total_seconds":LightningParticleEffect.TOTAL_SECONDS,"method":"Real GameRoot, Lv1 wooden bow, one scroll, two real casts, no damage or timing overrides"}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LIGHTNING_APPEARANCE_PASS ",spell," ",variant," damage=",damage," paths=",paths.size()," echoes=",echoes," particles_peak=",particles_peak)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await get_tree().create_timer(.3).timeout
	CampProgression.end_transient_session()
	get_tree().quit()

func _check_contract() -> void:
	var expected:=.28 if variant=="original" else .44
	assert(is_equal_approx(LightningParticleEffect.TOTAL_SECONDS,expected))
	var step:=LightningParticleEffect.STEP_SECONDS
	assert(is_equal_approx(LightningParticleEffect.alpha_at(step*.5),1.0))
	assert(is_equal_approx(LightningParticleEffect.alpha_at(step*1.5),.6))
	assert(is_equal_approx(LightningParticleEffect.alpha_at(step*2+.02),0.0))
	assert(is_equal_approx(LightningParticleEffect.alpha_at(step*2+.04+step*.5),1.0))
	assert(is_equal_approx(LightningParticleEffect.alpha_at(step*2+.04+step*1.5),.6))
	assert(is_equal_approx(LightningParticleEffect.alpha_at(expected+.01),0.0))
