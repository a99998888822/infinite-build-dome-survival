extends Node
## Compare a damaged wolf with an untouched wolf through the same animation poses.
const WOLF = preload("res://scenes/enemy/underworld_wolf.tscn")
const SETTINGS = preload("res://scripts/effects/combat_feedback_settings.gd")
var checks := 0
var failures := 0
var host: Node2D
var baseline: UnderworldWolf
var candidate: UnderworldWolf
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
	check(candidate._hit_visual != null and not candidate._hit_visual.flash_white and candidate.sprite.offset.length() > 0, "small boss shakes without flashing white")

func pose_matches(label: String) -> void:
	candidate._hit_visual._sync()
	var error := candidate.sprite.position.distance_to(baseline.sprite.position)
	max_error = maxf(max_error, error)
	check(error <= 0.001, "%s: no hit offset (actual %.3f)" % [label, error])
	check(candidate.sprite.texture == baseline.sprite.texture and candidate.sprite.scale == baseline.sprite.scale, label + ": animation frame and fit remain intact")
	var displacement := candidate.sprite.global_transform.basis_xform(candidate._hit_visual.applied_offset)
	check(displacement.is_equal_approx(Vector2(5, -2)), label + ": reduced shake keeps its world amplitude across poses/scales")

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.clear_runtime_flag(SETTINGS.FLAG)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	host = Node2D.new()
	add_child(host)
	baseline = make_wolf()
	candidate = make_wolf()
	pose(&"idle", 0)
	# Current authored wolf uses BASE_BODY_SCALE=1.5 (the old fixture used 2.0).
	check(baseline.sprite.scale.is_equal_approx(Vector2.ONE*1.2288), "base wolf enlargement survives an animation update")
	var body := baseline.get_node("CollisionShape2D") as CollisionShape2D
	pose(&"idle", 0, 0, false, 1.5)
	check(baseline.sprite.scale.is_equal_approx(Vector2.ONE*1.8432) and is_equal_approx(body.shape.height*body.scale.y,136.8), "challenge modifier scales the enlarged art and collider together")
	check(baseline.mouth_position().is_equal_approx(baseline.global_position+Vector2(108,-121.5)), "breath socket follows base and challenge enlargement")
	pose(&"idle", 0)
	check(body.position.is_equal_approx(Vector2(9.6,-45.6)) and body.scale.is_equal_approx(Vector2.ONE), "restoring challenge scale retains the new base collider")
	# Damage in midair must not leave an old origin for a later ground pose.
	pose(&"leap", 0.21, 66)
	hit()
	pose(&"idle", 0)
	hit()
	pose_matches("ground hit after first midair hit")
	check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), "damage keeps the current ground pose")
	# Element reactions must also leave the current animated pose unchanged.
	pose(&"breath", 0, 0, true)
	hit(&"heavy")
	candidate.take_damage(3, "element_reaction")
	check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), "reaction retains current mirrored pose")
	# Old feedback categories must never override frame, facing or body scale.
	for kind: StringName in [&"light", &"heavy", &"ritual", &"sustain"]:
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
			hit(kind)
			pose_matches(str(kind) + " after another hit")
		check(candidate.sprite.position.is_equal_approx(baseline.sprite.position), str(kind) + " retains latest pose")
	# Later damage also respects pose changes made while no damage was arriving.
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
