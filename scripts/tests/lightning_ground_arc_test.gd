extends Node2D
const LIGHTNING = preload("res://scripts/effects/lightning_particle_effect.gd")
const WORLD = preload("res://scripts/effects/particle_world.gd")
const ENEMY = preload("res://scenes/enemy/mutated_grub.tscn")
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
	# Ground accents remain owned, pause with the bolt, and use no extra RNG.
	var decorated = fixture()
	var first = decorated._path_pulses[0].bolt
	var first_fork = first.forks[0]
	var core = first.impact
	check(first.forks.size() == 2 and first.cell_size == 2, "initial ground flash has two thin forks")
	check(core.z_index == CombatRenderWorld.IMPACT_Z and not core.z_as_relative, "small impact core stays above actors")
	decorated._process(0.06)
	var fork_alpha: float = first_fork.modulate.a
	check(fork_alpha > 0.0 and fork_alpha < 1.0, "forks fade before main path")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	decorated._process(1.0)
	check(is_equal_approx(first_fork.modulate.a, fork_alpha), "pause freezes fork accents")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	decorated._process(0.06)
	check(is_zero_approx(first_fork.modulate.a) and is_zero_approx(core.modulate.a), "accents end before initial main flash")
	decorated._process(0.09)
	var echo = decorated._path_pulses[0].bolt
	check(echo.forks.size() == 1 and echo.cell_size == 1 and echo.impact == null, "echo is thinner with one fork and no impact core")
	var echo_fork = echo.forks[0]
	decorated.free()
	check(not is_instance_valid(first_fork) and not is_instance_valid(core) and not is_instance_valid(echo_fork), "controller cleanup owns every accent")
	var random_results: Array[int] = []
	for ground in [false, true]:
		var rng_fixture := LIGHTNING.new()
		add_child(rng_fixture)
		rng_fixture._is_ground_strike = ground
		seed(10242026)
		var path := rng_fixture._create_bolt_path(Vector2.ZERO, Vector2(0, 182))
		rng_fixture._create_bolt_path(Vector2.ZERO, Vector2(0, 182), path.points)
		random_results.append(randi())
		rng_fixture.free()
	check(random_results[0] == random_results[1], "ground-only decoration consumes no additional gameplay RNG")
	# The ground arc was removed; the main bolt must retain its timing and damage.
	# Exercise the real controller with wall-clock deltas around every boundary.
	var samples := [0.0, 0.07999, 0.08001, 0.15999, 0.16001, 0.19999, 0.20001, 0.27999, 0.28001, 0.35999]
	var alphas := [1.0, 1.0, 0.6, 0.6, 0.0, 0.0, 0.42, 0.42, 0.252, 0.252]
	for multiplier in [0.1, 0.5, 1.0, 2.0, 4.0]:
		var strike = fixture(multiplier)
		var pulse: Dictionary = strike._path_pulses[0]
		var lifetime_scale := clampf(multiplier, 0.5, 2.0)
		check(is_equal_approx(pulse.scale, lifetime_scale), "lifetime scale follows main bolt clamp")
		check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").is_empty(), "ground strike creates no ground arc")
		var previous := 0.0
		for index in samples.size():
			var age: float = samples[index]
			strike._process((age - previous) * lifetime_scale)
			previous = age
			check(is_equal_approx(pulse.age, age), "shared normalized clock")
			check(is_equal_approx(pulse.bolt.modulate.a, alphas[index]), "main bolt brightness boundary")
			check(pulse.echoed == (age >= 0.20), "main bolt still switches to echo")
			check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").is_empty(), "echo creates no ground arc")
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			strike._process(1.0)
			check(is_equal_approx(pulse.age, age) and is_equal_approx(pulse.bolt.modulate.a, alphas[index]), "pause freezes the main bolt")
			GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		var bolt = pulse.bolt
		strike._process(0.00002 * lifetime_scale)
		check(strike._path_pulses.is_empty() and bolt.is_queued_for_deletion(), "main bolt ends on scaled lifetime")
		strike.free()
	# A dropped frame may cross the gap, shape switch, or entire lifetime.
	var skipped = fixture()
	skipped._process(0.31)
	var skipped_bolt = skipped._path_pulses[0].bolt
	check(skipped._path_pulses[0].echoed and is_equal_approx(skipped_bolt.modulate.a, 0.252), "large delta catches up to echo")
	skipped._process(1.0)
	check(skipped_bolt.is_queued_for_deletion(), "large delta ends the bolt")
	skipped.free()
	var early = fixture()
	var owned_bolt = early._path_pulses[0].bolt
	early.free()
	check(not is_instance_valid(owned_bolt), "early controller removal leaves no orphan bolt")
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
	check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").is_empty(), "chain hits still create no ground arc")
	var weapon := WeaponInstance.new()
	check(weapon.initialize("weapon_void_blade", null), "fixture weapon")
	var event := DamageEvent.create({"damage":20,"original_damage":20,"source_weapon_id":weapon.weapon_id})
	var enemy := ENEMY.instantiate() as EnemyController
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(121.2,101.4)
	enemy.current_hp = 1000
	var real_strike := LIGHTNING.spawn_ground_strike(self, Vector2(121.2,101.4), weapon, event)
	EffectScheduler.cancel_owner(real_strike)
	real_strike.set_process(false)
	var landings := [0]
	real_strike.ground_strike_landed.connect(func(): landings[0] += 1)
	real_strike._strike_ground(Vector2(121.2,101.4))
	check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").is_empty(), "real landing creates no ground arc")
	check(real_strike._path_pulses.size() == 1 and real_strike._ground_strike_impact_age == 0.0, "main bolt and impact ring still start")
	check(landings[0] == 1 and enemy.current_hp < 1000, "landing signal and damage still occur")
	var hp_after := enemy.current_hp
	check(world.get_active_particle_count() == 900, "landing works with a full particle pool")
	real_strike._strike_ground(Vector2(121.2,101.4))
	check(enemy.current_hp == hp_after, "duplicate landing cannot deal damage twice")
	real_strike._process(0.21)
	check(enemy.current_hp == hp_after and real_strike._path_pulses[0].echoed, "echo stays visual only")
	check(get_tree().get_nodes_in_group("lightning_ground_arc_bursts").is_empty(), "real echo creates no ground arc")
	real_strike.free()
	enemy.free()
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
