extends Node
## Actual combat labels in GameRoot; fixed targets and damage values are review fixtures.

const SAMPLES := [[9, 999, 99999, 1000000], [99, 9999, 999999, 9999999], [88, 8888, 888888, 8888888]]
const EXPECTED_COLORS := [Color.WHITE, Color(1.0, 0.78, 0.28), Color(1.0, 0.57, 0.12), Color(0.95, 0.20, 0.20)]
const FPS := 60
const FRAME_COUNT := 300
var capture_dir := ""
var failures: Array[String] = []
var checks := 0
var targets: Array[EnemyController] = []
var observations: Array[Dictionary] = []
var game: GameRoot
var battle: BattleRoot
var overlay: CanvasLayer
var phase_label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("DAMAGE_NUMBER_REVIEW " + message)


func _run() -> void:
	CampProgression.begin_transient_session()
	seed(20261007)
	get_tree().root.unfocusable = true
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection():
		push_error("DAMAGE_NUMBER_REVIEW could not enter battle")
		get_tree().quit(2)
		return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	battle.player.set_process_input(false)
	battle.player.hide()
	await frames(4)
	for row in 2:
		for column in 4:
			var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
			enemy.auto_initialize_on_ready = false
			battle.player.get_parent().add_child(enemy)
			enemy.initialize("enemy_mutated_grub", battle.player)
			enemy.global_position = Vector2(-215 + column * 170, -10 + row * 160)
			enemy.current_hp = 1000000000
			enemy.set_physics_process(false)
			targets.append(enemy)
	_build_overlay()
	await frames(8)
	_validate_boundaries()
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
	var graphical := DisplayServer.get_name() != "headless"
	for index in FRAME_COUNT:
		if index in [15, 105, 195]:
			var cycle := int((index - 15) / 90.0)
			phase_label.text = "普通命中与暴击对照 · 第 %d / 3 组" % (cycle + 1)
			for target_index in targets.size():
				var column := target_index % 4
				var critical := target_index >= 4
				targets[target_index].take_damage(SAMPLES[cycle][column], "visual_review", critical)
		if graphical:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		if index in [24, 114, 204]:
			_record_labels(index)
		if graphical and not capture_dir.is_empty():
			var screenshot := get_tree().root.get_texture().get_image()
			check(screenshot.save_png(capture_dir.path_join("frames/frame_%04d.png" % index)) == OK, "save frame %d" % index)
	check(EnemyController.active_damage_numbers == 0, "all review labels recycled")
	# A critical popup must finish independently of the enemy that created it.
	var victim := targets[0]
	victim.current_hp = 1
	victim.take_damage(100, "visual_review", true)
	await frames(75)
	check(not is_instance_valid(victim), "lethal target freed during popup")
	check(EnemyController.active_damage_numbers == 0, "critical popup recycled after lethal target freed")
	var report := {"production_scene": "res://scenes/battle/battle_root.tscn", "fixture": "stationary enemies with scripted damage through take_damage", "fps": FPS, "frames": FRAME_COUNT, "checks": checks, "failures": failures, "samples": SAMPLES, "observations": observations}
	if not capture_dir.is_empty():
		var output := FileAccess.open(capture_dir.path_join("report.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(report, "\t"))
	print("DAMAGE_NUMBER_VISUAL_REVIEW checks=", checks, " failures=", failures.size())
	overlay.queue_free()
	game.queue_free()
	await frames(5)
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)


func _validate_boundaries() -> void:
	# Revisit tiers in a mixed order to expose wrong shared-theme cache keys.
	for critical in [false, true]:
		for entry in [[100, 1], [99, 0], [10000, 2], [9999, 1], [1000000, 3], [999999, 2], [1, 0], [10000000, 3]]:
			var theme := targets[0]._get_damage_number_theme(entry[0], critical)
			check(theme.get_color("font_color", "Label").is_equal_approx(EXPECTED_COLORS[entry[1]]), "color boundary %d critical=%s" % [entry[0], critical])
			check(theme.get_font_size("font_size", "Label") == (26 if critical else 18), "font size critical=%s" % critical)


func _record_labels(frame: int) -> void:
	var labels: Array[Dictionary] = []
	for child in targets[1].get_parent().get_children():
		if child is Label and child.visible and child.tree_exiting.is_connected(EnemyController.release_damage_number):
			labels.append({"text": child.text, "font_size": child.get_theme_font_size("font_size"), "color": child.get_theme_color("font_color").to_html(), "position": [child.position.x, child.position.y]})
	check(labels.size() == 8, "eight displayed damage labels at frame %d" % frame)
	observations.append({"frame": frame, "labels": labels})


func _label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)
	return label


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	_label("伤害飘字 · 视觉审阅", Vector2(280, 135), Vector2(790, 40), 26, Color.WHITE)
	phase_label = _label("普通命中与暴击对照", Vector2(280, 177), Vector2(790, 30), 16, Color(0.82, 0.87, 0.88))
	for column in 4:
		_label(["1–2 位 · 白色", "3–4 位 · 黄色", "5–6 位 · 橙色", "7+ 位 · 红色"][column], Vector2(350 + column * 170, 225), Vector2(150, 28), 17, EXPECTED_COLORS[column])
	_label("普通\n18 号", Vector2(268, 307), Vector2(78, 60), 18, Color.WHITE)
	_label("暴击\n26 号", Vector2(268, 467), Vector2(78, 60), 18, Color(1.0, 0.78, 0.28))
	_label("暴击：出现时短促震动 0.3 秒 → 上浮淡出", Vector2(300, 575), Vector2(760, 30), 17, Color(0.88, 0.91, 0.91))
