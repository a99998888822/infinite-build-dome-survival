extends Node2D
## Production bunker and enemy scenes, swept collisions and real chase movement.
const ENEMIES := [preload("res://scenes/enemy/mutated_grub.tscn"),
	preload("res://scenes/enemy/elite_rusher.tscn"), preload("res://scenes/enemy/underworld_wolf.tscn"),
	preload("res://scenes/enemy/echo_bat.tscn")]
const IDS := ["enemy_mutated_grub", "enemy_elite_rusher", "enemy_underworld_wolf", "enemy_echo_bat"]
var checks := 0
var failures := 0
var player: PlayerController
var phase: NightEvacuation


func _ready() -> void:
	WindowSettings._startup_applied = true
	get_tree().root.unfocusable = true
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func run() -> void:
	CampProgression.begin_transient_session()
	player = preload("res://scenes/player/player_root.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(3000, 1200)
	phase = NightEvacuation.new()
	phase.player = player
	phase.bank_anchor = Vector2(1800, 1200)
	phase.ring_center = phase.bank_anchor + Vector2(-10, -10)
	add_child(phase)
	phase.visual = preload("res://scripts/battle/night_evacuation_visual.gd").new()
	phase.add_child(phase.visual)
	phase.visual.initialize(phase)
	# One enemy predates the dynamically created bunker.
	var existing := make_enemy(0)
	phase.visual.begin()
	await get_tree().physics_frame
	check(is_instance_valid(EvacuationBunker.current), "production visual registers the bunker barrier")
	await sweep_checks(existing, "existing grub")
	existing.free()
	for index in ENEMIES.size():
		var enemy := make_enemy(index)
		await sweep_checks(enemy, IDS[index])
		if index == 1:
			enemy.apply_body_scale(1.5)
			await sweep_checks(enemy, "scaled elite")
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			await chase_check(enemy, direction)
		enemy.free()
	await moving_target_check()
	await skill_checks()
	var probe := make_enemy(0)
	probe.global_position = phase.bank_anchor
	check(not phase.placement_clear(phase.bank_anchor, player.global_position), "bunker placement rejects occupied enemy space")
	phase.visual.reset()
	check(not is_instance_valid(EvacuationBunker.current), "reset unregisters the barrier immediately")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start := phase.bank_anchor + Vector2(-700, -50)
	var finish := phase.bank_anchor + Vector2(700, -50)
	probe.global_position = start
	player.global_position = phase.bank_anchor + Vector2(0, 800)
	check(probe.move_and_collide(finish - start) == null, "next wave leaves no invisible bunker collision")
	check(probe._bunker_route.direction(probe, start).is_equal_approx(Vector2.LEFT), "chase returns to a straight route after removal")
	probe.free()
	phase.free()
	player.free()
	CampProgression.end_transient_session()
	print("BUNKER_OBSTACLE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func make_enemy(index: int) -> EnemyController:
	var enemy := ENEMIES[index].instantiate() as EnemyController
	enemy.auto_initialize_on_ready = false
	add_child(enemy)
	enemy.initialize(IDS[index], player)
	enemy.set_physics_process(false)
	return enemy


func sweep_checks(enemy: EnemyController, label: String) -> void:
	var center := phase.bank_anchor + EvacuationBunker.FOOTPRINT.get_center()
	player.global_position = center + Vector2(1500, 1500)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		enemy.global_position = center - direction * 700
		await get_tree().physics_frame
		var hit := enemy.move_and_collide(direction * 1400)
		# Bats also detect the original stone walls, which share the outer edges.
		check(hit != null and hit.get_collider().get_parent() == phase.visual.building,
			"swept movement blocked: %s %s" % [label, direction])
		enemy.velocity = Vector2.ZERO


func chase_check(enemy: EnemyController, direction: Vector2) -> void:
	var center := phase.bank_anchor + EvacuationBunker.FOOTPRINT.get_center()
	enemy.global_position = center - direction * 650
	enemy.velocity = Vector2.ZERO
	player.global_position = center + direction * 650
	var shape := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var wall := EvacuationBunker.current.get_child(0) as CollisionShape2D
	var penetrated := false
	var reached := false
	for frame in 2000:
		await get_tree().physics_frame
		# Exercise each concrete movement implementation, without attack windups.
		if enemy is EchoBat: enemy._step_delta = 1.0 / 60.0
		enemy._process_chase()
		if shape.shape.collide(shape.global_transform, wall.shape, wall.global_transform): penetrated = true
		var remaining := enemy.global_position.distance_to(player.global_position)
		if remaining < (290.0 if enemy is EchoBat else 90.0):
			reached = true
			break
	check(reached and not penetrated, "chase routes around bunker without penetration: %s %s" % [enemy.enemy_id, direction])
	if not reached: print("  stuck at ", enemy.global_position - center, " remaining=", enemy.global_position.distance_to(player.global_position))


func moving_target_check() -> void:
	var enemy := make_enemy(0)
	var center := phase.bank_anchor + EvacuationBunker.FOOTPRINT.get_center()
	enemy.global_position = center + Vector2(-400, 0)
	var first := enemy._bunker_route.direction(enemy, center + Vector2(400, -300))
	var second := enemy._bunker_route.direction(enemy, center + Vector2(400, 300))
	check(first.y < 0 and second.y > 0, "moving target replans the detour to the other side")
	enemy.free()


func skill_checks() -> void:
	var center := phase.bank_anchor + EvacuationBunker.FOOTPRINT.get_center()
	player.global_position = center + Vector2(0, 300)
	var knight := make_enemy(1) as EliteRusher
	knight.global_position = center + Vector2(0, -200)
	knight.skill_state = "dash"
	knight._origin = knight.global_position
	knight._direction = Vector2.DOWN
	knight._state_time = 0
	await get_tree().physics_frame
	knight._process_special_behavior(0.16)
	check(knight._dash_blocked and knight.global_position.y < center.y, "elite dash stops at the bunker")
	knight.free()
	var wolf := make_enemy(2) as UnderworldWolf
	wolf.global_position = center + Vector2(0, -200)
	wolf.leap_origin = wolf.global_position
	wolf.locked_point = center + Vector2(0, 300)
	wolf.state = "leap"
	wolf.state_time = 0
	await get_tree().physics_frame
	wolf._process_special_behavior(float(wolf.profile.leap_seconds))
	check(wolf.global_position.y < center.y, "wolf leap cannot cross the bunker")
	wolf.free()
