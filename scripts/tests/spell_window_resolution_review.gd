extends Node
## Production BattleRoot/effects at selected animation phases, private desktop only.
const OUTPUT := "res://artifacts/reports/spell_window_resolution"
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
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(99))

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
	for bonus in [0.0]:
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
	print("SPELL_WINDOW_RESOLUTION_REVIEW_COMPLETE")
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
		if i == 4: point.y += 70
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
			3: effect._elapsed=0.7
			4: effect._elapsed=0.3; effect._sync_ground_area()
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
	# Include the baked expansion-front PNG, alongside the mature ice field.
	battle.player.hide()
	var reaction = preload("res://scripts/effects/element_reaction_visual.gd")
	reaction.spawn(parent,"ice_expand",origin+Vector2(0,30),{"from_radius":51.2,"radius":69.12})
	for child in parent.get_children():
		if child.get_script() == reaction and child.kind == "ice_expand":
			child.set_process(false)
			child.elapsed = child.duration * 0.62
			child.queue_redraw()
			effects.append(child)
			var screen: Vector2 = child.get_global_transform_with_canvas() * Vector2.ZERO
			label_at("风扩张冰场前沿（PNG）",screen+Vector2(0,60),330)
			records.append({"id":"frost_front","center":[screen.x,screen.y],"axes":[80,48]})
	label_at("现有正式特效 · 三种窗口分辨率对照",Vector2(960,230),1100)
	label_at("同一场景、同一阶段、无范围加成 · 光辉剑为等待阶段",Vector2(960,263),1200)
	if is_instance_valid(FIRE_VISUAL.clock): FIRE_VISUAL.clock.advance(0.3)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await frames(10)
	# Freeze the actual world framebuffer after rendering the production effects.
	# UI and the real presentation surface still respond normally to window size.
	game._world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		WindowSettings._apply_window_settings(resolution,false)
		await frames(12)
		var actual := get_window().size
		if actual != resolution:
			push_error("Requested window size does not match actual size: %s / %s" % [resolution,actual])
			get_tree().quit(4)
			return
		var image_size := Vector2i.ZERO
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			image_size = img.get_size()
			assert(image_size == resolution)
			assert(img.save_png(OUTPUT.path_join("window_%dx%d.png" % [actual.x,actual.y])) == OK)
		var presentation := game.get_world_presentation_surface()
		var screen_transform := presentation.get_viewport().get_screen_transform() * presentation.get_global_transform_with_canvas()
		snapshots.append({"resolution":[actual.x,actual.y],"png_size":[image_size.x,image_size.y],"world_viewport_size":[game._world_viewport.size.x,game._world_viewport.size.y],"world_surface_scale":[screen_transform.x.length(),screen_transform.y.length()],"effects":records})
	game._world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
