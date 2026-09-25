extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func make_player(modifiers: Array = []) -> PlayerController:
	var p := PlayerController.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.initialize_from_character("character_void_hunter", modifiers)
	p.set_physics_process(false)
	return p


func make_manager(p: PlayerController) -> WaveManager:
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(p)
	return manager


func level_to(manager: WaveManager, level: int) -> void:
	while manager.player_level < level:
		manager.add_exp_and_gold(manager.get_required_exp_for_next_level() - manager.current_exp, 0)


func _run() -> void:
	CampProgression.begin_transient_session()
	_test_level_growth()
	_test_sources_and_preview()
	_test_contact_and_revive()
	_test_camp_and_regeneration()
	CampProgression.end_transient_session()
	print("HEALTH_GROWTH_COMPLETE checks=%d failures=%d" % [checks, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _test_level_growth() -> void:
	var p := make_player()
	var manager := make_manager(p)
	check(manager.player_level == 1 and p.current_hp == 5 and p.get_stat("max_hp") == 5, "actual character starts at level one with five HP")
	var signals := {"hp": 0, "stats": 0, "reward": 0, "seen_max": 0}
	p.hp_changed.connect(func(_hp, maximum, _shield): signals.hp += 1; signals.seen_max = maximum)
	p.stats_changed.connect(func(): signals.stats += 1)
	manager.shared_reward_shop_requested.connect(func(level):
		signals.reward += 1
		check(p.get_stat("max_hp") == level + 4, "growth is applied before reward preview opens")
	)
	p.take_damage(1)
	manager.add_exp_and_gold(manager.get_required_exp_for_next_level() - 1, 0)
	check(manager.player_level == 1 and p.get_stat("max_hp") == 5, "XP below threshold does not grant health")
	manager.add_exp_and_gold(1, 0)
	check(manager.player_level == 2 and p.current_hp == 4 and p.get_stat("max_hp") == 6, "exact XP threshold grows maximum without healing")
	check(signals.hp > 1 and signals.stats > 0 and signals.seen_max == 6 and signals.reward == 1, "HUD and reward signals include new maximum")
	var xp_batch := manager.get_required_exp_for_next_level() + ceili(0.45 * pow(4.8, 2.9)) + 3
	manager.add_exp_and_gold(xp_batch, 0)
	check(manager.player_level == 4 and manager.current_exp == 3 and p.get_stat("max_hp") == 8 and p.current_hp == 4, "one XP grant supports multiple levels and preserves remainder")
	level_to(manager, 10)
	check(p.get_stat("max_hp") == 14 and p.current_hp == 4, "level ten has fourteen base HP and no implicit healing")
	p.set_run_level(10)
	p.set_run_level(10)
	check(p.get_stat("max_hp") == 14, "repeated level sync does not stack")
	check(manager.start_next_wave() and p.current_hp == 14, "wave start retains full recovery with new health cap")
	manager.running = false
	level_to(manager, 20)
	check(p.get_stat("max_hp") == 24 and p.current_hp == 14, "level twenty has twenty-four base HP")
	check(manager.start_next_wave() and p.current_hp == 24 and p.get_stat("max_hp") == 24, "wave transition does not duplicate level growth")
	manager.running = false
	p.initialize_from_character("character_void_hunter")
	check(p.current_hp == 5 and p.get_stat("max_hp") == 5, "character reinitialization clears previous run level bonus")
	manager.initialize(p)
	check(manager.player_level == 1 and manager.current_exp == 0 and p.get_stat("max_hp") == 5, "new run resets level and experience")
	manager.free()
	p.free()


func _test_sources_and_preview() -> void:
	var p := make_player()
	var manager := make_manager(p)
	level_to(manager, 10)
	var bank := manager.finance_system
	p.add_relic("relic_worn_hemostatic_cloth")
	p.add_relic("relic_turtle_shell_pendant")
	check(p.get_stat("max_hp") == 21 and p.get_stat("armor") == 10, "level growth adds to revised cloth and turtle bonuses")
	p.add_relic("relic_coin_heart")
	bank.deposit(1000, true)
	p.restore_full_health()
	check(p.current_hp == 31 and p.get_stat("max_hp") == 31, "coin heart adds principal health on top of level and relics")
	var preview := p.create_stat_preview_copy()
	var preview_bank := bank.create_preview_copy(preview)
	preview_bank.withdraw(500)
	check(preview.get_stat("max_hp") == 26 and preview.current_hp == 26, "withdrawal preview preserves level growth and reduces principal HP")
	check(p.current_hp == 31 and p.get_stat("max_hp") == 31 and bank.principal == 1000, "preview cannot mutate live maximum or current health")
	preview.free()
	bank.withdraw(500)
	check(p.current_hp == 26 and p.get_stat("max_hp") == 26, "real withdrawal matches preview cap and current health")
	p.relic_system.refresh_effects()
	p.sync_relic_weapon_ids(p.get_start_weapon_ids())
	p.set_run_level(10)
	check(p.current_hp == 26 and p.get_stat("max_hp") == 26, "relic weapon and level refresh preserve full health")
	bank.deposit(500, true)
	check(p.current_hp == 26 and p.get_stat("max_hp") == 31, "redeposit restores maximum without healing")
	p.add_relic("relic_welfare_cutback")
	check(p.current_hp == 26 and p.get_stat("max_hp") == 29 and bank.principal == 1150, "welfare costs three HP while its principal gift adds one heart tier")
	level_to(manager, 11)
	check(p.current_hp == 26 and p.get_stat("max_hp") == 30, "level growth survives stat penalties")
	manager.free()
	p.free()


func _test_contact_and_revive() -> void:
	var p := make_player()
	var manager := make_manager(p)
	var enemy_a := manager.spawn_enemy("enemy_mutated_grub", p.global_position)
	var enemy_b := manager.spawn_enemy("enemy_mutated_grub", p.global_position)
	check(enemy_a != null and enemy_b != null, "ordinary contact test spawns two real enemies")
	if enemy_a != null and enemy_b != null:
		enemy_a.set_physics_process(false)
		enemy_b.set_physics_process(false)
		enemy_a._process_contact_damage()
		check(p.alive and p.current_hp == 2 and p._invincibility_timer == 0.0, "first ordinary contact deals three with no shared protection")
		enemy_b._process_contact_damage()
		check(not p.alive and p.current_hp == 0, "second enemy in same frame can kill five-HP player")
	manager.clear_battle_entities()
	manager.free()
	p.free()
	p = make_player()
	manager = make_manager(p)
	level_to(manager, 10)
	p.add_relic("relic_costly_seed_of_life")
	p.take_damage(99999)
	check(p.alive and p.current_hp == 7 and p.remaining_revives == 0, "revival restores half of level-scaled maximum")
	check(p.take_damage(3) == 0 and p.current_hp == 7, "one-second revival protection remains")
	level_to(manager, 11)
	check(p.current_hp == 7 and p.remaining_revives == 0 and p.get_stat("max_hp") == 15, "level growth cannot refill health or spent revival")
	manager.free()
	p.free()


func _test_camp_and_regeneration() -> void:
	var default_state := CampProgression.state.duplicate(true)
	CampProgression.state.building_levels["camp_council_hall"] = 2
	var p := make_player()
	var manager := make_manager(p)
	check(manager.player_level == 3 and p.get_stat("max_hp") == 7, "camp's two starting levels grant two maximum HP")
	manager.start_next_wave()
	manager.running = false
	check(p.current_hp == 7, "camp starting level enters battle at full seven HP")
	level_to(manager, 4)
	check(p.get_stat("max_hp") == 8 and p.current_hp == 7, "first earned level after camp bonus grants exactly one HP cap")
	manager.free()
	p.free()
	CampProgression.state.building_levels["camp_dome_shelter"] = 1
	CampProgression.state.upgrade_levels["camp_upgrade_max_hp"] = 10
	for training_level in [1, 5]:
		CampProgression.state.upgrade_levels["camp_upgrade_hp_regen"] = training_level
		p = make_player(CampProgression.get_outgame_modifiers())
		manager = make_manager(p)
		check(p.get_stat("max_hp") == 17, "camp max-HP training adds ten to level-three health")
		check(is_equal_approx(p.get_stat("hp_regen"), training_level * 0.1), "saved regen training levels use new per-level rate")
		manager.free()
		p.free()
	var option := CampProgression.get_upgrade_option_record("camp_upgrade_hp_regen")
	check(option.max_level == 5 and option.cost == 300 and CampProgression.get_upgrade_option_level("camp_upgrade_hp_regen") == 5, "training retains price cap and purchased levels")
	p = make_player(CampProgression.get_outgame_modifiers())
	manager = make_manager(p)
	level_to(manager, 10)
	check(p.get_stat("max_hp") == 24 and is_equal_approx(p.get_stat("hp_regen"), 0.5), "level ten and full camp training yield twenty-four HP and 0.5 regen")
	p.add_relic("relic_holy_silver_cup")
	check(is_equal_approx(p.get_stat("hp_regen"), 2.0) and is_equal_approx(manager.finance_system.get_interest_rate(), 4.0), "silver cup plus full training yields two regen and retains one-point interest cost")
	p.current_hp = 12
	p._process_regeneration(0.25)
	check(p.current_hp == 12, "fractional regeneration waits for a whole HP")
	p._process_regeneration(0.25)
	check(p.current_hp == 13, "fractional regeneration accumulates without loss")
	p._process_regeneration(5.5)
	check(p.current_hp == 24, "twenty-four HP with two regen recovers half health in six seconds")
	p._process_regeneration(20.0)
	check(p.current_hp == 24, "regeneration is capped at current maximum")
	manager.free()
	p.free()
	CampProgression.state = default_state
	p = make_player()
	p.add_relic("relic_holy_silver_cup")
	p.current_hp = 1
	p._process_regeneration(2.0)
	check(p.current_hp == 4 and is_equal_approx(p.get_stat("hp_regen"), 1.5), "silver cup alone heals three in two seconds")
	p.free()
