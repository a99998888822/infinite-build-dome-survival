extends Node2D

const LIGHTNING = preload("res://scripts/effects/lightning_particle_effect.gd")
const WORLD = preload("res://scripts/effects/particle_world.gd")
const FIELD = preload("res://scripts/effects/particle_light_field.gd")
const BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	CampProgression.begin_transient_session()
	var field := FIELD.new()
	field.name = "ParticleLightField"
	add_child(field)
	field.set_process(false)
	var world := WORLD.new()
	world.name = "ParticleWorld"
	add_child(world)
	world.set_process(false)
	while world.get_active_particle_count() < WORLD.MAX_PARTICLES:
		WORLD.emit_profile(self, "lightning_impact", Vector2(-5000, -5000), Vector2.ZERO, 10.0)
	check(world.get_active_particle_count() == 900, "fixture fills original shared pool")
	for ground in [false, true]:
		for multiplier in [1.0, 1.15, 1.2]:
			for intensity in [1.0, 1.5, 2.0]:
				var effect := LIGHTNING.new()
				add_child(effect)
				effect.set_process(false)
				effect._parent_root = self
				effect._is_ground_strike = ground
				effect._resolved_parameters = {"count_multiplier": multiplier, "attack_range_multiplier": intensity, "glow_multiplier": 1.3}
				effect._emit_hit_burst(Vector2(150, 120), Vector2.RIGHT)
				var burst = get_tree().get_nodes_in_group("lightning_hit_sprite_bursts")[-1]
				burst.set_process(false)
				check(burst.flash_count == roundi(5 * multiplier * intensity * 0.5) and burst.impact_count == roundi(30 * multiplier * intensity * 0.5), "reduced count preserved while pool is full: ground=%s count=%.2f range=%.1f" % [ground, multiplier, intensity])
				check(burst.batches.size() == 2 and world.get_active_particle_count() == 900, "PNG batches bypass shared particle slots")
				var radius := 0.5 if ground else 0.25
				check(is_equal_approx(field._radii[-1], 200.0 * radius) and is_equal_approx(field._radii[-2], 86.0 * radius), "existing reduced impact light radii preserved")
				check(burst.global_position == Vector2(150, 120), "impact stays at world-space contact")
				GameGlobal.set_runtime_flag("battle_runtime_paused", true)
				burst._process(0.2)
				check(burst.age == 0.0, "pause freezes GPU frame clock")
				GameGlobal.set_runtime_flag("battle_runtime_paused", false)
				burst._process(0.06)
				check(is_equal_approx(burst.batches[0].material.get_shader_parameter("elapsed"), 0.06), "PNG frame clock advances")
				burst._process(1.0)
				check(burst.is_queued_for_deletion(), "finished animation releases both batches")
				effect.queue_free()
				await get_tree().process_frame
	# More than 900 simultaneous lightning particles must also remain present.
	var total := 0
	for i in 80:
		var burst = BURST.spawn(self, Vector2.ZERO, Vector2.RIGHT, 1.0, {"count_multiplier": 0.6, "distance_multiplier": 0.5, "glow_radius_multiplier": 0.25})
		burst.set_process(false)
		total += burst.get_active_particle_count()
	check(total == 1680, "80 reduced-count hits retain all 1680 PNG particles beyond old pool cap")
	check(world.get_active_particle_count() == 900, "ordinary pool stays full without evicting live hit animations")
	for burst in get_tree().get_nodes_in_group("lightning_hit_sprite_bursts"):
		burst._process(1.0)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("lightning_hit_sprite_bursts").is_empty(), "all simultaneous hits retire cleanly")
	CampProgression.end_transient_session()
	print("LIGHTNING_HIT_PNG_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
