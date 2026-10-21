extends Node
## Run headless for resource checks, or on the private desktop for rendered checks.

const FONT_PATHS := ["res://assets/font/native_hud/interface.res", "res://assets/font/native_hud/character.res"]
const FONT_SIZES := [[17, 18, 20, 23, 27, 30, 33, 40], [20, 24, 33]]
const SOURCE_FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const SAMPLE := "设置全屏分辨率战斗返回 Settings 0123456789"

class TransientWindowSettings extends WindowSettingsManager:
	func _ready() -> void:
		pass
	func _save_settings() -> void:
		pass

var checks := 0
var failures := 0
var output := ""
var manager: TransientWindowSettings
var game: GameRoot
var menu: MainMenuUIController
var samples: Array[Label] = []
var baseline_ink: Array[int] = []
var sample_layer: CanvasLayer

func _ready() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("Run font tests headless or on a private desktop")
		get_tree().quit(9)
		return
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func frames(count := 12) -> void:
	for i in count: await get_tree().process_frame

func _run() -> void:
	CampProgression.begin_transient_session()
	manager = TransientWindowSettings.new()
	add_child(manager)
	manager.settings_changed.connect(func():
		WindowSettings._resolution_index = manager.get_resolution_index()
		WindowSettings._fullscreen = manager.is_fullscreen()
		WindowSettings.settings_changed.emit())
	for path in FONT_PATHS:
		var font := load(path) as FontFile
		check(is_equal_approx(font.oversampling, 1.0), path + " fixes bitmap oversampling at 1.0")
		check(font.data.is_empty(), path + " uses baked glyphs")
		check(font.allow_system_fallback, path + " retains fallback for characters absent from the source")
		for font_size in FONT_SIZES[FONT_PATHS.find(path)]:
			var key := Vector2i(font_size, 0)
			check(font.get_texture_count(0, key) > 0, "%s has atlas at %d" % [path, font_size])
			var missing := PackedStringArray()
			for code in SAMPLE.to_utf32_buffer().to_int32_array():
				# The original Ark font lacks some Chinese characters (e.g. U+8FA8).
				# Those intentionally use the system fallback, not a baked atlas.
				if code == 32 or not SOURCE_FONT.has_char(code): continue
				var glyph := font.get_glyph_index(font_size, code, 0)
				if font.get_glyph_size(0, key, glyph).length_squared() == 0: missing.append("U+%04X" % code)
			check(missing.is_empty(), "%s size=%d missing baked glyphs: %s" % [path.get_file(), font_size, str(missing)])
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames()
	menu = game.get_node("UiRoot/MainMenuUIController")
	menu._on_settings_pressed()
	await frames(40)
	if DisplayServer.get_name() != "headless":
		_build_samples()
		if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
		manager.set_resolution_index(5)
		await frames()
		await _capture("01_window_1080", true)
		for index in [2, 0, 6, 5]:
			manager.set_resolution_index(index)
			await frames()
			await _capture("02_window_%d" % index)
		for round_index in 2:
			manager.set_fullscreen(true)
			await frames()
			check(get_window().mode == Window.MODE_FULLSCREEN, "native fullscreen entered")
			await _capture("03_fullscreen_%d" % round_index)
			menu._settings_panel.select_page(1)
			await frames()
			await _capture("04_combat_fullscreen_%d" % round_index)
			manager.set_fullscreen(false)
			manager.set_resolution_index(2)
			await frames()
			await _capture("05_restored_%d" % round_index)
			menu._settings_panel.select_page(0)
		manager.set_fullscreen(true)
		await frames()
		L10n.set_locale("en", false)
		await frames()
		await _capture("06_settings_en_fullscreen")
		L10n.set_locale("zh_CN", false)
		menu._close_settings()
		await frames(30)
		var flow := game.get_main_flow_coordinator()
		flow.enter_talents_flow()
		await frames()
		await _capture("07_talents_fullscreen")
		flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
		await frames()
		await _capture("08_character_fullscreen")
		check(flow.confirm_character_selection(), "start battle to verify shared HUD fonts")
		await frames(30)
		while flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP: flow.close_shared_reward_shop_popup()
		var battle: BattleRoot = game.get_node("SceneDirector").battle_root
		if flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE: battle.combat_guide.skip_button.pressed.emit()
		battle.wave_manager.set_process(false)
		battle.wave_manager.clear_enemies()
		await frames()
		await _capture("09_battle_fullscreen")
		flow.request_battle_utility("settings")
		await frames()
		await _capture("10_battle_settings_fullscreen")
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("FULLSCREEN_FONT_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _build_samples() -> void:
	# Use the main viewport: an unscaled SubViewport would miss the broken cache.
	sample_layer = CanvasLayer.new()
	sample_layer.layer = 100
	add_child(sample_layer)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.size = Vector2(1000, 660)
	sample_layer.add_child(background)
	for index in FONT_PATHS.size():
		for font_size in FONT_SIZES[index]:
			var label := Label.new()
			label.text = SAMPLE
			label.position = Vector2(0, samples.size() * 60)
			label.add_theme_font_override("font", load(FONT_PATHS[index]))
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_constant_override("outline_size", 0)
			sample_layer.add_child(label)
			samples.append(label)
	sample_layer.hide()

func _capture(id: String, baseline := false) -> void:
	sample_layer.show()
	await frames(2)
	await RenderingServer.frame_post_draw
	var bitmap := get_window().get_texture().get_image()
	var transform := get_window().get_stretch_transform()
	var pixel_scale := transform.get_scale().x
	for index in samples.size():
		var ink := 0
		var rect := Rect2i(transform * Rect2(0, index * 60, 1000, 60))
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if bitmap.get_pixel(x, y).r > 0.5: ink += 1
		if baseline: baseline_ink.append(ink)
		var normalized_ink := ink / (pixel_scale * pixel_scale)
		check(normalized_ink > 100 and normalized_ink > baseline_ink[index] * 0.4, "%s sample=%d glyph pixels=%d baseline=%d scale=%.3f" % [id, index, ink, baseline_ink[index], pixel_scale])
	sample_layer.hide()
	await frames(2)
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		check(get_window().get_texture().get_image().save_png(output.path_join(id + ".png")) == OK, "capture " + id)
