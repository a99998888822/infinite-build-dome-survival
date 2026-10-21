extends Node
## Production BattleRoot/effects at selected animation phases, private desktop only.
const OUTPUT := "res://artifacts/reports/spell_terminal_ranges"
const FOOTPRINT = preload("res://scripts/effects/spell_footprint.gd")
const FIRE_VISUAL = preload("res://scripts/effects/pixel_fire_visual.gd")
var game: GameRoot
var battle: BattleRoot
var labels: CanvasLayer
var snapshots: Array = []
var effects: Array[Node2D] = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	_run.call_deferred()
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(99))

func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame

func _run() -> void:
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	GameGlobal.set_runtime_flag("review_visual_adaptive",false)
	get_window().size=Vector2i(1920,1080)
	get_window().content_scale_size=Vector2i(1920,1080)
	game=load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene=game
	await frames(15)
	var flow=game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames()
	if not flow.confirm_character_selection(): get_tree().quit(3); return
	await frames(20)
	battle=game.get_node("SceneDirector").battle_root
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.player.set_physics_process(false)
	battle.player._invincibility_timer=10000
	battle.loadout.set_physics_process(false)
	battle.active_controller.set_process(false)
	battle.active_controller.set_physics_process(false)
	labels=CanvasLayer.new()
	labels.layer=100
	add_child(labels)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for bonus in [0.0,100.0]:
		await capture_case(bonus)
	var manifest := "capture_headless.json" if DisplayServer.get_name() == "headless" else "capture.json"
	var file=FileAccess.open(OUTPUT.path_join(manifest),FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":[1920,1080],"production_scene":true,"selected_animation_phases":true,"captures":snapshots},"  "))
	file.close()
	await clear_review_effects()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("SPELL_TERMINAL_RANGE_REVIEW_COMPLETE")
	get_tree().quit()

func label_at(text: String, point: Vector2, width:=320) -> void:
	var label=Label.new()
	label.text=text
	label.position=point-Vector2(width*0.5,0)
	label.size.x=width
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	labels.add_child(label)

func clear_review_effects() -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	for node in effects:
		if is_instance_valid(node): node.queue_free()
	effects.clear()
	# Let detached strike particles and render batches finish before the next
	# comparison or scene teardown; frozen remnants must not enter later shots.
	await get_tree().create_timer(0.8).timeout
	await frames()

func capture_case(bonus: float) -> void:
	await clear_review_effects()
	for node in labels.get_children(): node.queue_free()
	await frames()
	var parent=CombatEffectWorld._get_visual_parent(battle)
	var origin=battle.player.global_position
	var ids=["scroll_water","scroll_black_hole","scroll_fire","scroll_ice","scroll_light_sword","scroll_electric_spark","scroll_wind","scroll_explosion"]
	var records: Array=[]
	for i in ids.size():
		var point: Vector2=origin+Vector2(-570+(i%4)*380,-140+(i/4)*350)
		var weapon := WeaponInstance.new()
		weapon.weapon_id="range_review_%d"%i
		weapon.weapon_data={"hit_radius":14.0,"tags":[]}
		weapon.runtime_stats={"area_size":0.0,"damage_area_size":bonus}
		weapon.owner_player=battle.player
		var record: Dictionary=DataRegistry.get_record("augmentations",ids[i]).duplicate(true)
		weapon._attached_item_instances.assign([record])
		var event=DamageEvent.create({"damage":100,"original_damage":100,"source_weapon_id":weapon.weapon_id,"source_player":battle.player})
		var before=parent.get_children()
		match i:
			0: WaterWaveEffect.spawn(parent,point,weapon,event)
			1: BlackHoleEffect.spawn(parent,point,weapon,event)
			2:
				var context=preload("res://scripts/effects/effect_parameter_resolver.gd").build_weapon_context(weapon,"fire",{"original_damage":100.0})
				FirePatch.spawn(parent,point,context)
			3: IceFieldEffect.spawn(parent,point,weapon,event)
			4: LightSwordEffect.spawn(parent,point,weapon,event)
			5: ElectricSparkEffect.spawn(parent,point,weapon,event)
			6: WindBladeEffect.spawn(parent,point,Vector2.RIGHT,480,0.46,weapon,event)
			7: preload("res://scripts/effects/enchantment_block_vfx.gd").spawn_shockwave(parent,point,55.2,0)
		var effect: Node2D
		for node in parent.get_children():
			if node is Node2D and not node in before:
				if node is WaterWaveEffect or node is BlackHoleEffect or node is FirePatch or node is IceFieldEffect or node is LightSwordEffect or node is ElectricSparkEffect or node is WindBladeEffect or node.get_script()==preload("res://scripts/effects/enchantment_block_vfx.gd"):
					effect=node
		assert(effect!=null)
		effects.append(effect)
		effect.set_process(false)
		effect.set_physics_process(false)
		match i:
			0: effect._elapsed=effect._duration*0.58
			1: effect._elapsed=effect._duration*0.4
			3: effect._elapsed=0.7; effect._sync_ground_area()
			4: effect._process(0.93)
			5: effect._elapsed=0.3; effect._sync_warning()
			6: effect._elapsed=0.12
			7: effect.elapsed=effect.duration*0.56
		effect.queue_redraw()
		if i==1: effect._vortex_back.queue_redraw(); effect._vortex_front.queue_redraw()
		if i==4: effect._ground_layer.queue_redraw()
		var axes: Vector2
		if effect.has_method("get_terminal_footprint_axes"): axes=effect.get_terminal_footprint_axes()
		elif i==1: axes=Vector2.ONE*effect._radius
		elif i==6: axes=Vector2.ONE*effect._hit_radius
		else: axes=Vector2.ONE*55.2
		var note="作用区 %.1f × %.1f"%[axes.x*2,axes.y*2]
		if i==1: note="球体半径 %.2f · 伤害半径 %.2f"%[effect._sphere_radius,effect._radius]
		if i==6: note="圆形判定半径 %.1f"%effect._hit_radius
		if i==7: note="固定圆形击退半径 55.2"
		var screen=effect.get_global_transform_with_canvas()*Vector2.ZERO
		label_at(str(record.display_name)+"\n"+note,screen+Vector2(0,100))
		records.append({"id":ids[i],"center":[screen.x,screen.y],"axes":[axes.x,axes.y]})
	label_at("终态范围实机对照 · 伤害范围 +%d · 倍率 %.2f"%[bonus,1+bonus*0.005],Vector2(960,245),1100)
	label_at("正式战斗场景与效果组件 · 固定在各自展示阶段 · 黑洞不绘制伤害范围",Vector2(960,278),1200)
	if is_instance_valid(FIRE_VISUAL.clock): FIRE_VISUAL.clock.advance(0.3)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await frames(10)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var path=OUTPUT.path_join("base.png" if bonus==0 else "area_plus100.png")
		assert(get_viewport().get_texture().get_image().save_png(path)==OK)
	# Advance the production warning into its actual strike, then hold the ring
	# after it reaches full size. This second image verifies the landing stage.
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	var warning := effects[5] as ElectricSparkEffect
	warning._struck = true
	warning._trigger_strike()
	for child in parent.get_children():
		if child is LightningParticleEffect and child._is_ground_strike:
			EffectScheduler.cancel_owner(child)
			child.set_process(false)
			child._strike_ground(child._ground_strike_position)
			child._process(0.26)
			effects.append(child)
	warning._elapsed = warning._ring_fade_start_elapsed + 0.26
	warning._sync_warning()
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await frames(4)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var path=OUTPUT.path_join("base_strike.png" if bonus==0 else "area_plus100_strike.png")
		assert(get_viewport().get_texture().get_image().save_png(path)==OK)
	snapshots.append({"bonus":bonus,"effects":records})
