extends Node
class_name WindowSettingsManager

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_VERSION: int = 2
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1024, 576),
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DEFAULT_RESOLUTION_INDEX: int = 1
const DEFAULT_FULLSCREEN: bool = false
const LEGACY_RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _resolution_index: int = DEFAULT_RESOLUTION_INDEX
var _fullscreen: bool = DEFAULT_FULLSCREEN
var _applying_settings: bool = false
var _startup_applied: bool = false


func _ready() -> void:
	call_deferred("_apply_startup_settings_deferred")


func _apply_startup_settings_deferred() -> void:
	await get_tree().process_frame
	_apply_startup_settings()


func get_resolution_index() -> int:
	return _resolution_index


func get_resolution() -> Vector2i:
	return RESOLUTION_PRESETS[_resolution_index]


func get_resolution_presets() -> Array[Vector2i]:
	return RESOLUTION_PRESETS.duplicate()


func get_resolution_label() -> String:
	var size := get_resolution()
	return "%d × %d" % [size.x, size.y]


func is_fullscreen() -> bool:
	return _fullscreen


func is_embedded() -> bool:
	var window := _get_main_window()
	return window != null and window.is_embedded()


func set_resolution_index(index: int) -> void:
	var next_index := clampi(index, 0, RESOLUTION_PRESETS.size() - 1)
	_resolution_index = next_index
	_apply_window_settings()
	_save_settings()
	settings_changed.emit()


func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_apply_window_settings()
	_save_settings()
	settings_changed.emit()


func apply_current_settings() -> void:
	_apply_window_settings()
	settings_changed.emit()


func _apply_startup_settings() -> void:
	if _startup_applied:
		return
	_startup_applied = true
	var config := ConfigFile.new()
	var has_saved_settings := config.load(SETTINGS_PATH) == OK
	var settings_version := int(config.get_value("display", "settings_version", 0)) if has_saved_settings else 0
	var has_current_settings := has_saved_settings and settings_version >= SETTINGS_VERSION
	if has_current_settings and config.has_section_key("display", "resolution_width") and config.has_section_key("display", "resolution_height"):
		var saved_size := Vector2i(int(config.get_value("display", "resolution_width", 1152)), int(config.get_value("display", "resolution_height", 648)))
		_resolution_index = _find_resolution_index(saved_size)
	elif has_current_settings and config.has_section_key("display", "resolution_index"):
		_resolution_index = _resolve_legacy_resolution_index(int(config.get_value("display", "resolution_index", DEFAULT_RESOLUTION_INDEX)))
	else:
		_resolution_index = _find_best_resolution_index()
	if has_saved_settings and config.has_section_key("display", "fullscreen"):
		_fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	else:
		_fullscreen = DEFAULT_FULLSCREEN
	_apply_window_settings()
	_save_settings()
	settings_changed.emit()


func _apply_window_settings() -> void:
	if _applying_settings:
		return
	var window := _get_main_window()
	if window == null or window.is_embedded():
		return
	_applying_settings = true
	if _fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = false
		window.size = get_resolution()
		_center_window(window, get_resolution())
	_applying_settings = false
	if not _fullscreen:
		call_deferred("_reapply_windowed_size")


func _reapply_windowed_size() -> void:
	if _fullscreen:
		return
	var window := _get_main_window()
	if window == null or window.is_embedded():
		return
	window.mode = Window.MODE_WINDOWED
	window.borderless = false
	window.size = get_resolution()
	_center_window(window, get_resolution())


func _get_main_window() -> Window:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root as Window


func _find_resolution_index(size: Vector2i) -> int:
	for index in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[index] == size:
			return index
	return _find_best_resolution_index()


func _resolve_legacy_resolution_index(index: int) -> int:
	var legacy_index := clampi(index, 0, LEGACY_RESOLUTION_PRESETS.size() - 1)
	return _find_resolution_index(LEGACY_RESOLUTION_PRESETS[legacy_index])


func _center_window(window: Window, target_size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return
	var target_position := Vector2i(
		usable_rect.position.x + (usable_rect.size.x - target_size.x) / 2,
		usable_rect.position.y + (usable_rect.size.y - target_size.y) / 2,
	)
	target_position.x = maxi(target_position.x, usable_rect.position.x)
	target_position.y = maxi(target_position.y, usable_rect.position.y)
	window.position = target_position


func _find_best_resolution_index() -> int:
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var usable_size := usable_rect.size
	if usable_size.x <= 0 or usable_size.y <= 0:
		usable_size = DisplayServer.screen_get_size(screen)
	if usable_size.x <= 0 or usable_size.y <= 0:
		return DEFAULT_RESOLUTION_INDEX
	var best_index := 0
	for index in range(RESOLUTION_PRESETS.size()):
		var candidate := RESOLUTION_PRESETS[index]
		if candidate.x <= usable_size.x and candidate.y <= usable_size.y:
			best_index = index
	return best_index


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("display", "settings_version", SETTINGS_VERSION)
	config.set_value("display", "resolution_index", _resolution_index)
	config.set_value("display", "resolution_width", get_resolution().x)
	config.set_value("display", "resolution_height", get_resolution().y)
	config.set_value("display", "fullscreen", _fullscreen)
	config.save(SETTINGS_PATH)
