extends Node
## Functional integration checks; optional captures use the actual game UI/player.

const CAPITALIST := "character_capitalist"
const BEGINNER := "character_void_hunter"
const RELICS := ["relic_medical_cutback", "relic_welfare_cutback", "relic_annual_leave_cutback", "relic_salary_adjustment"]
var checks := 0
var failures := 0
var capture_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
	check(error == OK, "capture " + name)


func _run() -> void:
	CampProgression.begin_transient_session()
	check(DataRegistry.get_load_errors().is_empty(), "catalog validates")
	_test_config_validation()
	_test_new_runs()
	await _test_live_flow()
	CampProgression.end_transient_session()
	await frames(3)
	print("CAPITALIST_CHARACTER_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_new_runs() -> void:
	var p := load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	p.auto_initialize_on_ready = false
	add_child(p)
	p.set_physics_process(false)
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	var bank := manager.finance_system
	for run_index in 2:
		check(p.initialize_from_character(CAPITALIST), "capitalist initializes run %d" % run_index)
		manager.initialize(p)
		check(bank.principal == 500 and manager.current_gold == 0, "four acquisitions grant exactly 500 principal and zero cash")
		check(p.get_relic_ids().size() == 4 and p.grant_starting_relics() and bank.principal == 500, "starting grants are idempotent")
		var expected := {"max_hp": 4, "hp_regen": -0.5, "armor": -5, "damage_percent": -30, "attack_speed": -12, "currency_gain_percent": -50, "load_capacity": 80, "move_speed": 240, "pickup_radius": 180, "humanity": 100, "divinity": 0, "luck": 0, "health_pack_heal_plus": -1, "shop_price_percent": -10}
		for stat_id in expected:
			check(is_equal_approx(p.get_stat(stat_id), float(expected[stat_id])), "effective starting stat " + stat_id)
		check(p.current_hp == 4 and bank.get_interest_rate() == 13, "full starting HP and thirteen percent interest")
		for relic_id in RELICS:
			check(p.relic_system.get_innate_relic_count(relic_id) == 1 and not p.relic_system.remove_relic(relic_id), "innate copy cannot be removed: " + relic_id)
		for instance_id in p.relic_system.relic_instances.keys():
			check(not p.relic_system.remove_relic_instance(instance_id), "instance removal also protects innate relic")
		p.relic_system.refresh_effects()
		bank._emit_changed()
		check(bank.principal == 500 and p.get_stat("max_hp") == 4, "stat refresh does not replay acquisition")
		var preview := p.create_stat_preview_copy()
		var preview_bank := bank.create_preview_copy(preview)
		preview.grant_starting_relics()
		check(preview.character_id == CAPITALIST and preview_bank.principal == 500 and not preview.relic_system.remove_relic(RELICS[0]), "purchase preview preserves character, grant state, and protection")
		preview.free()
		check(bank.settle_interest().gain == 65 and manager.current_gold == 65 and bank.principal == 500, "65 interest goes to wallet without increasing principal")
		check(bank.withdraw(200).success and bank.principal == 300 and manager.current_gold == 265, "starting principal may be withdrawn manually")
		check(bank.settle_interest().gain == 39 and manager.current_gold == 304, "300 remaining principal earns 39")
		manager.add_exp_and_gold(0, 100)
		check(manager.current_gold == 354, "combat gold alone is reduced by fifty percent")
		manager.apply_gold_delta(100, "goblin_trade")
		check(manager.current_gold == 454, "direct gold gift stays whole")
		check(p.add_relic(RELICS[0]) and bank.principal == 450 and p.get_relic_count(RELICS[0]) == 2, "later same-name copy grants its normal acquisition")
		check(p.relic_system.remove_relic(RELICS[0]) and p.get_relic_count(RELICS[0]) == 1 and bank.get_interest_rate() == 13, "ordinary duplicate removable while innate original remains")
		p.set_run_level(2)
		check(p.get_stat("max_hp") == 5 and p.current_hp == 4, "level growth adds one maximum HP without healing")
		p._process_regeneration(20)
		check(p.current_hp == 4, "negative regeneration does not drain health")
		p._update_walk_animation(Vector2.RIGHT, 0.2)
		check(p.sprite.hframes == 4 and p.sprite.frame == 1 and p.walk_animation_fps == 6 and p.sprite.texture.get_size() == Vector2(216, 54), "approved four-frame combat walk at six FPS")
		p._set_facing(false)
		check(p.visual_anchor.scale.x == -1, "left facing mirrors the character")
		p._update_walk_animation(Vector2.ZERO, 0)
		check(p.sprite.hframes == 1 and p.sprite.texture.resource_path.ends_with("capitalist_idle_right.png"), "stopping restores capitalist idle")
		p.initialize_from_character(BEGINNER)
		manager.initialize(p)
		check(p.get_relic_ids().is_empty() and bank.principal == 0 and bank.get_interest_rate() == 5 and p.get_stat("max_hp") == 5 and p.get_stat("damage_percent") == 0 and p.get_stat("currency_gain_percent") == 0, "switch to beginner clears all capitalist effects and awards")
		check(p.sprite.texture == PlayerController.PLAYER_IDLE_TEXTURE and p.walk_animation_fps == 7 and p.walk_frame_count == 8 and p.facing_right, "switch to beginner restores approved visuals")
		p._update_walk_animation(Vector2.RIGHT, 1.0)
		check(p.sprite.hframes == 8 and p.sprite.frame == 7 and p.sprite.texture.get_size() == Vector2(432, 54), "beginner reaches eighth frame without cropping")
		p._update_walk_animation(Vector2.RIGHT, 1.0 / 7.0 + 0.001)
		check(p.sprite.frame == 0, "beginner loops all eight frames")
		p._update_walk_animation(Vector2.ZERO, 0)
		check(p.sprite.hframes == 1 and p.sprite.texture == PlayerController.PLAYER_IDLE_TEXTURE, "beginner stopping restores idle")
	var camp_modifier := {"id": "test_camp_principal", "source_type": "camp", "source_id": "test_camp", "target_scope": "player", "stat": "finance", "operation": "add_flat", "value": 75, "duration": -1, "stack_rule": "stack_add"}
	p.initialize_from_character(CAPITALIST, [camp_modifier])
	manager.initialize(p)
	check(bank.principal == 575, "camp principal stacks with the four acquisition rewards")
	p.initialize_from_character(CAPITALIST)
	manager.initialize(p)
	check(bank.principal == 500, "new run does not inherit previous camp modifiers")
	var other := PlayerController.new()
	other.auto_initialize_on_ready = false
	add_child(other)
	other.set_physics_process(false)
	other.initialize_from_character(BEGINNER)
	manager.initialize(other)
	p.add_relic(RELICS[0])
	check(bank.principal == 0, "rebound manager no longer receives old player's acquisition signals")
	manager.free()
	p.free()
	other.free()


func _test_config_validation() -> void:
	var record := DataRegistry.get_record("characters", CAPITALIST)
	var validator := DataValidator.new()
	var invalid := record.duplicate(true)
	invalid.start_relics = ["relic_missing"]
	validator._validate_character_records([invalid], DataRegistry.records_by_id)
	check(not validator.errors.is_empty(), "validator rejects missing starting relic")
	validator.errors.clear()
	invalid = record.duplicate(true)
	invalid.combat_visuals.walk_frames = 0
	invalid.combat_visuals.walk_fps = -1
	invalid.combat_visuals.idle = "res://missing.png"
	validator._validate_character_records([invalid], DataRegistry.records_by_id)
	check(validator.errors.size() >= 3, "validator rejects missing texture and invalid animation settings")


func _test_live_flow() -> void:
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1152, 768)
	window.content_scale_size = window.size
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu._on_start_battle_pressed()
	menu._on_character_selected(CAPITALIST)
	await get_tree().create_timer(0.4).timeout
	var preview_stats := menu._get_character_starting_stats(DataRegistry.get_record("characters", CAPITALIST))
	check(preview_stats.max_hp == 4 and preview_stats.finance == 500 and preview_stats.interest_rate == 13, "selection preview shows actual post-relic stats")
	check(menu.stats_list.get_child_count() == 7 and menu.character_icon.texture.resource_path.ends_with("capitalist_idle_right.png") and menu.character_description_label.text.is_empty(), "selection displays capitalist art, seven selected stats, and a blank description")
	await capture("selection")
	menu.character_details_scroll.scroll_vertical = 10000
	await frames(3)
	await capture("traits")
	menu._on_character_selected(BEGINNER)
	menu._on_character_selected(CAPITALIST)
	check(menu.stats_list.get_child_count() == 7 and menu.weapon_list.get_child_count() == 1 and menu.passive_list.get_child_count() == 3, "repeated selection does not accumulate stale UI cards")
	menu._on_character_confirm_pressed()
	await frames(8)
	var flow := game.get_main_flow_coordinator()
	var manager := flow._bound_wave_manager
	var p := flow._bound_player
	manager.set_process(false)
	manager.clear_enemies()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and p.character_id == CAPITALIST and manager.finance_system.principal == 500 and p.current_hp == 4, "actual menu confirmation begins capitalist combat with complete rewards")
	var purse := flow._bound_loadout.get_weapon_instance("weapon_rentier_purse")
	check(flow._bound_loadout.get_weapon_instances().size() == 1 and purse != null and purse.get_current_principal() == 500 and purse.get_attachment_slot_count() == 1 and purse.get_attached_item_instances().is_empty() and p.item_inventory.get_item_count() == 0, "starting rentier purse uses initial principal, has one empty slot, and grants no enchantments")
	await capture("battle")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		for index in 48:
			p.set_mobile_move_direction(Vector2.RIGHT if index < 24 else Vector2.LEFT)
			await get_tree().create_timer(1.0 / 12.0).timeout
			await capture("walk_%03d" % index)
		p.set_mobile_move_direction(Vector2.ZERO)
	flow.finish_current_wave()
	await frames(15)
	check(manager.finance_system.principal == 500 and manager.current_gold == 65, "actual first wave settlement pays exactly 65 cash")
	await get_tree().create_timer(2.5 if not capture_dir.is_empty() else 0.01).timeout
	flow.close_interest_settlement()
	await frames(8)
	await capture("bank")
	check(p.grant_starting_relics() and manager.finance_system.principal == 500, "opening bank does not regrant initial principal")
	game.queue_free()
	await frames(4)
