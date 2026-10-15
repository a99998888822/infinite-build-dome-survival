extends Node
## Real battle and production casts; stationary durable enemies are review fixtures.
var capture_dir := ""
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var frame_index := 0
var coverage: Dictionary = {}
var timeline: Array[Dictionary] = []
var casts: Array[Dictionary] = []
var launches: Array[Dictionary] = []
var targets: Array[EnemyController] = []
var failures: Array[String] = []
var title: Label
var subtitle: Label
var resume_seen := false
var interrupted := false
var damage_total := 0

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.035,0.045,0.075,0.9)
	panel.position = Vector2(330,70)
	panel.size = Vector2(620,74)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	title = Label.new()
	title.position = Vector2(348,77)
	title.add_theme_font_size_override("font_size", 23)
	canvas.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(348,111)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color("a6c9d6")
	canvas.add_child(subtitle)

func _equip(ids: Array) -> void:
	for weapon in loadout.weapon_instances.duplicate():
		loadout.remove_weapon(weapon.weapon_id)
	for id: String in ids:
		check(loadout.equip_weapon(id), "equip " + id)
	for i in targets.size():
		var enemy := targets[i]
		damage_total += maxi(0, 100000 - enemy.current_hp)
		enemy.current_hp = 100000
		enemy.global_position = player.global_position + Vector2(85 + i * 30, (i % 2) * 42 - 21)
		# Keep landing poses legible instead of putting a target over the face.
		if ids.has("weapon_dash_blade") or ids.has("weapon_star_tome"):
			enemy.global_position = player.global_position + Vector2(145 + i * 30, 70 + (i % 2) * 30)
	player._clear_move_input()
	player._set_facing(true)

func _cast(id: String) -> void:
	var weapon := loadout.get_weapon_instance(id)
	check(weapon != null, "weapon exists " + id)
	if weapon == null: return
	var before := player.global_position
	var returning := weapon.is_return_ready()
	var ok := loadout.cast_weapon(weapon, before + Vector2(145,0))
	check(ok, "real cast " + id)
	casts.append({"frame":frame_index,"weapon":id,"success":ok,"return":returning,
		"action":player.action_animator.current_clip,"before":[before.x,before.y],
		"after":[player.global_position.x,player.global_position.y]})

func _stage(label: String, ids: Array, seconds: float, move := Vector2.ZERO, interrupt := false, star_return := false) -> void:
	_equip(ids)
	title.text = label
	var start_frame := frame_index
	for i in roundi(seconds * 30):
		if i == 3 and not ids.is_empty(): _cast(ids[0])
		if interrupt and i == 23:
			_cast("weapon_void_blade")
			interrupted = player.action_animator.current_clip == "attack"
		if star_return and i == 39: _cast("weapon_star_tome")
		player.set_mobile_move_direction(move)
		loadout.active_casting.tick(1.0/30.0)
		var animator := player.action_animator
		if move.x < 0.0 and animator.action in ["attack", "move_attack", "jump_forward", "jump_backward"]:
			check(player.facing_right, "rightward cast keeps facing while movement points left")
		subtitle.text = "%s  ·  %02d / %02d  |  128 × 128  |  实机镜头 2×" % [animator.current_clip,animator.current_frame+1,animator._count(animator.current_clip)]
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		var key := "%s:%d" % [animator.current_clip,animator.current_frame]
		coverage[key] = int(coverage.get(key,0)) + 1
		if interrupt and i > 23 and interrupted and animator.action == "sustain_hold": resume_seen = true
		timeline.append({"frame":frame_index,"clip":animator.current_clip,"cell":animator.current_frame,
			"x":player.position.x,"y":player.position.y,"facing_right":player.facing_right})
		if DisplayServer.get_name() != "headless":
			check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % frame_index)) == OK, "save frame")
		frame_index += 1
	print("REVIEW_STAGE ", label, " frames=",frame_index-start_frame," coverage=",coverage.size())

func _run() -> void:
	CampProgression.begin_transient_session()
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	check(flow.confirm_character_selection(), "start production battle")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames(4)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	check(player.action_animator.enabled, "novice animations mounted")
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	loadout.set_active_combat_enabled(true)
	player.camera_2d.zoom = Vector2(2,2)
	# Fixtures avoid random deaths/modals. Weapon damage, timing, ranges, player
	# movement, art scale and actual effect runtimes remain production values.
	player.modifier_stack.set_base_stat("max_hp", 1000)
	player.restore_full_health()
	battle.wave_manager.finance_system.deposit(400, true, "action_review")
	for i in 4:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(90+i*30,20))
		enemy.set_physics_process(false)
		enemy.current_hp = 100000
		targets.append(enemy)
	loadout.weapon_fired.connect(func(id: String,count: int): launches.append({"frame":frame_index,"weapon":id,"count":count}))
	check(DisplayServer.get_name() == "headless" or not capture_dir.is_empty(), "capture output provided")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	_overlay()
	await _stage("01  待机 · 完整封口手套", [], 1.5)
	await _stage("02  移动 · 连续步态", [], 2.0, Vector2(0.25,0))
	await _stage("02b  移动攻击 · 单次挥拳", ["weapon_void_blade"], 1.6, Vector2(0.25,0))
	for entry in [
		["木质弓箭","weapon_void_blade"],["电浆炮","weapon_plasma_cannon"],
		["铸铁榴弹炮","weapon_iron_grenade_cannon"],["食利者钱袋","weapon_rentier_purse"],
		["异化触手","weapon_mutant_tentacle"],["裂地战锤","weapon_earth_hammer"],
		["营地短刀","weapon_camp_dagger"],["守夜长枪","weapon_nightwatch_spear"],
		["流星摆锤","weapon_meteor_flail"]]:
		await _stage("03  单手挥击 · " + entry[0], [entry[1]], 1.6, Vector2(-0.25,0) if entry[1] == "weapon_void_blade" else Vector2.ZERO)
	await _stage("04  静止抬手 · 坤舆秘仪书", ["weapon_kunyu_ritual_tome"], 2.2)
	await _stage("05  移动抬手 · 赤铜炉灯", ["weapon_copper_lamp"], 2.5, Vector2(0.2,0.08))
	await _stage("06  炉灯 → 弓箭打断 → 恢复抬手", ["weapon_copper_lamp","weapon_void_blade"], 2.5, Vector2.ZERO, true)
	await _stage("07  前跃姿态 · 突进短刃", ["weapon_dash_blade"], 1.6, Vector2(-0.25,0))
	await _stage("08  后跃姿态 · 巨型手持火炮", ["weapon_hand_cannon"], 2.3, Vector2(-0.25,0))
	await _stage("09  移星秘典 · 向前瞬移 / 向后返回", ["weapon_star_tome"], 3.3, Vector2.ZERO, false, true)
	await _stage("10  移动衔接 · 左向镜像", [], 1.5, Vector2(-0.25,0))
	player.set_mobile_move_direction(Vector2.ZERO)
	for enemy in targets: damage_total += maxi(0,100000-enemy.current_hp)
	var expected_cells := 0
	for clip: String in player.action_animator._clips:
		expected_cells += player.action_animator._count(clip)
	check(coverage.size() == expected_cells, "all configured action cells rendered, expected %d got %d" % [expected_cells, coverage.size()])
	check(resume_seen, "sustain resumes after real bow interruption")
	check(casts.size() == 18, "all weapon casts plus moving punch, interruption and return")
	check(damage_total > 0, "real enemy damage recorded")
	var report := {"valid":failures.is_empty(),"failures":failures,"frames":frame_index,"fps":30,
		"coverage":coverage,"covered_frames":coverage.size(),"expected_cells":expected_cells,"casts":casts,"weapon_fired":launches,
		"sustain_resume_seen":resume_seen,"damage_total":damage_total,"timeline":timeline,
		"review_fixtures":{"stationary_enemies":4,"enemy_hp":100000,"player_hp":1000,"principal":400,"camera_zoom":2}}
	if not capture_dir.is_empty():
		var output := FileAccess.open(capture_dir.path_join("capture.json"),FileAccess.WRITE)
		output.store_string(JSON.stringify(report,"\t"))
	print("PLAYER_ACTION_LIVE_COMPLETE frames=",frame_index," coverage=",coverage.size()," casts=",casts.size()," damage=",damage_total," valid=",failures.is_empty())
	get_tree().quit(0 if failures.is_empty() else 1)
