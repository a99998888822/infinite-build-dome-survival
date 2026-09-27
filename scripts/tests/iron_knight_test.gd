extends Node2D

var checks := 0
var failures := 0
var player: PlayerController
var knight: EliteRusher


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func reset_knight() -> void:
	knight.initialize("enemy_elite_rusher", player)
	knight.position = Vector2.ZERO
	knight._process_special_behavior(0.75)
	knight._cooldown = 0.0
	player.position = Vector2(200, 0)
	player.current_hp = 1000
	player._invincibility_timer = 0.0


func _run() -> void:
	check(DataRegistry.get_load_errors().is_empty(), "project configuration validates")
	player = load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	# Preserve the actual capsule for hit tests without blocking a full sweep.
	player.collision_layer = 0
	knight = load("res://scenes/enemy/elite_rusher.tscn").instantiate() as EliteRusher
	add_child(knight)
	knight.set_physics_process(false)
	await get_tree().physics_frame
	reset_knight()
	var expected := {&"idle": 4, &"move": 8, &"windup": 4, &"dash": 6, &"recover": 4, &"death": 6}
	for action in expected:
		check(EliteRusher.FRAMES.get_frame_count(action) == expected[action], "approved frame count: " + str(action))
		check(EliteRusher.FRAMES.get_frame_texture(action, 0).get_size() == Vector2(160, 160), "native resolution: " + str(action))
	check((knight.sprite.position + Vector2(0, 42) * knight.sprite.scale).is_zero_approx(), "fixed foot anchor aligns with world origin")
	player.position = Vector2(600, 0)
	check(not knight.start_dash(), "far target cannot manually trigger dash")
	check(not knight._process_special_behavior(0.1), "expired cooldown outside range yields to chase")
	knight._physics_process(1.0 / 60.0)
	check(knight.position.x > 0.0 and knight.skill_state == "chase", "out-of-range knight actually keeps approaching")
	knight.position = Vector2.ZERO
	player.position = Vector2(240.01, 0)
	check(not knight.start_dash(), "target just beyond configured distance rejected")
	player.position = Vector2(240, 0)
	check(knight.start_dash(), "exact distance boundary accepted")
	var direction := knight._direction
	player.position = Vector2(0, 400)
	knight._process_special_behavior(0.4)
	check(not knight.start_dash() and knight._state_time == 0.4, "active windup cannot restart")
	check(knight._direction == direction, "sidestep never retargets the telegraph")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	knight._physics_process(1.0)
	check(knight._state_time == 0.4, "pause freezes windup clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	knight._process_special_behavior(0.4)
	check(knight.skill_state == "dash", "800ms warning precedes dash")
	knight._process_special_behavior(0.08)
	knight._animate(0.0)
	check(knight.position.distance_to(Vector2(120, 0)) < 0.01, "half dash travels 120 units in 80ms")
	check(knight.sprite.texture == EliteRusher.FRAMES.get_frame_texture(&"dash", 3), "hammer synchronized at half dash")
	knight._process_special_behavior(0.08)
	check(knight.skill_state == "recover" and knight.position.distance_to(Vector2(240, 0)) < 0.01, "full dash completes in 160ms")
	check(player.current_hp == 1000, "sidestepping outside warning avoids damage")
	knight._process_special_behavior(0.5)
	player.position = knight.position + Vector2(100, 0)
	check(not knight.start_dash() and is_equal_approx(knight._cooldown, 6.0), "recovery retains six-second cooldown")
	# A single low-frame-rate step must hit the swept target, not just the endpoint.
	for offset in [Vector2(120, 0), Vector2(120, 39), Vector2(120, 41)]:
		reset_knight()
		knight.start_dash()
		player.position = offset
		knight._process_special_behavior(0.8)
		knight._process_special_behavior(0.16)
		var should_hit: bool = offset.y < 40.0
		check((player.current_hp < 1000) == should_hit, "swept capsule boundary y=%s" % offset.y)
		var health := player.current_hp
		player._invincibility_timer = 0.0
		knight._try_dash_damage(0.0, 240.0)
		check(player.current_hp == health, "one damage attempt per dash y=%s" % offset.y)
	reset_knight()
	knight._profile = knight._profile.duplicate(true)
	knight._profile["dash_distance"] = 100
	player.position = Vector2(101, 0)
	check(not knight.start_dash(), "range gate reads configuration rather than hardcoding 240")
	player.position = Vector2(100, 0)
	check(knight.start_dash(), "custom range boundary accepted")
	reset_knight()
	knight.start_dash()
	knight.apply_freeze(1.0)
	knight._physics_process(0.01)
	check(knight.skill_state == "windup" and knight._state_time == 0.0, "resisted freeze pauses skill and animation together")
	knight._frozen_remaining = 0.0
	knight._profile["dash_ms"] = 320
	knight._process_special_behavior(0.8)
	knight._process_special_behavior(0.16)
	knight._animate(0.0)
	check(knight.sprite.texture == EliteRusher.FRAMES.get_frame_texture(&"dash", 3), "configured duration rescales the entire swing")
	# Walls stop movement while the final swing frames still play.
	reset_knight()
	var wall := StaticBody2D.new()
	wall.position = Vector2(80, 0)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 180)
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	await get_tree().physics_frame
	knight.start_dash()
	knight._process_special_behavior(0.8)
	knight._process_special_behavior(0.04)
	var stopped := knight.position
	check(knight._dash_blocked and knight.skill_state == "dash" and stopped.x < 60, "wall blocks travel while swing continues")
	knight._process_special_behavior(0.08)
	check(knight.position == stopped and knight.skill_state == "dash", "blocked knight remains still during remaining swing")
	knight._process_special_behavior(0.04)
	check(knight.skill_state == "recover" and player.current_hp == 1000, "blocked swing ends on time without hitting through wall")
	wall.free()
	knight.free()
	player.free()
	await get_tree().process_frame
	print("IRON_KNIGHT_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
