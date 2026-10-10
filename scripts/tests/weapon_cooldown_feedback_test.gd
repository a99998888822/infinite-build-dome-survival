extends Node
## Real casting/HUD regression and GPU checks for the installed cooldown border.
const BASE := "res://artifacts/validation/weapon_cooldown_feedback_install_20261010/"
const PULSE = preload("res://scripts/ui/weapon_pulse_r02.gd")
var game: GameRoot
var battle: BattleRoot
var loadout: WeaponLoadout
var bar: ActiveCombatWeaponBar
var targets: Array[EnemyController] = []
var failures: Array = []
var checks := 0
var captured := 0
var graphical := false
var home := Vector2.ZERO
var events: Array = []
var simulation_tick := 0

func _ready() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await get_tree().create_timer(230, true, false, true).timeout
	push_error("COOLDOWN_FEEDBACK_TIMEOUT")
	get_tree().quit(99)

func frames(count: int = 2) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func reset(ids: Array) -> void:
	for source in loadout.weapon_instances: loadout._clear_weapon_runtime(source)
	loadout.weapon_instances.clear()
	loadout.active_casting.states.clear()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects") + get_tree().get_nodes_in_group("combat_impacts_r02"):
		if is_instance_valid(runtime): runtime.queue_free()
	for source_id in ids:
		var source := WeaponInstance.new()
		source.initialize(source_id, battle.player)
		source.use_active_range_rules = true
		loadout.weapon_instances.append(source)
	bar.setup(loadout.weapon_instances)
	bar.show()
	battle.player.global_position = home
	for target in targets: target.current_hp = 100000
	for target in targets:
		if target.has_meta(&"combat_feedback_r02"):
			var response = target.get_meta(&"combat_feedback_r02")
			response.restore()
			response.age = response.duration
	events.clear()
	simulation_tick = 0
	for i in loadout.weapon_instances.size():
		loadout.weapon_instances[i].cooldown_ready_changed.connect(func(ready: bool): events.append([simulation_tick, i, ready]))
	refresh()

func refresh() -> void:
	battle.hud._refresh_active_combat()
	# Keep the close-up crop clear of the unrelated keyboard-hint line.
	battle.hud.combat_hints.hide()

func advance(automatic: bool = false) -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for target in targets:
		if target.has_meta(&"combat_feedback_r02"): target.get_meta(&"combat_feedback_r02")._physics_process(1.0 / 60)
	for tween in get_tree().get_processed_tweens(): tween.custom_step(1.0 / 60)
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects") + get_tree().get_nodes_in_group("combat_impacts_r02"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.has_method("_physics_process"):
			node._physics_process(1.0 / 60)
	loadout.active_casting.tick(1.0 / 60)
	if automatic: loadout.active_casting.auto_attack()
	for card in bar.cards:
		for child in card.get_children():
			if child.get_script() == PULSE and child.is_physics_processing(): child._physics_process(1.0 / 60)
	for feedback in bar.feedbacks:
		if feedback.is_physics_processing(): feedback._physics_process(1.0 / 60)
	AudioManager._process(1.0 / 60)
	AudioManager.flush_combat_audio(true)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	refresh()
	simulation_tick += 1

func cast_at(index: int, automatic: bool = false) -> bool:
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var source := loadout.weapon_instances[index]
	var point := home + Vector2(60, 0)
	var result := loadout.active_casting.cast(source, point, true) if automatic else loadout.cast_weapon(source, point)
	if result:
		var state := loadout.active_casting.state_for(loadout.weapon_instances[index])
		var body: Variant = state.body.get_ref() if state.body is WeakRef else null
		if body is RitualDomain: body.target_rng.seed = 4455
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	refresh()
	return result

func run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	CampProgression.begin_transient_session()
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection(): get_tree().quit(3); return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.active_controller.indicator.hide()
	battle.active_controller.cursor_icon.hide()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(12)
	battle.combat_guide.hide()
	battle.hud.set_process(false)
	loadout = battle.loadout
	bar = battle.hud.combat_bar
	check(flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT, "capture uses active combat HUD; run with --transient-session")
	if flow.get_current_state() != MainFlowCoordinator.STATE_WAVE_COMBAT:
		get_tree().quit(2)
		return
	home = battle.player.global_position
	AudioManager.stop_bgm()
	Engine.time_scale = 0
	for offset in [Vector2(45,0),Vector2(80,20),Vector2(120,-12)]:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		battle.player.get_parent().add_child(enemy)
		enemy.global_position = home + offset
		enemy.current_hp = 100000
		enemy.set_physics_process(false)
		targets.append(enemy)
	await test_events()
	if graphical: await capture_ready()
	var path := "validation/gpu_capture.json" if graphical else "validation/headless.json"
	FileAccess.open(BASE + path, FileAccess.WRITE).store_string(JSON.stringify({"captured":captured,"checks":checks,"failures":failures},"\t"))
	Engine.time_scale = 1
	game.queue_free()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("COOLDOWN_FEEDBACK checks=", checks, " captured=", captured, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func test_events() -> void:
	reset(["weapon_camp_dagger", "weapon_camp_dagger"])
	await frames()
	advance()
	check(events.is_empty() and bar.feedbacks[0].ready_count == 0, "initial ready slots do not flash")
	var icon_position := bar.icons[0].position
	check(cast_at(0), "actual manual cast succeeds")
	check(bar.icons[0].position == icon_position and bar.icons[0].scale == Vector2.ONE, "successful cast has no icon motion")
	check(bar.icons[0].get_parent() == bar.cards[0], "icon uses the original card hierarchy")
	check(not bar.feedbacks[0].is_physics_processing(), "cast does not start a cooldown border animation")
	check(not cast_at(0) and bar.feedbacks[0].ready_count == 0, "rejected cast does not flash")
	check(not loadout.cast_weapon(loadout.weapon_instances[1], home), "paused cast remains rejected")
	for i in 600:
		advance()
		if bar.feedbacks[0].ready_count == 1: break
	check(bar.feedbacks[0].ready_count == 1 and bar.feedbacks[1].ready_count == 0, "real cooldown lights only its source instance by default")
	check(loadout.active_casting.can_cast(loadout.weapon_instances[0]), "ready cue matches actual casting availability")
	var age: float = bar.feedbacks[0].ready_age
	var remaining: float = loadout.active_casting.state_for(loadout.weapon_instances[0]).remaining
	bar.feedbacks[0]._physics_process(0.4)
	loadout.active_casting.tick(0.4)
	check(bar.feedbacks[0].ready_age == age and loadout.active_casting.state_for(loadout.weapon_instances[0]).remaining == remaining, "pause freezes cooldown and border")
	for i in 90: advance()
	check(bar.feedbacks[0].ready_count == 1 and not bar.feedbacks[0].is_physics_processing(), "ready cue ends and does not repeat")
	check(bar.icons[0].position == icon_position and bar.icons[0].scale == Vector2.ONE, "cooldown feedback never transforms the icon")
	var old: Control = bar.feedbacks[0]
	var source: WeaponInstance = loadout.weapon_instances[0]
	loadout.weapon_instances.reverse()
	bar.setup(loadout.weapon_instances)
	check(not source.cooldown_ready_changed.is_connected(old.on_ready_changed), "rebuilding disconnects old listeners immediately")
	check(bar.feedbacks[1].source == source and bar.feedbacks[0].ready_count == 0, "reordering duplicate weapons preserves instance identity")
	await frames()
	cast_at(1)
	for i in 600:
		advance()
		if bar.feedbacks[1].ready_count == 1: break
	check(bar.feedbacks[1].ready_count == 1 and bar.feedbacks[0].ready_count == 0, "reordered cooldown lights the new slot once")
	cast_at(1)
	check(bar.feedbacks[1].ready_age >= bar.feedbacks[1].READY_DURATION and not bar.feedbacks[1].is_physics_processing(), "manual recast clears an active ready border")
	bar.hide()
	for i in 600: advance()
	# refresh() shows the normal battle HUD; explicitly exercise hidden signal delivery.
	bar.hide()
	var count: int = bar.feedbacks[1].ready_count
	source.cooldown_ready_changed.emit(true)
	check(bar.feedbacks[1].ready_count == count and not bar.feedbacks[1].is_physics_processing(), "hidden HUD ignores ready cues")
	bar.show()
	check(not bar.feedbacks[1].is_physics_processing(), "showing HUD does not synthesize ready cues")
	reset(["weapon_void_blade"])
	await frames()
	loadout.weapon_instances[0].active_cooldown_ms = 150
	for i in 180:
		if loadout.active_casting.can_cast(loadout.weapon_instances[0]): cast_at(0, true)
		advance()
	check(loadout.weapon_instances[0].volley_index >= 6, "automatic attack rate remains unchanged")
	check(bar.feedbacks[0].ready_count == 0, "immediate automatic recasts consume the ready flash")
	for i in 90: advance()
	check(bar.feedbacks[0].ready_count == 1, "automatic weapon lights once when it stays ready")
	reset(["weapon_star_tome"])
	await frames()
	cast_at(0)
	for i in 45: advance()
	check(cast_at(0), "actual star return still succeeds")
	remaining = loadout.active_casting.state_for(loadout.weapon_instances[0]).remaining
	check(remaining > 0 and bar.feedbacks[0].ready_count == 0, "star return does not create a ready cue")
	for i in 500: advance()
	check(bar.feedbacks[0].ready_count == 1, "shared star cooldown emits ready exactly once")
	reset(["weapon_copper_lamp"])
	await frames()
	for target in targets: target.global_position += Vector2(10000,0)
	check(not cast_at(0) and events.is_empty(), "lamp with no target does not emit a readiness transition")
	for target in targets: target.global_position -= Vector2(10000,0)
	reset(["weapon_camp_dagger"])
	await frames()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	battle.player.alive = false
	check(not loadout.cast_weapon(loadout.weapon_instances[0], home) and events.is_empty(), "dead owner emits no readiness transition")
	battle.player.alive = true
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	# Earlier R02 behavior still owns its own icon pulse; readiness only draws borders.
	loadout.weapon_instances[0].feedback_mark.emit(0)
	check(bar.icons[0].scale.x < 1.0, "previously installed R02 mark response is preserved")
	for i in 30: advance()
	check(bar.icons[0].scale == Vector2.ONE, "R02 restores independently of cooldown feedback")


func capture_ready() -> void:
	reset(["weapon_camp_dagger", "weapon_earth_hammer", "weapon_kunyu_ritual_tome"])
	await frames(4)
	seed(73091)
	for i in 3: cast_at(i)
	for i in 600:
		advance()
		if loadout.weapon_instances.all(func(w: WeaponInstance): return not loadout.active_casting.state_for(w).executing): break
	for weapon in loadout.weapon_instances:
		var state := loadout.active_casting.state_for(weapon)
		state.remaining = minf(state.remaining, 0.7)
	for feedback in bar.feedbacks: feedback.clear_feedback()
	for f in 60:
		for sub in 2: advance()
		await capture("ready_installed", f)
	check(bar.feedbacks.all(func(feedback: Control): return feedback.ready_count == 1), "all three installed slots flash exactly once")


func capture(id: String, frame: int) -> void:
	await frames(1)
	await RenderingServer.frame_post_draw
	var screenshot := get_tree().root.get_texture().get_image()
	screenshot.convert(Image.FORMAT_RGB8)
	# Real context above, 3x nearest-neighbor weapon bar below, plus 1x reference.
	var out := Image.create(720,560,false,Image.FORMAT_RGB8)
	out.fill(Color("17221f"))
	out.blit_rect(screenshot,Rect2i(340,270,720,120),Vector2i.ZERO)
	var rect := Rect2i(Vector2i(bar.position) - Vector2i(10,12), Vector2i(bar.size) + Vector2i(20,18))
	var crop := screenshot.get_region(rect)
	out.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((720-crop.get_width())/2,128))
	crop.resize(crop.get_width()*3,crop.get_height()*3,Image.INTERPOLATE_NEAREST)
	out.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((720-crop.get_width())/2,244))
	if out.save_png(BASE + "frames/%s_%03d.png" % [id,frame]) != OK: failures.append(id + " save")
	if frame == 17: screenshot.save_png(BASE + "validation/" + id + "_context.png")
	captured += 1
