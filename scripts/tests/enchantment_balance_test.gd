extends Node

class AcceptRolls:
	extends DropRewardSystem
	var chances: Array[float] = []
	var accept := true
	func _roll_drop_chance(chance: float) -> bool:
		chances.append(chance)
		return accept and chance > 0

var checks := 0
var failures := 0
var player: PlayerController
var host: Node2D

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func clear_host() -> void:
	for child in host.get_children(): child.free()

func _run() -> void:
	CampProgression.begin_transient_session()
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	host = Node2D.new()
	add_child(host)
	var drops := AcceptRolls.new()
	var snapshot := RewardSnapshot.new()
	var basic := DataRegistry.get_record("drop_tables", "drop_basic_enemy")
	await resonance_catchup(basic)
	check(float(basic.augmentation_chance_percent) == 1.5, "ordinary base remains 1.5 percent")
	check(is_equal_approx(drops.calculate_augmentation_chance(1.5), 1.5), "zero luck has positive unchanged base")
	check(is_equal_approx(drops.calculate_augmentation_chance(1.5, 100, 100), 2.16), "bounded bonuses compose multiplicatively")
	check(drops.calculate_augmentation_chance(1.5, 1e12, 1e12) < 3.36, "extreme bonuses stay below 2.24x")
	check(is_equal_approx(drops.calculate_augmentation_chance(1.5, -95), .375), "negative drop bonus has a nonzero floor")
	check(drops.calculate_augmentation_chance(0, 9999, 9999) == 0, "disabled table never gains chance")
	var weights := {"drop_basic_enemy": {"common": 10, "uncommon": 60, "rare": 25, "epic": 5},
		"drop_elite_enemy": {"common": 5, "uncommon": 45, "rare": 40, "epic": 10},
		"drop_boss_enemy": {"common": 0, "uncommon": 35, "rare": 50, "epic": 15}}
	for table_id in weights:
		var table := DataRegistry.get_record("drop_tables", table_id)
		var entries: Array = table.entries.filter(func(entry): return entry.type == "augmentation")
		var expected_weights: Dictionary = weights[table_id]
		var actual_weights: Dictionary = table.augmentation_rarity_weights
		var weights_match := actual_weights.size() == expected_weights.size()
		for rarity in expected_weights:
			weights_match = weights_match and actual_weights.has(rarity) and is_equal_approx(float(actual_weights.get(rarity, -1)), float(expected_weights[rarity]))
		check(weights_match, "source-specific rarity distribution " + table_id)
		check(entries.size() == 20 and entries.all(func(entry): return entry.weight == 1) and entries.any(func(entry): return entry.item_id == "scroll_fire"), "complete equal-weight item pool " + table_id)
	var fixed_rolls := true
	for _i in 30:
		var split := player.item_inventory.add_item_from_base("scroll_split", "drop")
		var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "drop")
		fixed_rolls = fixed_rolls and split.rolled_parameters.child_count == 2 and pierce.rolled_parameters.extra_target_hits == 2
	check(fixed_rolls, "actual dropped split and pierce items roll fixed counts")
	for wave in [1, 5, 6, 20]:
		clear_host()
		drops.begin_wave(wave)
		var batch: Array[Dictionary] = []
		for _i in 100: batch.append(drops._build_augmentation_action(basic, 10000, 9999))
		drops.chances.clear()
		var spawned := drops.spawn_drop_actions(batch, Vector2(2000, 0), host, player, snapshot)
		var limit := 3 if wave <= 5 else 4
		check(spawned.size() == limit and host.get_child_count() == limit, "same-frame batch obeys wave limit %d" % wave)
		check(drops.chances.size() == limit, "capped rolls do not keep rolling")
		for n in limit:
			check(is_equal_approx(drops.chances[n], 100.0 * pow(.45, n)), "decay uses actual earlier spawns in deferred batch")
		check(drops.spawn_action(batch[0], Vector2.ZERO, host, player) == null, "accepted action cannot replay")
		check(drops.spawn_augmentation("scroll_fire", 5, Vector2.ZERO, host, player) == null, "direct grant cannot bypass quota")
		drops.begin_wave(6)
		check(drops.spawn_action(batch.back(), Vector2.ZERO, host, player) == null, "old-wave deferred action rejected")
	clear_host()
	drops.begin_wave(6)
	drops.spawn_augmentation("scroll_fire", 2, Vector2.ZERO, host, player)
	drops.chances.clear()
	var elite := drops._build_augmentation_action(DataRegistry.get_record("drop_tables", "drop_elite_enemy"), 0)
	check(drops.chances == [15.0], "elite base is 15 percent")
	drops.chances.clear()
	check(drops.spawn_action(elite, Vector2.ZERO, host, player) != null and drops.chances.is_empty(), "elite uses common quota without ordinary decay")
	var last := drops.spawn_augmentation("scroll_water", 8, Vector2.ZERO, host, player)
	check(last != null and last.amount == 1 and drops.get_augmentation_snapshot().augmentation_drops == 4, "direct multi-amount request is clipped to remaining quota")
	clear_host()
	drops.begin_wave()
	var rejected := drops._build_augmentation_action(basic, 0)
	drops.accept = false
	check(drops.spawn_action(rejected, Vector2.ZERO, host, player) == null, "failed deferred decay produces no pickup")
	drops.accept = true
	check(drops.spawn_action(rejected, Vector2.ZERO, host, player) == null and drops.get_augmentation_snapshot().augmentation_drops == 0, "failed roll cannot be replayed and consumes no quota")

	drops.reset_run()
	var before := player.item_inventory.get_item_count()
	check(not drops.finish_wave(30, player, snapshot), "first eligible empty wave does not grant pity")
	check(not drops.finish_wave(30, player, snapshot) and drops.get_augmentation_snapshot().augmentation_dry_waves == 1, "duplicate finish does not advance pity")
	drops.begin_wave(2)
	check(not drops.finish_wave(29, player, snapshot) and drops.get_augmentation_snapshot().augmentation_dry_waves == 1, "low-kill wave does not advance or erase pity")
	drops.begin_wave(3)
	check(drops.finish_wave(30, player, snapshot), "second eligible empty wave grants immediately")
	check(player.item_inventory.get_item_count() == before + 1 and snapshot.pity_augmentations == 1, "pity reaches inventory and accounting")
	check(drops.get_augmentation_snapshot().augmentation_drops == 1 and drops.get_augmentation_snapshot().augmentation_dry_waves == 0, "pity consumes quota and resets drought")
	check(not drops.finish_wave(30, player, snapshot), "pity cannot be paid twice")
	drops.begin_wave(4)
	drops.finish_wave(30, player)
	drops.begin_wave(5)
	drops.spawn_augmentation("scroll_fire", 1, Vector2(2000, 0), host, player)
	check(drops.get_augmentation_snapshot().augmentation_dry_waves == 0, "uncollected normal drop resets drought")
	check(not drops.finish_wave(30, player), "normal drop prevents extra pity")
	drops.begin_wave(6)
	player.alive = false
	check(not drops.finish_wave(100, player) and drops.get_augmentation_snapshot().augmentation_dry_waves == 0, "death does not advance drought")
	player.alive = true
	drops.reset_run()
	check(drops.get_augmentation_snapshot().augmentation_dry_waves == 0, "new run resets pity")
	clear_host()

	# Exercise the real wave completion path, including offscreen auto collection.
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager.pickup_root = host
	manager.enemy_root = host
	manager.start_next_wave()
	var before_collect := player.item_inventory.get_item_count()
	var offscreen := manager.drop_reward_system.spawn_augmentation("scroll_water", 1, Vector2(20000, 0), host, player, manager.reward_snapshot)
	manager.finish_current_wave()
	check(player.item_inventory.get_item_count() == before_collect + 1 and offscreen.collected_once, "successful wave collects offscreen augmentation before cleanup")
	check(manager.reward_snapshot.collected_augmentations == 1, "wave collection recorded")
	manager.finish_current_wave()
	check(player.item_inventory.get_item_count() == before_collect + 1, "duplicate wave finish cannot collect twice")
	await get_tree().process_frame
	manager.start_next_wave()
	manager._augmentation_valid_kills = 30
	manager.finish_current_wave()
	manager.start_next_wave()
	manager._augmentation_valid_kills = 30
	manager.finish_current_wave()
	check(player.item_inventory.get_item_count() == before_collect + 2 and manager.reward_snapshot.pity_augmentations == 1, "real completion invokes cross-wave pity")
	manager.free()
	host.free()
	player.free()
	await get_tree().process_frame
	AudioManager.stop_bgm()
	print("ENCHANTMENT_BALANCE_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func resonance_catchup(table: Dictionary) -> void:
	var drops := AcceptRolls.new()
	var ordinary := {"item_id": "scroll_fire"}
	check(drops._prefer_second_resonance(ordinary, table, player) == ordinary, "zero resonance has no catch-up")
	var first := player.item_inventory.add_item_from_base("scroll_resonance", "test")
	check(drops._prefer_second_resonance(ordinary, table, player).item_id == "scroll_resonance", "one inventory resonance enables catch-up")
	player.item_inventory.set_equipped_weapon(first.item_instance_id, "weapon_void_blade")
	check(drops._prefer_second_resonance(ordinary, table, player).item_id == "scroll_resonance", "equipped resonance counts toward catch-up")
	var second := player.item_inventory.add_item_from_base("scroll_resonance", "test")
	check(drops._prefer_second_resonance(ordinary, table, player) == ordinary, "two resonance restores normal distribution")
	player.item_inventory.take_unequipped_item_for_trade(second.item_instance_id)
	check(drops._prefer_second_resonance(ordinary, table, player).item_id == "scroll_resonance", "selling excess to one re-enables catch-up")
	var pending := drops.spawn_augmentation("scroll_resonance", 1, Vector2(10000, 0), host, player)
	check(drops._prefer_second_resonance(ordinary, table, player) == ordinary, "uncollected second resonance prevents same-frame bonus duplication")
	pending.collect()
	check(drops._prefer_second_resonance(ordinary, table, player) == ordinary, "collected second resonance restores normal distribution")
	for item in player.item_inventory.get_available_items(): player.item_inventory.take_unequipped_item_for_trade(item.item_instance_id)
	await get_tree().process_frame
	check(drops._prefer_second_resonance(ordinary, table, player).item_id == "scroll_resonance", "expired pickup weak reference does not block future catch-up")
	drops.reset_run()
	drops.begin_wave(1)
	drops.finish_wave(30, player)
	drops.begin_wave(2)
	var before_pity := player.item_inventory.get_item_count()
	var paid := drops.finish_wave(30, player)
	check(paid and player.item_inventory.get_item_count() == before_pity + 1 and player.item_inventory.get_items().filter(func(item): return item.base_item_id == "scroll_resonance").size() == 2, "pity also catches up resonance without extra scrolls")
	player.item_inventory.clear()
	player.item_inventory.add_item_from_base("scroll_resonance", "test")
	var random_drops := DropRewardSystem.new()
	seed(30092026)
	var total := 12000
	var resonance := 0
	for _i in total:
		if random_drops._prefer_second_resonance(random_drops._pick_augmentation_entry(table), table, player).item_id == "scroll_resonance": resonance += 1
	var rate := float(resonance) / total
	check(absf(rate - 0.30875) < 0.02, "seeded catch-up distribution near 30.875 percent")
	print("RESONANCE_CATCHUP samples=", total, " rate=", rate)
	player.item_inventory.clear()
	clear_host()
