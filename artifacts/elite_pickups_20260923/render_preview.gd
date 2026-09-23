extends Node

func label_at(root: Node, text: String, point: Vector2, size: int = 21) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color("e6dab8")
	root.add_child(label)

func _ready() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(960, 540)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var bg := ColorRect.new()
	bg.color = Color("1b2a2c")
	bg.size = Vector2(960, 540)
	world.add_child(bg)
	label_at(world, "ELITE RUSHER / IN-ENGINE REVIEW", Vector2(34, 22), 28)
	label_at(world, "20x same-wave HP   |   2x armor   |   rectangular warning at 30%", Vector2(34, 65), 19)
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	world.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.position = Vector2(610, 245)
	var elite := preload("res://scenes/enemy/elite_rusher.tscn").instantiate() as EliteRusher
	elite.auto_initialize_on_ready = false
	world.add_child(elite)
	elite.initialize("enemy_elite_rusher", player)
	elite.set_physics_process(false)
	elite.position = Vector2(170, 245)
	elite._process_special_behavior(0.75)
	elite.start_dash()
	elite._animate(0.5)
	elite.queue_redraw()
	label_at(world, "FIXED DASH PATH / 240 px", Vector2(150, 307), 18)
	label_at(world, "RELIC GROUND DROPS", Vector2(630, 150), 20)
	var drops := DropRewardSystem.new()
	for index in 3:
		var action := {"type": "relic", "amount": 1, "relic_id": ["relic_finance_manager", "relic_piggy_bank", "relic_costly_seed_of_life"][index]}
		var pickup := drops.spawn_action(action, Vector2(665 + index * 95, 245), world, player)
		pickup.set_physics_process(false)
	label_at(world, "Collect nearby during combat.", Vector2(610, 307), 18)
	label_at(world, "Remaining relics auto-collect at wave end.", Vector2(34, 398), 21)
	label_at(world, "Drop tiers: 100%  >  50%  >  25%  >  12.5%", Vector2(34, 440), 24)
	label_at(world, "The tier advances when the relic appears, before collection.", Vector2(34, 480), 18)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image().save_png("D:/project/useless/resources/infinite-build-dome-survival/artifacts/elite_pickups_20260923/engine_preview.png")
	print("ELITE_PREVIEW_SAVED result=", result)
	get_tree().quit()
