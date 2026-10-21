extends Node2D
## Differential checks against the frozen pre-optimization budget and burst.
const OLD_BUDGET = preload("res://scripts/tests/fixtures/lightning_admission_original_budget.gd")
const BUDGET = preload("res://scripts/effects/thunder_fire_visual_budget.gd")
const OLD_BURST = preload("res://scripts/tests/fixtures/lightning_admission_original_burst.gd")
const BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
const FIELD = preload("res://scripts/effects/particle_light_field.gd")

class ParameterProbe extends LightningParticleEffect:
	var reads := 0
	func _get_cached_parameter(channel: String, fallback: float = 0.0) -> float:
		reads += 1
		return super._get_cached_parameter(channel, fallback)

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func _ready() -> void:
	run.call_deferred()

func same_regions(old: Node, current: Node) -> bool:
	if old._clock != current._clock or old.tier_counts != current.tier_counts: return false
	if old._cells.keys() != current._cells.keys(): return false
	for key in old._cells:
		if old._cells[key].size() != current._cells[key].size(): return false
		for index in old._cells[key].size():
			for field in ["position", "last_seen", "times", "spark_patches"]:
				if old._cells[key][index][field] != current._cells[key][index][field]: return false
	return old.is_processing() == current.is_processing()

func budget_test() -> void:
	var old := OLD_BUDGET.new()
	var current := BUDGET.new()
	add_child(old)
	add_child(current)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	# Includes negative cells, exact radius/patch edges and equidistant anchors.
	var points := [Vector2(-96, 0), Vector2(96, 0), Vector2.ZERO,
		Vector2(95.999, -0.001), Vector2(96, 24), Vector2(-24, -96), Vector2(500, 0)]
	for step in 1200:
		if step % 100 == 0:
			old.reset()
			current.reset()
		GameGlobal.set_runtime_flag("battle_runtime_paused", step % 13 == 0)
		get_tree().paused = step % 17 == 0
		var delta: float = [0.0, 0.00001, 0.016, 0.05, 0.09999, 0.1, 0.101][step % 7]
		old._process(delta)
		current._process(delta)
		var center: Vector2 = points[step % points.size()]
		for contact in 40:
			var point := center
			if contact % 3 == 0: point += Vector2(rng.randi_range(-4, 4), rng.randi_range(-4, 4)) * 24
			check(old.claim(point) == current.claim(point), "budget tier step %d contact %d" % [step, contact])
		check(same_regions(old, current), "budget history/patches/anchors/clock step %d" % step)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	get_tree().paused = false
	# A region survives on sparse contacts while its old spark patch expires.
	old.reset()
	current.reset()
	for count in [13, 1, 12]:
		for i in count: check(old.claim(Vector2.ZERO) == current.claim(Vector2.ZERO), "sparse-to-dense expiry")
		old._process(0.05)
		current._process(0.05)
		check(same_regions(old, current), "independent spark cleanup clock")
	old.free()
	current.free()

func burst_state(host: Node, field: Node) -> Dictionary:
	var states: Array = []
	for burst in host.get_meta(BURST.POOL_META, []):
		states.append([burst.global_position, burst._active, burst.age, burst.duration, burst.flash_count,
			burst.impact_count, burst._buffers.duplicate(true), burst._lifetimes.duplicate(),
			burst._parameters.duplicate(true), burst._extents.duplicate()])
	var tiers: Array = []
	for node in [host, field]:
		for key in node.get_meta_list():
			if str(key).begins_with("effect_visual_budget_"):
				tiers.append([key, node.get_meta(key).tier_counts.duplicate()])
	return {"bursts": states, "tiers": tiers, "lights": [field._positions.duplicate(), field._colors.duplicate(),
		field._energies.duplicate(), field._radii.duplicate(), field._order.duplicate()]}

func burst_test() -> void:
	for adaptive in [true, false]:
		GameGlobal.set_runtime_flag("review_visual_adaptive", adaptive)
		var expected: Dictionary
		var expected_rng := 0
		for legacy in [true, false]:
			var host := Node2D.new()
			add_child(host)
			var field := FIELD.new()
			host.add_child(field)
			var script = OLD_BURST if legacy else BURST
			script._random_ready = true
			script._random.seed = 20261021
			for i in 192:
				var point := Vector2((i % 8) * 24 - 96, (i / 8 % 3) * 24 - 24)
				var direction := Vector2.ZERO if i % 2 == 0 else Vector2.RIGHT
				var params := {"count_multiplier": 0.6, "size_multiplier": 1.2, "lifetime_multiplier": 0.8,
					"speed_multiplier": 1.1, "distance_multiplier": 0.5, "glow_multiplier": 1.3,
					"glow_radius_multiplier": 0.25, "alpha_multiplier": 0.7}
				var original := params.duplicate()
				if legacy:
					OLD_BURST.spawn(host, point, direction, 1.5, params)
				else:
					var tier := BURST.claim_tier(host, point)
					if tier != BUDGET.Tier.SUPPRESSED:
						BURST.spawn_admitted(host, point, direction, 1.5, params, tier)
				check(params == original, "caller parameters unchanged")
			if legacy:
				expected = burst_state(host, field)
				expected_rng = script._random.state
			else:
				check(burst_state(host, field) == expected, "identical buffers/lifetimes/tiers/lights adaptive=%s" % adaptive)
				check(script._random.state == expected_rng, "identical burst random stream")
			host.free()

func early_exit_test() -> void:
	GameGlobal.set_runtime_flag("review_visual_adaptive", true)
	var host := Node2D.new()
	add_child(host)
	var probe := ParameterProbe.new()
	host.add_child(probe)
	probe._parent_root = host
	for i in 13: probe._emit_hit_burst(Vector2.ZERO, Vector2.RIGHT)
	check(probe.reads > 0, "admitted hits still resolve visual parameters")
	probe.reads = 0
	var random_before: int = BURST._random.state
	for i in 3072: probe._emit_hit_burst(Vector2.ZERO, Vector2.RIGHT)
	check(probe.reads == 0 and BURST._random.state == random_before, "suppressed hits skip parameters and RNG")
	check(host.get_meta("effect_visual_budget_lightning_hit").tier_counts == [4, 8, 1, 3072], "each hit claims exactly once")
	check(BURST.claim_tier(null, Vector2.ZERO) == BUDGET.Tier.SUPPRESSED, "null parent rejected")
	host.free()

func run() -> void:
	CampProgression.begin_transient_session()
	budget_test()
	burst_test()
	early_exit_test()
	GameGlobal.clear_runtime_flag("review_visual_adaptive")
	CampProgression.end_transient_session()
	print("LIGHTNING_ADMISSION_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
