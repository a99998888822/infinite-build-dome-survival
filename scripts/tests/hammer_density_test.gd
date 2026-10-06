extends "res://scripts/tests/weapon_trio_test.gd"

var cases: Array[Dictionary] = []

func total(stat: String, value: float) -> void:
	weapon.runtime_stats[stat] = float(weapon.runtime_stats.get(stat, 0.0)) + value - weapon.get_stat(stat)

func prepare(bonus: float, attachments: Array = ["scroll_electric_spark"], positions: Array = []) -> void:
	await fixture(HAMMER, positions, attachments)
	loadout.set_active_combat_enabled(true)
	for stat in ["area_size", "damage_area_size", "crit_chance", "attack_speed"]:
		total(stat, bonus if stat == "area_size" else 0)
	total("projectile_count", 1)

func sparks() -> Array[ElectricSparkEffect]:
	var result: Array[ElectricSparkEffect] = []
	for child in host.get_children():
		if child is ElectricSparkEffect:
			result.append(child)
	return result

func _run() -> void:
	CampProgression.begin_transient_session()
	for bonus in [0, 1, 50, 100, 300]:
		for area in [0, 100]:
			await prepare(bonus)
			total("damage_area_size", area)
			var quake := hammer()
			advance(quake, 0.619)
			check(sparks().is_empty(), "no warning before hammer impact")
			advance(quake, 0.401, 0.401)
			var expected: int = {0: 5, 1: 6, 50: 7, 100: 8, 300: 12}[bonus]
			var warnings := sparks()
			check(warnings.size() == expected, "sample count range=%d area=%d" % [bonus, area])
			check(emitted.size() == 5 and quake.nodes.size() == 5, "native cells stay five")
			check(not quake.is_attacking(), "all warnings dispatched within original 0.4s travel")
			check(warnings[0]._hit_position.is_equal_approx(Vector2(40, 0)), "first lightning stays at 40px")
			check(warnings[-1]._hit_position.is_equal_approx(Vector2(weapon.get_attack_range(), 0)), "last lightning at exact range")
			var largest := 0.0
			for i in range(1, warnings.size()):
				var distance := warnings[i]._hit_position.distance_to(warnings[i - 1]._hit_position)
				largest = maxf(largest, distance)
				check(distance > 0 and distance <= 64.001, "distinct points at most 64px apart")
			check(warnings.all(func(s): return is_equal_approx(s._radius, 30.0 * (1.0 + area / 200.0))), "damage area changes radius only")
			cases.append({"range_bonus": bonus, "area_bonus": area, "count": warnings.size(), "gap": largest, "range": weapon.get_attack_range()})

	# Four in-range targets, one outside; the independent sampler must not
	# multiply native contacts or water events. Source-runtime parity was
	# verified in the archived review before this regression was installed.
	await prepare(100, ["scroll_water", "scroll_electric_spark"], [Vector2(100, 0), Vector2(210, 0), Vector2(320, 0), Vector2(430, 0), Vector2(550, 0)])
	var expected_native_damage: int = weapon.calculate_damage_events()[0].damage
	var native := hammer()
	advance(native, 1.03, 1.03)
	check(effect_count(WaterWaveEffect) == 5, "water remains one event per native node")
	check(hits.size() == 4 and hits.all(func(hit): return hit.damage == expected_native_damage), "native hits occur once per in-range target at full damage")

	for before_split in [true, false]:
		await prepare(100, ["scroll_electric_spark", "scroll_split"] if before_split else ["scroll_split", "scroll_electric_spark"])
		var quake := hammer()
		advance(quake, 1.03, 1.03)
		check(sparks().size() == (8 if before_split else 16), "split order preserves main versus child lightning")
		check(quake.nodes.size() == 15, "split does not create extra native cracks")
		var scale := 1.0 if before_split else 0.45
		check(sparks().all(func(s): return s._damage_event.split_child == not before_split and is_equal_approx(s._damage_event.elemental_damage_scale, scale)), "split source and damage multiplier preserved")
		for child_index in (1 if before_split else 2):
			for i in range(child_index + (1 if before_split else 2), sparks().size(), 1 if before_split else 2):
				check(sparks()[i]._hit_position.distance_to(sparks()[i - (1 if before_split else 2)]._hit_position) <= 64.001, "split endpoint rows remain dense")

	await prepare(100)
	total("projectile_count", 3)
	check(weapon.get_projectile_angles() == [-10.0, 0.0, 10.0], "three rays have ten degree adjacent gaps")
	var quake := hammer()
	advance(quake, 1.03, 1.03)
	check(sparks().size() == 24 and emitted.size() == 15, "three independent dense rays")
	for i in 3:
		check(is_equal_approx(rad_to_deg((sparks()[i]._hit_position - quake.global_position).angle()), weapon.get_projectile_angles()[i]), "actual lightning uses configured angle")

	await prepare(100)
	wall(Vector2(150, 0))
	await frames()
	quake = hammer()
	advance(quake, 1.03, 1.03)
	check(sparks().size() == 2 and sparks().all(func(s): return s._hit_position.x < 150), "wall stops lightning but retains nearer samples")
	check(not quake.is_attacking(), "blocked ray completes without a stuck cooldown")

	await prepare(100, ["scroll_split", "scroll_electric_spark"])
	wall(Vector2(70, 0))
	await frames()
	quake = hammer()
	advance(quake, 1.03, 1.03)
	check(sparks().is_empty(), "branch crossing a wall cannot create lightning beyond it")

	await prepare(100)
	quake = hammer()
	advance(quake, 0.67)
	var count := sparks().size()
	var old_age := quake.age
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(quake, 2.0, 2.0)
	check(sparks().size() == count and quake.age == old_age, "pause freezes the independent queue")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	loadout.remove_weapon(HAMMER)
	advance(quake, 2.0)
	check(quake.cancelled and sparks().size() == count, "unloading cancels all pending warnings")

	await prepare(100)
	quake = hammer()
	advance(quake, 0.67)
	count = sparks().size()
	player.alive = false
	advance(quake, 2.0)
	check(quake.cancelled and sparks().size() == count, "death cancels pending samples")

	await prepare(100)
	quake = hammer()
	advance(quake, 0.63)
	player.position = Vector2(200, 200)
	total("area_size", 300)
	advance(quake, 0.40, 0.40)
	check(sparks().size() == 8 and sparks()[-1]._hit_position.is_equal_approx(Vector2(444, 0)), "cast locks lightning origin and reach")

	# The stock dispatcher remains unchanged for all non-hammer callers.
	await prepare(0)
	CombatEffectWorld.trigger_ground_weapon_impact(host, weapon, weapon.calculate_damage_events()[0], Vector2(90, 0), Vector2.RIGHT)
	check(sparks().size() == 1, "default dispatcher emits one normal lightning warning")
	var warning := sparks()[0]
	warning.set_process(false)
	warning._process(0.499)
	check(not warning._struck, "warning still waits half a second")
	warning._process(0.0011)
	check(warning._struck, "warning strikes after half a second")
	await frames()
	var bolt: LightningParticleEffect
	for child in host.get_children():
		if child is LightningParticleEffect: bolt = child
	check(bolt != null and is_equal_approx(bolt._ground_strike_damage_radius, 30), "actual strike retains thirty pixel base radius")

	# Exercise the normal cast/cooldown path, not just a manually ticked hammer.
	await prepare(100)
	check(loadout.cast_weapon(weapon, Vector2(600, 0)), "real active cast accepted")
	var state := loadout.active_casting.state_for(weapon)
	quake = state.body.get_ref() as EarthHammer
	quake.set_physics_process(false)
	advance(quake, 1.019, 1.019)
	loadout.tick(0.001)
	check(state.executing, "cast remains active until final sampling time")
	advance(quake, 0.002)
	loadout.tick(0.001)
	check(not state.executing and is_equal_approx(state.remaining, weapon.get_active_cooldown_seconds()), "unchanged cooldown starts immediately after final sample")

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "cases": cases}, "\t"))
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("HAMMER_DENSITY_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
