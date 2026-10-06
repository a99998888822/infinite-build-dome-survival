extends "res://scripts/tests/active_combat_integration_test.gd"
## Actual GameRoot + native ActiveWeaponCasting. Only fixtures/adapters live here.
const TARGET = preload("res://artifacts/previews/range_half_bonus_review/preview_target.gd")
const EFFECT_PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const SIZE := Vector2i(960, 540)
const SCORES := [0, 50, 100, 200]
const FRAME_COUNT := 180
const CAST_FRAME := 42
var family := "range"
var review_mode := "current"
var take_movie := false
var sample_only := false
var source: WeaponInstance
var targets: Array[EnemyController] = []
var target_offsets: Array[Vector2] = []
var hits: Dictionary = {}
var observations: Array[Dictionary] = []
var stat_label: Label
var dimension_label: Label
var phase_label: Label
var indicator: WeaponAttackIndicator
var current_score := 0
var current_phase := ""
var last_mask_check := false

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="): family = arg.trim_prefix("--family=")
		if arg.begins_with("--mode="): review_mode = arg.trim_prefix("--mode=")
		if arg == "--capture": take_movie = true
		if arg == "--sample": sample_only = true
	super._ready()

func _watchdog() -> void:
	await get_tree().create_timer(150).timeout
	push_error("RANGE_BONUS_REVIEW_TIMEOUT")
	get_tree().quit(99)

func _run() -> void:
	check(family in ["range", "area", "combined"], "known preview family")
	check(review_mode in ["current", "half"], "known efficiency")
	CampProgression.begin_transient_session()
	CombatSettings.set_option("wheelchair_mode", false, false)
	seed(10062026)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = SIZE
	get_tree().root.content_scale_size = SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await boot()
	battle.set_process(false)
	controller.enabled = false
	controller.set_process(false)
	controller.clear_input()
	player.set_physics_process(false)
	player.set_process_input(false)
	player.last_move_direction = Vector2.RIGHT
	player._invincibility_timer = 9999
	player.camera_2d.zoom = Vector2.ONE * (1.0 if family == "area" else 0.62 if family == "combined" else 0.9)
	player.camera_2d.offset = Vector2(95 if family == "area" else 300, -90 if family == "combined" else 0)
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	for old: WeaponInstance in loadout.weapon_instances.duplicate():
		loadout.remove_weapon(old.weapon_id)
	source = WeaponInstance.new()
	var weapon_id: String = {"range": "weapon_nightwatch_spear", "area": "weapon_iron_grenade_cannon", "combined": "weapon_copper_lamp"}[family]
	check(source.initialize(weapon_id, player), "native weapon initialized")
	source.use_active_range_rules = true
	source.principal_getter = Callable(loadout, "get_current_principal")
	loadout.weapon_instances.append(source)
	loadout.set_active_combat_enabled(true)
	for stat in ["area_size", "damage_area_size", "crit_chance", "attack_speed"]:
		_set_total(stat, 0)
	_set_total("projectile_count", 1)
	_setup_targets()
	_setup_ui()
	indicator = WeaponAttackIndicator.new()
	player.get_parent().add_child(indicator)
	indicator.global_position = player.global_position
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames(15)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		FileAccess.open(capture_dir.path_join(".gdignore"), FileAccess.WRITE).close()
	for score in ([100] if sample_only else SCORES):
		await _case(score)
	if not capture_dir.is_empty():
		var report := {"family": family, "mode": review_mode, "efficiency": StatDefinitions.RANGE_BONUS_EFFICIENCY,
			"size": [SIZE.x, SIZE.y], "render_fps": 60, "capture_fps": 20,
			"cases": observations, "checks": checks, "failures": failures,
			"method": "Real GameRoot and native casting/collision/VFX. Raw equipment stats preserved; preview-only cast snapshots halve the two bonuses. Stationary durable native enemies, fixed camera, seeded environment. No production resource edits."}
		FileAccess.open(capture_dir.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("RANGE_BONUS_REVIEW family=", family, " mode=", review_mode, " checks=", checks, " failures=", failures)
	flow.enter_start_page()
	await frames(4)
	source = null
	targets.clear()
	game.queue_free()
	await frames(4)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer: child.stream = null
	CampProgression.end_transient_session()
	get_tree().quit(1 if failures else 0)

func _set_total(stat: String, value: float) -> void:
	source.runtime_stats[stat] = float(source.runtime_stats.get(stat, 0)) + value - source.get_stat(stat)

func _setup_targets() -> void:
	if family == "range":
		for x in [180, 260, 310, 370, 420, 500, 610, 720]:
			target_offsets.append(Vector2(x, 0))
	elif family == "area":
		# All cases aim at the same point 5 px ahead; even radius 192 fits within
		# the fixed 200 px throwing boundary. Thus range cannot confound this test.
		for r in [40, 72, 88, 110, 145, 180, 210]:
			for sign_y in [-1, 1]:
				target_offsets.append(Vector2(5, 0) + Vector2(r * 0.72, sign_y * r * 0.694 * AttackFootprint.ELLIPSE_RATIO))
	else:
		for x in [85, 145, 205, 270, 330, 420, 550, 650]:
			target_offsets.append(Vector2(x, -x * 0.17 if int(x) % 2 else x * 0.17))
	for index in target_offsets.size():
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(TARGET)
		enemy.auto_initialize_on_ready = false
		player.get_parent().add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.modifier_stack.set_base_stat("max_hp", 100000)
		enemy.current_hp = 100000
		enemy.global_position = player.global_position + target_offsets[index]
		enemy.damage_received.connect(_hit.bind(index))
		targets.append(enemy)
		var tag := Label.new()
		tag.position = Vector2(-17, 9)
		tag.add_theme_font_size_override("font_size", 14)
		tag.add_theme_color_override("font_color", Color("d5dbc8"))
		tag.add_theme_constant_override("outline_size", 3)
		tag.text = str(int(target_offsets[index].x)) if family != "area" else str([40, 72, 88, 110, 145, 180, 210][index / 2])
		enemy.add_child(tag)

func _hit(_weapon_id: String, damage: int, index: int) -> void:
	hits[index] = int(hits.get(index, 0)) + damage
	_update_phase()

func _setup_ui() -> void:
	var hud := battle.hud as BattleHud
	hud.set_process(false)
	hud._weapon_damage_meter.hide()
	hud._performance_line.hide()
	hud.combat_bar.setup([source])
	hud._apply_combat_layout()
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var bg := ColorRect.new()
	bg.position = Vector2(10, 77)
	bg.size = Vector2(940, 62)
	bg.color = Color(0.025, 0.04, 0.035, 0.96)
	layer.add_child(bg)
	stat_label = _label(layer, Vector2(22, 80), 19)
	dimension_label = _label(layer, Vector2(22, 109), 15)
	phase_label = _label(layer, Vector2(24, 414 if family == "combined" else 399), 17)

func _label(parent: Node, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0ebe2"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _update_phase() -> void:
	phase_label.text = "%s  |  命中目标 %d / %d" % [current_phase, hits.size(), targets.size()]

func _case(score: int) -> void:
	current_score = score
	hits.clear()
	for index in targets.size():
		targets[index].current_hp = 100000
		targets[index].global_position = player.global_position + target_offsets[index]
		targets[index].velocity = Vector2.ZERO
	loadout._clear_weapon_runtime(source)
	loadout.active_casting.states.clear()
	_set_total("area_size", 0 if family == "area" else score)
	_set_total("damage_area_size", 0 if family == "range" else score)
	var snapshot := source.make_cast_copy()
	var raw_range := source.get_stat("area_size")
	var raw_area := source.get_stat("damage_area_size")
	check(source.get_script() == preload("res://scripts/weapons/weapon_instance.gd") and raw_range == (0 if family == "area" else score) and raw_area == (0 if family == "range" else score), "raw panel values preserved")
	check(is_equal_approx(source.get_attack_range(), snapshot.get_attack_range()), "aim and live snapshot range agree")
	check(is_equal_approx(source.get_grenade_blast_radius(), snapshot.get_grenade_blast_radius()), "aim and live blast agree")
	var parameters := EFFECT_PARAMETERS.build_weapon_context(snapshot, "fire")
	check(is_equal_approx(parameters.get_resolved_parameter("damage_area_size_multiplier", 1), 1.0 + raw_area * StatDefinitions.RANGE_BONUS_EFFICIENCY / 100), "enchantment receives scaled bonus exactly once")
	var aim := player.global_position + Vector2(5 if family == "area" else 900, 0)
	indicator.configure(source, aim - player.global_position)
	indicator.show()
	current_phase = "瞄准预览"
	_update_phase()
	stat_label.text = "%s · %s  |  攻击距离属性 +%d  伤害范围属性 +%d" % [source.weapon_data.display_name, "当前规则" if review_mode == "current" else "预览：加成收益减半", raw_range, raw_area]
	dimension_label.text = "实际距离 %.0f px · 实际爆炸半径 %.0f px" % [source.get_attack_range(), source.get_grenade_blast_radius()] if family == "area" else "实际攻击距离 %.0f px · 基础距离 %.0f px" % [source.get_attack_range(), source.get_base_attack_range()]
	await frames(5)
	var entries: Array[Dictionary] = []
	var damage_events := snapshot.calculate_damage_events()
	var single_damage: int = damage_events[0].damage
	var physics_start := Engine.get_physics_frames()
	var cast_tick := 0
	for frame in FRAME_COUNT:
		await get_tree().process_frame
		loadout.tick(1.0 / 60.0)
		if frame == CAST_FRAME:
			check(loadout.cast_weapon(source, aim), "real active cast accepted")
			cast_tick = Engine.get_physics_frames()
			indicator.hide()
			current_phase = "实际攻击"
			_update_phase()
		if frame == 154:
			current_phase = "本次命中结果"
			_update_phase()
		var state := loadout.active_casting.state_for(source)
		(battle.hud as BattleHud).combat_bar.update_slot(0, state.remaining, state.total, state.executing, false)
		if frame % 3 == 0 and take_movie and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var filename := "%03d_%03d.png" % [score, frame / 3]
			var screenshot := get_tree().root.get_texture().get_image()
			check(screenshot.save_png(capture_dir.path_join(filename)) == OK, "GPU frame saved")
			entries.append({"file": filename, "simulation_frame": frame, "physics_tick": Engine.get_physics_frames() - physics_start, "hit_targets": hits.size()})
	var expected: Array[int] = []
	for index in target_offsets.size():
		var offset := target_offsets[index]
		if family == "range":
			# Targets are deliberately separated from the collider boundary.
			if offset.x < snapshot.get_attack_range(): expected.append(index)
		elif family == "area":
			if ((offset - Vector2(5, 0)) / AttackFootprint.grenade_blast_axes(snapshot)).length_squared() <= 1:
				expected.append(index)
		elif AttackFootprint.in_lamp_cone(offset, Vector2.RIGHT, snapshot.get_attack_range(), snapshot.get_lamp_cone_degrees()):
			expected.append(index)
	check(hits.size() == expected.size() and expected.all(func(i): return hits.has(i)), "native damage matches expected coverage " + str(expected))
	if family != "combined":
		check(hits.values().all(func(d): return d == single_damage), "single-hit damage unchanged")
	observations.append({"score": score, "range_attribute": raw_range, "area_attribute": raw_area,
		"actual_range": source.get_attack_range(), "blast_radius": source.get_grenade_blast_radius(),
		"single_damage": single_damage, "hits": hits.duplicate(), "expected_targets": expected,
		"cast_tick": cast_tick - physics_start, "frames": entries})
	print("CASE ", family, " ", review_mode, " score=", score, " range=", source.get_attack_range(), " blast=", source.get_grenade_blast_radius(), " hit_targets=", hits.size())
