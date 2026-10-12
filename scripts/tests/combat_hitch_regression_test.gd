extends Node

const REACTION = preload("res://scripts/effects/element_reaction_text.gd")
var checks := 0
var failures := 0
var captures := ""
var legacy_path := ""
var selections: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): captures = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--legacy-reaction="): legacy_path = arg.trim_prefix("--legacy-reaction=")
	_run.call_deferred()


func frames(count := 3) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("COMBAT_HITCH_REGRESSION " + message)


func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(captures.path_join(name + ".png"))


func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().size = Vector2i(1152, 648)
	get_window().content_scale_size = Vector2i(1152, 648)
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	await _cards()
	await _reactions()
	await _damage()
	if not legacy_path.is_empty(): await _compare_reaction_pixels()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("COMBAT_HITCH_REGRESSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _cards() -> void:
	var popup := preload("res://scenes/ui/shop/shop_popup.tscn").instantiate() as ShopPopup
	add_child(popup)
	popup.offer_selected.connect(func(offer): selections.append(offer))
	var generator := ShopOfferGenerator.new()
	var pool := generator.build_shop_candidate_pool({"load_capacity": 100, "current_load": 0})
	var relics := pool.filter(func(c): return c.offer_type == "relic")
	var weapons := pool.filter(func(c): return c.offer_type == "new_weapon")
	await frames()
	check(popup._card_pool.size() == 4 and popup._offer_cards.is_empty(), "cards prepared without active offers")
	popup.configure({"mode": "free", "offers": relics.slice(0, 3)})
	popup.show_popup()
	var reused := popup._offer_cards[0]
	await get_tree().create_timer(0.5).timeout
	await capture("reward_free")
	reused._set_card_hovered(true)
	reused.play_claim_animation(true)
	popup.hide_popup()
	check(reused.offer_data.is_empty() and reused._bond_player == null and reused._icon_float_tween == null, "closing releases data and animation")
	popup.configure({"mode": "shop", "offers": [weapons[0], relics[5]], "gold": 999, "refresh_cost": 10})
	popup.show_popup()
	await get_tree().create_timer(0.5).timeout
	check(popup._offer_cards.size() == 2 and popup._offer_cards[0] == reused, "same card reused across reward and shop")
	check(not reused.select_button.disabled and reused.mouse_filter == Control.MOUSE_FILTER_STOP, "claimed slot regains interaction")
	check(reused.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(reused.modulate.a, 1.0) and reused.z_index == 0, "claim and hover cannot animate the next offer")
	check(reused.offer_data == weapons[0] and reused.select_button.icon != null, "new offer and shop button replace previous contents")
	check(ItemIconArt.source_path(reused.icon_texture.texture) == str(weapons[0].icon), "relic card restores weapon icon")
	check(reused.selected.get_connections().size() == 1, "reuse does not multiply selection callbacks")
	reused.select_button.pressed.emit()
	check(selections.size() == 1 and selections[0] == weapons[0], "selection submits the new offer exactly once")
	popup.reset_submission()
	await capture("reward_reused_shop")
	for count in [8, 1, 3, 8, 2]:
		popup.configure({"mode": "free", "offers": relics.slice(0, count)})
		popup.show_popup()
		check(popup._offer_cards.size() == count and popup._card_pool.size() == 8, "bounded pool handles page size %d" % count)
		popup.hide_popup()
	popup.reset_run()
	await frames()
	check(popup.offer_grid.get_child_count() == 0 and popup._card_pool.is_empty(), "run reset releases pooled widgets")
	var locale := L10n.locale
	L10n.set_locale("en" if locale == "zh_CN" else "zh_CN", false)
	await frames()
	check(popup._offer_cards.is_empty() and popup.payload.is_empty(), "locale change cannot revive old offers")
	L10n.set_locale(locale, false)
	popup.queue_free()
	await frames()
	check(FinanceUIStyle._pending_item_icons.is_empty(), "background icon requests finish")


func _reactions() -> void:
	var arena := Node2D.new()
	add_child(arena)
	var identities: Array[int] = []
	for index in 160:
		var text := REACTION.spawn(arena, "thunder_fire", Vector2(index * 3, 100))
		identities.append(text.get_instance_id())
	check(get_tree().get_nodes_in_group(REACTION.GROUP).size() == 160, "all simultaneous reaction contacts retain their text")
	var first = arena.get_child(0)
	var age: float = first.age
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	first._physics_process(0.4)
	check(is_equal_approx(first.age, age), "reaction animation respects battle pause")
	var previous_line: TextLine = first._line
	var locale := L10n.locale
	L10n.set_locale("en" if locale == "zh_CN" else "zh_CN", false)
	check(first._line != previous_line and is_equal_approx(first.age, age), "paused reaction updates language without restarting")
	L10n.set_locale(locale, false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for text in get_tree().get_nodes_in_group(REACTION.GROUP):
		text.cancel()
		text.cancel()
	await frames()
	check(arena.get_child_count() == 128 and get_tree().get_nodes_in_group(REACTION.GROUP).is_empty(), "idle pool bounded and cancellation idempotent")
	var second = REACTION.spawn(arena, "conduct", Vector2(50, 80))
	check(second.get_instance_id() in identities and second.kind == "conduct" and second.age == 0.0, "pooled reaction resets kind and lifetime")
	check(second.get_index() == arena.get_child_count() - 1, "reused contact draws after older contacts")
	check(second.global_position == (Vector2(50, 80) - second._line.get_size() * 0.5).round(), "pooled reaction starts at new contact")
	second._physics_process(1.0)
	check(not second.visible and not second.is_physics_processing(), "expired reaction stops processing")
	arena.queue_free()
	await frames()
	check(get_tree().get_nodes_in_group(REACTION.GROUP).is_empty(), "encounter cleanup leaves no reaction nodes")


func _damage() -> void:
	var arena := Node2D.new()
	add_child(arena)
	EnemyController.prepare_damage_number_pool(arena)
	EnemyController.prepare_damage_number_pool(arena)
	check(arena.get_child_count() == 160 and EnemyController.active_damage_numbers == 0, "battle preparation is idempotent and reserves no active budget")
	var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.current_hp = 10000
	for index in 400: enemy.take_damage(1, "hitch_regression")
	check(enemy.current_hp == 9600, "display optimization preserves every damage event")
	check(EnemyController.active_damage_numbers == 128, "ordinary display budget unchanged")
	for index in 40: enemy.take_damage(2, "hitch_regression", true)
	check(enemy.current_hp == 9520 and EnemyController.active_damage_numbers == 160, "critical reserve does not cap damage")
	await get_tree().create_timer(1.2).timeout
	check(EnemyController.active_damage_numbers == 0, "numbers recycle after animation")
	enemy.take_damage(9, "hitch_regression", true)
	arena.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 0, "scene cleanup releases active number budget")


func _compare_reaction_pixels() -> void:
	if DisplayServer.get_name() == "headless": return
	var legacy := GDScript.new()
	legacy.source_code = FileAccess.get_file_as_string(legacy_path)
	check(legacy.reload() == OK, "load pre-change reaction for visual comparison")
	for kind in ["thunder_fire", "conduct"]:
		var images: Array[Image] = []
		for script in [legacy, REACTION]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(160, 80)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var text = script.spawn(viewport, kind, Vector2(80, 50))
			text.age = 0.2
			text._paint()
			text.set_physics_process(false)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			images.append(viewport.get_texture().get_image())
			viewport.queue_free()
			await frames()
		if not captures.is_empty():
			images[0].save_png(captures.path_join(kind + "_before.png"))
			images[1].save_png(captures.path_join(kind + "_after.png"))
		check(images[0].get_data() == images[1].get_data(), "reaction appearance matches original pixels: " + kind)
