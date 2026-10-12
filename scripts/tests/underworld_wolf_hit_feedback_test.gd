extends Node
## Compare a damaged wolf with an untouched wolf through the same animation poses.
const WOLF = preload("res://scenes/enemy/underworld_wolf.tscn")
const RESPONSE = preload("res://scripts/effects/combat_feedback_r02.gd")
var checks := 0
var failures := 0
var host: Node2D
var baseline: UnderworldWolf
var candidate: UnderworldWolf
var response: Node
var max_error := 0.0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func make_wolf() -> UnderworldWolf:
	var result := WOLF.instantiate() as UnderworldWolf
	result.auto_initialize_on_ready = false
	host.add_child(result)
	check(result.initialize("enemy_underworld_wolf"), "production wolf initialized")
	result.current_hp = 100000
	result.set_physics_process(false)
	return result

func pose(action: StringName, time: float, height: float = 0, flipped: bool = false, body_scale: float = 1.0) -> void:
	for wolf in [baseline, candidate]:
		wolf.state = "leap" if height > 0 else "chase"
		wolf.animation = action
		wolf.animation_time = time
		wolf.air_height = height
		wolf.sprite.flip_h = flipped
		wolf.apply_body_scale(body_scale)
		wolf.animate(0)

func hit(kind: StringName = &"light") -> void:
	candidate.take_damage_with_feedback(5, "wolf_pose_regression", false, Vector2.RIGHT, kind)
	response = candidate.get_meta(RESPONSE.META)
	response.set_physics_process(false)

func pose_matches(label: String) -> void:
	var error := candidate.sprite.position.distance_to(baseline.sprite.position)
	max_error = maxf(max_error, error)
	check(error <= 4.01, "%s: only the authored 0-4px hit offset (actual %.3f)" % [label, error])
	check(candidate.sprite.texture == baseline.sprite.texture and candidate.sprite.scale == baseline.sprite.scale, label + ": animation frame and fit remain intact")

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	host = Node2D.new()
	add_child(host)
	baseline = make_wolf()
	candidate = make_wolf()
	# Reproduce the reported intermittent hop: first feedback is cached in midair.
	pose(&"leap", 0.21, 66)
	hit()
	response._physics_process(0.3)
	pose(&"idle", 0)
	hit()
	pose_matches("ground hit after first midair hit")
	response._physics_process(0.3)
	check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), "response ends at current ground pose, not old airborne origin")
	# A reaction with no native feedback category interrupts the response too.
	pose(&"breath", 0, 0, true)
	hit(&"heavy")
	candidate.take_damage(3, "element_reaction")
	check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), "legacy reaction restores current mirrored pose")
	# Every response kind must follow frame registration, facing and body scale.
	for kind: StringName in [&"light", &"heavy", &"ritual", &"sustain"]:
		response._physics_process(0.5)
		pose(&"idle", 0)
		hit(kind)
		for sample in [
			[&"move", 0.32, 0.0, true, 1.0],
			[&"leap_charge", 0.6, 0.0, false, 1.0],
			[&"leap", 0.24, 53.0, true, 1.5],
			[&"land", 0.0, 0.0, true, 1.5],
			[&"idle", 0.0, 0.0, false, 1.0],
		]:
			pose(sample[0], sample[1], sample[2], sample[3], sample[4])
			pose_matches(str(kind) + " after animation update")
			response._physics_process(0.01)
			pose_matches(str(kind) + " after feedback update")
		response._physics_process(0.5)
		check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), str(kind) + " finishes at latest pose")
	# Completed feedback must also forget its old anchor before a later hit.
	pose(&"leap", 0.2, 60)
	pose(&"move", 0.4, 0, true)
	hit(&"heavy")
	pose_matches("later hit after inactive pose changes")
	check(candidate.global_position == baseline.global_position, "visual feedback never teleports the collision body")
	candidate.take_damage(200000, "lethal")
	check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), "death fade keeps the final animated pose")
	print("WOLF_HIT_FEEDBACK checks=%d failures=%d max_visual_offset=%.3f" % [checks, failures, max_error])
	host.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)
