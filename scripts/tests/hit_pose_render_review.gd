extends Node2D
## Real render-boundary comparison, including contacts after the normal pose pass.
const BASELINE = preload("res://scripts/tests/fixtures/pulse_checked_enemy_hit_visual.gd")
const CURRENT = preload("res://scripts/effects/enemy_hit_visual.gd")
const BASELINE_ACTOR = preload("res://scripts/tests/fixtures/pulse_checked_profiled_grub.gd")
const CURRENT_ACTOR = preload("res://scripts/tests/fixtures/dense_profiled_grub.gd")
const COST = preload("res://scripts/tests/fixtures/dense_cost_counters.gd")
var bodies: Array[Sprite2D] = []
var actors: Array[EnemyController] = []
var armored: EnemyController
var armed := false
var scenario := 0
var checks := 0
var failures := 0
var rows: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func _ready() -> void:
	process_priority = 1000 # After hit poses and armor outlines update.
	WindowSettings._startup_applied = true
	get_window().unfocusable = true
	get_window().size = Vector2i(640, 400)
	get_window().content_scale_size = Vector2i(640, 400)
	RenderingServer.set_default_clear_color(Color(0.035, 0.04, 0.055))
	run.call_deferred()

func _process(_delta: float) -> void:
	if not armed: return
	armed = false
	for actor in actors:
		actor.take_damage(1, "render_review")
		for i in 100: actor.take_damage(1, "render_review")
		var visual: Node = actor._hit_visual
		match scenario:
			1:
				visual.sprite.scale = Vector2(2.5, 1.25)
				visual.sprite.rotation = 0.24
				actor.take_damage(1, "render_review")
			2:
				visual.sprite.offset += Vector2(7, -3)
				visual.sprite.material = CanvasItemMaterial.new()
				actor.take_damage(1, "render_review")
			3:
				actor.take_damage(1, "render_review")
				visual.sprite.material = CanvasItemMaterial.new()
			4:
				visual.reset()
			5:
				visual.reset()
				actor.enemy_data = {"enemy_type": "elite"}
				actor.take_damage(1, "render_review")
				for i in 100: actor.take_damage(1, "render_review")
	# Armor already updated at priority 10, before these late contacts/scales.
	armored.take_damage(1, "render_review")
	armored.sprite.scale = Vector2(1.2 + scenario * 0.05, 1.0)
	armored.take_damage(1, "render_review")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("HIT_POSE_RENDER requires real renderer")
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	CombatHitFeedback.active = false
	COST.no_numbers = true # Keep the two damage paths' pixel crops comparable.
	var source := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	source.fill(Color(0.15, 0.35, 0.7, 1))
	var texture := ImageTexture.create_from_image(source)
	for i in 2:
		var host := EnemyController.new()
		host.set_script(BASELINE_ACTOR if i == 0 else CURRENT_ACTOR)
		host.auto_initialize_on_ready = false
		host.current_hp = 100000
		host.position = Vector2(160 + i * 320, 120)
		var body := Sprite2D.new()
		body.name = "Sprite2D"
		body.texture = texture
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.scale = Vector2(2, 2)
		host.add_child(body)
		add_child(host)
		host.set_physics_process(false)
		actors.append(host)
		bodies.append(body)
	armored = preload("res://scenes/enemy/mutated_grub.tscn").instantiate()
	add_child(armored)
	armored.position = Vector2(320, 310)
	armored.current_hp = 10000
	armored.set_physics_process(false)
	armored._start_super_armor()
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	for i in 6:
		scenario = i
		armed = true
		while armed:
			await RenderingServer.frame_post_draw
			if armed: await get_tree().process_frame
		var capture := get_viewport().get_texture().get_image()
		var left := capture.get_region(Rect2i(0, 0, 320, 240))
		var right := capture.get_region(Rect2i(320, 0, 320, 240))
		check(left.get_data() == right.get_data(), "render pixels match baseline scenario %d" % i)
		check(actors[0]._hit_visual.applied_offset.is_equal_approx(actors[1]._hit_visual.applied_offset), "render-boundary shake amplitude matches")
		check(actors[0].current_hp == actors[1].current_hp, "render comparison retains all damage")
		check(not armored._hit_visual_pending, "queued pose flushed in the hit frame")
		check(armored._super_armor_visual.outline.offset == armored.sprite.offset, "late pose keeps armor outline aligned")
		check(armored._super_armor_visual.outline.transform == armored.sprite.transform, "late scale keeps armor outline aligned")
		if i in [0, 1, 3, 4, 5]: capture.save_png("artifacts/reports/hit_pose_render_%d.png" % i)
		rows.append({"scenario": i, "frame": Engine.get_process_frames(), "pixel_equal": left.get_data() == right.get_data()})
		await get_tree().process_frame
	# A pending update must not resurrect a removed component or leave a callback.
	armored.take_damage(1, "pending_removal")
	armored.queue_free()
	actors[1].queue_free()
	await RenderingServer.frame_post_draw
	check(not is_instance_valid(actors[1]), "removed pending actor is ignored safely")
	check(not is_instance_valid(armored), "removed pending enemy is ignored safely")
	FileAccess.open("artifacts/reports/hit_pose_render_review.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "rows": rows}, "\t"))
	actors[0].queue_free()
	COST.no_numbers = false
	await get_tree().process_frame
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("HIT_POSE_RENDER checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
