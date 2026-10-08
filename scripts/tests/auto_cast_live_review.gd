extends "res://scripts/tests/active_combat_integration_test.gd"
## Real GameRoot, production input events and naturally ticking combat.
## Only encounter layout/health/spawning and explanatory overlays are fixtures.
const DASH := "weapon_dash_blade"
const CANNON := "weapon_hand_cannon"
const TOME := "weapon_star_tome"
const BOW := "weapon_void_blade"
const LAMP := "weapon_copper_lamp"
var samples: Dictionary = {}
var launches: Array[Dictionary] = []
var clip := ""
var clip_frame := 0
var title_label: Label
var title_back: ColorRect
var detail_label: Label
var input_label: Label
var pointer_mark: Polygon2D
var click_ring: Line2D
var status_back: ColorRect
var pointer := Vector2(920, 370)
var press_flash := 0
var descriptions: Dictionary = {}
var capture_variant := "all"

func _watchdog() -> void:
	await get_tree().create_timer(360.0).timeout
	push_error("AUTO_CAST_REVIEW_TIMEOUT")
	get_tree().quit(99)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): capture_variant = arg.trim_prefix("--variant=")
	if DisplayServer.get_name() == "headless":
		print("AUTO_CAST_REVIEW_PARSED GPU capture required")
		get_tree().quit()
		return
	if capture_dir.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	CampProgression.begin_transient_session()
	CombatSettings.load_config(ConfigFile.new())
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	_build_overlay()
	await boot()
	loadout.weapon_fired.connect(func(id: String, count: int): launches.append({"clip": clip, "tick": Engine.get_physics_frames(), "weapon": id, "count": count}))
	if capture_variant in ["all", "settings", "icons"]: await settings_clip()
	if capture_variant in ["all", "mixed", "icons"]: await mixed_clip()
	if capture_variant in ["all", "dash"]: await dash_clip()
	if capture_variant in ["all", "cannon"]: await cannon_clip()
	if capture_variant in ["all", "tome"]: await tome_clip()
	if capture_variant in ["all", "mouse"]: await mouse_clip()
	if capture_variant in ["all", "restraint"]: await restraint_clip()
	if capture_variant in ["all", "return"]: await manual_return_clip()
	clip = ""
	controller.clear_input()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var report := {"production_scene": "res://scenes/core/game_root.tscn", "fixed_fps": 60, "physics_fps": Engine.physics_ticks_per_second,
		"samples": samples, "descriptions": descriptions, "launches": launches, "checks": checks, "failures": failures,
		"fixtures": ["spawner and wave clock paused", "encounters placed between chapters", "enemy health increased", "stationary enemies explicitly noted where used", "player health increased", "review-only captions and cursor"],
		"input": "Input.parse_input_event; no direct auto-cast calls", "animation": "native gameplay, no manual physics stepping"}
	var output := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print("AUTO_CAST_LIVE_REVIEW checks=%d failures=%d clips=%d" % [checks, failures, samples.size()])
	get_tree().quit(1 if failures else 0)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var backdrop := ColorRect.new()
	title_back = backdrop
	backdrop.position = Vector2(290, 0)
	backdrop.size = Vector2(850, 68)
	backdrop.color = Color(0.02, 0.035, 0.03, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)
	title_label = _review_label(layer, Vector2(306, 3), 20, Color("eed791"))
	detail_label = _review_label(layer, Vector2(306, 35), 16, Color("e0e8df"))
	status_back = ColorRect.new()
	status_back.position = Vector2(305, 534)
	status_back.size = Vector2(800, 42)
	status_back.color = backdrop.color
	status_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status_back)
	input_label = _review_label(layer, Vector2(318, 542), 16, Color("c5edff"))
	pointer_mark = Polygon2D.new()
	pointer_mark.polygon = PackedVector2Array([Vector2.ZERO, Vector2(0, 22), Vector2(6, 16), Vector2(12, 25), Vector2(17, 22), Vector2(11, 13), Vector2(20, 13)])
	pointer_mark.color = Color("f5e29c")
	layer.add_child(pointer_mark)
	click_ring = Line2D.new()
	click_ring.width = 3.0
	click_ring.default_color = Color("c5edff")
	for i in 33: click_ring.add_point(Vector2.from_angle(i * TAU / 32.0) * 20.0)
	layer.add_child(click_ring)

func _review_label(parent: Node, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(820, 32)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func begin_clip(id: String, title: String, description: String) -> void:
	clip = id
	clip_frame = 0
	samples[id] = []
	descriptions[id] = {"title": title, "description": description}
	DirAccess.make_dir_recursive_absolute(capture_dir.path_join(id))
	title_label.text = title
	detail_label.text = description
	print("RECORDING ", id)

func caption(text: String) -> void:
	detail_label.text = text

func take(seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		pointer_mark.position = pointer
		click_ring.position = pointer
		click_ring.visible = press_flash > 0
		press_flash = maxi(0, press_flash - 1)
		var info := "设置操作演示（鼠标标记为录制辅助）"
		status_back.visible = is_instance_valid(player) and not battle.utility_overlay.visible
		input_label.visible = status_back.visible
		if is_instance_valid(player):
			var keys := ""
			for entry in [[KEY_W, "W"], [KEY_A, "A"], [KEY_S, "S"], [KEY_D, "D"]]:
				if bool(player._held_move_keys.get(entry[0], false)): keys += entry[1]
			info = "实际按键：" + (keys if not keys.is_empty() else "无")
			info += "  ·  右键目的地：" + ("保留" if player.has_move_destination else "无")
			info += "  ·  本段位移施放：%d" % mobility_cast_count()
		input_label.text = info
		await RenderingServer.frame_post_draw
		if not clip.is_empty() and clip_frame % 3 == 0:
			var name := "%s/frame_%05d.png" % [clip, clip_frame]
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name))
			if error != OK:
				push_error("REVIEW_FRAME_WRITE_FAILED")
				get_tree().quit(4)
				return
			var sample := {"file": name, "tick": Engine.get_physics_frames(), "caption": detail_label.text}
			if is_instance_valid(player):
				sample["player"] = [player.global_position.x, player.global_position.y]
				sample["destination"] = [player.move_destination.x, player.move_destination.y] if player.has_move_destination else []
				sample["keys"] = player._held_move_keys.duplicate()
			samples[clip].append(sample)
		clip_frame += 1

func move_pointer(at: Vector2) -> void:
	pointer = at
	var event := InputEventMouseMotion.new()
	event.position = at
	Input.parse_input_event(event)

func press_key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func click_at(at: Vector2, button: int = MOUSE_BUTTON_LEFT, delay: float = 0.15) -> void:
	move_pointer(at)
	await take(delay)
	press_flash = 15
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await take(0.05)

func click_control(control: Control) -> void:
	await click_at(control.get_global_rect().get_center())

func click_setting(panel: GameSettingsPanel, control: Control) -> void:
	panel.content_scroll.ensure_control_visible(control)
	await take(0.3)
	await click_control(control)
	await take(0.6)

func world_pointer(point: Vector2) -> Vector2:
	var world := player.get_viewport()
	return (world.get_canvas_transform() * point) * get_viewport().get_visible_rect().size / world.get_visible_rect().size

func mobility_cast_count() -> int:
	var count := 0
	for launch in launches:
		if launch.clip == clip and launch.weapon in [DASH, CANNON, TOME]: count += 1
	return count

func fixture(ids: Array[String], keyboard: bool, automatic: Array[String]) -> void:
	clip = ""
	controller.clear_input()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	for old in loadout.weapon_instances.duplicate(): loadout.remove_weapon(old.weapon_id)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	await frames(4)
	CombatSettings.reset_weapon_auto_cast(false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(true)
	CombatSettings.set_option("keyboard_movement", keyboard, false)
	CombatSettings.set_option("quick_cast", false, false)
	player.global_position = Vector2.ZERO
	player.modifier_stack.set_base_stat("max_hp", 1000)
	player.current_hp = 1000
	for id in ids:
		loadout.equip_weapon(id)
		CombatSettings.set_weapon_auto_cast(id, automatic.has(id), false)
	loadout.active_casting.mobility_planner = AutoMobilityPlanner.new()
	await frames(8)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	move_pointer(Vector2(1050, 430))

func enemy_at(point: Vector2, moving: bool = false) -> EnemyController:
	var enemy := manager.spawn_enemy("enemy_mutated_grub", point)
	enemy.modifier_stack.set_base_stat("max_hp", 10000)
	enemy.current_hp = 10000
	if not moving: enemy.set_physics_process(false)
	return enemy

func pursuers(moving: bool = true) -> void:
	for point in [Vector2(-70, 0), Vector2(-90, 45), Vector2(-90, -45)]: enemy_at(point, moving)

func await_auto(weapon: WeaponInstance, limit: float = 2.0) -> bool:
	for i in ceili(limit * 20.0):
		if weapon.volley_index > 0: return true
		await take(0.05)
	return weapon.volley_index > 0

func settings_clip() -> void:
	await fixture([BOW, LAMP, DASH, CANNON, TOME], false, [BOW, LAMP])
	set_header_low(true)
	begin_clip("01_settings", "Esc 武器图标：点击切换自动／手动", "循环箭头 = 自动，手形 = 手动；攻击默认自动，位移默认手动")
	await inventory_key()
	var strip := battle.esc_overlay.weapon_strip
	await take(1.2)
	caption("点击弓箭下方图标改为手动，再开启三种位移的自动释放")
	for index in [0, 2, 3, 4]:
		await click_control(strip._cast_mode_buttons[index])
		await take(0.6)
	check(not CombatSettings.prefers_auto_cast(BOW, false) and CombatSettings.prefers_auto_cast(DASH, true) and CombatSettings.prefers_auto_cast(TOME, true), "recorded Esc icon choices")
	caption("关闭 Esc：战斗栏同步显示相同图标，武器图与冷却区独立")
	await inventory_key()
	await take(1.5)
	caption("重新打开 Esc：每把武器保留刚才的选择")
	await inventory_key()
	await take(1.2)
	check(strip._cast_mode_buttons[4].automatic, "recorded inventory reopen retains choice")
	caption("战斗设置只选择移动方式与快捷施法；逐技能图标直接生效")
	await click_control((battle.hud as BattleHud).settings_button)
	await take(0.4)
	var panel := battle.utility_overlay._settings_view
	await click_control(panel.tabs[1])
	await take(1.1)
	check(panel.tabs.size() == 2, "recorded removed automation submenu")
	check(panel.find_child("WheelchairMode", true, false) == null, "recorded removal of automation master switch")
	await click_control(panel.return_button)
	caption("每个技能独立自动或手动；无需开启额外的总开关")
	await take(1.8)
	check(strip._cast_mode_buttons[4].automatic, "recorded automatic choice remains effective")
	await inventory_key()
	await take(1.4)
	set_header_low(false)
	clip = ""

func inventory_key() -> void:
	press_key(KEY_ESCAPE, true)
	await take(0.05)
	press_key(KEY_ESCAPE, false)
	await take(0.5)

func set_header_low(low: bool) -> void:
	var y := 450.0 if low else 0.0
	title_back.position.y = y
	title_label.position.y = y + 3
	detail_label.position.y = y + 35

func mixed_clip() -> void:
	await fixture([BOW, LAMP, DASH], false, [LAMP])
	enemy_at(Vector2(125, 0))
	begin_clip("02_mixed", "混合控制：炉灯自动，弓箭与位移手动", "站立时炉灯自动喷射；弓箭和短刃保持待命（静止目标）")
	await take(1.6)
	var bow := loadout.get_weapon_instance(BOW)
	check(bow.volley_index == 0 and loadout.get_weapon_instance(LAMP).volley_index > 0, "mixed policy only fires enabled attack")
	caption("数字键 1 选择手动弓箭，左键确认发射")
	move_pointer(world_pointer(Vector2(125, 0)))
	press_key(KEY_1, true)
	await take(0.1)
	press_key(KEY_1, false)
	await take(0.8)
	await click_at(pointer)
	await take(0.8)
	check(bow.volley_index == 1, "recorded manual attack works in automatic mode")
	set_header_low(true)
	caption("按 Esc，点击炉灯下方的循环箭头，将它切换为手动")
	await inventory_key()
	await click_control(battle.esc_overlay.weapon_strip._cast_mode_buttons[1])
	await take(0.9)
	await inventory_key()
	set_header_low(false)
	caption("当前动作完成后，炉灯不会再次自动启动")
	var before := loadout.get_weapon_instance(LAMP).volley_index
	await take(4.5)
	check(loadout.get_weapon_instance(LAMP).volley_index == before, "recorded lamp opt-out stops repeats")

func dash_clip() -> void:
	await fixture([DASH], true, [DASH])
	enemy_at(Vector2(275, 25))
	enemy_at(Vector2(335, 95))
	begin_clip("03_wasd_pursuit", "WASD 追击：短按不触发，持续靠近才突进", "先站立，再短按 D；技能保留（静止目标便于观察落点）")
	await take(0.7)
	press_key(KEY_D, true)
	await take(0.12)
	press_key(KEY_D, false)
	await take(0.7)
	var weapon := loadout.get_weapon_instance(DASH)
	check(weapon.volley_index == 0, "recorded short tap does not auto-dash")
	caption("持续按住 D，系统选择能攻击且留有间距的落点")
	press_key(KEY_D, true)
	check(await await_auto(weapon), "live keyboard pursuit triggers dash")
	await take(0.08)
	press_key(KEY_D, false)
	caption("突进途中松开 D：动作完成后停步，不恢复旧按键")
	await take(1.5)
	check(player.movement_intent().is_zero_approx(), "recorded mid-dash release stays released")

func cannon_clip() -> void:
	await fixture([CANNON], true, [CANNON])
	pursuers()
	begin_clip("04_wasd_retreat", "WASD 撤退：火炮朝后攻击，后坐力帮助脱离", "近处敌人持续追击；按 D 向右撤退")
	await take(0.25)
	press_key(KEY_D, true)
	var weapon := loadout.get_weapon_instance(CANNON)
	check(await await_auto(weapon), "live moving pursuers trigger cannon retreat")
	caption("火炮释放后 D 仍然按住，角色继续向右移动")
	var after := player.global_position
	await take(1.1)
	check(bool(player._held_move_keys.get(KEY_D, false)) and player.global_position.x > after.x + 50, "recorded cannon preserves held movement")
	press_key(KEY_D, false)
	caption("松开 D 即停步；不会因为技能结束而恢复旧输入")
	await take(1.1)

func tome_clip() -> void:
	await fixture([TOME], false, [TOME])
	enemy_at(Vector2(295, 55))
	enemy_at(Vector2(350, 100))
	begin_clip("05_mouse_blink", "右键追击：自动闪现，不建立返回入口", "只右键点一次目的地；系统顺着追击意图闪现（静止目标）")
	await take(0.6)
	await click_at(world_pointer(Vector2(440, -45)), MOUSE_BUTTON_RIGHT)
	var goal := player.move_destination
	var weapon := loadout.get_weapon_instance(TOME)
	check(await await_auto(weapon), "live right-click pursuit triggers blink")
	check(player.has_move_destination and player.move_destination == goal, "recorded blink retains clicked goal")
	caption("闪现后继续走向原目的地；图标直接显示冷却，没有返回印记")
	await take(0.8)
	press_key(KEY_S, true)
	await take(0.08)
	press_key(KEY_S, false)
	caption("按 S 停止后等待：位置不回跳，自动闪现始终没有返回状态")
	var stopped := player.global_position
	await take(3.0)
	check(not weapon.is_return_ready() and player.global_position.distance_to(stopped) < 1.0, "recorded automatic blink never returns")

func mouse_clip() -> void:
	await fixture([DASH], false, [DASH])
	pursuers()
	begin_clip("06_mouse_retreat", "右键撤退：突进后保留目的地，支持途中改点", "向右点一次，短刃沿撤退方向脱离追击者")
	await take(0.2)
	await click_at(world_pointer(Vector2(360, 0)), MOUSE_BUTTON_RIGHT)
	var weapon := loadout.get_weapon_instance(DASH)
	check(await await_auto(weapon), "live right-click retreat triggers dash")
	caption("突进途中改点右上方：新目的地生效，技能不会清空它")
	var revised := player.global_position + Vector2(190, -130)
	await click_at(world_pointer(revised), MOUSE_BUTTON_RIGHT, 0.02)
	var retained_goal := player.move_destination
	await take(0.7)
	check(player.has_move_destination and player.move_destination == retained_goal, "recorded new click survives displacement")
	caption("按 S 取消剩余行走；系统不继续自动位移")
	press_key(KEY_S, true)
	await take(0.08)
	press_key(KEY_S, false)
	await take(1.0)
	check(not player.has_move_destination, "recorded mouse stop clears destination")

func restraint_clip() -> void:
	await fixture([DASH, CANNON, TOME], true, [DASH, CANNON, TOME])
	enemy_at(Vector2(-140, 0))
	begin_clip("07_restraint", "克制触发：低压力保留技能，高压力也不连续连跳", "只有一个较远敌人，向右撤退不会自动消耗位移技能")
	press_key(KEY_D, true)
	await take(1.1)
	press_key(KEY_D, false)
	check(mobility_cast_count() == 0, "recorded low-pressure retreat keeps all mobility")
	caption("切换到高压力测试：三把技能同时就绪，先站立不操作")
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for offset in [Vector2(-75, 0), Vector2(-90, 40), Vector2(-90, -40)]: enemy_at(player.global_position + offset)
	await take(1.0)
	check(mobility_cast_count() == 0, "recorded standing under pressure never auto-moves")
	caption("按住 D 撤退：只选择一把，其他位移不会紧接着释放")
	press_key(KEY_D, true)
	await take(1.3)
	check(mobility_cast_count() == 1, "recorded all-ready mobility releases only one")
	press_key(KEY_D, false)
	await take(1.1)

func manual_return_clip() -> void:
	await fixture([TOME], true, [])
	begin_clip("08_manual_return", "手动秘典：独立关闭自动后，原返回操作仍然可用", "轮椅总开关开启，秘典单独设为手动；数字键 1 进入瞄准")
	await take(0.7)
	move_pointer(world_pointer(Vector2(150, -20)))
	press_key(KEY_1, true)
	await take(0.08)
	press_key(KEY_1, false)
	await take(0.8)
	await click_at(pointer)
	caption("手动闪现留下返回印记，武器栏出现返回图标")
	await take(1.0)
	var weapon := loadout.get_weapon_instance(TOME)
	check(weapon.is_return_ready(), "recorded manual tome keeps return mark")
	caption("再次按 1 返回；冷却继续计时，不重新开始")
	press_key(KEY_1, true)
	await take(0.08)
	press_key(KEY_1, false)
	await take(1.4)
	check(player.global_position.length() < 2.0 and not weapon.is_return_ready(), "recorded manual tome returns to origin")
