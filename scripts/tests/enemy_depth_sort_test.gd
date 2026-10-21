extends Node
## Real enemy ownership with solid sprite fixtures makes occlusion measurable.

var checks := 0
var failures := 0
var output := ""
var manager: WaveManager
var front: EnemyController
var back: EnemyController

func _ready() -> void:
	WindowSettings._startup_applied = true
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(9)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func frames() -> void:
	for i in 3: await get_tree().process_frame

func _run() -> void:
	get_window().size = Vector2i(640, 360)
	get_window().content_scale_size = Vector2i(640, 360)
	manager = load("res://scenes/waves/wave_manager.tscn").instantiate() as WaveManager
	add_child(manager)
	check(manager.enemy_root is Node2D and manager.enemy_root.y_sort_enabled, "production enemy root sorts at actor ground positions")
	front = manager.spawn_enemy("enemy_elite_rusher", Vector2(200, 160))
	back = manager.spawn_enemy("enemy_mutated_grub", Vector2(200, 140))
	_fixture(front, Color.RED)
	_fixture(back, Color.BLUE)
	await _check_pixel("spawned_upper_enemy_last", Color.RED)
	front.position.y = 130
	await _check_pixel("enemies_cross", Color.BLUE)
	front.position.y = 140.5
	back.position.y = 140.25
	await _check_pixel("fractional_ground_positions", Color.RED)
	manager.enemy_root.move_child(back, 0)
	await _check_pixel("reordered_children", Color.RED)
	# Hit/bob offsets move the art, but must not change its ground-based order.
	front.sprite.position.y = -36
	back.sprite.position.y = -20
	await _check_pixel("animation_offsets", Color.RED)
	manager.queue_free()
	await frames()
	print("ENEMY_DEPTH_SORT_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _fixture(enemy: EnemyController, color: Color) -> void:
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for child in enemy.get_children():
		if child is CanvasItem: child.visible = child == enemy.sprite
	var bitmap := Image.create(48, 80, false, Image.FORMAT_RGBA8)
	bitmap.fill(color)
	enemy.sprite.texture = ImageTexture.create_from_image(bitmap)
	enemy.sprite.hframes = 1
	enemy.sprite.vframes = 1
	enemy.sprite.region_enabled = false
	enemy.sprite.scale = Vector2.ONE
	enemy.sprite.position = Vector2(0, -30)
	enemy.sprite.modulate = Color.WHITE
	enemy.sprite.material = null

func _check_pixel(id: String, expected: Color) -> void:
	await frames()
	check(front.z_index == back.z_index, id + " keeps actors on the same depth layer")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var bitmap := get_viewport().get_texture().get_image()
	check(bitmap.get_pixel(200, 115).is_equal_approx(expected), id + " lower enemy occludes upper enemy")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		bitmap.save_png(output.path_join(id + ".png"))
