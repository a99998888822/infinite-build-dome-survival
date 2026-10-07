extends "res://scripts/tests/pixel_combat_effect_test.gd"

const DAGGER := "weapon_camp_dagger"
var player: PlayerController
var loadout: WeaponLoadout
var hits: Array[Dictionary] = []


func fixture(positions: Array, attachments: Array = []) -> CampDagger:
	await setup(positions)
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	loadout = WeaponLoadout.new()
	host.add_child(loadout)
	loadout.initialize(player)
	check(loadout.equip_weapon(DAGGER), "equip registered dagger")
	weapon = loadout.get_weapon_instance(DAGGER)
	if attachments.size() > 1:
		loadout.upgrade_weapon(DAGGER)
		loadout.upgrade_weapon(DAGGER)
	for id in attachments:
		var item := player.item_inventory.add_item_from_base(id, "dagger_test")
		check(loadout.attach_item_to_weapon(DAGGER, item.item_instance_id), "attach real inventory " + str(id))
	weapon.runtime_stats.crit_chance = 0
	var dagger := motion()
	await frames()
	return dagger


func motion() -> CampDagger:
	hits.clear()
	var dagger := CampDagger.new()
	host.add_child(dagger)
	dagger.initialize(weapon, Vector2.RIGHT)
	dagger.set_physics_process(false)
	dagger.target_hit.connect(func(id: int, damage: int, child: bool): hits.append({"id": id, "damage": damage, "child": child}))
	return dagger


func advance(dagger: CampDagger, duration: float, step: float = 1.0 / 60.0) -> void:
	var left := duration
	while left > 0.00001 and not dagger.cancelled:
		var delta := minf(left, step)
		dagger._physics_process(delta)
		left -= delta


func wall(at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 100)
	collider.shape = shape
	body.add_child(collider)
	host.add_child(body)
	body.position = at


func _run() -> void:
	CampProgression.begin_transient_session()
	var dagger := await fixture([Vector2(30, 0), Vector2(26, 22), Vector2(-20, 0), Vector2(0, 130), Vector2(130, 0)])
	check(weapon.is_camp_dagger() and weapon.get_attack_kind() == "melee", "dedicated melee behavior")
	check(weapon.get_base_attack_damage() == 7 and weapon.calculate_damage_events(true)[0].damage == 11, "native melee and critical calculation")
	check(weapon.get_load_cost() == 16 and weapon.get_attachment_slot_count() == 1, "light load and common slot count")
	check(load(weapon.weapon_data.icon).get_size() == Vector2(128, 128) and CampDagger.BLADE.get_size() == Vector2(32, 32), "approved art installed at native sizes")
	var details := weapon.build_full_stats_text()
	check(details.contains("伤害：[/color]（[color=#FFFFFF]7[/color][color=#EE7777]+0[/color]）"), "tooltip shows unboosted damage components")
	for removed in ["每轮斩击", "斩击距离", "角度", "刀刃伤害宽度", "伤害加成", "伤害基础", "（非暴击）"]:
		check(not details.contains(removed), "tooltip omits " + removed)
	advance(dagger, 0.055)
	check(hits.is_empty(), "windup deals no damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(dagger, 0.5)
	check(is_equal_approx(dagger.age, 0.055) and hits.is_empty(), "pause freezes blade and damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	advance(dagger, 0.4, 0.4)
	check(hits.size() == 2 and hits.all(func(hit): return hit.damage == 7), "long frame sweeps front targets once")
	check(enemies[2].current_hp == 10000 and enemies[3].current_hp == 10000 and enemies[4].current_hp == 10000, "rear and out-of-range enemies remain unharmed")
	check(dagger.cancelled and not dagger.visible, "recovery retires blade")
	for level in range(2, 6): check(loadout.upgrade_weapon(DAGGER), "upgrade to level " + str(level))
	check(weapon.get_base_attack_damage() == 15 and weapon.get_attachment_slot_count() == 2 and not weapon.upgrade(), "level five cap and rarity slots")
	player.add_runtime_modifier({"id": "dagger_melee", "source_type": "test", "source_id": "dagger_test", "stat": "melee_damage", "operation": "add_flat", "value": 10, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
	check(weapon.get_base_attack_damage() == 23, "player melee coefficient is 0.8")
	check(weapon.build_full_stats_text().contains("（[color=#FFFFFF]15[/color][color=#EE7777]+8[/color]）"), "tooltip includes upgraded base and coefficient-scaled player contribution")
	weapon.runtime_stats.ranged_damage = 100
	check(weapon.get_base_attack_damage() == 23, "ranged damage cannot scale dagger")

	dagger = await fixture([Vector2(36, 0)])
	var radius: float = enemies[0].get_node("CollisionShape2D").shape.radius
	enemies[0].position.x = 90 + 8 + radius + 1
	await frames()
	dagger._contact(dagger.cuts[0], Vector2.ZERO, 0.11)
	check(hits.is_empty(), "outside visible blade plus collider misses")
	check(CampDagger.find_target(weapon) == null, "acquisition excludes out-of-reach collider")
	enemies[0].position.x -= 2
	await frames()
	dagger._contact(dagger.cuts[0], Vector2.ZERO, 0.11)
	check(hits.size() == 1, "actual enemy collider edge contact counts")
	check(CampDagger.find_target(weapon) == enemies[0], "acquisition sees reachable edge even when center is outside range")
	weapon.runtime_stats.area_size = 100
	check(dagger.blade_segment(dagger.cuts[0], 0.11)[1].length() == 135 and weapon.get_hit_radius() == 8, "range scales rendered blade path without changing contact thickness")
	weapon.runtime_stats.damage_area_size = 100
	check(weapon.get_hit_radius() == 12 and weapon.get_attack_range() == 150, "damage area separately scales blade thickness")
	check(dagger.blade_segment(dagger.cuts[0], 0.11)[0].length() == 21, "increasing reach does not create an inner blind ring")

	dagger = await fixture([Vector2(16, 0), Vector2(36, 0)])
	wall(Vector2(25, 0))
	await frames()
	advance(dagger, 0.2)
	check(hits.size() == 1 and enemies[1].current_hp == 10000, "wall blocks damage beyond terrain")
	enemies[0].alive = false
	check(CampDagger.find_target(weapon) == null, "acquisition rejects dead and terrain-blocked enemies")

	dagger = await fixture([Vector2(30, 45)])
	advance(dagger, 0.06)
	player.position.y = 45
	advance(dagger, 0.10, 0.10)
	check(hits.size() == 1 and dagger.heading == Vector2.RIGHT and dagger.global_position == player.global_position, "moving slash follows player with direction locked")
	dagger.cancel()
	weapon.volley_index = 1
	dagger = motion()
	check(dagger.cuts[0].sign == -1, "next volley reverses the slash")

	dagger = await fixture([Vector2(30, 0)])
	dagger.cancel()
	weapon.runtime_stats.projectile_count = 3
	weapon.runtime_stats.attack_speed = 700
	dagger = motion()
	advance(dagger, 0.13, 0.13)
	check(hits.size() == 3 and hits.all(func(hit): return hit.damage == 7), "extra projectiles become three full damage cuts even in a long frame")
	check(dagger.cancelled and is_equal_approx(dagger.time_scale, 0.5), "whole combo accelerates and still fits cooldown")
	check(dagger.cut_end(dagger.cuts[0]) <= float(dagger.cuts[1].start) + 0.00001, "main cuts are sequential, never three floating blades")

	dagger = await fixture([Vector2(30, 0), Vector2(31, 4)], ["scroll_split", "scroll_fire"])
	advance(dagger, 0.4, 0.4)
	check(dagger.cuts.size() == 3 and hits.size() == 6, "split adds two follow-throughs once per volley, not per victim")
	check(hits.all(func(hit): return hit.damage == (5 if hit.child else 11)), "child multiplier applied once with rounding")
	check(enemies.all(func(enemy): return enemy.has_status("burning")), "all slash contacts trigger fire attachment")
	check(dagger.cuts.all(func(cut): return cut.event.source_weapon_id == DAGGER), "main and split damage retain weapon attribution")
	var split_event: DamageEvent = dagger.cuts[1].event
	split_event.element_damage_bonus = 10
	check(is_equal_approx(split_event.get_elemental_base_damage(), 9.45), "full elemental base scaled once without early rounding")
	check(dagger.cuts[1].event.is_critical == dagger.cuts[0].event.is_critical, "split inherits primary critical")

	dagger = await fixture([Vector2(130, 0)], ["scroll_split"])
	advance(dagger, 0.4)
	check(hits.is_empty() and dagger.cuts.size() == 1, "a missed slash cannot create split follow-throughs")

	dagger = await fixture([Vector2(30, 0)], ["scroll_split"])
	advance(dagger, 0.12)
	check(dagger.cuts.size() == 3, "split queued after first real contact")
	loadout.remove_weapon(DAGGER)
	var before := hits.size()
	advance(dagger, 1.0)
	check(dagger.cancelled and hits.size() == before, "selling cancels queued split damage")

	dagger = await fixture([Vector2(30, 0)])
	var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "dagger_test")
	check(not loadout.attach_item_to_weapon(DAGGER, pierce.item_instance_id), "contact slash rejects pierce")
	player.alive = false
	advance(dagger, 0.2)
	check(dagger.cancelled and hits.is_empty(), "death cancels before damage")

	dagger = await fixture([Vector2(120, 0)])
	dagger.cancel()
	weapon.attack_timer = 0
	check(not loadout._try_attack_with_weapon(weapon) and weapon.attack_timer == 0, "no target preserves cooldown")
	enemies[0].position = Vector2(30, 0)
	await frames()
	check(loadout._try_attack_with_weapon(weapon) and weapon.attack_timer > 0, "formal loadout spawns the real dagger")
	check(not loadout._try_attack_with_weapon(weapon), "active combo cannot overlap")
	loadout.initialize(player)
	check(get_tree().get_nodes_in_group("camp_daggers").all(func(node): return node.cancelled), "reinitialize clears all dagger runtime")
	check_shop()
	check(DataValidator.new().validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full configuration validation")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("CAMP_DAGGER_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func check_shop() -> void:
	var generator := ShopOfferGenerator.new()
	var context := {"load_capacity": 100, "current_load": 88, "luck": 0}
	check(generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == DAGGER), "dagger fits exactly twelve remaining load")
	context.current_load = 89
	check(not generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == DAGGER), "shop rejects insufficient capacity")
	context.current_load = 0
	context.owned_weapon_ids = [DAGGER]
	check(not generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == DAGGER and offer.offer_type == "new_weapon"), "shop excludes duplicate dagger")
	context.luck = 350
	for level in range(1, 6):
		context.equipped_weapons = [{"weapon_id": DAGGER, "level": level}]
		var upgrades := generator.build_shop_candidate_pool(context).filter(func(offer): return offer.target_id == DAGGER and offer.offer_type == "weapon_upgrade")
		check((upgrades.size() == 1 and upgrades[0].to_level == level + 1) if level < 5 else upgrades.is_empty(), "only next legal shop upgrade from " + str(level))
