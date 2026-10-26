extends Node
## Production casts: takeoff at the origin, airborne travel, then landing.
const IDS := ["weapon_dash_blade", "weapon_hand_cannon", "weapon_star_tome"]
var checks := 0
var failures := 0
var session: RecordingSession
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var walls: Array[Node] = []
var capture_dir := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func freeze() -> void:
	for body in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		body.set_physics_process(false)

func step(count := 1) -> void:
	for i in count:
		player._physics_process(1.0 / 60.0)
		for body in get_tree().get_nodes_in_group("weapon_runtime_effects"):
			if not body.is_queued_for_deletion() and body.has_method("_physics_process"):
				body._physics_process(1.0 / 60.0)
		freeze()
		loadout.active_casting.tick(1.0 / 60.0)
		await get_tree().process_frame

func reset() -> void:
	for weapon in loadout.weapon_instances: loadout._clear_weapon_runtime(weapon)
	for body in EnemyRegistry.get_registered_enemies().duplicate(): body.free()
	for body in walls: body.free()
	walls.clear()
	await frames()
	loadout.active_casting.states.clear()
	player.alive = true
	player.current_hp = 1000
	player.global_position = Vector2.ZERO
	player._clear_move_input()
	player.action_animator.reset()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()

func cast(id: String, automatic := false) -> MobilityWeaponRuntime:
	var weapon := loadout.get_weapon_instance(id)
	check(loadout.active_casting.cast(weapon, Vector2(170, 0), automatic), "cast " + id)
	freeze()
	return weapon.mobility_runtime.get_ref() as MobilityWeaponRuntime

func enemy(at: Vector2) -> EnemyController:
	var body := battle.wave_manager.spawn_enemy("enemy_mutated_grub", at)
	body.set_physics_process(false)
	body.current_hp = 10000
	body.target_player = null
	var shape := CircleShape2D.new()
	shape.radius = 5
	var collision := body.get_node("CollisionShape2D") as CollisionShape2D
	collision.shape = shape
	collision.position = Vector2.ZERO
	return body

func wall(at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 240)
	collision.shape = shape
	body.add_child(collision)
	player.get_parent().add_child(body)
	body.global_position = at
	walls.append(body)

func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var screen := get_tree().root.get_texture().get_image()
	check(screen.save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)

func _test_jump(id: String, automatic := false) -> void:
	await reset()
	var weapon := loadout.get_weapon_instance(id)
	var target := enemy(Vector2(80, 0) if weapon.is_hand_cannon() else Vector2(180, 0))
	await frames()
	var runtime := cast(id, automatic)
	var destination := runtime.destination
	var tag := id + ("_auto" if automatic else "")
	check(player.global_position == Vector2.ZERO and player.action_animator.current_frame == 0, tag + " starts takeoff at origin")
	var takeoff_frames := {0: true}
	var landing_frames := {}
	var takeoff_still := true
	var protected := true
	var airborne := true
	var landing_still := true
	var captures := {}
	for i in 80:
		if player.is_mobility_moving():
			player.play_weapon_action("weapon_wood_arrow", null, 0.0, Vector2.RIGHT)
			protected = protected and player.action_animator.action in ["jump_forward", "jump_backward"]
		await step()
		var frame := player.action_animator.current_frame
		if is_instance_valid(runtime) and runtime.phase == "takeoff":
			takeoff_frames[frame] = true
			takeoff_still = takeoff_still and player.global_position == Vector2.ZERO and target.current_hp == 10000
		elif is_instance_valid(runtime) and runtime.phase == "moving":
			airborne = airborne and frame == 3
		elif is_instance_valid(runtime) and runtime.phase == "landing":
			landing_frames[frame] = true
			landing_still = landing_still and player.global_position.is_equal_approx(destination)
			if not captures.has("landing"):
				check(not loadout.active_casting.can_cast(weapon), tag + " cannot recast during landing")
		if not automatic and is_instance_valid(runtime):
			var label := runtime.phase + "_" + str(frame)
			if label in ["takeoff_1", "takeoff_2", "moving_3", "landing_3", "landing_5"] and not captures.has(label):
				captures[label] = true
				await capture(tag + "_" + label)
		if is_instance_valid(runtime) and runtime.phase == "landing": captures["landing"] = true
	check(takeoff_still and takeoff_frames.keys() == [0, 1, 2], tag + " first three frames stay at origin without damage")
	check(airborne, tag + " continuous travel holds apex pose")
	check(landing_still and landing_frames.keys() == [3, 4, 5], tag + " final three frames play at destination")
	check(protected, tag + " other attacks do not overwrite the jump")
	check(player.global_position.is_equal_approx(destination) and not player.is_mobility_moving(), tag + " releases movement at destination")
	check(target.current_hp < 10000, tag + " native attack still deals damage")
	check(player.action_animator.action.is_empty(), tag + " animation finishes without a stuck apex")
	if weapon.is_star_tome():
		check(weapon.is_return_ready() == not automatic, tag + " return availability follows cast mode")
	else:
		check(get_tree().get_nodes_in_group("mobility_weapon_runtimes").is_empty(), tag + " runtime cleans up")

func _test_return() -> void:
	await reset()
	var tome := loadout.get_weapon_instance(IDS[2])
	var target := enemy(Vector2(180, 0))
	await frames()
	var runtime := cast(IDS[2])
	await step(60)
	var hp := target.current_hp
	var cooldown := float(loadout.active_casting.state_for(tome).remaining)
	check(loadout.cast_weapon(tome, Vector2.ZERO), "return accepted after landing")
	await step(20)
	check(player.global_position == Vector2(170, 0) and player.action_animator.current_frame == 2, "return takes off before teleporting")
	await capture("star_return_takeoff")
	await step(3)
	check(player.global_position == Vector2.ZERO and player.action_animator.current_frame == 3, "return teleports at apex")
	await capture("star_return_apex")
	await step(17)
	check(player.action_animator.current_frame == 5, "return displays landing frame")
	await capture("star_return_landing")
	await step(20)
	check(target.current_hp == hp and not tome.is_return_ready(), "return adds no damage and consumes mark")
	check(is_equal_approx(float(loadout.active_casting.state_for(tome).remaining), cooldown - 1.0), "return preserves original cooldown")
	await reset()
	runtime = cast(IDS[2])
	await step(60)
	check(loadout.cast_weapon(tome, Vector2.ZERO), "return starts before a new obstacle appears")
	await step(10)
	wall(Vector2(85, 0))
	await frames()
	await step(50)
	check(player.global_position == Vector2(170, 0) and tome.is_return_ready(), "obstacle during takeoff keeps position and return mark")
	check(not player.is_mobility_moving() and player.action_animator.action.is_empty(), "blocked return finishes landing")
	await reset()
	var original_cooldown := tome.active_cooldown_ms
	tome.active_cooldown_ms = 150
	cast(IDS[2])
	await step(60)
	check(player.global_position == Vector2(170, 0) and not tome.is_return_ready(), "cooldown expiry during takeoff does not abort blink or restore mark")
	check(loadout.active_casting.can_cast(tome), "short cooldown becomes ready after landing")
	tome.active_cooldown_ms = original_cooldown

func _test_cleanup() -> void:
	for id in IDS:
		for interruption_frame in [10, 25, 40]:
			await reset()
			cast(id)
			await step(interruption_frame)
			var position := player.global_position
			var frame := player.action_animator.current_frame
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			await step(10)
			check(player.global_position == position and player.action_animator.current_frame == frame, id + " pause freezes phase " + str(interruption_frame))
			GameGlobal.set_runtime_flag("battle_runtime_paused", false)
			loadout._clear_weapon_runtime(loadout.get_weapon_instance(id))
			await step()
			check(not player.is_mobility_moving() and player.action_animator.action.is_empty(), id + " unequip clears jump " + str(interruption_frame))
		await reset()
		cast(id)
		await step(10)
		player.alive = false
		await step()
		check(not player.is_mobility_moving() and player.action_animator.action.is_empty(), id + " death clears jump")
	await reset()
	wall(Vector2(85, 0))
	await frames()
	cast(IDS[0])
	await step(70)
	check(player.global_position.x > 0 and player.global_position.x < 85 and not player.is_mobility_moving(), "dash lands before terrain and releases lock")

func _run() -> void:
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"countdown":0, "hud":false, "relics":[], "weapons":[{"id":IDS[0],"level":1,"attachments":[]},{"id":IDS[1],"level":1,"attachments":[]},{"id":IDS[2],"level":1,"attachments":[]}]}, true)
	var error := await session.prepare(config)
	check(error.is_empty() and session.begin(), "production battle prepared")
	if not error.is_empty(): get_tree().quit(1); return
	battle = session.battle
	player = battle.player
	loadout = battle.loadout
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.set_process(false)
	loadout.set_process(false)
	player.set_physics_process(false)
	player.relic_system.clear()
	player.modifier_stack.clear()
	player.modifier_stack.set_base_stats({"max_hp":1000,"move_speed":150,"load_capacity":1000,"crit_damage":150})
	for weapon in loadout.weapon_instances: weapon.runtime_stats.crit_chance = 0
	AudioServer.set_bus_mute(0, true)
	await frames(12)
	for id in IDS: await _test_jump(id)
	await _test_jump(IDS[2], true)
	await _test_return()
	await _test_cleanup()
	await reset()
	await session.dispose()
	session.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("MOBILITY_JUMP_TIMING checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
