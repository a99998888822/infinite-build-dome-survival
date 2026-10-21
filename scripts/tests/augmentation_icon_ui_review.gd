extends Node
## Production screens with transient inventory; capture on a private desktop only.

const OUTPUT := "res://artifacts/previews/spell_icons_32/20261021-r01/screenshots"
var checks := 0
var failures := 0
var captures: Array[Dictionary] = []
var game: GameRoot
var battle: BattleRoot
var flow: MainFlowCoordinator
var items: Array[Dictionary] = []
var pointer := Vector2.ZERO

func _ready() -> void:
	WindowSettings._startup_applied = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
	get_tree().create_timer(100).timeout.connect(func(): get_tree().quit(99))

func frames(count := 12) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func icon_controls(node: Node, result: Array = []) -> Array:
	if node is Control and node.is_visible_in_tree():
		var texture: Texture2D = node.texture if node is TextureRect else node.icon if node is Button else null
		if ItemIconArt.is_augmentation(texture): result.append(node)
	for child in node.get_children(): icon_controls(child, result)
	return result

func inspect_icon(control: CanvasItem, tier: int) -> Dictionary:
	var texture: Texture2D = control.texture if control is TextureRect or control is Sprite2D else control.icon
	var source := ItemIconArt.source_path(texture)
	check(ItemIconArt.is_augmentation(texture), "augmentation identity " + source.get_file())
	check((load(source) as Texture2D).get_size() == Vector2(32, 32), "native source 32")
	var rect := Rect2()
	if control is Sprite2D:
		rect = control.get_rect()
		check(control.scale == Vector2.ONE, "pickup 1x without rotation")
	elif texture is ItemIconArt.PIXEL_TEXTURE:
		check(texture.logical_size == Vector2.ONE * tier, "fixed logical tier " + str(tier))
		rect = texture.last_local_rect
	else:
		check(control.size == Vector2.ONE * tier, "native drag preview size")
		rect = Rect2(Vector2.ZERO, control.size)
	var screen := ItemIconArt.PIXEL_TEXTURE.screen_transform(control) * rect
	if DisplayServer.get_name() != "headless":
		check(screen.size.is_equal_approx(Vector2.ONE * tier), "actual drawn size " + str(tier))
		check(screen.position.is_equal_approx(screen.position.round()), "integer drawing origin")
	return {"source": source, "rect": [screen.position.x, screen.position.y, screen.size.x, screen.size.y], "tier": tier}

func capture(id: String, controls: Array, tier: int, rich: RichTextLabel = null, weapon: WeaponInstance = null) -> void:
	await frames(16)
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var icons: Array = []
	for control in controls:
		icons.append(inspect_icon(control, tier))
	var embedded: Array = []
	if rich != null and weapon != null:
		check(rich.is_visible_in_tree() and rich.text.contains("[img=32x32]"), "visible native 32px embedded icons")
		var bounds := rich.get_global_rect()
		for item in weapon.get_attached_item_instances():
			embedded.append({"source": item.icon, "tier": 32, "search_rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
	if DisplayServer.get_name() != "headless":
		check(get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(id + ".png")) == OK, "capture " + id)
	captures.append({"name": id, "icons": icons, "embedded": embedded})

func move_pointer(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	event.relative = point - pointer
	pointer = point
	get_window().push_input(event, true)
	await frames(3)

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_window().push_input(event, true)
	await frames(3)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.set_option("show_hints", false, false)
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(20)
	flow = game.get_main_flow_coordinator()
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu.start_battle_button.pressed.emit()
	await frames()
	var starting := icon_controls(menu.character_view)
	check(starting.size() == 1, "beginner initial spell is present")
	await capture("01_character_select_32", starting, 32)
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start production battle")
	await frames(30)
	battle = game.get_node("SceneDirector").battle_root
	var manager := battle.wave_manager
	manager.set_process(false)
	manager.clear_battle_entities()
	battle.player.set_physics_process(false)
	battle.player.set("_invincibility_timer", 1000.0)
	battle.player.modifier_stack.set_base_stat("load_capacity", 1000)
	battle.loadout.set_physics_process(false)
	battle.active_controller.set_process(false)
	battle.active_controller.set_physics_process(false)
	var weapon := battle.loadout.get_weapon_instance("weapon_void_blade")
	for item in weapon.get_attached_item_instances(): battle.loadout.detach_item_from_weapon(weapon.weapon_id, str(item.item_instance_id))
	battle.player.item_inventory.clear()
	for record in DataRegistry.get_table("augmentations"):
		items.append(battle.player.item_inventory.add_item_from_base(str(record.id), "icon_review"))
	check(items.size() == 19, "all 19 formal icons in inventory")
	var pickups: Array = []
	for i in items.size():
		var pickup := preload("res://scenes/pickups/augmentation_pickup.tscn").instantiate() as AugmentationPickup
		battle.player.get_parent().add_child(pickup)
		pickup.global_position = battle.player.global_position + Vector2(-260 + (i % 7) * 76, -190 + (i / 7) * 76)
		pickup.initialize(str(items[i].base_item_id))
		pickup.set_physics_process(false)
		pickups.append(pickup._icon_sprite)
	await capture("02_battle_drops_32", pickups, 32)
	for sprite in pickups: sprite.get_parent().queue_free()
	manager.current_wave_index = 7
	manager.wave_time_left = 43
	manager.current_gold = 1280
	battle.hud._refresh_all()
	flow.request_esc_overlay()
	await get_tree().create_timer(0.7).timeout
	check(battle.esc_overlay._item_cards.size() == 19, "Esc exposes all 19 icons")
	await capture("03_esc_inventory_64", battle.esc_overlay._item_cards, 64)
	flow.close_esc_overlay()
	for id in ["scroll_lightning", "scroll_might", "scroll_multishot"]:
		for attempt in 10:
			if weapon.has_available_attachment_slot(): break
			if not weapon.upgrade(): break
		var item := battle.player.item_inventory.add_item_from_base(id, "icon_review_equipped")
		check(battle.loadout.attach_item_to_weapon(weapon.weapon_id, str(item.item_instance_id)), "fixture attachment " + id)
	check(battle.loadout.equip_weapon("weapon_plasma_cannon"), "second weapon enables sale dialog")
	flow.request_esc_overlay()
	await frames()
	var strip := battle.esc_overlay.weapon_strip
	var button: Button = strip._weapon_buttons[0]
	strip._tooltip_mouse_position = button.get_global_rect().get_center()
	strip._show_weapon_tooltip(weapon, button)
	await capture("04_esc_weapon_details_32", [], 32, strip.weapon_tooltip_label, weapon)
	flow.close_esc_overlay()
	battle.player.add_relic("relic_finance_manager")
	flow.finish_current_wave()
	await frames(25)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.visible, "production finance screen opens")
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("augmentation_icon_review")
	popup._select_tab("enchant")
	var bench := popup.workbench
	bench._select_weapon(weapon.weapon_id)
	await frames(20)
	var workbench_icons := icon_controls(bench)
	check(workbench_icons.size() == 22, "workbench includes 19 inventory and 3 equipped icons")
	await capture("05_workbench_inventory_slots_32", workbench_icons, 32)
	# Exercise the actual input drag path, including its native-size cursor preview.
	var card := bench._inventory.get_child(0) as EnchantmentInventoryCard
	var start := card.get_global_rect().get_center()
	await move_pointer(start)
	await mouse_button(start, true)
	var destination := start + Vector2(-150, -100)
	await move_pointer(destination, true)
	check(get_window().gui_is_dragging(), "inventory drag is active")
	var drag_icons := icon_controls(get_window())
	check(drag_icons.size() > workbench_icons.size(), "native drag preview is visible")
	await capture("06_workbench_drag_32", drag_icons, 32)
	await mouse_button(destination, false)
	check(not get_window().gui_is_dragging(), "drag ends without changing inventory")
	# The same 32px BBCode is used by finance weapon details.
	bench._weapon_row.get_child(0).mouse_entered.emit()
	await frames()
	var rich := popup._tooltip_text
	check(rich != null, "finance weapon tooltip contains rich text")
	if rich != null: await capture("07_workbench_weapon_details_32", [], 32, rich, weapon)
	popup._tooltip.hide()
	popup._open_sale("weapon", weapon.weapon_id)
	await frames()
	check(popup._sale_layer.visible, "weapon sale confirmation opens")
	await capture("08_weapon_sale_returns_32", icon_controls(popup._sale_items), 32)
	popup._sale_layer.hide()
	# Also cover the reusable enchantment sale dialog, although the workbench sells directly.
	popup._open_sale("enchantment", str(items[0].item_instance_id))
	await frames()
	check(popup._sale_layer.visible, "enchantment sale dialog uses 32px tier")
	await capture("09_enchantment_sale_32", [popup._sale_icon], 32)
	popup._sale_layer.hide()
	# Reusing it for a weapon again must restore 36px instead of retaining 32px.
	popup._open_sale("weapon", weapon.weapon_id)
	await frames()
	check(popup._sale_icon.texture.logical_size == Vector2(36, 36), "reused dialog restores weapon tier")
	popup._sale_layer.hide()
	var filename := "headless-manifest.json" if DisplayServer.get_name() == "headless" else "capture-manifest.json"
	var file := FileAccess.open(OUTPUT.path_join(filename), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures}, "\t"))
	file.close()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("AUGMENTATION_ICON_UI_REVIEW checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
