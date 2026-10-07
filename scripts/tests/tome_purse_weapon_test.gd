extends Node

const TOME := "weapon_kunyu_ritual_tome"
const PURSE := "weapon_rentier_purse"
var checks := 0
var failures := 0
var player: PlayerController
var loadout: WeaponLoadout
var manager: WaveManager
var tome: WeaponInstance
var purse: WeaponInstance
var host: Node2D
var enemies: Array[EnemyController] = []


func _ready() -> void:
	_run.call_deferred()


func frames(count: int = 4) -> void:
	for index in count:
		await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func modifier(stat: String, value: float) -> void:
	player.add_runtime_modifier({"id": "tome_purse_" + stat, "source_type": "test", "source_id": "tome_purse",
		"stat": stat, "operation": "add_flat", "value": value, "duration": -1,
		"stack_rule": "replace_same_source", "target_scope": "player"})


func fixture(offsets: Array) -> void:
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		node.free()
	if is_instance_valid(host): host.free()
	host = Node2D.new()
	player.get_parent().add_child(host)
	enemies.clear()
	for offset: Vector2 in offsets:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.global_position = player.global_position + offset
		enemy.current_hp = 1000
		enemy.set_physics_process(false)
		enemies.append(enemy)


func coins() -> Array[CoinProjectile]:
	var result: Array[CoinProjectile] = []
	for node in get_tree().get_nodes_in_group("coin_projectiles"):
		if not node.cancelled:
			node.set_physics_process(false)
			result.append(node)
	return result


func shot(shared: Dictionary = {}, heading: Vector2 = Vector2.RIGHT) -> CoinProjectile:
	var coin := CoinProjectile.new()
	host.add_child(coin)
	coin.initialize(purse, purse.calculate_damage_events()[0], player.global_position, heading, shared)
	coin.set_physics_process(false)
	return coin


func attach(weapon: WeaponInstance, item_id: String) -> Dictionary:
	var item := player.item_inventory.add_item_from_base(item_id, "tome_purse_test")
	check(loadout.attach_item_to_weapon(weapon.weapon_id, item.item_instance_id), item_id + " attaches to " + weapon.weapon_id)
	return item


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [TOME, PURSE])
	await frames()
	check(flow.confirm_character_selection(), "both weapons start through real selection flow")
	(game.get_node("SceneDirector") as GameSceneDirector).battle_root.set_process(false)
	await frames(8)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	player.set_physics_process(false)
	for old_enemy in EnemyRegistry.get_registered_enemies().duplicate(): old_enemy.free()
	tome = loadout.get_weapon_instance(TOME)
	purse = loadout.get_weapon_instance(PURSE)
	tome.runtime_stats.crit_chance = 0
	purse.runtime_stats.crit_chance = 0
	_test_body_sizes_and_contact()
	check(loadout.get_total_load_cost() == 50 and tome.get_attachment_slot_count() == 2 and purse.get_attachment_slot_count() == 1, "load and rarity attachment slots integrate")
	check(tome.calculate_damage_events()[0].damage == 10 and tome.calculate_damage_events()[0].damage_kind == "element", "native tome is ten elemental damage")
	check(purse.calculate_damage_events()[0].damage == 4 and purse.get_stat("projectile_count") == 3, "native purse has three four-damage coins at zero principal")
	manager.finance_system.deposit(400, true, "test")
	check(purse.get_current_principal() == 400 and player.get_stat("finance") == 0, "purse reads live bank balance rather than starting finance talent")
	modifier("ranged_damage", 10)
	modifier("element_damage", 7)
	modifier("melee_damage", 100)
	modifier("damage_percent", 20)
	check(purse.calculate_damage_events()[0].damage == 19, "purse combines ranged and sqrt principal before percent and final rounding")
	var elemental := tome.calculate_damage_events()[0]
	check(elemental.damage == 20 and elemental.element_damage_bonus == 0 and elemental.get_elemental_base_damage() == 20, "elemental bonus enters tome and attachment basis exactly once")
	check(purse.calculate_damage_events(true)[0].damage == 29 and tome.calculate_damage_events(true)[0].damage == 31, "both support critical scaling before rounding")
	manager.finance_system.deposit(500, true, "test")
	check(purse.calculate_damage_events()[0].damage == 23, "next shot reflects changed principal")
	check(purse.build_full_stats_text().contains("[color=#7FD88F]+6[/color][color=#F5D76E]+9[/color]")
		and tome.build_full_stats_text().contains("[color=#78B7FF]+7[/color]"), "details show resolved live principal ranged and elemental contributions")
	modifier("attack_speed", 100)
	check(is_equal_approx(tome.get_actual_attack_interval_seconds(), 0.6) and is_equal_approx(purse.get_actual_attack_interval_seconds(), 0.825), "100 attack speed keeps 75 percent of both intervals")
	modifier("area_size", 50)
	check(tome.get_domain_axes() == Vector2(275,181.25) and purse.get_attack_range() == 350, "attack range scales ellipse and coin travel")
	modifier("damage_area_size", 100)
	check(tome.get_domain_axes() == Vector2(275,181.25), "damage area does not silently change domain targeting")
	player.remove_runtime_modifiers_by_source("test", "tome_purse")
	check(manager.finance_system.withdraw(900).success and purse.get_base_attack_damage() == 4, "withdrawing bank balance immediately removes principal scaling")
	fixture([Vector2(219,0), Vector2(221,0), Vector2(0,144), Vector2(0,146), Vector2(200,100)])
	var domain := loadout._ensure_ritual_domain(tome)
	check(domain.contains_enemy(enemies[0]) and domain.contains_enemy(enemies[2]) and not domain.contains_enemy(enemies[1]) and not domain.contains_enemy(enemies[3]) and not domain.contains_enemy(enemies[4]), "ellipse checks axes and diagonal rather than bounding rectangle")
	check(domain.try_attack() and enemies.filter(func(e): return e.current_hp < 1000).size() == 1, "one native tick hits exactly one in-domain target")
	var origin := player.global_position
	player.global_position += Vector2(30,-20)
	domain._physics_process(0.1)
	check(domain.global_position == player.global_position and domain.boundary_particles.size() == 144 and domain.outer_particles.size() == 24, "approved domain follows player with unchanged particle counts")
	var clock := domain.elapsed
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	domain._physics_process(1)
	tome.attack_timer = 0.4
	loadout.tick(1)
	check(domain.elapsed == clock and tome.attack_timer == 0.4 and not domain.try_attack(), "pause freezes domain, damage and cooldown")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	player.global_position = origin
	fixture([])
	tome.attack_timer = 0
	check(not loadout._try_attack_with_weapon(tome) and tome.attack_timer == 0, "empty domain consumes no attack")
	fixture([Vector2(100,0),Vector2(-100,0),Vector2(0,100),Vector2(0,-100),Vector2(70,60),Vector2(260,0)])
	var split := attach(tome, "scroll_split")
	var fire := attach(tome, "scroll_fire")
	domain = loadout._ensure_ritual_domain(tome)
	enemies[0].current_hp = 1
	domain.try_attack()
	var changed := enemies.slice(0,5).filter(func(e): return e.current_hp != 1000 and e.current_hp != 1)
	var burning := enemies.slice(0,5).filter(func(e): return e.has_status("burning"))
	check(changed.size() == 3 and burning.size() == 2, "tome split affects three distinct contacts and fire applies only to the two child contacts")
	check(enemies[5].current_hp == 1000 and not enemies[5].has_status("burning"), "tome native and split contacts stay inside domain")
	loadout.detach_item_from_weapon(TOME, fire.item_instance_id)
	loadout.detach_item_from_weapon(TOME, split.item_instance_id)
	fixture([Vector2(100,0),Vector2(-100,0)])
	modifier("projectile_count", 8)
	domain = loadout._ensure_ritual_domain(tome)
	domain.try_attack()
	check(enemies.all(func(e): return e.current_hp == 990), "extra tome projectiles reserve unique targets without repeat damage")
	player.remove_runtime_modifiers_by_source("test", "tome_purse")
	fixture([Vector2(200, 0)])
	purse.volley_index = 0
	loadout._try_attack_with_weapon(purse)
	var volley := coins()
	check(volley.size() == 3 and is_equal_approx(volley[0].direction.dot(volley[1].direction), cos(deg_to_rad(10))), "real loadout emits three coins spaced ten degrees")
	loadout._try_attack_with_weapon(purse)
	volley = coins()
	check(volley.size() == 6 and volley[3].direction.is_equal_approx(volley[0].direction), "same target keeps the next volley centered on the same aim")
	fixture([Vector2(100,0),Vector2(200,0)])
	var shared: Dictionary = {}
	var coin := shot(shared)
	var twin := shot(shared)
	coin._physics_process(0.7)
	twin._physics_process(0.7)
	check(enemies[0].current_hp == 996 and enemies[1].current_hp == 996 and shared.size() == 2, "swept coins do not tunnel or repeat a same-volley contact")
	fixture([Vector2(100,0),Vector2(200,0)])
	var pierce := attach(purse, "scroll_pierce")
	coin = shot()
	coin._physics_process(0.7)
	check(enemies.all(func(e): return e.current_hp == 996), "pierce processes ordered contacts in one large frame")
	check(not loadout.attach_item_to_weapon(TOME, pierce.item_instance_id) and player.item_inventory.find_item(pierce.item_instance_id).equipped_weapon_id == PURSE, "incompatible pierce transfer preserves its purse owner")
	loadout.detach_item_from_weapon(PURSE, pierce.item_instance_id)
	check(loadout.upgrade_weapon(PURSE) and loadout.upgrade_weapon(PURSE) and purse.get_attachment_slot_count() == 2, "rare purse unlocks a second slot")
	fixture([Vector2(90,0),Vector2(180,40),Vector2(180,-40)])
	split = attach(purse, "scroll_split")
	fire = attach(purse, "scroll_fire")
	manager.finance_system.deposit(400, true, "test")
	coin = shot()
	enemies[0].current_hp = 1
	coin._physics_process(0.22)
	var children := coins().filter(func(c): return c.split_generation == 1)
	check(children.size() == 2 and not enemies[0].is_alive(), "lethal purse hit still launches two split coins")
	for child in children: child._physics_process(0.4)
	check(enemies[1].current_hp == 995 and enemies[2].current_hp == 995 and enemies[1].has_status("burning") and enemies[2].has_status("burning"), "rare purse split coins deal forty-five percent damage and carry fire")
	check(coins().is_empty(), "split coins stop at one generation")
	check(manager.finance_system.principal == 400, "firing and split never spend principal")
	loadout.detach_item_from_weapon(PURSE, fire.item_instance_id)
	loadout.detach_item_from_weapon(PURSE, split.item_instance_id)
	manager.finance_system.withdraw(400)
	player.remove_runtime_modifiers_by_source("test", "tome_purse")
	fixture([Vector2(320,0)])
	coin = shot()
	coin._physics_process(2)
	check(coin.cancelled and is_equal_approx(coin.distance_travelled, 280) and enemies[0].current_hp == 1000, "coin expires at actual range without overshoot")
	await _test_coin_body_contacts()
	fixture([])
	coin = shot()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	coin._physics_process(1)
	check(coin.global_position == player.global_position and coin.age == 0, "pause freezes coin position and spin")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	domain = loadout._ensure_ritual_domain(tome)
	manager.clear_battle_entities()
	coin._physics_process(1)
	check(coin.cancelled and domain.cancelled and coin.age == 0, "wave cleanup immediately cancels projectiles and domain")
	loadout.tick(0)
	check(not loadout._ensure_ritual_domain(tome).cancelled, "next combat tick recreates persistent domain")
	var taken := loadout.take_weapon_for_trade(TOME)
	check(taken == tome and not loadout.has_weapon(TOME), "trade removes live domain weapon")
	loadout.restore_traded_weapon(taken, 0)
	check(loadout.has_weapon(TOME) and not loadout._ensure_ritual_domain(tome).cancelled, "trade rollback restores operational domain")
	for index in 4:
		check(loadout.upgrade_weapon(TOME) and (purse.level == 5 or loadout.upgrade_weapon(PURSE)), "both upgrade towards maximum on step %d" % (index + 2))
	check(tome.get_base_attack_damage() == 22 and purse.get_base_attack_damage() == 8 and not tome.upgrade() and not purse.upgrade(), "level five gains persist and max level is enforced")
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity": 100, "current_load": 0})
	check(pool.any(func(o): return o.target_id == TOME) and pool.any(func(o): return o.target_id == PURSE), "both enter shared shop and reward pool")
	var limited := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity": 13, "current_load": 0})
	check(not limited.any(func(o): return o.target_id in [TOME, PURSE]), "candidate filtering respects remaining load")
	var owned := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity":100, "owned_weapon_ids":[TOME,PURSE], "equipped_weapons":[{"weapon_id":TOME,"level":1},{"weapon_id":PURSE,"level":1}]})
	check(owned.filter(func(o): return o.target_id in [TOME,PURSE]).all(func(o): return o.offer_type == "weapon_upgrade"), "owned weapons offer upgrades instead of duplicates")
	check(InventoryTradeService.new().quote_weapon(tome).upgrade_value > 0, "sale quote includes implemented upgrades")
	manager.apply_gold_delta(1000, "test")
	flow.finish_current_wave()
	await frames(20)
	check(flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "real wave end opens preparation finance")
	for weapon_id in [TOME, PURSE]:
		check(flow.submit_enchantment_operation("attach", weapon_id, fire.item_instance_id).success, "finance attaches an element to " + weapon_id)
		var quote := flow.get_inventory_sale_quote("weapon", weapon_id)
		var gold_before := manager.get_current_gold()
		check(flow.submit_inventory_sale("weapon", weapon_id, quote.quote_token).success and manager.get_current_gold() == gold_before + int(quote.total), "real sale credits the quoted value for " + weapon_id)
		check(not loadout.has_weapon(weapon_id) and player.item_inventory.find_item(fire.item_instance_id).equipped_weapon_id == "", "sale returns the attachment and removes the weapon")
		var offer: Dictionary = pool.filter(func(o): return o.target_id == weapon_id and o.offer_type == "new_weapon")[0]
		ShopPricing.apply(offer, flow._build_shop_context())
		flow._active_shop_offers[offer.offer_id] = offer.duplicate(true)
		gold_before = manager.get_current_gold()
		check(flow.submit_shop_purchase(offer, "shop").success and loadout.has_weapon(weapon_id) and manager.get_current_gold() == gold_before - int(offer.shop_cost), "real purchase deducts cost and equips " + weapon_id)
		var upgrade: Dictionary = owned.filter(func(o): return o.target_id == weapon_id and o.offer_type == "weapon_upgrade")[0]
		ShopPricing.apply(upgrade, flow._build_shop_context())
		flow._active_shop_offers[upgrade.offer_id] = upgrade.duplicate(true)
		check(flow.submit_shop_purchase(upgrade, "shop").success and loadout.get_weapon_instance(weapon_id).level == 2, "real purchase applies next-level upgrade")
	check(flow.submit_enchantment_operation("attach", TOME, pierce.item_instance_id).reason == "incompatible_enchantment", "finance authority rejects tome pierce")
	flow.request_battle_utility("settings")
	flow.return_to_main_menu_from_settings()
	await frames(12)
	check(get_tree().get_nodes_in_group("coin_projectiles").is_empty() and get_tree().get_nodes_in_group("ritual_domains").is_empty(), "return to menu removes weapon runtime nodes")
	game.queue_free()
	await frames(3)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	CampProgression.end_transient_session()
	await get_tree().create_timer(0.3).timeout
	print("TOME_PURSE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_body_sizes_and_contact() -> void:
	for character in ["character_void_hunter", "character_capitalist"]:
		var actor := preload("res://scenes/player/player_root.tscn").instantiate() as PlayerController
		actor.auto_initialize_on_ready = false
		actor.get_node("Camera2D").free()
		add_child(actor)
		actor.set_physics_process(false)
		for repeat in 2:
			actor.initialize_from_character(character)
			actor._set_facing(false)
			check(actor.visual_anchor.scale == Vector2(-1.2, 1.2), "left-facing player keeps 1.2 scale: " + character)
			actor._set_facing(true)
			check(actor.visual_anchor.scale == Vector2(1.2, 1.2), "right-facing player keeps 1.2 scale: " + character)
		var shape := actor.get_node("CollisionShape2D") as CollisionShape2D
		check(is_equal_approx(shape.shape.radius, 10.08) and is_equal_approx(shape.shape.height, 55.2) and shape.position == Vector2.ZERO, "capsule follows enlarged central body")
		check(actor.get_node("PickupArea/CollisionShape2D").shape.radius == actor.get_stat("pickup_radius"), "visual scale does not multiply pickup radius")
		actor.free()
	fixture([Vector2(40, 0)])
	var enemy := enemies[0]
	var shape := enemy.get_node("CollisionShape2D") as CollisionShape2D
	check(enemy.sprite.scale.is_equal_approx(Vector2(0.44, 0.44)) and enemy.sprite.position.is_equal_approx(Vector2(0, 1.76)) and shape.position.is_equal_approx(Vector2(0, -7.04)) and is_equal_approx(shape.shape.radius, 19.36), "small enemy uses approved 128px art and 1.1x body")
	check(not enemy._is_touching_player(), "no contact damage across visible 40px gap")
	enemy.global_position = player.global_position + Vector2(28, 0)
	check(enemy._is_touching_player(), "physical body contact includes slide safe margin")
	shape.disabled = true
	check(not enemy._is_touching_player(), "disabled body cannot contact player")
	var boss := preload("res://scenes/enemy/elite_rusher.tscn").instantiate()
	check(boss.get_node("Sprite2D").scale == Vector2(0.56, 0.56) and boss.get_node("CollisionShape2D").shape is CapsuleShape2D and boss.get_node("CollisionShape2D").position == Vector2(0, -46), "boss retains its art size with a capsule inside the sprite")
	boss.free()


func _test_coin_body_contacts() -> void:
	for offset in [Vector2(100, 36), Vector2(100, -25), Vector2(300, 0)]:
		fixture([offset])
		var coin := shot()
		coin._physics_process(2.0)
		check(enemies[0].current_hp < 1000, "coin hits real body edge even when root point is outside ray: " + str(offset))
	for offset in [Vector2(100, 42), Vector2(100, -28)]:
		fixture([offset])
		var coin := shot()
		coin._physics_process(2.0)
		check(enemies[0].current_hp == 1000, "coin misses outside body and projectile radii: " + str(offset))
	fixture([Vector2(100, 60)])
	var body := enemies[0].get_node("CollisionShape2D") as CollisionShape2D
	body.position = Vector2(0, -60)
	var coin := shot()
	coin._physics_process(1)
	check(enemies[0].current_hp < 1000, "coin follows collider offset rather than entity root")
	fixture([Vector2(100, 0)])
	body = enemies[0].get_node("CollisionShape2D")
	body.disabled = true
	coin = shot()
	coin._physics_process(1)
	check(enemies[0].current_hp == 1000, "disabled collision body is skipped")
	fixture([Vector2(100, 20)])
	body = enemies[0].get_node("CollisionShape2D")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 20)
	body.shape = rectangle
	coin = shot()
	coin._physics_process(1)
	check(enemies[0].current_hp < 1000, "non-circle enemy uses actual swept shape")
	fixture([Vector2(150, 0)])
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(4, 80)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	host.add_child(wall)
	wall.global_position = player.global_position + Vector2(80, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	coin = shot()
	coin._physics_process(1)
	check(enemies[0].current_hp == 1000 and coin.cancelled and coin.distance_travelled < 78, "swept coin radius stops at wall before enemy")
