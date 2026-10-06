extends "res://scripts/tests/attribute_enchantment_test.gd"

const PARAMS = preload("res://scripts/effects/effect_parameter_resolver.gd")
var burn_received: Dictionary = {}


func impact() -> void:
	event = weapon.calculate_damage_events()[0]
	CombatEffectWorld.trigger_weapon_impact(host, weapon, event, enemies[0].global_position, Vector2.RIGHT, enemies[0])


func _run() -> void:
	CampProgression.begin_transient_session()
	var effects := {"water": WaterWaveEffect, "light_sword": LightSwordEffect, "black_hole": BlackHoleEffect,
		"fire": FireSeed, "explosion": ExplosionEffect, "electric_spark": ElectricSparkEffect,
		"ice": IceFieldEffect, "lightning": LightningParticleEffect, "wind": WindBladeEffect}
	for id in effects:
		await fixture(BOW, [Vector2(40, 0)], ["scroll_" + id, "scroll_" + id])
		normalize_damage(weapon)
		impact()
		check(effect_count(effects[id]) == (8 if id == "fire" else 2), "two independent effects for " + id)
		if id == "fire":
			check(enemies[0]._burn_sources.size() == 1 and enemies[0]._burn_damage_per_tick == 10, "two fire copies still share one weapon burn contribution")

	await fixture(BOW, [Vector2(40, 0)], ["scroll_water", "scroll_water"])
	normalize_damage(weapon)
	weapon._attached_item_instances[0].effect_parameters.damage_multiplier = 0.2
	weapon._attached_item_instances[1].effect_parameters.damage_multiplier = 0.6
	impact()
	await frames()
	check(enemies[0].current_hp == 9920, "two water copies deal their own 20 and 60 damage")

	await fixture(BOW, [Vector2(40, 0)], ["scroll_lightning", "scroll_lightning"])
	normalize_damage(weapon)
	weapon._attached_item_instances[0].rolled_parameters.chain_count = 2
	weapon._attached_item_instances[1].rolled_parameters.chain_count = 4
	weapon.add_effect_modifier({"effect_id": "lightning", "channel": "chain_count", "operation": "add_flat", "value": 1, "source_id": "relic_test"})
	impact()
	var counts: Array[int] = []
	for child in host.get_children():
		if child is LightningParticleEffect:
			counts.append(roundi(child._context.get_resolved_parameter("chain_count")))
	counts.sort()
	check(counts == [3, 5], "per-copy rolls stay independent and global relic applies to both")
	await frames()
	check(enemies[0].current_hp == 9890, "two chains each damage the first target")

	await fixture(HAMMER, [], ["scroll_lightning", "scroll_lightning"])
	CombatEffectWorld.trigger_ground_weapon_impact(host, weapon, weapon.calculate_damage_events()[0], Vector2.ZERO, Vector2.RIGHT)
	check(effect_count(LightningParticleEffect) == 0, "two ground chains with no enemies emit nothing")
	await fixture(HAMMER, [Vector2(40, 0)], ["scroll_lightning", "scroll_lightning"])
	CombatEffectWorld.trigger_ground_weapon_impact(host, weapon, weapon.calculate_damage_events()[0], Vector2.ZERO, Vector2.RIGHT)
	check(effect_count(LightningParticleEffect) == 2, "ground point emits two independent chains with a real target")

	await fixture(BOW, [Vector2(40, 0)], ["scroll_bounce", "scroll_bounce"])
	normalize_damage(weapon)
	impact()
	check(bounces().size() == 2, "two bounces replay immediately at first contact")
	CombatEffectWorld.trigger_weapon_impact(host, weapon, event, Vector2(80, 0), Vector2.RIGHT, enemies[0])
	check(bounces().size() == 2 and bounces().all(func(copy): return not copy.replay.has_effect("bounce")), "later contacts cannot replay either copy or recurse")

	await fixture(BOW, [Vector2(40, 0)])
	var victim := enemies[0]
	burn_received.clear()
	victim.damage_received.connect(func(source: String, amount: int): burn_received[source] = int(burn_received.get(source, 0)) + amount)
	victim.apply_burning(3, 10.25, "A")
	victim.apply_burning(3, 20.75, "B")
	victim._process_burning(0.5)
	check(victim.current_hp == 9970 and burn_received == {"A": 10, "B": 20}, "burn ticks keep separate source attribution")
	victim.apply_burning(4, 999, "A")
	victim.apply_burning(4, 1, "B")
	check(victim._burn_damage_per_tick == 31 and victim._burn_sources.size() == 2 and victim._burning_remaining == 4, "same sources only refresh shared time, even if incoming damage changes")
	victim._process_burning(1.5)
	check(burn_received == {"A": 41, "B": 83} and victim.current_hp == 9876, "fractional burn damage accumulates independently without losing attribution")
	victim.clear_burning()
	check(victim._burn_sources.is_empty(), "cleansing removes every contribution")
	victim.apply_burning(0.2, 7, "A")
	victim._process_burning(0.3)
	check(victim._burn_sources.is_empty() and not victim.has_status("burning"), "burn expiry before next tick clears sources")
	victim.apply_burning(2, 4, "A")
	check(victim._burn_damage_per_tick == 4, "new burn after expiry accepts a fresh source strength")
	victim.apply_burning(2, 6, "B", true)
	var hp := victim.current_hp
	victim._process_burning(0.5)
	check(hp - victim.current_hp == 20, "holy fire amplifies both sources once")
	ElementReactionResolver.apply_element(victim, "water", {"original_damage": 1, "source_id": "C"})
	check(victim._burn_sources.is_empty(), "water reaction clears the full shared burn")

	await fixture(BOW, [Vector2(40, 0)], ["scroll_domain", "scroll_lightning"])
	var lightning_item := str(weapon.get_effect_instances("lightning")[0].item_instance_id)
	var ctx := PARAMS.build_weapon_context(weapon, "lightning", {"jump_radius": 170}, lightning_item)
	check(ctx.get_resolved_parameter("jump_radius") == 170 and ctx.get_resolved_parameter("attack_range_multiplier") == 1, "domain changes neither chain search nor propagation distance")
	enemies[0].position = Vector2(180, 0)
	CombatEffectWorld.trigger_ground_weapon_impact(host, weapon, weapon.calculate_damage_events()[0], Vector2.ZERO, Vector2.RIGHT)
	check(effect_count(LightningParticleEffect) == 0, "domain cannot acquire an enemy outside ground chain search range")
	await fixture(BOW, [Vector2(62, 0)], ["scroll_domain", "scroll_ice"])
	normalize_damage(weapon)
	IceFieldEffect.spawn(host, Vector2.ZERO, weapon, weapon.calculate_damage_events()[0], str(weapon.get_effect_instances("ice")[0].item_instance_id))
	await frames()
	check(enemies[0].current_hp < 10000, "domain-expanded ice damage reaches the outer target")
	for child in host.get_children():
		if child is IceFieldEffect: check(is_equal_approx(child._radius, 51.2 * 1.15), "ice area scales exactly once")

	await fixture(BOW, [Vector2(15.5, 0)], ["scroll_domain", "scroll_wind"])
	WindBladeEffect.spawn(host, Vector2.ZERO, Vector2.RIGHT, 480, 0.46, weapon, weapon.calculate_damage_events()[0], 0, Callable(), str(weapon.get_effect_instances("wind")[0].item_instance_id))
	for child in host.get_children():
		if child is WindBladeEffect:
			child.set_process(false)
			child._damage_path_enemies()
			check(is_equal_approx(child._hit_radius, 16.1) and child._speed == 480 and child._lifetime == 0.46, "domain scales wind damage width without changing flight distance")
	check(enemies[0].current_hp < 10000, "expanded wind blade hits outside its original 14px width")
	var wind_item := str(weapon.get_effect_instances("wind")[0].item_instance_id)
	ctx = PARAMS.build_weapon_context(weapon, "wind", {}, wind_item)
	check(ctx.get_resolved_parameter("wet_propagation_radius") == 92 and ctx.get_resolved_parameter("field_search_radius") == 18, "domain leaves wind propagation and field-search distances unchanged")
	var reflected_event := weapon.calculate_damage_events()[0].duplicate_event()
	enemies[0].apply_freeze()
	ElementReactionResolver.apply_element(enemies[0], "light", {"parent": host, "damage_event": reflected_event})
	for child in host.get_children():
		if child is LightReflectionEffect: check(is_equal_approx(child._radius, 253), "reflection damage fan inherits captured domain scale once")

	await fixture(LAMP, [], ["scroll_domain"])
	check(is_equal_approx(weapon.get_lamp_cone_degrees(), 69) and weapon.build_full_stats_text().contains("69°"), "lamp preview displays the enlarged 60-degree base cone")
	for data in DataRegistry.tables.weapons:
		await fixture(str(data.id), [], ["scroll_might", "scroll_wisdom"])
		normalize_damage(weapon)
		var preview := weapon._build_damage_event(weapon.get_attack_kind(), false, false)
		var damage_line := weapon.build_full_stats_text().split("\n")[1]
		check(damage_line.begins_with("[color=#F5D76E]伤害：[/color]（") and damage_line.ends_with("）"), "single base-damage row for " + str(data.id))
		for removed in ["伤害加成", "伤害基础", "（非暴击）", "本武器全部伤害", "本武器元素伤害", "元素附魔伤害基数"]:
			check(not weapon.build_full_stats_text().contains(removed), "damage preview omits " + removed)
		check(preview.damage == weapon.calculate_damage_events()[0].damage, "preview and live noncritical damage agree")
		weapon.runtime_stats.damage_percent = 75
		check(weapon.build_full_stats_text().split("\n")[1] == damage_line and weapon.calculate_damage_events()[0].damage > preview.damage, "percentage damage changes combat but not base-damage row")
		seed(731)
		var expected_random := randf()
		seed(731)
		weapon.build_full_stats_text()
		check(randf() == expected_random, "opening preview does not roll combat RNG")
		var before := weapon.build_full_stats_text()
		for item in weapon.get_attached_item_instances(): loadout.detach_item_from_weapon(weapon.weapon_id, item.item_instance_id)
		check(weapon.build_full_stats_text() != before and weapon.build_full_stats_text().split("\n")[1] == damage_line, "detachment updates icons without changing unboosted damage")

	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("ENCHANTMENT_STACKING_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
