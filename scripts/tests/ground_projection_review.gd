extends Node
## Staged checkpoints in the production battle, using the actual effect renderers.
const GROUND = preload("res://scripts/effects/ground_projection_r05.gd")
const MOBILITY_GUIDE = preload("res://scripts/battle/mobility_weapon_indicator.gd")
var battle: BattleRoot
var player: PlayerController
var host: Node2D
var caption: Label
var capture_dir := ""
var checks := 0
var failures := 0
var samples: Array[Dictionary] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count: int = 3) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func weapon(id: String) -> WeaponInstance:
	var result := WeaponInstance.new()
	check(result.initialize(id, player), "weapon initialized " + id)
	result.use_active_range_rules = true
	return result

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func make_wolf(point: Vector2) -> UnderworldWolf:
	var wolf := load("res://scenes/enemy/underworld_wolf.tscn").instantiate() as UnderworldWolf
	wolf.auto_initialize_on_ready = false
	host.add_child(wolf)
	check(wolf.initialize("enemy_underworld_wolf", player), "wolf initialized")
	wolf.global_position = point
	freeze(wolf)
	wolf.push_controller.set_physics_process(false)
	return wolf

func _run() -> void:
	CampProgression.begin_transient_session()
	seed(261012)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_hand_cannon"])
	await frames(4)
	check(flow.confirm_character_selection(), "production main battle opened")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.active_controller._cursor_layer.hide()
	player = battle.player
	player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	GameGlobal.clear_runtime_flag(GROUND.FLAG)
	host = Node2D.new()
	player.get_parent().add_child(host)
	await frames()
	_test_leap_boundary()
	await _reset()
	await get_tree().create_timer(1.0).timeout
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var overlay := CanvasLayer.new()
		overlay.layer = 100
		add_child(overlay)
		caption = Label.new()
		caption.position = Vector2(28, 594)
		caption.add_theme_font_size_override("font_size", 21)
		caption.add_theme_constant_override("outline_size", 6)
		caption.add_theme_color_override("font_outline_color", Color("102019"))
		overlay.add_child(caption)
		await _capture_all()
	check(not GROUND.enabled(), "production ground projection works without the legacy review flag")
	if not samples.is_empty():
		var report := FileAccess.open(capture_dir.path_join("review.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"production_battle": true, "staged_checkpoints": true,
			"projection": [1.0, 145.0 / 220.0], "legacy_review_flag": GROUND.enabled(),
			"checks": checks, "failures": failures, "samples": samples}, "\t"))
	print("GROUND_PROJECTION_REVIEW checks=%d failures=%d captures=%d" % [checks, failures, samples.size()])
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)

func _test_leap_boundary() -> void:
	var wolf := make_wolf(Vector2(-250, 0))
	wolf.transition("land", &"idle")
	var body := player.get_node("CollisionShape2D") as CollisionShape2D
	var body_offset := body.global_position - player.global_position
	var half_body := body.shape.get_rect().size * body.global_scale.abs() * 0.5
	# Exercise actual damage, on both sides of all four axes and at two radii.
	# The capsule may overlap the ellipse while its center remains outside it.
	for radius: float in [60.0, 120.0]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var support := half_body.x if direction.x != 0 else half_body.y
			var extent := radius if direction.x != 0 else radius * 145.0 / 220.0
			for gap in [-3.0, 3.0]:
				player.global_position = direction * (extent + support + gap) - body_offset
				player.current_hp = int(player.get_stat("max_hp"))
				player.current_shield = 0
				player._invincibility_timer = 0
				var before := player.current_hp
				wolf.area_damage(Vector2.ZERO, radius, 10)
				check((player.current_hp < before) == (gap < 0), "leap capsule boundary radius=%s direction=%s gap=%s" % [radius, direction, gap])
				wolf.push_controller.cancel()
	# A body wholly outside the ellipse but inside the old circle must be safe.
	player.global_position = Vector2(0, 112) - body_offset
	player._invincibility_timer = 0
	var before := player.current_hp
	wolf.area_damage(Vector2.ZERO, 120, 10)
	check(player.current_hp == before, "outside projected warning is safe inside old circular radius")
	body.disabled = true
	player.global_position = -body_offset
	wolf.area_damage(Vector2.ZERO, 120, 10)
	check(player.current_hp == before, "disabled player collider remains unhittable")
	body.disabled = false

func _reset() -> void:
	for child in host.get_children(): child.queue_free()
	for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
		if is_instance_valid(effect) and not host.is_ancestor_of(effect): effect.queue_free()
	await frames(4)
	player.global_position = Vector2(-80, 30)
	player.current_hp = int(player.get_stat("max_hp"))
	player.current_shield = 0
	player._invincibility_timer = 100
	player.sprite.modulate = Color.WHITE
	player.camera_2d.global_position = Vector2(0, 20)
	player.camera_2d.zoom = Vector2.ONE * 1.6
	player.camera_2d.offset = Vector2.ZERO
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()

func capture(name: String, title: String, point: Vector2) -> void:
	caption.text = title + "  ·  主战斗场景 / 地面投影 145∶220"
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture := get_tree().root.get_texture().get_image()
	check(picture.save_png(capture_dir.path_join(name + ".png")) == OK, "GPU screenshot " + name)
	samples.append({"file": name + ".png", "title": title,
		"point": [point.x, point.y], "viewport": [picture.get_width(), picture.get_height()]})

func _capture_all() -> void:
	var point := Vector2(65, 35)
	var cannon := weapon("weapon_hand_cannon")
	player.global_position = Vector2(60, 25)
	var guide := MOBILITY_GUIDE.new()
	host.add_child(guide)
	guide.global_position = player.global_position
	guide.configure_weapon(cannon, Vector2(160, -35), true)
	await capture("01_cannon_retreat", "01 巨型手持火炮 · 后撤终点", player.global_position + guide.get_landing_offset())
	await _reset()
	var source := weapon("weapon_void_blade")
	var event := DamageEvent.create({"damage": 10, "original_damage": 10,
		"source_weapon_id": source.weapon_id, "source_player": player})
	# Leave room for the vertical sword above its small ground mark.
	player.camera_2d.global_position = Vector2(0, -40)
	player.camera_2d.force_update_scroll()
	LightSwordEffect.spawn(host, point, source, event)
	var sword := host.get_child(0) as LightSwordEffect
	freeze(sword)
	sword._elapsed = sword._delay * 0.8
	sword.queue_redraw()
	sword._ground_layer.queue_redraw()
	await capture("02_sword_mark", "02 光剑附魔 · 落地前标记", point)
	await _reset()
	var wolf := make_wolf(point)
	wolf.state = "spawn"
	wolf.sprite.hide()
	wolf.floor_art.queue_redraw()
	await capture("03_wolf_spawn", "03 冥狼 · 出生预警", point)
	await _reset()
	wolf = make_wolf(Vector2(-100, 0))
	wolf.transition("leap_charge", &"leap_charge")
	wolf.state_time = float(wolf.profile.leap_charge) * 0.72
	wolf.locked_point = point
	wolf.sprite.show()
	wolf.floor_art.queue_redraw()
	player.global_position = point + Vector2(100, 30)
	await capture("04_wolf_leap_warning", "04 冥狼 · 跳扑落点预警", point)
	await _reset()
	var star := weapon("weapon_star_tome")
	var runtime := MobilityWeaponRuntime.new()
	host.add_child(runtime)
	runtime.initialize(star, star, point)
	freeze(runtime)
	for clip in runtime.get_children():
		if clip is MobilityAtlasEffect: clip.frame = mini(5, clip.hframes - 1)
	await capture("05_star_impact", "05 移星秘典 · 落地冲击", point)
	await _reset()
	# Use the equipped water-scroll radius, matching the production attachment.
	var scroll: Dictionary = DataRegistry.get_record("augmentations", "scroll_water").duplicate(true)
	scroll["item_instance_id"] = "ground_review_water"
	source._attached_item_instances.append(scroll)
	source._rebuild_attachment_effects()
	WaterWaveEffect.spawn(host, point, source, event)
	var water := host.get_child(0) as WaterWaveEffect
	freeze(water)
	water._elapsed = water._duration * 0.62
	water.queue_redraw()
	await capture("06_water_wave", "06 水元素 · 扩散水波", point)
	await _reset()
	wolf = make_wolf(point)
	wolf.transition("land", &"land")
	wolf.impact_time = 0.19
	wolf.sprite.show()
	wolf.floor_art.queue_redraw()
	await capture("07_wolf_landing", "07 冥狼 · 跳扑落地扩散", point)
	await _reset()
	var lightning := LightningParticleEffect.spawn_ground_strike(host, point, source, event, "", 182, 62)
	EffectScheduler.cancel_owner(lightning)
	lightning._strike_ground(point)
	freeze(lightning)
	lightning._ground_strike_impact_age = 0.24
	lightning.queue_redraw()
	await capture("08_lightning_ground", "08 落雷 · 触地扩散", point)
	lightning.queue_free()
