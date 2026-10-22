extends Node
## Production GPU captures at base stats, plus the live finance workbench.

var output := "res://artifacts/reviews/weapon_range_finance_20261022"
var mode := "all"
var game: GameRoot
var battle: BattleRoot
var flow: MainFlowCoordinator
var player: PlayerController
var loadout: WeaponLoadout
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var ui_metrics: Array[Dictionary] = []
var caption: Label
var detail: Label
var plate: CanvasLayer
var anchor := Vector2.ZERO


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--review-mode="): mode = arg.trim_prefix("--review-mode=")
	get_tree().create_timer(180).timeout.connect(func(): get_tree().quit(99))
	run.call_deferred()


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	check(get_window().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	seed(22102026)
	get_window().unfocusable = true
	get_window().size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "production battle starts")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	player = battle.player
	loadout = battle.loadout
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.set_process(false)
	battle.active_controller.clear_input()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player.set_physics_process(false)
	player.set_process_input(false)
	player.current_hp = 5000
	anchor = player.global_position
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for node in game.find_children("*", "Label", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/ui/combat_performance_line.gd": node.hide()
	if mode != "finance": await capture_weapons()
	if mode != "weapons": await capture_finance()
	FileAccess.open(output.path_join("verification_" + mode + ".json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "weapons": records, "ui": ui_metrics}, "\t"))
	flow.enter_start_page()
	await frames()
	game.queue_free()
	await frames()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for audio in AudioManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	CampProgression.end_transient_session()
	print("WEAPON_RANGE_FINANCE_REVIEW checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func clear_weapons() -> void:
	for weapon in loadout.get_weapon_instances(): loadout.remove_weapon(weapon.weapon_id)
	loadout.active_casting.states.clear()
	player.item_inventory.clear()


func add_weapon(id: String) -> WeaponInstance:
	var weapon := WeaponInstance.new()
	weapon.initialize(id, player)
	weapon.use_active_range_rules = true
	weapon.principal_getter = Callable(loadout, "get_current_principal")
	loadout.weapon_instances.append(weapon)
	return weapon


func build_plate() -> void:
	plate = CanvasLayer.new()
	plate.layer = 100
	game.add_child(plate)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 160)
	panel.add_theme_stylebox_override("panel", FinanceUIStyle.box("16201fee", "566d5d", 16))
	plate.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	caption = Label.new()
	FinanceUIStyle.label(caption, 28, Color("f1d58c"))
	box.add_child(caption)
	detail = Label.new()
	FinanceUIStyle.label(detail, 18, Color("e6e8dc"))
	box.add_child(detail)


func capture_weapons() -> void:
	build_plate()
	for data: Dictionary in DataRegistry.get_table("weapons"):
		clear_weapons()
		battle.wave_manager.clear_enemies()
		await frames()
		player.global_position = anchor
		player._sync_camera()
		player.camera_2d.force_update_scroll()
		var weapon := add_weapon(str(data.id))
		for stat in ["area_size", "damage_area_size", "projectile_count"]:
			var base := float(data.get("base_stats", {}).get(stat, StatDefinitions.get_default_value(stat)))
			weapon.runtime_stats[stat] = base - player.get_stat(stat) + StatDefinitions.get_default_value(stat)
		check(weapon.level == 1 and weapon.get_attached_item_instances().is_empty(), "level 1 without enchantments " + weapon.weapon_id)
		check(is_zero_approx(weapon.get_stat("area_size")) and is_zero_approx(weapon.get_stat("damage_area_size")), "zero range/area bonus " + weapon.weapon_id)
		var reach := weapon.get_attack_range()
		check(is_equal_approx(reach, float(data.attack_range)), "configured reach " + weapon.weapon_id)
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", anchor + Vector2(reach * 0.68, 0)) as EnemyController
		enemy.set_physics_process(false)
		enemy.current_hp = 100000
		await frames()
		var controller := battle.active_controller
		controller.selected_weapon = weapon
		controller._has_pointer_position = true
		controller._pointer_position = player.get_global_transform_with_canvas().origin + Vector2(800, 0)
		controller._update_indicator()
		caption.text = "%s  ·  初始攻击距离 %d" % [data.display_name, reach]
		detail.text = "Lv.1 · 无附魔 · 距离/范围加成 0 · 默认投射物 %d\n正式场景范围预览 · 固定镜头 1× · 向右瞄准" % weapon.get_stat("projectile_count")
		check(controller.indicator.visible, "live indicator visible " + weapon.weapon_id)
		await capture(weapon.weapon_id + "_range")
		var entry := {"id": weapon.weapon_id, "name": data.display_name, "range": reach, "hit_radius": weapon.get_hit_radius(), "projectile_count": weapon.get_stat("projectile_count"), "aim": weapon.weapon_id + "_range.png", "attack": weapon.weapon_id + "_attack.png", "camera_zoom": player.camera_2d.zoom.x}
		controller.cancel_aim()
		player.set_physics_process(true)
		check(loadout.cast_weapon(weapon, anchor + Vector2(800, 0)), "production cast " + weapon.weapon_id)
		var duration := 0.15
		if weapon.is_copper_lamp() or weapon.is_ritual_tome() or weapon.is_grenade(): duration = 0.6
		elif weapon.is_mutant_tentacle(): duration = 0.25
		elif weapon.is_earth_hammer(): duration = 0.45
		elif weapon.is_mobility_weapon() and not weapon.is_hand_cannon(): duration = 0.28
		elif str(data.get("projectile_behavior", "")) == "plasma": duration = 0.5
		await get_tree().create_timer(duration).timeout
		detail.text = "Lv.1 · 无附魔 · 距离/范围加成 0 · 默认投射物 %d\n正式武器运行时 · 实际释放后 %.2f 秒" % [weapon.get_stat("projectile_count"), duration]
		await capture(weapon.weapon_id + "_attack")
		player.set_physics_process(false)
		loadout._clear_weapon_runtime(weapon)
		records.append(entry)
		await get_tree().create_timer(0.7).timeout
	plate.hide()
	clear_weapons()
	battle.wave_manager.clear_enemies()
	await frames()


func capture_finance() -> void:
	clear_weapons()
	for id in ["weapon_void_blade", "weapon_nightwatch_spear", "weapon_copper_lamp", "weapon_hand_cannon", "weapon_kunyu_ritual_tome", "weapon_iron_grenade_cannon", "weapon_meteor_flail"]:
		add_weapon(id)
	loadout._notify_loadout_changed()
	battle.wave_manager.apply_gold_delta(800, "font_review")
	flow.finish_current_wave()
	await frames(25)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	battle.wave_manager.goblin_trades.cancel()
	popup.cancel_trade("font_review")
	popup._select_tab("enchant")
	for pair in [["weapon_void_blade", "scroll_fire"], ["weapon_nightwatch_spear", "scroll_ice"]]:
		var item := player.item_inventory.add_item_from_base(pair[1], "font_review")
		check(flow.submit_enchantment_operation("attach", pair[0], str(item.item_instance_id)).success, "attach representative enchantment " + pair[1])
	var tome := loadout.get_weapon_instance("weapon_kunyu_ritual_tome")
	for i in 3: tome.upgrade()
	var count := 0
	for data: Dictionary in DataRegistry.get_table("augmentations"):
		var item := player.item_inventory.add_item_from_base(str(data.id), "font_review")
		if count < 24: count += 1
		else: break
		if tome.get_attached_item_instances().size() < tome.get_attachment_slot_count() and tome.get_attachment_incompatibility(item).is_empty():
			flow.submit_enchantment_operation("attach", tome.weapon_id, str(item.item_instance_id))
	var work := popup.workbench
	for selected in ["weapon_void_blade", "weapon_kunyu_ritual_tome"]:
		work._select_weapon(selected)
		work._weapon_scroll.scroll_horizontal = 0
		await frames(15)
		verify_workbench(work, selected)
		await capture("finance_" + selected)
	work._weapon_scroll.scroll_horizontal = roundi(work._weapon_scroll.get_h_scroll_bar().max_value)
	await frames()
	await capture("finance_weapon_scroll_end")
	check(not work._weapon_scroll_right.visible and work._weapon_scroll_left.visible, "overflow list reaches final weapon")
	get_window().size = Vector2i(1280, 720)
	await frames(15)
	verify_workbench(work, "1280x720")
	await capture("finance_1280")
	get_window().size = Vector2i(1920, 1080)
	await frames()
	work._select_weapon("weapon_void_blade")
	var first := work._inventory.get_child(0) as EnchantmentInventoryCard
	first.pressed.emit()
	check(work.selected_item_id == str(first.item_instance.item_instance_id), "inventory item still selects")
	var second_weapon := work._weapon_row.get_child(1) as Button
	second_weapon.pressed.emit()
	check(work.selected_weapon_id == "weapon_nightwatch_spear", "resized weapon card still selects")


func verify_workbench(work: EnchantmentWorkbench, label: String) -> void:
	var first := work._inventory.get_child(0) as EnchantmentInventoryCard
	var font_size := first._caption.get_theme_font_size("font_size")
	check(work._weapon_name.get_theme_font_size("font_size") == font_size, "weapon heading matches inventory " + label)
	for button: Button in work._weapon_row.get_children():
		check(button.get_theme_font_size("font_size") == font_size and not button.clip_text, "weapon name and slot count fit " + button.weapon.weapon_id)
		check(button.size.x >= button.get_minimum_size().x, "weapon frame contains its text " + button.weapon.weapon_id)
	for slot in work._slots.get_children():
		if not slot is EnchantmentSlotCard: continue
		var text_width: float = slot._caption.get_theme_font("font").get_string_size(slot._caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		check(slot._caption.get_theme_font_size("font_size") == font_size, "equipped caption matches inventory " + label)
		check(slot._caption.size.x >= text_width and slot.get_global_rect().encloses(slot._caption.get_global_rect()), "equipped caption fits frame " + label)
		var binding: Node = slot._art.get_node(ItemIconArt.BINDING_NAME)
		check(binding.minimum_pixels == 32 and binding._logical_extent == 32, "equipped icon remains 32px " + label)
	check(first._art.custom_minimum_size == Vector2(32, 32), "inventory icon remains 32px " + label)
	ui_metrics.append({"case": label, "font_size": font_size, "weapon_card": str(work._weapon_row.get_child(0).size), "inventory_card": str(first.size), "workbench_rect": str(work.get_global_rect()), "viewport": str(get_window().size)})
