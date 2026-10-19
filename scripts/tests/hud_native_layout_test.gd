extends Node
## Native canvas contract and physical mouse routing at supported window sizes.

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count := 12) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	WindowSettings._startup_applied = true
	_run.call_deferred()

func _run() -> void:
	CampProgression.begin_transient_session()
	var window := get_tree().root
	window.size = Vector2i(1920, 1080)
	var game: GameRoot = load("res://scenes/core/game_root.tscn").instantiate()
	window.add_child(game)
	get_tree().current_scene = game
	await frames()
	var menu: MainMenuUIController = game.get_node("UiRoot/MainMenuUIController")
	menu._on_settings_pressed()
	await frames(40)
	var settings := menu._settings_panel
	var settings_bounds := settings.get_global_rect()
	for dimensions in [Vector2i(1152, 648), Vector2i(1184, 666), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		window.size = dimensions
		await frames()
		check(window.content_scale_size == Vector2i(1920, 1080), "logical canvas changes at " + str(dimensions))
		check(settings.scale == Vector2.ONE, "settings uses a presentation scale at " + str(dimensions))
		check(settings.get_global_rect().is_equal_approx(settings_bounds), "window resize moves native settings geometry at " + str(dimensions))
		settings.select_page(0)
		var point := window.get_stretch_transform() * settings.tabs[1].get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		window.push_input(motion)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			window.push_input(event)
		await frames(2)
		check(settings.combat_settings.visible, "physical click misses native tab at " + str(dimensions))
	menu._close_settings()
	await frames(30)
	var flow := game.get_main_flow_coordinator()
	flow.enter_talents_flow()
	await frames()
	var talents: CampBlueprintUIController = game.get_node("UiRoot/CampBlueprintUIController")
	check(talents._content.scale == Vector2.ONE and talents._zoom == 1.0, "talent HUD still scales a legacy canvas")
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(menu.character_view.canvas.scale == Vector2.ONE and menu.character_view.canvas.size == Vector2(1920, 1080), "character composition is not native")
	check(flow.confirm_character_selection(), "cannot start native HUD battle")
	await frames()
	var battle: BattleRoot = game.get_node("SceneDirector").battle_root
	var hud := battle.hud as BattleHud
	for control in [hud.top_left, hud._vitals_frame, hud._performance_line, hud._weapon_damage_meter, hud.wave_panel, hud.economy_panel, hud.combat_bar]:
		check(control.scale == Vector2.ONE, "combat HUD retains legacy scale on " + control.name)
	check(hud.combat_bar.cards.size() > 0 and is_equal_approx(hud.combat_bar.slot_size, 106.666667), "native weapon slot footprint changed")
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("HUD_NATIVE_LAYOUT_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
