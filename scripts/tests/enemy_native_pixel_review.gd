extends Node
## Real production actors and UI, staged for unobstructed pixel review.
const OUTPUT := "res://artifacts/previews/enemies_native_96_192/20261021-r01/runtime"
var game: GameRoot
var battle: BattleRoot
var actors: Array[EnemyController] = []
var labels: CanvasLayer
var records: Array = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	_run.call_deferred()
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(99))

func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame

func capture(name: String) -> void:
	await frames()
	var geometry: Array = []
	for actor in actors:
		var sprite := actor.sprite
		assert(sprite.is_visible_in_tree())
		var rect_size := sprite.get_rect().size
		geometry.append({"id":actor.enemy_id,"frame_size":[rect_size.x,rect_size.y],"scale":[sprite.scale.x,sprite.scale.y],"offset":[sprite.position.x,sprite.position.y]})
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(name+".png")) == OK)
	records.append({"name":name,"actors":geometry})

func _run() -> void:
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("show_hints", false, false)
	get_window().size = Vector2i(1920,1080)
	get_window().content_scale_size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(20)
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu.start_battle_button.pressed.emit()
	await frames()
	assert(menu.character_view.character_icon.size == Vector2(288,288))
	await capture("01_character_select_3x")
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	assert(flow.confirm_character_selection())
	await frames(30)
	battle = game.get_node("SceneDirector").battle_root
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.player.set_physics_process(false)
	battle.player._invincibility_timer = 10000
	battle.loadout.set_physics_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.player.camera_2d.position_smoothing_enabled = false
	battle.player.camera_2d.zoom = Vector2.ONE
	var origin := battle.player.global_position
	var ids := ["enemy_mutated_grub", "enemy_echo_bat", "enemy_elite_rusher", "enemy_underworld_wolf"]
	var positions := [Vector2(-510,-30),Vector2(-260,-30),Vector2(260,-30),Vector2(530,-30)]
	for i in ids.size():
		var actor := battle.wave_manager.spawn_enemy(ids[i],origin+positions[i]) as EnemyController
		assert(actor != null)
		actor.set_physics_process(false)
		actor.sprite.flip_h = false
		if actor is UnderworldWolf: actor._process_special_behavior(float(actor.profile.spawn_seconds))
		if actor is EliteRusher: actor._process_special_behavior(1); actor._animate(0)
		actors.append(actor)
	labels = CanvasLayer.new()
	labels.layer = 100
	add_child(labels)
	await frames(8)
	# Review-only clearing: keep the production terrain, actors and their
	# normal render transforms; hide scenery that would obscure the new art.
	var ground := get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	ground.set_process(false)
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if node is CanvasItem and node.has_meta("scenery"):
				var kind := str(node.get_meta("scenery").get("kind", ""))
				if kind in ["prop","grass","grass_batch","contact","cast_shadow"]: node.hide()
	var note := Label.new()
	note.text = "主体像素审阅 · 临时隐藏遮挡草丛／石块 · 相机1倍"
	note.position = Vector2(565,245)
	note.add_theme_font_size_override("font_size",20)
	note.add_theme_constant_override("outline_size",4)
	labels.add_child(note)
	for i in actors.size():
		var actor := actors[i]
		assert(actor.sprite.scale == Vector2.ONE)
		var label := Label.new()
		label.text = str(actor.enemy_data.display_name)+("  96px / 1倍" if i<2 else "  192px / 1倍")
		label.position = actor.get_global_transform_with_canvas()*Vector2.ZERO+Vector2(-115,40)
		label.size.x = 230
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_constant_override("outline_size",4)
		labels.add_child(label)
	await capture("02_battle_idle_1x")
	var bat := actors[1] as EchoBat
	var knight := actors[2] as EliteRusher
	var wolf := actors[3] as UnderworldWolf
	for i in 12:
		actors[0]._set_movement_visual(true,1.0/14)
		bat.skill_state = "move"
		bat._animate(1.0/14)
		knight._animation = &"move"
		knight._animate(0.1)
		wolf.animation = &"move"
		wolf.animate(0.1)
		await capture("move_%02d" % i)
	bat.skill_state = "release"
	bat.state_time = 0.05
	bat._animate(0)
	knight._state_time = 0.65
	knight._set_animation(&"windup")
	wolf.transition("breath", &"breath")
	await capture("03_battle_attack_1x")
	wolf.transition("leap", &"leap")
	wolf.air_height = 42
	wolf.animate(0.25)
	await capture("04_wolf_jump_1x")
	var file := FileAccess.open(OUTPUT.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"window":[1920,1080],"camera_zoom":1,"production_scene":true,"staged_poses":true,"review_only_scenery_hidden":true,"captures":records},"  "))
	file.close()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("ENEMY_NATIVE_PIXEL_REVIEW_COMPLETE")
	get_tree().quit()
