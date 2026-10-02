extends Node

const SEQUENCE = preload("res://scripts/tests/lightning_line_sequence.gd")
const TARGET = preload("res://scripts/tests/water_review_target.gd")
const WEAPON := "weapon_camp_dagger"
const FRAMES := 180
const FPS := 30.0

var capture_dir := ""
var wave := 0
var checks := 0
var failures := 0
var points: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var tracked: Array[Dictionary] = []
var targets: Array[EnemyController] = []
var player: PlayerController
var sequence: Node2D
var phase_label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", message)


func _run() -> void:
	CampProgression.begin_transient_session()
	seed(290926)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await _frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [WEAPON])
	await _frames(4)
	if not flow.confirm_character_selection():
		push_error("Lightning preview could not enter battle")
		CampProgression.end_transient_session()
		get_tree().quit(2)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await _frames(6)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if effect.has_method("cancel"):
			effect.cancel()
	player = battle.player
	player.set_physics_process(false)
	var weapon: WeaponInstance = battle.loadout.get_weapon_instance(WEAPON)
	player.item_inventory.clear()
	var attachment := player.item_inventory.add_item_from_base("scroll_electric_spark", "lightning_line_preview")
	_check(battle.loadout.attach_item_to_weapon(WEAPON, attachment.item_instance_id), "existing electric spark enchantment equipped")
	weapon.runtime_stats["crit_chance"] = 0.0
	var event := DamageEvent.create({"damage": 10, "original_damage": 10,
		"source_weapon_id": WEAPON, "source_player": player})
	sequence = SEQUENCE.new()
	player.get_parent().add_child(sequence)
	player.camera_2d.offset = Vector2((sequence.first_offset + (sequence.point_count - 1) * sequence.point_spacing) * 0.5, -35)
	sequence.point_created.connect(_point_created)
	_create_caption()
	await _frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for frame in FRAMES:
		if frame == 15 or frame == 105:
			wave += 1
			_check(sequence.start_wave(player.global_position, weapon, event, attachment.item_instance_id), "wave %d started" % wave)
		if frame == 90:
			_create_targets()
			phase_label.text = "第二轮：固定靶受击演示（上方目标在范围外）"
		_observe_landings()
		if graphical:
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		if graphical and not capture_dir.is_empty():
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % frame))
			if error != OK:
				push_error("Could not save lightning capture frame")
				failures += 1
				break
	_observe_landings()
	_validate()
	var report := {"prototype": true, "formal_weapon_added": false, "fps": FPS, "frames": FRAMES,
		"interval_seconds": sequence.point_interval, "warning_seconds": ElectricSparkEffect.ACTIVATION_DELAY_SECONDS,
		"point_count": sequence.point_count, "spacing_pixels": sequence.point_spacing,
		"first_offset_pixels": sequence.first_offset, "points": points, "hits": hits,
		"checks": checks, "failures": failures, "fixture": "idle player; first wave empty; second wave stationary targets",
		"target_health": targets.map(func(target): return target.current_hp)}
	if not capture_dir.is_empty():
		var output := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("LIGHTNING_LINE_PREVIEW checks=", checks, " failures=", failures, " points=", points.size(), " hits=", hits.size())
	event = null
	weapon = null
	tracked.clear()
	targets.clear()
	game.queue_free()
	await _frames(3)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	# Fixed-fps headless frames can outrun the audio thread; let it release voices.
	if not graphical:
		OS.delay_msec(150)
	await get_tree().create_timer(0.12).timeout
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)


func _point_created(index: int, world_position: Vector2) -> void:
	var entry := {"wave": wave, "index": index, "x": world_position.x, "y": world_position.y,
		"spawn_frame": Engine.get_process_frames(), "land_frame": -1}
	points.append(entry)
	tracked.append({"effect": sequence.get_child(sequence.get_child_count() - 1), "entry": entry})


func _observe_landings() -> void:
	for track in tracked:
		if track.entry.land_frame >= 0:
			continue
		var effect = track.effect
		if is_instance_valid(effect) and effect._strike_landed:
			track.entry.land_frame = Engine.get_process_frames()


func _create_targets() -> void:
	# Preserve real hit/status handling, but keep the review arrangement stationary.
	for index in 4:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(TARGET)
		enemy.auto_initialize_on_ready = false
		sequence.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 10000
		enemy.set_physics_process(false)
		var point_index: int = [1, 4, 7, 4][index]
		enemy.global_position = player.global_position + Vector2(sequence.first_offset + point_index * sequence.point_spacing, -85 if index == 3 else 0)
		enemy.damage_received.connect(func(source: String, damage: int):
			hits.append({"target": index, "frame": Engine.get_process_frames(), "source": source, "damage": damage}))
		targets.append(enemy)


func _create_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(48, 96)
	label.text = "直线落雷 · 测试原型\n0.1 秒一枚  /  预警 0.5 秒  /  8 枚  /  间距 %.0f 像素" % sequence.point_spacing
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	phase_label = Label.new()
	phase_label.position = Vector2(48, 700)
	phase_label.text = "第一轮：从玩家右侧开始，预警与雷击依次向外推进"
	phase_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(phase_label)


func _validate() -> void:
	_check(points.size() == 16, "two waves contain exactly eight points each")
	var timing_ok := true
	var layout_ok := true
	var delayed_ok := true
	for index in points.size():
		var point := points[index]
		layout_ok = layout_ok and is_equal_approx(point.x, player.global_position.x + sequence.first_offset + point.index * sequence.point_spacing)
		layout_ok = layout_ok and is_equal_approx(point.y, player.global_position.y)
		var delay: int = point.land_frame - point.spawn_frame
		delayed_ok = delayed_ok and delay >= 15 and delay <= 18
		if point.index > 0:
			var previous := points[index - 1]
			timing_ok = timing_ok and point.spawn_frame - previous.spawn_frame == 3
			timing_ok = timing_ok and point.land_frame - previous.land_frame == 3
	_check(layout_ok, "fixed row moves right by %.0f pixels, starting %.0f pixels beside player" % [sequence.point_spacing, sequence.first_offset])
	_check(timing_ok, "warnings and actual impacts progress every 0.1 seconds at 30 fps")
	_check(delayed_ok, "all 16 native strikes land after the 0.5 second warning plus scheduler frame tolerance")
	_check(targets.size() == 4 and targets[0].current_hp < 10000 and targets[1].current_hp < 10000 and targets[2].current_hp < 10000, "all three in-row targets receive native lightning damage")
	_check(targets.size() == 4 and targets[3].current_hp == 10000, "target outside the row receives no damage")
	var second_wave := points.filter(func(point): return point.wave == 2)
	_check(not hits.is_empty() and hits.all(func(hit): return hit.source == WEAPON and hit.frame >= second_wave[0].land_frame - 1), "damage retains source attribution and never occurs during the initial warning")
