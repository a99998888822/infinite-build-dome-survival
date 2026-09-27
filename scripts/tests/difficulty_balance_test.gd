extends Node

var checks := 0
var failures := 0
var selection_completed := false

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int = 4) -> void:
	for index in count: await get_tree().process_frame

func _run() -> void:
	CampProgression.begin_transient_session()
	check(DataRegistry.get_load_errors().is_empty(), "all data validates including fractional scroll odds")
	check(BattleDifficulty.normalize("") == "1" and BattleDifficulty.normalize("unknown") == "1" and BattleDifficulty.normalize("nightmare") == "3" and BattleDifficulty.normalize("standard") == "1", "numeric default and legacy difficulty mapping")
	await _test_selection_and_slots()
	_test_drops()
	await frames()
	check(selection_completed, "all integration checks reached completion")
	print("DIFFICULTY_BALANCE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_selection_and_slots() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	var menu := game.find_child("MainMenuUIController", true, false) as MainMenuUIController
	check(menu != null, "real selection menu exists")
	if menu == null: return
	for index in BattleDifficulty.IDS.size():
		var id := BattleDifficulty.IDS[index]
		menu._on_start_battle_pressed()
		await frames()
		check(menu._selected_difficulty_id == "1", "each new run defaults to tier one")
		var clicked := false
		for button in menu.difficulty_list.get_children():
			if button is Button and str(button.get_meta("difficulty_id", "")) == id:
				button.pressed.emit()
				clicked = true
		check(clicked and menu._selected_difficulty_id == id, "compact difficulty card click selects " + id)
		menu.character_confirm_button.pressed.emit()
		await frames()
		var manager := flow._bound_wave_manager
		var player := flow.get_bound_player()
		var loadout := flow.get_bound_loadout()
		manager.set_process(false)
		player.set_physics_process(false)
		(game.get_node("SceneDirector") as GameSceneDirector).battle_root.set_process(false)
		check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and manager.difficulty_id == id, "UI selection reaches live wave manager: " + id)
		var enemy := manager.spawn_enemy("enemy_mutated_grub", player.global_position)
		enemy.set_physics_process(false)
		check(enemy.get_stat("max_hp") == [8, 10, 10][index] and enemy.get_stat("move_speed") == [85, 102, 111][index], "difficulty controls actual enemy HP and speed: " + id)
		var before := player.current_hp
		enemy._process_contact_damage()
		check(before - player.current_hp == [1, 2, 2][index], "actual rounded contact damage in tier " + id)
		for stat in ["melee_damage", "ranged_damage", "element_damage", "armor"]:
			enemy.modifier_stack.set_base_stat(stat, 100.0)
			var base := 100.0 if stat == "armor" else 45.0
			check(enemy.get_stat(stat) == roundi(base * [1.0, 1.2, 1.3][index]), "actual enemy multiplier: " + id + " " + stat)
		enemy.free()
		check(manager.calculate_enemy_spawn_count(6) == 2 and manager.calculate_enemy_spawn_count(4) == 2, "same first-wave group sizes: " + id)
		check(is_equal_approx(manager.calculate_spawn_interval(1200), 1620.0), "same regular spawn interval: " + id)
		if id == "1":
			_test_slots(player, loadout)
			for wave in 3:
				manager.current_wave_index = wave
				manager._initialize_elite_schedule()
				check(manager.get_miniboss_spawn_snapshot().planned == 0, "beginner wave %d has no elites" % (wave + 1))
			manager.current_wave_index = 3
			manager._initialize_elite_schedule()
			check(is_equal_approx(manager._elite_expected_count, 0.2), "beginner wave four starts low elite expectation")
		manager.current_wave_index = 1
		manager._initialize_elite_schedule()
		check(is_equal_approx(manager._elite_expected_count, 0.2 if id == "3" else 0.0), "only tier three allows second-wave elites")
		manager.current_wave_index = 9
		manager._initialize_elite_schedule()
		check(is_equal_approx(manager._elite_expected_count, 1.0 if id == "3" else 0.5), "tier three doubles elite expectation at the same wave")
		var late_enemy := manager.spawn_enemy("enemy_mutated_grub", Vector2(3000, 0))
		check(late_enemy.current_hp == roundi(8.0 * pow(1.14, 9) * [1.0, 1.2, 1.3][index]), "later waves retain the exact difficulty multiplier before rounding")
		late_enemy.free()
		# Fill to the configured limit and exercise real group spawning.
		manager.current_wave_index = 0
		var cap := int(BattleDifficulty.get_profile(id).enemy_limit)
		for n in cap:
			var blocker := manager.spawn_enemy("enemy_mutated_grub", Vector2(2000 + n * 3, 0))
			blocker.set_physics_process(false)
		manager.spawn_timers_ms.fill(0.0)
		manager._process_spawn_timers(0.1)
		check(EnemyRegistry.get_registered_enemies().size() == cap, "live enemy cap prevents an extra batch: " + id)
		for live_enemy in EnemyRegistry.get_registered_enemies().duplicate(): live_enemy.free()
		flow.enter_start_page()
		await frames(8)
	game.queue_free()
	await frames(8)
	selection_completed = true

func _test_slots(player: PlayerController, loadout: WeaponLoadout) -> void:
	var bow := loadout.get_weapon_instance("weapon_void_blade")
	var attached := bow.get_attached_item_instances()
	check(bow.get_attachment_slot_count() == 1 and attached.size() == 1 and attached[0].base_item_id == "scroll_lightning", "starter has exactly one working lightning enchantment")
	var fire := player.item_inventory.add_item_from_base("scroll_fire", "balance_test")
	check(not loadout.attach_item_to_weapon(bow.weapon_id, fire.item_instance_id), "common bow rejects second enchantment")
	check(loadout.upgrade_weapon(bow.weapon_id) and bow.get_attachment_slot_count() == 1, "uncommon still has one slot")
	check(loadout.upgrade_weapon(bow.weapon_id) and bow.get_attachment_slot_count() == 2, "upgrading to rare unlocks second slot")
	check(loadout.attach_item_to_weapon(bow.weapon_id, fire.item_instance_id), "new rare slot accepts inventory enchantment")
	var ice := player.item_inventory.add_item_from_base("scroll_ice", "balance_test")
	check(not loadout.attach_item_to_weapon(bow.weapon_id, ice.item_instance_id), "rare rejects third enchantment")
	check(loadout.equip_weapon("weapon_rentier_purse"), "equip uncommon target for full-slot transfer")
	check(loadout.attach_item_to_weapon("weapon_rentier_purse", ice.item_instance_id), "uncommon target accepts first item")
	check(not loadout.attach_item_to_weapon("weapon_rentier_purse", fire.item_instance_id) and player.item_inventory.find_item(fire.item_instance_id).equipped_weapon_id == bow.weapon_id and bow.get_attached_item_instances().size() == 2, "full destination preserves source and inventory ownership")
	for record in DataRegistry.get_table("weapons"):
		var weapon := WeaponInstance.new()
		weapon.initialize(str(record.id), player)
		for level in 5:
			var expected := 1 if weapon.get_visual_rarity() in ["common", "uncommon"] else 2
			check(weapon.get_attachment_slot_count() == expected, "%s level %d slots match current rarity" % [record.id, level + 1])
			weapon.upgrade()

func _test_drops() -> void:
	var drops := DropRewardSystem.new()
	seed(872341)
	for table_id in ["drop_basic_enemy", "drop_elite_enemy", "drop_boss_enemy"]:
		var table := DataRegistry.get_record("drop_tables", table_id)
		var count := 0
		var distribution: Dictionary = {}
		drops.begin_wave()
		for attempt in 20000:
			var actions := drops.build_drop_actions(table_id).filter(func(a): return a.type == "augmentation")
			if actions.size() > 1:
				check(false, "one kill must not drop multiple enchantments")
				return
			if not actions.is_empty():
				count += 1
				var item_id: String = actions[0].entry.item_id
				distribution[item_id] = int(distribution.get(item_id, 0)) + 1
		var rate := float(count) / 200.0
		print("DROP_SAMPLE ", table_id, " rate=", rate, " distribution=", distribution)
		check(absf(rate - float(table.augmentation_chance_percent)) < 1.0 and distribution.size() == (table.entries as Array).filter(func(e): return e.type == "augmentation").size(), "20000 kills match total chance and reach all weighted items: " + table_id)
		check(drops._build_augmentation_action(table, -100).is_empty(), "minus 100 drop bonus disables enchantments: " + table_id)
		# Guaranteed rolls exercise deferred spawning; there is no per-wave limit.
		drops.begin_wave()
		var guaranteed := table.duplicate(true)
		guaranteed.augmentation_chance_percent = 100
		var batch: Array[Dictionary] = []
		for death in 100:
			var action := drops._build_augmentation_action(guaranteed, 0)
			if not action.is_empty(): batch.append(action)
		check(batch.size() == 100, "all one hundred same-wave successful rolls survive: " + table_id)
		var player := PlayerController.new()
		player.auto_initialize_on_ready = false
		add_child(player)
		player.initialize_from_character("character_void_hunter")
		player.set_physics_process(false)
		var root := Node2D.new()
		add_child(root)
		check(drops.spawn_action(batch[0], Vector2.ZERO, root, player) != null and drops.spawn_action(batch[0], Vector2.ZERO, root, player) == null, "deferred action cannot replay")
		var extra_spawned := drops.spawn_drop_actions(batch.slice(1), Vector2(1000, 0), root, player)
		check(extra_spawned.size() == 99 and root.get_child_count() == 100, "all deferred drops spawn beyond the old cap")
		drops.begin_wave()
		check(drops.spawn_action(batch[1], Vector2.ZERO, root, player) == null and not drops._build_augmentation_action(guaranteed, 0).is_empty(), "new wave rejects stale rewards and accepts new drops")
		player.modifier_stack.set_base_stat("luck", 100)
		var rolled_chance := -1.0
		for attempt in 1000:
			for action in drops.build_drop_actions(table_id, player):
				if action.type == "augmentation": rolled_chance = action.adjusted_chance_percent
			if rolled_chance >= 0.0: break
		check(is_equal_approx(rolled_chance, float(table.augmentation_chance_percent) * 1.1), "live player luck adds ten percent relative chance: " + table_id)
		root.free()
		player.free()
	var base := DataRegistry.get_record("drop_tables", "drop_basic_enemy")
	var boosted := 0
	for attempt in 20000:
		drops.begin_wave()
		if not drops._build_augmentation_action(base, 100).is_empty(): boosted += 1
	check(absf(float(boosted) / 200.0 - 3.0) < 0.5, "100 percent drop bonus doubles total ordinary chance to three percent")
	check(is_equal_approx(DropRewardSystem.calculate_augmentation_chance(1.5, 100, 100), 3.3), "luck stacks multiplicatively with drop-rate modifiers")
	check(DropRewardSystem.calculate_augmentation_chance(1.5, -100, 9999) == 0.0 and DropRewardSystem.calculate_augmentation_chance(60, 100, 9999) == 100.0, "luck respects zero chance and probability ceiling")
	check(DropRewardSystem.calculate_augmentation_chance(1.5, 0, -10) == 1.5, "nonpositive luck preserves base odds")
