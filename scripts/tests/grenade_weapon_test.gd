extends Node

const WEAPON := "weapon_iron_grenade_cannon"
var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var player: PlayerController
var loadout: WeaponLoadout
var manager: WaveManager
var weapon: WeaponInstance
var host: Node2D
var enemies: Array[EnemyController] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(100).timeout
	push_error("GRENADE_TEST_TIMEOUT")
	get_tree().quit(99)


func frames(count: int = 4) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	var paused := bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)
	GameGlobal.set_runtime_flag("battle_runtime_paused", paused)


func fixture(offsets: Array) -> void:
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


func grenade(target: Vector2, event: DamageEvent = null) -> GrenadeProjectile:
	var projectile := GrenadeProjectile.new()
	host.add_child(projectile)
	projectile.initialize(weapon, event if event != null else weapon.calculate_damage_events()[0], player.global_position, target)
	projectile.set_physics_process(false)
	return projectile


func add_modifier(stat: String, value: float) -> void:
	player.add_runtime_modifier({"id": "grenade_" + stat, "source_type": "test", "source_id": "grenade", "stat": stat, "operation": "add_flat", "value": value, "duration": -1, "stack_rule": "replace_same_source", "target_scope": "player"})


func split_children() -> Array[GrenadeProjectile]:
	var result: Array[GrenadeProjectile] = []
	for node in get_tree().get_nodes_in_group("grenade_projectiles"):
		if node.split_generation > 0 and not node.is_queued_for_deletion():
			node.set_physics_process(false)
			result.append(node)
	return result


func clear_grenades() -> void:
	for node in get_tree().get_nodes_in_group("grenade_projectiles"):
		node.free()


func test_split(split: Dictionary) -> void:
	clear_grenades()
	var offsets: Array = [Vector2(200, 0), Vector2(210, 25), Vector2(245, 0), Vector2(280, 0)]
	for index in 8:
		offsets.append(Vector2(245, 0) + Vector2.RIGHT.rotated(TAU * index / 8.0) * 138)
	fixture(offsets)
	var shot := grenade(player.global_position + Vector2(245, 0))
	shot._physics_process(0.45)
	var children := split_children()
	check(children.size() == 8, "four primary victims create eight production child grenades")
	var landings: Dictionary = {}
	for child in children:
		landings[child.target_position] = true
	check(landings.size() == 8, "siblings reserve distinct outer targets")
	check(children.all(func(child): return child.damage_event.damage == 10 and child.blast_radius == 32 and child.flight_seconds == 0.32 and child.arc_height == 32), "children use approved damage radius flight and arc")
	check(children.all(func(child): return child.excluded_target_ids.size() == 4 and child.excluded_target_ids.is_read_only()), "all siblings share immutable primary-hit exclusions")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	for child in children: child._physics_process(1.0)
	check(children.all(func(child): return child.elapsed == 0 and not child.exploded), "pause freezes every child grenade")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for child in children: child._physics_process(0.32)
	check(split_children().size() == 8 and children.all(func(child): return child.hit_target_ids.size() == 1), "child hits never create grandchildren")
	check(enemies.slice(0, 4).all(func(enemy): return enemy.current_hp == 984) and enemies.slice(4).all(func(enemy): return enemy.current_hp == 990), "core takes only primary damage and outer targets take child damage")
	shot._detonate()
	for child in children: child._detonate()
	check(split_children().size() == 8 and enemies[4].current_hp == 990, "duplicate detonation cannot duplicate children or damage")
	fixture([Vector2(200, 0), Vector2(330, 0)])
	shot = grenade(player.global_position + Vector2(200, 0))
	shot._physics_process(0.45)
	children = split_children()
	for child in children:
		child.target_position = enemies[0].global_position
		child._physics_process(0.32)
	check(enemies[0].current_hp == 984 and children.all(func(child): return child.hit_target_ids.is_empty()), "child landing on primary victim still excludes its native damage and enchantments")
	fixture([Vector2(200, 0), Vector2(330, 0), Vector2(350, 40)])
	enemies[0].current_hp = 1
	shot = grenade(player.global_position + Vector2(200, 0))
	shot._physics_process(0.45)
	children = split_children()
	check(not enemies[0].is_alive() and children.size() == 2 and children.all(func(child): return child.start_position == player.global_position + Vector2(200, 0)), "lethal primary hit still splits at captured contact position")
	var fixed_landing := children[0].target_position
	enemies[1].global_position += Vector2(500, 0)
	enemies[2].global_position += Vector2(500, 0)
	for child in children: child._physics_process(0.32)
	check(children[0].target_position == fixed_landing and children.all(func(child): return child.hit_target_ids.is_empty()), "child landing stays fixed and misses moved targets")
	fixture([])
	shot = grenade(player.global_position + Vector2(200, 0))
	shot._physics_process(0.45)
	check(split_children().is_empty(), "missed primary explosion never splits")
	fixture([Vector2(200, 0), Vector2(330, 0), Vector2(340, 12)])
	var fire := player.item_inventory.add_item_from_base("scroll_fire", "grenade_split_test")
	check(loadout.attach_item_to_weapon(WEAPON, fire.item_instance_id), "split and fire share the two slots")
	shot = grenade(player.global_position + Vector2(200, 0))
	shot._physics_process(0.45)
	children = split_children()
	for child in children: child._physics_process(0.32)
	check(children.all(func(child): return child.impact_batches == 2) and enemies[1].has_status("burning") and enemies[2].has_status("burning"), "each child applies enchantments to every secondary blast victim")
	check(enemies[1].current_hp == 980 and enemies[2].current_hp == 980 and split_children().size() == 2, "sibling blasts may overlap without recursively splitting")
	loadout.detach_item_from_weapon(WEAPON, fire.item_instance_id)
	var extra := player.item_inventory.add_item_from_base("scroll_split", "grenade_split_test")
	# Inventory getters return copies; replace the fixture's stored item too.
	extra = player.item_inventory.take_unequipped_item_for_trade(extra.item_instance_id)
	extra.rolled_parameters = {"child_count": 4, "spread_angle": 48}
	player.item_inventory.restore_traded_item(extra)
	check(loadout.attach_item_to_weapon(WEAPON, extra.item_instance_id), "second split instance attaches")
	fixture([Vector2(200, 0)])
	add_modifier("damage_area_size", 50)
	shot = grenade(player.global_position + Vector2(200, 0), weapon.calculate_damage_events(true)[0])
	shot._physics_process(0.45)
	children = split_children()
	check(children.size() == 6, "independent rolled split counts add two plus four")
	check(children.all(func(child): return child.blast_radius == 48 and child.damage_event.damage == 14 and child.damage_event.is_critical), "children inherit area once and scale the original critical result")
	check(weapon.get_grenade_split_profiles()[1].child_count == 4 and weapon.build_full_stats_text().contains("48"), "resolved split values reach weapon details")
	player.remove_runtime_modifiers_by_source("test", "grenade")
	loadout.detach_item_from_weapon(WEAPON, extra.item_instance_id)
	fixture([Vector2(200, 0)])
	weapon.runtime_stats.projectile_count = 2
	loadout._try_attack_with_weapon(weapon)
	var roots: Array[GrenadeProjectile] = []
	for node in get_tree().get_nodes_in_group("grenade_projectiles"):
		if node.split_generation == 0:
			node.set_physics_process(false)
			roots.append(node)
	for root in roots: root._physics_process(0.45)
	check(roots.size() == 2 and split_children().size() == 4, "each real loadout projectile splits independently")
	weapon.runtime_stats.projectile_count = 1
	children = split_children()
	manager.clear_battle_entities()
	for child in children: child._physics_process(1)
	check(children.all(func(child): return child.cancelled and not child.exploded), "wave cleanup cancels all airborne children")
	clear_grenades()
	var crowd: Array = []
	for index in 80: crowd.append(Vector2(180 + index % 10 * 2, index / 10 * 2))
	fixture(crowd)
	shot = grenade(player.global_position + Vector2(190, 8))
	var started := Time.get_ticks_usec()
	shot._physics_process(0.45)
	children = split_children()
	check(children.size() == 160, "dense blast has no hidden primary-target or child-count cap")
	for child in children: child._physics_process(0.32)
	check(split_children().size() == 160 and enemies.all(func(enemy): return enemy.current_hp == 984), "dense child bursts exclude all primary victims and stop at one generation")
	print("GRENADE_SPLIT_STRESS victims=80 children=160 simulation_us=", Time.get_ticks_usec() - started)
	clear_grenades()
	loadout.detach_item_from_weapon(WEAPON, split.item_instance_id)


func _run() -> void:
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [WEAPON])
	await frames()
	check(flow.confirm_character_selection(), "grenade can start a real battle")
	(game.get_node("SceneDirector") as GameSceneDirector).battle_root.set_process(false)
	await frames(8)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	for old_enemy in EnemyRegistry.get_registered_enemies().duplicate(): old_enemy.free()
	for old in get_tree().get_nodes_in_group("grenade_projectiles"): old.free()
	player.set_physics_process(false)
	weapon = loadout.get_weapon_instance(WEAPON)
	weapon.runtime_stats.crit_chance = 0
	check(weapon != null and loadout.get_total_load_cost() == 25, "config equips with correct load")
	check(weapon.get_attachment_slot_count() == 2, "two attachment slots")
	check(weapon.calculate_damage_events()[0].damage == 16, "base native damage 16")
	check(weapon.calculate_damage_events(true)[0].damage == 24, "critical damage 150 percent")
	check(is_equal_approx(weapon.get_actual_attack_interval_seconds(), 1.8), "base interval 1.8 seconds")
	add_modifier("ranged_damage", 10)
	add_modifier("damage_percent", 20)
	check(weapon.calculate_damage_events()[0].damage == 34, "coefficient applies to player damage before percent and rounding")
	add_modifier("element_damage", 100)
	add_modifier("melee_damage", 100)
	check(weapon.calculate_damage_events()[0].damage == 34, "native blast ignores melee and element bonuses")
	check(weapon.calculate_damage_events()[0].element_damage_bonus == 100, "element bonus remains available for attachments")
	add_modifier("area_size", 50)
	check(weapon.get_attack_range() == 630 and weapon.get_grenade_blast_radius() == 64, "attack range does not enlarge blast")
	add_modifier("damage_area_size", 50)
	check(weapon.get_grenade_blast_radius() == 96 and weapon.get_attack_range() == 630, "blast area scales independently")
	add_modifier("attack_speed", 100)
	check(is_equal_approx(weapon.get_actual_attack_interval_seconds(), 0.9), "attack speed changes launch interval")
	var stats := weapon.build_full_stats_text()
	check(stats.contains("1.2") and stats.contains("96") and stats.contains("0.45"), "tooltip displays coefficient radius and fixed flight time")
	player.remove_runtime_modifiers_by_source("test", "grenade")
	for level in range(2, 6):
		check(loadout.upgrade_weapon(WEAPON) and weapon.get_weapon_stat("ranged_damage") == 12 + 4 * level, "level %d base damage" % level)
	check(weapon.get_grenade_blast_radius() == 80 and not loadout.upgrade_weapon(WEAPON), "level five radius and max-level boundary")
	weapon.initialize(WEAPON, player)
	weapon.runtime_stats.crit_chance = 0
	fixture([Vector2(40, 0), Vector2(180, 0), Vector2(200, 0), Vector2(200, 30), Vector2(-180, 0), Vector2(-180, 20)])
	var chosen := loadout.targeting_service.find_cluster_targets(player.global_position, 420, 64, 3)
	check(chosen.size() == 3 and chosen[0].distance_to(player.global_position + Vector2(180, 0)) < 0.1, "dense group wins over nearest lone enemy")
	check(chosen[1].x < player.global_position.x, "second grenade prioritizes independent group")
	check(chosen[2] == player.global_position + Vector2(40, 0), "third grenade covers remaining isolated enemy")
	fixture([Vector2(200, 0), Vector2(210, 25), Vector2(245, 0), Vector2(280, 0)])
	var landing := player.global_position + Vector2(210, 0)
	var shot := grenade(landing)
	shot._physics_process(0.22)
	check(enemies[0].current_hp == 1000 and not shot.exploded, "flight does no contact damage")
	await capture("01_grenade_in_flight")
	var clock := shot.elapsed
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	shot._physics_process(1.0)
	check(shot.elapsed == clock and not shot.exploded, "pause freezes grenade flight")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	shot._physics_process(0.23)
	check(shot.exploded and shot.hit_target_ids.size() == 3, "one blast hits exactly the three in-radius enemies")
	check(enemies[0].current_hp == 984 and enemies[1].current_hp == 984 and enemies[2].current_hp == 984 and enemies[3].current_hp == 1000, "native damage has no falloff or extra direct hit")
	check(not enemies[0].has_status("burning"), "native blast does not apply fire")
	await capture("02_grenade_explosion")
	shot._detonate()
	shot._physics_process(0.1)
	check(enemies[0].current_hp == 984, "smoke and repeat detonate cannot deal damage twice")
	fixture([Vector2(200, 0)])
	shot = grenade(enemies[0].global_position)
	enemies[0].global_position += Vector2(160, 0)
	shot._physics_process(0.45)
	check(enemies[0].current_hp == 1000 and shot.impact_batches == 0, "fixed landing does not track enemy or trigger enchantment on miss")
	fixture([Vector2(200, 0)])
	weapon.runtime_stats.projectile_count = 2
	check(loadout._try_attack_with_weapon(weapon), "real loadout fires grenades")
	var fired: Array[GrenadeProjectile] = []
	for node in get_tree().get_nodes_in_group("grenade_projectiles"):
		if not node.is_queued_for_deletion():
			node.set_physics_process(false)
			fired.append(node)
	check(fired.size() == 2, "projectile count creates two actual grenades")
	for node in fired: node._physics_process(0.45)
	check(enemies[0].current_hp == 968, "separate grenades each damage same single target: %d" % enemies[0].current_hp)
	for node in fired: node.free()
	weapon.runtime_stats.projectile_count = 1
	fixture([])
	weapon.attack_timer = 0
	check(not loadout._try_attack_with_weapon(weapon) and weapon.attack_timer == 0, "empty battlefield does not consume cooldown")
	var crowd: Array = []
	for index in 80: crowd.append(Vector2(180 + index % 10 * 2, index / 10 * 2))
	fixture(crowd)
	shot = grenade(player.global_position + Vector2(190, 8), weapon.calculate_damage_events(true)[0])
	shot._physics_process(0.45)
	check(shot.hit_target_ids.size() == 80, "native explosion has no physics-query 64-target cap")
	check(enemies.all(func(enemy): return enemy.current_hp == 976), "one grenade shares critical roll across all victims")
	fixture([Vector2(200, 0)])
	weapon.runtime_stats.projectile_count = 16
	weapon.runtime_stats.crit_chance = 50
	seed(1357)
	loadout._try_attack_with_weapon(weapon)
	var critical_count := 0
	for node in get_tree().get_nodes_in_group("grenade_projectiles"):
		if node.damage_event.is_critical: critical_count += 1
		node.free()
	check(critical_count > 0 and critical_count < 16, "each grenade gets an independent critical roll")
	weapon.runtime_stats.projectile_count = 1
	weapon.runtime_stats.crit_chance = 0
	fixture([Vector2(200, 0), Vector2(220, 0), Vector2(250, 0)])
	var enchant := player.item_inventory.add_item_from_base("scroll_explosion", "grenade_test")
	check(loadout.attach_item_to_weapon(WEAPON, enchant.item_instance_id), "compatible enchantment attaches")
	await frames()
	shot = grenade(player.global_position + Vector2(210, 0))
	enemies[0].current_hp = 1
	shot._physics_process(0.45)
	check(shot.impact_batches == 3, "each of three victims dispatches its own attachment batch")
	check(not enemies[0].is_alive(), "native blast kills primary")
	await frames(8)
	check(enemies[1].current_hp == 939 and enemies[2].current_hp == 939, "three 15-damage elemental blasts survive lethal contact and do not recurse")
	fixture([Vector2(150, 0), Vector2(270, 0), Vector2(355, 0)])
	await frames()
	shot = grenade(player.global_position + Vector2(210, 0))
	shot._physics_process(0.45)
	await frames(8)
	# The scroll multiplies radius by 1.15; collision circles make these two
	# secondary blasts overlap even though the enemy centers are 120 apart.
	check(shot.impact_batches == 2 and enemies[0].current_hp == 954 and enemies[1].current_hp == 954, "separated contacts dispatch two overlapping elemental blasts: batches=%d hp=%d,%d" % [shot.impact_batches, enemies[0].current_hp, enemies[1].current_hp])
	check(enemies[2].current_hp == 985, "outside native blast only receives nearby victim's enchantment splash")
	loadout.detach_item_from_weapon(WEAPON, enchant.item_instance_id)
	fixture([Vector2(200, 0), Vector2(225, 0), Vector2(245, 15), Vector2(340, 0)])
	var fire := player.item_inventory.add_item_from_base("scroll_fire", "grenade_test")
	check(loadout.attach_item_to_weapon(WEAPON, fire.item_instance_id), "fire attachment attaches")
	shot = grenade(player.global_position + Vector2(220, 0))
	shot._physics_process(0.45)
	check(enemies[0].has_status("burning") and enemies[1].has_status("burning") and enemies[2].has_status("burning"), "all blast victims receive direct fire application")
	check(not enemies[3].has_status("burning") and enemies[3].current_hp == 1000, "outside target receives no native hit or contact enchantment")
	check(shot.impact_batches == 3 and shot.hit_target_ids.size() == 3, "per-target effects preserve one native hit per victim")
	shot._detonate()
	check(shot.impact_batches == 3 and enemies[0].current_hp == 984, "repeat detonation cannot repeat enchantments or native damage")
	loadout.detach_item_from_weapon(WEAPON, fire.item_instance_id)
	fixture([])
	check(loadout.equip_weapon("weapon_plasma_cannon"), "existing plasma still equips")
	check(loadout.equip_weapon("weapon_void_blade"), "existing bow still equips")
	var bow := loadout.get_weapon_instance("weapon_void_blade")
	var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "grenade_test")
	check(loadout.attach_item_to_weapon(bow.weapon_id, pierce.item_instance_id), "pierce remains valid on bow")
	check(not loadout.attach_item_to_weapon(WEAPON, pierce.item_instance_id), "incompatible transfer rejected")
	check(player.item_inventory.find_item(pierce.item_instance_id).equipped_weapon_id == bow.weapon_id and bow.get_attached_item_instances().size() == 1, "rejected transfer preserves source ownership")
	var split := player.item_inventory.add_item_from_base("scroll_split", "grenade_test")
	check(loadout.attach_item_to_weapon(WEAPON, split.item_instance_id), "production grenade accepts split")
	test_split(split)
	manager.apply_gold_delta(2000, "test")
	flow.finish_current_wave()
	await frames(20)
	check(flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "normal wave end enters finance: " + flow.current_state)
	var finance := game.find_child("FinancePopup", true, false) as FinancePopup
	finance._select_tab("enchant")
	finance.workbench._select_weapon(WEAPON)
	finance.workbench._select_item(pierce.item_instance_id)
	await frames(8)
	check(finance.workbench._apply.disabled and not finance.workbench._apply.tooltip_text.is_empty(), "workbench explains disabled incompatible attachment")
	check(flow.submit_enchantment_operation("attach", WEAPON, pierce.item_instance_id).reason == "incompatible_enchantment", "authoritative operation still rejects pierce")
	finance.workbench._select_item(split.item_instance_id)
	check(not finance.workbench._apply.disabled, "workbench enables split attachment")
	check(flow.submit_enchantment_operation("attach", WEAPON, split.item_instance_id).success, "finance operation equips split")
	check(flow.submit_enchantment_operation("detach", WEAPON, split.item_instance_id).success, "finance operation detaches split")
	check(flow.submit_enchantment_operation("attach", bow.weapon_id, split.item_instance_id).success, "split still attaches to existing bow")
	check(flow.submit_enchantment_operation("attach", WEAPON, split.item_instance_id).success and bow.get_attached_item_instances().size() == 1 and player.item_inventory.find_item(split.item_instance_id).equipped_weapon_id == WEAPON, "finance transfers split from bow without losing ownership or other attachment")
	await capture("03_grenade_workbench")
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity": 100, "current_load": 0})
	check(pool.any(func(offer): return offer.target_id == WEAPON), "new weapon appears in shop and reward candidate pool")
	var limited := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity": 24, "current_load": 0})
	check(not limited.any(func(offer): return offer.target_id == WEAPON), "candidate respects load capacity")
	shot = grenade(player.global_position + Vector2(200, 0))
	manager.clear_battle_entities()
	check(shot.cancelled and shot.is_queued_for_deletion(), "wave cleanup cancels airborne grenade immediately")
	shot._physics_process(1.0)
	check(not shot.exploded, "cancelled grenade cannot detonate in next wave")
	print("GRENADE_WEAPON_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
