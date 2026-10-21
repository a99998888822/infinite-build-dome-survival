extends Node

class SustainFixture extends Node:
	var cancelled := false
	var active := true
	func is_attacking() -> bool:
		return active

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var player := load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	add_child(player)
	player.set_physics_process(false)
	check(player.initialize_from_character("character_void_hunter"), "novice initialized")
	var animator := player.action_animator
	check(animator.enabled, "eight action strips enabled")
	check(player.sprite.scale == Vector2.ONE, "96px actions render at their authored pixel size")
	var expected_counts := {"idle":1,"move":8,"attack":7,"move_attack":9,"sustain":8,"move_sustain":8,"jump_forward":6,"jump_backward":6}
	for clip in expected_counts:
		var count: int = animator._count(clip)
		check(count == expected_counts[clip] and (animator._clips[clip].texture as Texture2D).get_size() == Vector2(count * 96, 96), "approved frame count and 96px cells: " + clip)
	check(animator._count("jump_forward") == 6 and animator._clips.jump_forward.texture == preload("res://assets/sprites/player/actions/novice_96/jump.png"), "forward jump uses six approved scene-preview frames")
	check(animator._clips.jump_forward.texture == animator._clips.jump_backward.texture, "forward and backward jump share one atlas")
	var origin := player.position
	player.play_weapon_action("weapon_void_blade")
	animator.tick(0.15, false)
	check(animator.current_clip == "attack" and animator.current_frame > 0, "attack advances")
	player.play_mobility_action("weapon_dash_blade", Vector2.RIGHT * 100)
	check(animator.current_clip == "jump_forward" and animator.current_frame == 0, "new jump interrupts attack")
	player.play_weapon_action("weapon_plasma_cannon")
	check(animator.current_clip == "attack" and animator.current_frame == 0, "new attack interrupts jump")
	check(player.sprite.position == Vector2(0, -3), "attack interruption preserves the shared foot alignment")
	animator.tick(0.2, false)
	player.play_weapon_action("weapon_void_blade")
	check(animator.current_frame == 0, "same action restarts on latest cast")
	var source := SustainFixture.new()
	add_child(source)
	player.play_weapon_action("weapon_kunyu_ritual_tome", source)
	check(animator.current_clip == "sustain", "sustain interrupts attack")
	animator.tick(0.45, false)
	check(animator.action == "sustain_hold", "raise enters hold")
	animator.tick(0.05, true)
	check(animator.current_clip == "move_sustain", "walking selects moving hold")
	animator.tick(0.05, false)
	check(animator.current_clip == "sustain" and animator.current_frame in [4,5], "stopping returns to hold without windup")
	player.play_weapon_action("weapon_void_blade")
	animator.tick(0.51, true)
	check(animator.current_clip == "move_sustain", "live sustain resumes after interruption")
	player.play_weapon_action("weapon_void_blade")
	source.active = false
	animator.tick(0.51, false)
	check(animator.current_clip == "idle", "expired sustain does not resume")
	source.active = true
	animator.start_sustain(source)
	animator.tick(0.5, false)
	source.cancelled = true
	animator.tick(0.01, false)
	check(animator.current_clip == "sustain" and animator.current_frame == 6, "cancel lowers hand")
	animator.tick(0.11, false)
	check(animator.current_frame == 7, "last lowering frame displayed")
	animator.tick(0.11, false)
	check(animator.current_clip == "idle", "lowering returns idle")
	source.cancelled = false
	animator.start_sustain(source)
	var other := SustainFixture.new()
	add_child(other)
	animator.start_sustain(other)
	source.cancelled = true
	animator.play("attack")
	animator.tick(0.51, false)
	check(animator.action == "sustain_hold", "second live sustain survives first cancellation")
	other.free()
	animator.tick(0.25, false)
	animator.tick(0.25, false)
	check(animator.current_clip == "idle", "freed sustain source cleans up")
	for right in [true, false]:
		player._set_facing(right)
		var forward := Vector2.RIGHT if right else Vector2.LEFT
		player.play_mobility_action("weapon_star_tome", forward * 100)
		check(animator.current_clip == "jump_forward", "teleport toward facing: " + str(right))
		player.play_mobility_action("weapon_star_tome", -forward * 100)
		check(animator.current_clip == "jump_backward", "return opposite facing: " + str(right))
		player.play_mobility_action("weapon_hand_cannon", -forward * 100)
		check(animator.current_clip == "jump_backward", "cannon recoil: " + str(right))
	check(player.position == origin, "visual action requests never move player")
	_test_facing(player)
	_test_new_actions(player)
	animator.play("attack")
	animator.tick(0.15, false)
	var before := animator.current_frame
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	player._physics_process(1.0)
	check(animator.current_frame == before and animator.current_clip == "attack", "pause freezes action")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	player.alive = false
	player._physics_process(0.1)
	check(animator.current_clip == "idle" and animator._sustains.is_empty(), "death clears actions")
	player.initialize_from_character("character_capitalist")
	check(not animator.enabled and player.sprite.hframes == 1 and player.sprite.scale == Vector2.ONE, "other character retains original visuals")
	check(player.sprite.material == null, "character switching removes the beginner sampling material")
	player._set_facing(true)
	player.begin_mobility_motion(source, player.global_position + Vector2.LEFT * 40, 0.2)
	player._process_movement(0.1)
	check(player.facing_right, "other character keeps its original facing during recoil")
	player.cancel_mobility_motion(source)
	player.initialize_from_character("character_void_hunter")
	check(animator.enabled and animator.current_clip == "idle" and animator._sustains.is_empty(), "new run resets novice state")
	check(player.sprite.scale == Vector2.ONE, "returning to beginner restores native pixel scale")
	source.free()
	print("PLAYER_ACTION_TEST_COMPLETE checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_facing(player: PlayerController) -> void:
	var animator := player.action_animator
	var loadout := WeaponLoadout.new()
	add_child(loadout)
	loadout.set_process(false)
	loadout.set_physics_process(false)
	loadout.initialize(player)
	loadout.set_active_combat_enabled(true)
	var bow := loadout.get_weapon_instance("weapon_void_blade")
	for right in [true, false]:
		var aim := Vector2.RIGHT if right else Vector2.LEFT
		player._set_facing(not right)
		player.set_mobile_move_direction(-aim)
		loadout.active_casting.states.clear()
		check(loadout.cast_weapon(bow, player.global_position + aim * 100), "real bow cast behind movement: " + str(right))
		check(player.facing_right == right, "cast immediately faces shot: " + str(right))
		var before := player.position
		player._process_movement(0.1)
		check(player.facing_right == right and player.visual_anchor.scale.x * aim.x > 0.0, "moving cannot flip attack art: " + str(right))
		check((player.position - before).dot(-aim) > 0.0 and player.last_move_direction == -aim, "attack facing preserves actual movement: " + str(right))
		player._process_movement(0.41)
		check(animator.current_clip == "move" and player.facing_right != right, "finished attack restores movement facing: " + str(right))
		player._set_facing(right)
		player.play_weapon_action("weapon_void_blade", null, 0.0, Vector2.UP)
		player._process_movement(0.1)
		check(player.facing_right == right, "vertical attack preserves side while moving: " + str(right))
		player.play_weapon_action("weapon_void_blade", null, 0.0, -aim)
		check(player.facing_right != right and animator.current_frame == 0, "new attack replaces locked side: " + str(right))
		player.play_mobility_action("weapon_dash_blade", aim * 100, aim)
		player._process_movement(0.1)
		check(animator.current_clip == "jump_forward" and player.facing_right == right, "dash faces landing despite opposite movement: " + str(right))
		player._set_facing(not right)
		player.play_mobility_action("weapon_hand_cannon", -aim * 100, aim)
		player._process_movement(0.1)
		check(animator.current_clip == "jump_backward" and player.facing_right == right, "recoil faces shot despite opposite movement: " + str(right))
		player.play_mobility_action("weapon_star_tome", -aim * 100)
		player._process_movement(0.1)
		check(animator.current_clip == "jump_backward" and player.facing_right == right, "backward blink keeps departure facing: " + str(right))
	player._clear_move_input()
	animator.reset()
	var lamp := CopperLamp.new()
	lamp.burst_active = true
	lamp.heading = Vector2.LEFT
	lamp.set_physics_process(false)
	add_child(lamp)
	player.play_weapon_action("weapon_copper_lamp", lamp, 0.0, Vector2.LEFT)
	player._update_walk_animation(Vector2.RIGHT, 0.45)
	check(animator.current_clip == "move_sustain" and not player.facing_right, "moving sustain faces active spray")
	lamp.heading = Vector2.RIGHT
	player._update_walk_animation(Vector2.LEFT, 0.01)
	check(player.facing_right, "sustain follows spray turning to other side")
	player.play_weapon_action("weapon_void_blade", null, 0.0, Vector2.LEFT)
	player._update_walk_animation(Vector2.RIGHT, 0.1)
	check(not player.facing_right, "interrupt owns facing over a live sustain")
	player._update_walk_animation(Vector2.LEFT, 0.41)
	check(animator.current_clip == "move_sustain" and player.facing_right, "resumed sustain restores its own direction")
	lamp.burst_active = false
	player._update_walk_animation(Vector2.LEFT, 0.01)
	check(player.facing_right, "sustain lowering keeps its last direction")
	player._update_walk_animation(Vector2.LEFT, 0.21)
	check(animator.current_clip == "move" and not player.facing_right, "ended sustain releases facing")
	lamp.free()
	animator.reset()
	check(animator.facing_direction.is_zero_approx(), "reset clears action facing")
	for weapon in loadout.weapon_instances:
		loadout._clear_weapon_runtime(weapon)
	loadout.free()


func _test_new_actions(player: PlayerController) -> void:
	var animator := player.action_animator
	for right in [true, false]:
		var aim := Vector2.RIGHT if right else Vector2.LEFT
		player.set_mobile_move_direction(aim)
		player.play_weapon_action("weapon_void_blade", null, 0.0, aim)
		check(animator.current_clip == "move_attack" and animator.current_frame == 0, "advancing punch starts new strip: " + str(right))
		player.set_mobile_move_direction(-aim)
		player._process_movement(0.4)
		check(animator.current_clip == "move_attack" and player.facing_right == right, "direction lock survives changed movement: " + str(right))
		player._process_movement(0.34)
		check(animator.current_frame == 8, "single moving punch reaches recovery at source speed")
		player._process_movement(0.02)
		check(animator.current_clip == "move" and player.facing_right != right, "moving punch returns to current movement")
		player.play_weapon_action("weapon_void_blade", null, 0.0, aim)
		check(animator.current_clip == "attack", "retreat uses planted punch without false forward steps")
	player._clear_move_input()
	for clip in ["jump_forward", "jump_backward"]:
		for index in 6:
			animator.play(clip, Vector2.RIGHT)
			animator.tick(index * 0.12 + 0.06, false)
			check(animator.current_clip == clip and animator.current_frame == index, clip + " shows approved frame " + str(index))
			check(player.sprite.position == Vector2(0, -3), clip + " keeps the preview foot alignment without accumulating offset")
		animator.play(clip, Vector2.RIGHT)
		animator.tick(0.719, false)
		check(animator.current_clip == clip and animator.current_frame == 5, clip + " displays final landing frame")
		animator.tick(0.002, false)
		check(animator.current_clip == "idle" and player.sprite.position == Vector2(0, -3), clip + " returns to aligned idle after 0.72 seconds")
		animator.play(clip, Vector2.LEFT)
		animator.tick(0.721, true)
		check(animator.current_clip == "move" and player.sprite.position == Vector2(0, -3), clip + " returns to aligned movement")
	animator.reset()
