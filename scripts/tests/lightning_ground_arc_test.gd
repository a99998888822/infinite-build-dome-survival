extends Node2D
const ARC = preload("res://scripts/effects/lightning_ground_arc_burst.gd")
const LIGHTNING = preload("res://scripts/effects/lightning_particle_effect.gd")
const WORLD = preload("res://scripts/effects/particle_world.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func fixture(multiplier: float = 1.0) -> Node2D:
	var strike := LIGHTNING.new()
	add_child(strike)
	strike.set_process(false)
	strike._parent_root = self
	strike._is_ground_strike = true
	strike._resolved_parameters = {"lifetime_multiplier": multiplier, "alpha_multiplier": 0.35}
	strike._emit_bolt(Vector2(121.2, -81), Vector2(121.2, 101.4))
	return strike

func _run() -> void:
	CampProgression.begin_transient_session()
	var image: Image = ARC.ATLAS.get_image()
	check(image.get_size() == Vector2i(1280, 224), "native atlas dimensions")
	var aligned := true
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var color := image.get_pixel(x, y)
			if image.get_pixel(x+1,y) != color or image.get_pixel(x,y+1) != color or image.get_pixel(x+1,y+1) != color:
				aligned = false
	check(aligned, "all PNG texels obey two-pixel grid")
	for variant in 8:
		var first := image.get_region(Rect2i(variant*160,0,160,112)).get_data()
		var second := image.get_region(Rect2i(variant*160,112,160,112)).get_data()
		check(first != second, "two distinct shapes per variant")
	# Exercise the real controller with wall-clock deltas around every boundary.
	var samples := [0.0, 0.07999, 0.08001, 0.15999, 0.16001, 0.19999, 0.20001, 0.27999, 0.28001, 0.35999]
	var alphas := [1.0, 1.0, 0.6, 0.6, 0.0, 0.0, 1.0, 1.0, 0.6, 0.6]
	for multiplier in [0.1, 0.5, 1.0, 2.0, 4.0]:
		var strike = fixture(multiplier)
		var pulse: Dictionary = strike._path_pulses[0]
		var arc = pulse.ground_arc
		var lifetime_scale := clampf(multiplier, 0.5, 2.0)
		check(is_equal_approx(pulse.scale, lifetime_scale), "lifetime scale follows main bolt clamp")
		check(not arc.is_processing(), "ground sprite has no independent clock")
		check(arc.get_parent() == strike, "lightning controller owns the ground sprite")
		check(arc.global_position == Vector2(122,102), "world-space pixel alignment")
		check(arc.scale == Vector2.ONE and arc.rotation == 0.0 and arc.top_level, "fixed native world grid")
		check(not arc.z_as_relative and arc.z_index == 16, "ground layer independent of lightning layer")
		check(is_equal_approx(arc.modulate.a, pulse.bolt.base_alpha), "base opacity multiplier matches main bolt")
		var previous := 0.0
		for index in samples.size():
			var age: float = samples[index]
			strike._process((age - previous) * lifetime_scale)
			previous = age
			check(is_equal_approx(pulse.age, age), "shared normalized clock")
			check(is_equal_approx(pulse.bolt.modulate.a, alphas[index]), "main bolt brightness boundary")
			check(is_equal_approx(arc.self_modulate.a, pulse.bolt.modulate.a), "ground brightness matches in same update")
			check(arc._phase == (1 if age >= 0.20 else 0), "ground shape switches with echo")
			check(arc._phase == int(pulse.echoed) and arc.frame == arc.variant_index + arc._phase * 8, "texture row follows actual echo state")
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			strike._process(1.0)
			check(is_equal_approx(pulse.age, age) and is_equal_approx(arc.self_modulate.a, alphas[index]), "pause freezes both arcs")
			GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		var bolt = pulse.bolt
		strike._process(0.00002 * lifetime_scale)
		check(strike._path_pulses.is_empty() and bolt.is_queued_for_deletion(), "main bolt ends on scaled lifetime")
		check(arc.is_queued_for_deletion() and not arc.visible, "ground ends in same update")
		strike.free()
	# A dropped frame may cross the gap, shape switch, or entire lifetime.
	var skipped = fixture()
	skipped._process(0.31)
	var skipped_arc = skipped._path_pulses[0].ground_arc
	check(skipped_arc._phase == 1 and is_equal_approx(skipped_arc.self_modulate.a, 0.6), "large delta catches up to second shape")
	skipped._process(1.0)
	check(skipped_arc.is_queued_for_deletion(), "large delta ends both paths")
	skipped.free()
	var early = fixture()
	var owned_arc = early._path_pulses[0].ground_arc
	early.free()
	check(not is_instance_valid(owned_arc), "early controller removal leaves no orphan ground sprite")
	# Keep the ordinary pool full while triggering the real ground-strike path.
	var world := WORLD.new()
	world.name = "ParticleWorld"
	add_child(world)
	world.set_process(false)
	WORLD.emit_profile(self, "explosion_burst", Vector2(-5000,-5000), Vector2.ZERO, 10.0)
	check(world.get_active_particle_count() == 900, "pool full fixture")
	var chain := LIGHTNING.new()
	add_child(chain)
	chain._parent_root = self
	chain._emit_bolt(Vector2(100,100), Vector2(150,100))
	chain._emit_hit_burst(Vector2(120,100), Vector2.RIGHT)
	check(chain._path_pulses[0].ground_arc == null, "chain hits do not add ground arcs")
	var weapon := WeaponInstance.new()
	check(weapon.initialize("weapon_void_blade", null), "fixture weapon")
	var event := DamageEvent.create({"damage":20,"original_damage":20,"source_weapon_id":weapon.weapon_id})
	var real_strike := LIGHTNING.spawn_ground_strike(self, Vector2(121.2,101.4), weapon, event)
	EffectScheduler.cancel_owner(real_strike)
	real_strike.set_process(false)
	real_strike._strike_ground(Vector2(121.2,101.4))
	check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").size() == 1, "one arc sprite per real landing")
	check(world.get_active_particle_count() == 900, "ground arcs bypass full particle pool")
	real_strike._strike_ground(Vector2(121.2,101.4))
	check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").size() == 1, "duplicate landing cannot add extra ground set")
	real_strike.free()
	chain.free()
	world.free()
	for burst in get_tree().get_nodes_in_group("lightning_hit_sprite_bursts"): burst.queue_free()
	AudioManager.stop_combat_sfx()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	weapon = null
	event = null
	for frame in 3: await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	OS.delay_msec(120)
	CampProgression.end_transient_session()
	print("GROUND_ARC_TEST checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
