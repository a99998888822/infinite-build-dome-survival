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
	check(animator.enabled, "seven action strips enabled")
	for clip in {"idle":1,"move":8,"attack":7,"sustain":8,"move_sustain":8,"jump_forward":8,"jump_backward":10}:
		var count: int = animator._count(clip)
		check((animator._clips[clip].texture as Texture2D).get_width() == count * 128, "128px cells: " + clip)
	var origin := player.position
	player.play_weapon_action("weapon_void_blade")
	animator.tick(0.15, false)
	check(animator.current_clip == "attack" and animator.current_frame > 0, "attack advances")
	player.play_mobility_action("weapon_dash_blade", Vector2.RIGHT * 100)
	check(animator.current_clip == "jump_forward" and animator.current_frame == 0, "new jump interrupts attack")
	player.play_weapon_action("weapon_plasma_cannon")
	check(animator.current_clip == "attack" and animator.current_frame == 0, "new attack interrupts jump")
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
	player.initialize_from_character("character_void_hunter")
	check(animator.enabled and animator.current_clip == "idle" and animator._sustains.is_empty(), "new run resets novice state")
	source.free()
	print("PLAYER_ACTION_TEST_COMPLETE checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
