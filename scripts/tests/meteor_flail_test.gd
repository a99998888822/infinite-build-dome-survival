extends "res://scripts/tests/pixel_combat_effect_test.gd"

const FLAIL := "weapon_meteor_flail"
const PLASMA := "weapon_plasma_cannon"
var player: PlayerController
var loadout: WeaponLoadout
var hits: Array[Dictionary] = []


func fixture(positions: Array, attachments: Array = []) -> MeteorFlail:
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
	loadout.equip_weapon(FLAIL)
	weapon = loadout.get_weapon_instance(FLAIL)
	weapon.runtime_stats.crit_chance = 0
	for id in attachments:
		var item := player.item_inventory.add_item_from_base(id, "flail_test")
		check(loadout.attach_item_to_weapon(FLAIL, item.item_instance_id), "attach real inventory item " + str(id))
	var flail := MeteorFlail.new()
	host.add_child(flail)
	flail.initialize(weapon, Vector2.RIGHT)
	flail.set_physics_process(false)
	hits.clear()
	flail.target_hit.connect(func(id: int, damage: int, child: bool): hits.append({"id": id, "damage": damage, "child": child}))
	await frames()
	return flail


func advance(flail: MeteorFlail, seconds: float, step: float = 1.0 / 60.0) -> void:
	var remaining := seconds
	while remaining > 0.00001 and not flail.cancelled:
		var delta := minf(remaining, step)
		flail._physics_process(delta)
		remaining -= delta


func check_refresh() -> void:
	var generator := ShopOfferGenerator.new()
	var context := {"load_capacity": 100, "current_load": 0, "luck": 0}
	var pool := generator.build_shop_candidate_pool(context)
	var rarity := generator.get_shop_rarity_weights(0)
	check(rarity.epic == 0 and rarity.rare > 0, "baseline rarity gates still protect epic relics")
	check(pool.any(func(offer): return offer.target_id == PLASMA and offer.rarity == "rare"), "plasma has an eligible baseline candidate")
	var types := generator.get_shop_type_weights({"candidate_pool": pool, "load_capacity": 100, "current_load": 0})
	seed(9252026)
	var free_found := false
	var paid_found := false
	var flail_found := false
	for index in 400:
		var free := generator.roll_shop_offers(rarity, types, pool, 3)
		var paid := generator.roll_paid_offers(rarity, types, pool, 5, index)
		free_found = free_found or free.any(func(offer): return offer.target_id == PLASMA)
		paid_found = paid_found or paid.any(func(offer): return offer.target_id == PLASMA)
		flail_found = flail_found or paid.any(func(offer): return offer.target_id == FLAIL)
	check(free_found and paid_found, "plasma actually rolls in zero-luck free rewards and paid refreshes")
	check(flail_found, "flail actually rolls in baseline shop")
	context.owned_weapon_ids = [PLASMA]
	check(not generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == PLASMA), "owned plasma excluded")
	context.owned_weapon_ids = []
	context.current_load = 77
	check(not generator.build_shop_candidate_pool(context).any(func(offer): return offer.target_id == PLASMA), "plasma still respects remaining load")


func _run() -> void:
	CampProgression.begin_transient_session()
	var flail := await fixture([Vector2(140, 0), Vector2(45, 0), Vector2(-100, 0)])
	check(weapon.get_attack_kind() == "melee" and weapon.calculate_damage_events()[0].damage == 22, "native melee damage event")
	weapon.runtime_stats.ranged_damage = 100
	check(weapon.calculate_damage_events()[0].damage == 22, "ranged damage never scales flail")
	weapon.runtime_stats.melee_damage += 10
	check(weapon.calculate_damage_events()[0].damage == 32, "melee stat scales damage")
	weapon.runtime_stats.melee_damage -= 10
	check(weapon.get_load_cost() == 18 and weapon.get_attachment_slot_count() == 3, "load and attachment slots")
	check(weapon.build_full_stats_text().contains("近战伤害") and weapon.build_full_stats_text().contains("22 / 33"), "details show melee and outer damage")
	advance(flail, 0.17)
	check(hits.is_empty(), "windup has no damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(flail, 0.5)
	check(is_equal_approx(flail.age, 0.17) and hits.is_empty(), "pause freezes swing and contact")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	advance(flail, 0.60, 0.60)
	check(hits.size() == 1 and hits[0].damage == 33, "large time step sweeps the curve, outer contact hits once")
	check(enemies[1].current_hp == 10000 and enemies[2].current_hp == 10000, "chain and rear enemies receive no sector damage")
	check(flail.heading == Vector2.RIGHT, "attack direction remains locked")
	advance(flail, 0.4)
	check(flail.cancelled and not flail.visible, "weapon disappears after recovery")
	for index in range(4): check(weapon.upgrade(), "level upgrade " + str(index + 2))
	check(weapon.get_base_attack_damage() == 42 and not weapon.upgrade(), "four upgrades reach forty-two and stop at level five")

	flail = await fixture([Vector2(140, 0)])
	var near_time := 0.18
	var head := flail.head_position(flail.swings[0], near_time)
	var radius: float = enemies[0].get_node("CollisionShape2D").shape.radius
	enemies[0].position = head + Vector2.RIGHT * (flail.head_radius(flail.swings[0]) + radius + 0.8)
	await frames()
	flail._sweep_contacts(flail.swings[0], head, head, near_time)
	check(hits.is_empty(), "outside actual head plus enemy collider stays unharmed")
	enemies[0].position.x -= 1.6
	await frames()
	flail._sweep_contacts(flail.swings[0], head, head, near_time)
	check(hits.size() == 1 and hits[0].damage == 22, "inner visible contact gives baseline damage")
	player.add_runtime_modifier({"id": "melee_bonus", "source_type": "test", "source_id": "flail_test",
		"stat": "melee_damage", "operation": "add_flat", "value": 10, "duration": -1,
		"stack_rule": "unique", "target_scope": "player"})
	check(weapon.get_base_attack_damage() == 34, "player melee bonus uses the configured 1.2 coefficient")
	weapon.runtime_stats.area_size = 100
	check(flail.head_radius(flail.swings[0]) == 32 and is_equal_approx(flail.head_position(flail.swings[0], 0.455).length(), 288), "range growth updates rendered trajectory and contact radius together")
	flail.cancel()
	weapon.runtime_stats.area_size = 0
	weapon.runtime_stats.attack_speed = 100
	flail = MeteorFlail.new()
	host.add_child(flail)
	flail.initialize(weapon, Vector2.RIGHT)
	flail.set_physics_process(false)
	flail.sparks.append({"point": Vector2.ZERO, "velocity": Vector2.ZERO, "life": 1.0})
	advance(flail, 0.44)
	check(is_equal_approx(flail.age, 0.88) and not flail.is_swinging(), "attack speed scales windup, sweep and recovery as well as cooldown")
	enemies[0].position = Vector2(140, 0)
	await frames()
	check(loadout._try_attack_with_weapon(weapon), "lingering cosmetic sparks cannot block the next loadout attack")
	flail.cancel()

	flail = await fixture([Vector2(140, 0)], ["scroll_split", "scroll_fire"])
	advance(flail, 1.49)
	check(flail.swings.size() == 3 and hits.filter(func(hit): return hit.child).size() == 2, "one split adds exactly two real contact sweeps, no recursion")
	check(hits.all(func(hit): return hit.damage == (20 if hit.child else 33)), "split and outer multipliers apply once")
	check(enemies[0].has_status("burning"), "native contacts trigger actual fire enchantment")
	var split_swing := flail.swings[1]
	split_swing.event.element_damage_bonus = 10
	var child_event := flail.damage_for_contact(split_swing, float(split_swing.start) + 0.03 + 0.16)
	check(is_equal_approx(child_event.get_elemental_base_damage(), 28.8), "elemental base scales both weapon and bonus once without early rounding")
	var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "flail_test")
	check(not loadout.attach_item_to_weapon(FLAIL, pierce.item_instance_id), "incompatible pierce rejected")

	flail = await fixture([Vector2(140, 0), Vector2(210, 0)], ["scroll_lightning"])
	advance(flail, 0.7)
	await get_tree().create_timer(0.30).timeout
	check(enemies[1].current_hp < 10000 and hits.size() == 1, "lightning damages an out-of-reach secondary enemy through real enchantment")

	flail = await fixture([Vector2(140, 0), Vector2(142, 4)], ["scroll_fire"])
	advance(flail, 0.7)
	check(hits.size() == 2 and enemies.all(func(enemy): return enemy.has_status("burning")), "all contacted enemies receive enchantments independently")
	loadout.remove_weapon(FLAIL)
	check(flail.cancelled, "selling removes the active weapon effect immediately")

	flail = await fixture([Vector2(500, 0)])
	flail.cancel()
	check(not loadout._try_attack_with_weapon(weapon), "no nearby target means no attack")
	enemies[0].position = Vector2(140, 0)
	await frames()
	check(loadout._try_attack_with_weapon(weapon), "native loadout launches a flail")
	check(not loadout._try_attack_with_weapon(weapon), "one instance cannot overlap attack sequences")
	loadout._clear_weapon_runtime(weapon)
	check(get_tree().get_nodes_in_group("meteor_flails").all(func(node): return node.cancelled), "runtime cleanup cancels every active flail")
	check_refresh()
	check(DataValidator.new().validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full configuration validation")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("METEOR_FLAIL_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
