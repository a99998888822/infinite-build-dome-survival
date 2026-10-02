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
var _request_id := 0
var _apply_pending := false
var _apply_scheduled := false
var _save_pending := false


func _ready() -> void:
	# Foreign native hosts own size and visibility; avoid moving them or saving
	# capture dimensions over the user's normal fullscreen/resolution settings.
	if OS.get_cmdline_user_args().has("--background-capture"):
		return
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
	_queue_window_settings(true)


func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_queue_window_settings(true)


func apply_current_settings() -> void:
	_queue_window_settings(false)


func _apply_startup_settings() -> void:
	if _startup_applied:
		return
	_startup_applied = true
	# An explicit choice made before startup settles takes precedence over disk.
	if _request_id > 0:
		return
	var config := ConfigFile.new()
	var load_result := config.load(_get_settings_path())
	var has_saved_settings := load_result == OK
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
	_queue_window_settings(true)


func _queue_window_settings(persist: bool) -> void:
	_request_id += 1
	_apply_pending = true
	_save_pending = _save_pending or persist
	_schedule_window_settings()


func _schedule_window_settings() -> void:
	if _apply_scheduled or _applying_settings:
		return
	_apply_scheduled = true
	call_deferred("_apply_queued_settings")


func _apply_queued_settings() -> void:
	# call_deferred alone can drain more deferred work in the same idle cycle.
	# Waiting for a frame also lets the dropdown finish handling its input.
	await get_tree().process_frame
	_apply_scheduled = false
	if not _apply_pending or _applying_settings:
		return
	var request := _request_id
	var target_size := get_resolution()
	var target_fullscreen := _fullscreen
	var persist := _save_pending
	_apply_pending = false
	_save_pending = false
	_applying_settings = true
	_apply_window_settings(target_size, target_fullscreen)
	if request != _request_id:
		# A resize listener can request a new target synchronously. Finish this
		# transaction, but persist/notify only the final request on a later frame.
		_save_pending = _save_pending or persist
	else:
		if persist:
			_save_settings()
		settings_changed.emit()
	_applying_settings = false
	if _apply_pending:
		_schedule_window_settings()


func _apply_window_settings(target_size: Vector2i, target_fullscreen: bool) -> void:
	var window := _get_main_window()
	if window == null or window.is_embedded():
		return
	var target_mode := Window.MODE_FULLSCREEN if target_fullscreen else Window.MODE_WINDOWED
	if window.mode != target_mode:
		window.mode = target_mode
	if target_fullscreen:
		return
	if window.borderless:
		window.borderless = false
	if window.size != target_size:
		window.size = target_size
	_center_window(window, target_size)


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
	if window.position != target_position:
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
	var path := _get_settings_path()
	var config := ConfigFile.new()
	var load_result := config.load(path)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		return
	config.set_value("display", "settings_version", SETTINGS_VERSION)
	config.set_value("display", "resolution_index", _resolution_index)
	config.set_value("display", "resolution_width", get_resolution().x)
	config.set_value("display", "resolution_height", get_resolution().y)
	config.set_value("display", "fullscreen", _fullscreen)
	var result := config.save(path)
	if result != OK:
		push_warning("[WindowSettings] Cannot save display settings: %s" % error_string(result))


func _get_settings_path() -> String:
	return SETTINGS_PATH
