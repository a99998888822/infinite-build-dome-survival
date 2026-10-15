extends Node
## Native-size captures of selection and combat; production camera stays at 1x.
var output := ""
var report: Dictionary = {}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count: int = 4) -> void:
	for i in count: await get_tree().process_frame

func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1600,900)
	get_tree().root.content_scale_size = Vector2i.ZERO
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(8)
	var view := (game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController).character_view
	view.set_process(false)
	view.reset_animation()
	await capture("selection_idle_1600")
	view._process(0.75)
	await capture("selection_breath_1600")
	report.selection = {"texture":view._idle.resource_path,"rect":str(view.character_icon.get_global_rect()),
		"screen_transform":str(view.character_icon.get_global_transform_with_canvas())}
	flow.confirm_character_selection()
	await frames(12)
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	var player := battle.player
	player.set_physics_process(false)
	player._clear_move_input()
	player.global_position = Vector2.ZERO
	player._sync_camera(1)
	player.camera_2d.force_update_scroll()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await capture("battle_idle_1600")
	report.battle = {"texture":player.sprite.texture.resource_path,"scale":str(player.sprite.scale),
		"camera_zoom":str(player.camera_2d.zoom),"world_size":str(player.get_viewport().get_visible_rect().size),
		"screen_transform":str(player.sprite.get_global_transform_with_canvas())}
	for i in 8:
		player.action_animator._show("move", i)
		await capture("battle_move_%02d_1600" % i)
	player.action_animator._show("idle", 0)
	# Explicit reference only, to expose the magnification used by the old demo.
	player.camera_2d.zoom = Vector2(2,2)
	player.camera_2d.force_update_scroll()
	await capture("reference_camera_2x_1600")
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.3).timeout
	print("PLAYER_RESOLUTION_REVIEW_COMPLETE")
	get_tree().quit()
