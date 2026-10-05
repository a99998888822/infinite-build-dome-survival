extends "res://scripts/tests/pixel_combat_effect_test.gd"

const SPEAR_ID := "weapon_nightwatch_spear"
var player: PlayerController
var loadout: WeaponLoadout
var hits: Array[Dictionary] = []
var shards: Array[NightwatchSpearShard] = []


func fixture(positions: Array, attachments: Array = []) -> NightwatchSpear:
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
	check(loadout.equip_weapon(SPEAR_ID), "equip registered spear")
	weapon = loadout.get_weapon_instance(SPEAR_ID)
	if attachments.size() > 1:
		loadout.upgrade_weapon(SPEAR_ID)
		loadout.upgrade_weapon(SPEAR_ID)
	for id in attachments:
		var item := player.item_inventory.add_item_from_base(id, "spear_test")
		check(loadout.attach_item_to_weapon(SPEAR_ID, item.item_instance_id), "attach inventory " + str(id))
	weapon.runtime_stats.crit_chance = 0
	var spear := motion()
	await frames()
	return spear


func motion() -> NightwatchSpear:
	hits.clear()
	shards.clear()
	var spear := NightwatchSpear.new()
	host.add_child(spear)
	spear.initialize(weapon, Vector2.RIGHT)
	spear.set_physics_process(false)
	spear.target_hit.connect(func(id: int, damage: int, thrust: int): hits.append({"id": id, "damage": damage, "thrust": thrust}))
	spear.shard_launched.connect(func(shard: NightwatchSpearShard):
		shards.append(shard)
		shard.set_physics_process(false))
	return spear


func advance(spear: NightwatchSpear, seconds: float, step: float = 1.0 / 60.0) -> void:
	var remaining := seconds
	while remaining > 0.00001 and not spear.cancelled:
		var delta := minf(remaining, step)
		spear._physics_process(delta)
		remaining -= delta


func wall(at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 160)
	collider.shape = shape
	body.add_child(collider)
	host.add_child(body)
	body.position = at
	return body


func check_shop() -> void:
	var generator := ShopOfferGenerator.new()
	var context := {"load_capacity": 100, "current_load": 0, "luck": 0}
	var pool := generator.build_shop_candidate_pool(context)
	check(pool.any(func(offer): return offer.target_id == SPEAR_ID and offer.rarity == "uncommon"), "spear in zero-luck shop pool")
	var rarity := generator.get_shop_rarity_weights(0)
	var types := generator.get_shop_type_weights({"candidate_pool": pool, "load_capacity": 100, "current_load": 0})
	seed(9292026)
	var rolled := false
	for index in 200:
		rolled = rolled or generator.roll_paid_offers(rarity, types, pool, 5, index).any(func(offer): return offer.target_id == SPEAR_ID)
	check(rolled, "spear rolls through actual shop selection")
	context.current_load = 85
	check(not generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == SPEAR_ID), "insufficient load excludes spear")
	context.current_load = 84
	check(generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == SPEAR_ID), "exactly sixteen load permits spear")
	context.owned_weapon_ids = [SPEAR_ID]
	check(not generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == SPEAR_ID and offer.offer_type == "new_weapon"), "owned spear cannot be bought twice")
	context.luck = 350
	for level in range(1, 6):
		context.equipped_weapons = [{"weapon_id": SPEAR_ID, "level": level}]
		var upgrades := generator.build_shop_candidate_pool(context).filter(func(offer): return offer.target_id == SPEAR_ID and offer.offer_type == "weapon_upgrade")
		check((upgrades.size() == 1 and upgrades[0].to_level == level + 1) if level < 5 else upgrades.is_empty(), "shop offers only the next legal spear level from " + str(level))


func _run() -> void:
	CampProgression.begin_transient_session()
	var spear := await fixture([Vector2(70, 0), Vector2(175, 0), Vector2(-70, 0), Vector2(150, 60), Vector2(260, 0)])
	check(weapon.is_nightwatch_spear() and weapon.get_attack_kind() == "melee", "dedicated production melee behavior")
	check(weapon.get_base_attack_damage() == 14 and weapon.calculate_damage_events(true)[0].damage == 21, "native damage and critical calculation")
	check(weapon.get_load_cost() == 28 and weapon.get_attachment_slot_count() == 1, "medium load and initial attachment slot")
	check(load(weapon.weapon_data.icon).get_size() == Vector2(128, 128), "formal 128 pixel icon")
	check(weapon.build_full_stats_text().contains("每轮刺击"), "details describe thrusts instead of projectiles")
	advance(spear, 0.09)
	check(hits.is_empty(), "windup cannot damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(spear, 0.5)
	check(is_equal_approx(spear.age, 0.09) and hits.is_empty(), "pause freezes animation and damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	advance(spear, 0.30, 0.30)
	check(hits.size() == 2 and hits.all(func(hit): return hit.damage == 14), "large frame pierces each aligned enemy exactly once")
	check(enemies[2].current_hp == 10000 and enemies[3].current_hp == 10000 and enemies[4].current_hp == 10000, "rear, off-width and out-of-range enemies are untouched")
	check(spear.cancelled and not spear.visible, "recovery hides and retires spear")
	for index in 4: check(loadout.upgrade_weapon(SPEAR_ID), "upgrade to level " + str(index + 2))
	check(weapon.get_base_attack_damage() == 26 and weapon.get_attachment_slot_count() == 2 and not weapon.upgrade(), "level five damage and rarity slots, capped upgrades")

	spear = await fixture([Vector2(150, 0)])
	var body := enemies[0].get_node("CollisionShape2D") as CollisionShape2D
	var radius: float = body.shape.radius * body.global_scale.y
	enemies[0].position.y = 14 + radius + 1 - body.position.y
	await frames()
	spear._contact(spear.thrusts[0], 0, Vector2.ZERO, 220)
	check(hits.is_empty(), "outside rectangle plus actual collider misses")
	enemies[0].position.y -= 2
	await frames()
	spear._contact(spear.thrusts[0], 0, Vector2.ZERO, 220)
	check(hits.size() == 1, "collider edge contact counts even with center outside width")
	weapon.runtime_stats.area_size = 100
	check(weapon.get_attack_range() == 440 and weapon.get_hit_radius() == 14, "attack range scales reach alone")
	weapon.runtime_stats.damage_area_size = 100
	check(weapon.get_attack_range() == 440 and weapon.get_hit_radius() == 28, "damage area scales width alone")
	player.add_runtime_modifier({"id": "spear_melee", "source_type": "test", "source_id": "spear_test", "stat": "melee_damage", "operation": "add_flat", "value": 10, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
	check(weapon.get_base_attack_damage() == 24, "player melee uses one-to-one coefficient")
	weapon.runtime_stats.ranged_damage = 100
	check(weapon.get_base_attack_damage() == 24, "ranged damage does not scale spear")

	spear = await fixture([Vector2(60, 0), Vector2(170, 0)])
	wall(Vector2(110, 0))
	await frames()
	advance(spear, 0.25)
	check(hits.size() == 1 and enemies[1].current_hp == 10000, "terrain blocks primary damage behind a wall")

	spear = await fixture([Vector2(150, 70)])
	advance(spear, 0.10)
	player.position.y = 70
	advance(spear, 0.12, 0.12)
	check(hits.size() == 1 and spear.aim == Vector2.RIGHT and spear.global_position == player.global_position, "moving player carries the locked thrust and sweeps between frames")

	spear = await fixture([Vector2(150, 0), Vector2(150, 0).rotated(deg_to_rad(-20)), Vector2(150, 0).rotated(deg_to_rad(20))])
	spear.cancel()
	weapon.runtime_stats.projectile_count = 3
	weapon.runtime_stats.attack_speed = 100
	spear = motion()
	advance(spear, 0.30)
	check(hits.size() == 3 and hits.all(func(hit): return hit.damage == 14), "extra projectiles become independent full-damage thrusts")
	check(spear.cancelled and is_equal_approx(spear.time_scale, 0.5), "attack speed accelerates the whole volley")

	spear = await fixture([Vector2(130, 0), Vector2(190, 0), Vector2(270, 45), Vector2(270, -45)], ["scroll_split", "scroll_fire"])
	advance(spear, 0.23)
	check(hits.size() == 2 and shards.size() == 4, "two main contacts create four short spears")
	check(not enemies[0].has_status("burning") and not enemies[1].has_status("burning"), "split reserves the following fire attachment for short spear contacts")
	check(shards.all(func(shard): return shard.damage_event.damage == 9 and shard.damage_event.source_weapon_id == SPEAR_ID and shard._split_depth == 1), "short spear damage, attribution and generation limit")
	check(shards.all(func(shard): return is_equal_approx(shard.damage_event.get_elemental_base_damage(), 9.0)), "child elemental damage scaled once")
	var child := shards[0]
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var start := child.global_position
	child._physics_process(0.5)
	check(child.global_position == start and child.active, "pause freezes short spear movement and lifetime")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	child.damage_event.element_damage_bonus = 10
	check(is_equal_approx(child.damage_event.get_elemental_base_damage(), 13.5), "elemental bonuses inherit child multiplier without early rounding")
	child.damage_event.element_damage_bonus = 0
	var hp := enemies[0].current_hp
	for shard in shards: shard._on_body_entered(enemies[0])
	check(enemies[0].current_hp == hp, "all primary victims excluded from every short spear")
	var secondary := enemies[2] if not child.hit_targets.has(enemies[2].get_instance_id()) else enemies[3]
	hp = secondary.current_hp
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	child._on_body_entered(secondary)
	check(secondary.current_hp == hp and child.active, "overlap arriving on pause cannot deal damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	child._physics_process(0.0)
	check(secondary.current_hp < hp and secondary.has_status("burning") and shards.size() == 4 and not child.active, "short spear uses real damage and enchantments without recursive split")
	var blocker := wall(Vector2(230, 0))
	shards[1]._on_body_entered(blocker)
	check(shards[1].cancelled, "terrain consumes short spears")
	loadout.remove_weapon(SPEAR_ID)
	check(spear.cancelled and shards.all(func(shard): return shard.cancelled), "selling cancels primary and all remaining child projectiles")

	spear = await fixture([Vector2(150, 0)])
	var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "spear_test")
	check(not loadout.attach_item_to_weapon(SPEAR_ID, pierce.item_instance_id), "inherent line piercing rejects redundant pierce attachment")
	player.alive = false
	advance(spear, 0.15)
	check(spear.cancelled and hits.is_empty(), "owner death cancels before damage")

	spear = await fixture([Vector2(150, 0)], ["scroll_split"])
	advance(spear, 0.23)
	player.alive = false
	for shard in shards: shard._physics_process(0.01)
	check(shards.size() == 2 and shards.all(func(shard): return shard.cancelled), "owner death cancels airborne short spears")

	spear = await fixture([Vector2.ZERO], ["scroll_fire"])
	var fire_context := WeaponInstance.EFFECT_PARAMETERS.build_weapon_context(weapon, "fire", {"original_damage": 20, "burn_duration": 3})
	var patch := FirePatch.spawn(host, Vector2.ZERO, fire_context)
	patch.set_process(false)
	await frames()
	patch._apply_tick_damage()
	check(enemies[0].has_status("burning") and enemies[0]._burn_source_id == SPEAR_ID, "lingering fire preserves weapon attribution")
	fire_context = null

	spear = await fixture([Vector2(500, 0)])
	spear.cancel()
	weapon.attack_timer = 0
	check(not loadout._try_attack_with_weapon(weapon) and weapon.attack_timer == 0, "no target does not consume cooldown")
	enemies[0].position = Vector2(150, 0)
	await frames()
	check(loadout._try_attack_with_weapon(weapon) and weapon.attack_timer > 0, "formal loadout launches and resets cooldown")
	check(not loadout._try_attack_with_weapon(weapon), "active volley prevents overlapping sequences")
	loadout.initialize(player)
	check(get_tree().get_nodes_in_group("nightwatch_spears").all(func(node): return node.cancelled), "reinitializing loadout clears active spear")
	check_shop()
	check(DataValidator.new().validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full data validation")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	# Let the audio server release the last playback before the test quits.
	await get_tree().create_timer(0.12).timeout
	CampProgression.end_transient_session()
	print("NIGHTWATCH_SPEAR_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
