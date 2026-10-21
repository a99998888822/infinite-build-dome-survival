extends Node
## Compare live shadow and routing behavior against the frozen pre-change code.
const OLD_SHADOW = preload("res://scripts/tests/fixtures/idle_original_ground_shadow.gd")
const OLD_TERRAIN = preload("res://scripts/tests/fixtures/idle_original_terrain_obstacle.gd")
const IDS := ["mutated_grub", "echo_bat", "elite_rusher", "underworld_wolf"]
var checks := 0
var failures: Array[String] = []
var output := ""

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() != "headless" and "--background-capture" not in OS.get_cmdline_user_args():
		get_tree().quit(9)
		return
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frames() -> void:
	for i in 3: await get_tree().process_frame

func run() -> void:
	CampProgression.begin_transient_session()
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	await shadow_checks()
	route_checks()
	CampProgression.end_transient_session()
	print("IDLE_UPDATE_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func shadow_checks() -> void:
	var actors: Array[EnemyController] = []
	var originals: Array[Sprite2D] = []
	for i in IDS.size():
		var enemy := load("res://scenes/enemy/" + IDS[i] + ".tscn").instantiate() as EnemyController
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)
		enemy.initialize("enemy_" + IDS[i], null)
		enemy.position = Vector2(150 + 320 * i, 430)
		enemy.sprite.show()
		enemy.get_node("GroundShadow").refresh()
		var old := OLD_SHADOW.new()
		enemy.add_child(old)
		old.configure(enemy)
		actors.append(enemy)
		originals.append(old)
	for step in 32:
		for i in actors.size():
			var enemy := actors[i]
			var current := enemy.get_node("GroundShadow") as Sprite2D
			var old := originals[i]
			enemy.apply_body_scale([1.0, 0.75, 1.6, 1.0][step % 4])
			enemy.sprite.flip_h = step % 2 == 1
			enemy.sprite.modulate = Color(0.2, 0.5, 1.0, [1.0, 0.35, 0.0, 0.001][(step / 2) % 4])
			enemy.sprite.self_modulate.a = 0.6 if step % 5 == 0 else 1.0
			enemy.sprite.visible = step % 7 != 0
			enemy.sprite.position += Vector2(0.25, -0.5)
			enemy.sprite.offset += Vector2(-0.5, 0.25)
			if enemy is UnderworldWolf: enemy.air_height = step * 2.5
			current.refresh()
			old.refresh()
			var tag: String = IDS[i] + " step=" + str(step)
			check(current.visible == old.visible, "visibility " + tag)
			check(current.position == old.position and current.modulate == old.modulate, "anchor/fade " + tag)
			check(current.footprint == old.footprint, "size " + tag)
			if current.texture != null and old.texture != null:
				check(current.texture.get_image().get_data() == old.texture.get_image().get_data(), "texture " + tag)
			# A second refresh exercises the unchanged-input fast path, including
			# a caller hiding and restoring a shadow without changing the actor.
			current.hide()
			current.refresh()
			check(current.visible == old.visible and current.position == old.position and current.modulate == old.modulate, "repeat " + tag)
	# Fixed poses compare the complete rendered output as well as texture bytes.
	for step in 6:
		for i in actors.size():
			var enemy := actors[i]
			enemy.apply_body_scale([1.0, 0.75, 1.35][step % 3])
			enemy.sprite.visible = true
			enemy.sprite.flip_h = step % 2 == 1
			enemy.sprite.modulate = Color(0.3, 0.7, 1.0, 0.5 if step == 2 else 1.0)
			enemy.sprite.self_modulate = Color.WHITE
			if enemy is UnderworldWolf: enemy.air_height = [0.0, 12.0, 30.0, 52.0, 66.0, 0.0][step]
			enemy.get_node("GroundShadow").refresh()
			originals[i].refresh()
		await compare_pixels(actors, originals, step)
	for enemy in actors: enemy.queue_free()
	await frames()

func compare_pixels(actors: Array[EnemyController], originals: Array[Sprite2D], step: int) -> void:
	if DisplayServer.get_name() == "headless": return
	for enemy in actors: enemy.get_node("GroundShadow").hide()
	await frames()
	await RenderingServer.frame_post_draw
	var reference := get_viewport().get_texture().get_image()
	for i in actors.size():
		originals[i].hide()
		actors[i].get_node("GroundShadow").show()
	await frames()
	await RenderingServer.frame_post_draw
	var candidate := get_viewport().get_texture().get_image()
	check(reference.get_data() == candidate.get_data(), "GPU shadow pixels step=" + str(step))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		reference.save_png(output.path_join("before_%d.png" % step))
		candidate.save_png(output.path_join("after_%d.png" % step))

func route_checks() -> void:
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	add_child(body)
	var rocks: Array[BattleTerrainObstacle] = []
	for i in 12:
		var rock := BattleTerrainObstacle.new()
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(-45, -25), Vector2(45, -25), Vector2(45, 25), Vector2(-45, 25)])
		rock.add_child(polygon)
		rock.position = Vector2((i % 4) * 160 - 240, (i / 4) * 140 - 140)
		rock.rotation = i * 0.1
		add_child(rock)
		rocks.append(rock)
	var current := BattleTerrainObstacle.Route.new()
	var original := OLD_TERRAIN.Route.new()
	for step in 360:
		if step % 60 == 0:
			match (step / 60) % 3:
				0: shape.shape = CircleShape2D.new()
				1: shape.shape = CapsuleShape2D.new()
				2: shape.shape = RectangleShape2D.new()
		shape.position = Vector2(step % 5, -3)
		shape.scale = Vector2(0.75 + (step % 3) * 0.5, 1.5)
		shape.rotation = step * 0.02
		body.rotation = step * 0.01
		body.scale = Vector2(-1.2, 0.8) if step % 4 == 0 else Vector2.ONE
		body.position = Vector2.from_angle(step * 0.03) * (80 if step % 7 == 0 else 450)
		var destination := Vector2.from_angle(step * 0.04 + PI) * 520
		check(current.direction(body, destination) == original.direction(body, destination), "route direction " + str(step))
		check(current.obstacle == original.obstacle and current.bounds == original.bounds and current.points == original.points, "route state " + str(step))
		if step == 150: rocks.pop_back().free()
		if step == 210: shape.shape = null
	for rock in rocks: rock.free()
	check(current.direction(body, Vector2.ZERO) == original.direction(body, Vector2.ZERO) and current.points.is_empty(), "empty terrain after unload")
	body.free()
