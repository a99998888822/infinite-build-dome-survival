extends Node2D

const BUDGET = preload("res://scripts/effects/thunder_fire_visual_budget.gd")
const WORLD = preload("res://scripts/effects/particle_world.gd")
class ProbeExplosion extends ExplosionEffect:
	static var damage_calls := 0
	static var terrain_calls := 0
	static var total_damage := 0
	func _damage_enemies(_radius: float, damage: int, _falloff: float) -> void:
		damage_calls += 1
		total_damage += damage
	func _damage_terrain(_radius: float) -> Array[Dictionary]:
		terrain_calls += 1
		return []

var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func _run() -> void:
	CampProgression.begin_transient_session()
	_test_local_density()
	_test_parameters()
	await _test_emission()
	GameGlobal.clear_runtime_flag("thunder_fire_visual_mode")
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("THUNDER_FIRE_LOD_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _test_local_density() -> void:
	var host := Node2D.new()
	add_child(host)
	var budget = BUDGET.for_parent(host)
	check(BUDGET.for_parent(host) == budget, "a battle parent reuses its local budget")
	for i in 4: check(budget.claim(Vector2(95, -1)) == BUDGET.Tier.FULL, "first four contacts retain full detail")
	check(budget.claim(Vector2(97, 1)) == BUDGET.Tier.REDUCED, "adjacent grid cells share nearby density")
	for i in 7: check(budget.claim(Vector2(95, -1)) == BUDGET.Tier.REDUCED, "contacts 5 through 12 halve particles")
	check(budget.claim(Vector2(95, -1)) == BUDGET.Tier.SPARK, "first dense patch gets a small spark")
	check(budget.claim(Vector2(95, -1)) == BUDGET.Tier.SUPPRESSED, "repeated dense patch creates no redundant particles")
	check(budget.claim(Vector2(500, -1)) == BUDGET.Tier.FULL, "distant explosion retains full detail")
	check(budget.claim(Vector2(180, -1)) == BUDGET.Tier.SPARK, "new dense patch retains local contact feedback")
	check(budget.claim(Vector2(270, -1)) == BUDGET.Tier.FULL, "fixed anchors prevent crowd density spreading across the screen")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var before: float = budget._clock
	budget._process(1.0)
	check(budget._clock == before and budget.claim(Vector2(95, -1)) == BUDGET.Tier.SUPPRESSED, "battle pause freezes density expiry")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	get_tree().paused = true
	budget._process(1.0)
	check(budget._clock == before, "scene-tree pause freezes density expiry")
	get_tree().paused = false
	budget._process(0.101)
	check(budget._cells.is_empty() and not budget.is_processing(), "expired regions release storage and stop idle processing")
	check(budget.claim(Vector2(95, -1)) == BUDGET.Tier.FULL, "density recovers after 100 milliseconds of combat time")
	budget.reset()
	for i in 12: budget.claim(Vector2.ZERO)
	var sparks := 0
	for x in range(-2, 3):
		for y in range(-2, 3):
			if budget.claim(Vector2(x * 24, y * 24)) == BUDGET.Tier.SPARK: sparks += 1
	check(sparks == BUDGET.SPARK_PATCH_LIMIT, "dense area admits at most eight distinct spark patches per window")
	check(budget._cells[Vector2i.ZERO][0].times.size() == 13, "dense history storage is bounded")
	GameGlobal.runtime_state_reset.emit()
	check(budget._cells.is_empty() and budget.tier_counts == [0, 0, 0, 0], "new-run reset clears all local visual history")
	host.free()
	check(get_tree().get_nodes_in_group("thunder_fire_visual_budgets").is_empty(), "scene teardown releases its budget")

func _test_parameters() -> void:
	var parameters := {"count_multiplier": 2.0, "glow_multiplier": 1.4, "size_multiplier": 1.5, "distance_multiplier": 2.0}
	var before := parameters.duplicate()
	ExplosionEffect._apply_visual_tier(parameters, BUDGET.Tier.FULL)
	check(parameters == before, "full detail preserves all original visual parameters")
	ExplosionEffect._apply_visual_tier(parameters, BUDGET.Tier.REDUCED)
	check(parameters.count_multiplier == 1.0 and parameters.glow_multiplier == 0.7 and parameters.size_multiplier == 1.5 and parameters.distance_multiplier == 2.0, "medium detail reduces count and halo while preserving size and coverage")
	ExplosionEffect._apply_visual_tier(parameters, BUDGET.Tier.SPARK)
	check(roundi(parameters.count_multiplier * 96.0) == 4 and parameters.glow_multiplier == 0.0, "dense sparks are capped at four even with particle bonuses")
	parameters.count_multiplier = 0.01
	ExplosionEffect._apply_visual_tier(parameters, BUDGET.Tier.SPARK)
	check(parameters.count_multiplier == 0.01, "dense tier never increases a smaller configured count")

func _test_emission() -> void:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", player)
	var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": weapon.weapon_id, "source_player": player})
	for mode in ["full", "adaptive", "off"]:
		var host := Node2D.new()
		add_child(host)
		var world := WORLD.new()
		world.name = "ParticleWorld"
		host.add_child(world)
		world.set_process(false)
		world._random.seed = 512
		GameGlobal.set_runtime_flag("thunder_fire_visual_mode", mode)
		ProbeExplosion.damage_calls = 0
		ProbeExplosion.terrain_calls = 0
		ProbeExplosion.total_damage = 0
		seed(20261012)
		var expected_random := randf()
		seed(20261012)
		for i in 96:
			var explosion := ProbeExplosion.new()
			host.add_child(explosion)
			explosion._weapon = weapon
			explosion._damage_event = event
			explosion._reaction_id = "thunder_fire"
			explosion._damage_multiplier_override = 1.8
			explosion._radius_override = 72.0
			explosion._detonate()
		check(ProbeExplosion.damage_calls == 96 and ProbeExplosion.terrain_calls == 96 and ProbeExplosion.total_damage == 1728, mode + ": every explosion still executes damage and terrain work")
		check(randf() == expected_random, mode + ": visual admission does not consume gameplay RNG")
		var expected_particles := 900 if mode == "full" else 772 if mode == "adaptive" else 0
		check(world.get_active_particle_count() == expected_particles, mode + ": particle admission matches the visual tier before creation")
		if mode == "adaptive":
			var budget = BUDGET.for_parent(host)
			check(budget.tier_counts == [4, 8, 1, 83], "identical overlapping explosions retain representative bursts and one spark patch")
		host.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	player.queue_free()
	await get_tree().process_frame
