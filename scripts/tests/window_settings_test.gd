extends Node

class TestSettings extends WindowSettingsManager:
	var directory := ""
	var apply_count := 0
	var save_count := 0
	var apply_depth := 0
	var max_apply_depth := 0
	func _ready() -> void:
		pass
	func _get_settings_path() -> String:
		return directory.path_join("settings.cfg")
	func _apply_window_settings(target_size: Vector2i, target_fullscreen: bool) -> void:
		apply_count += 1
		apply_depth += 1
		max_apply_depth = maxi(max_apply_depth, apply_depth)
		super._apply_window_settings(target_size, target_fullscreen)
		apply_depth -= 1
	func _save_settings() -> void:
		save_count += 1
		super._save_settings()

var checks := 0
var failures := 0
var directory := ""
var manager: TestSettings

func _ready() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("Run window tests headless or on a private desktop")
		get_tree().quit(9)
		return
	directory = OS.get_environment("TEMP").path_join("window-settings-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(directory)
	_run.call_deferred()

func frames(count: int = 6) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func saved_config() -> ConfigFile:
	var config := ConfigFile.new()
	check(config.load(manager._get_settings_path()) == OK, "isolated display config readable")
	return config

func _run() -> void:
	manager = TestSettings.new()
	manager.directory = directory
	add_child(manager)
	var config := ConfigFile.new()
	config.set_value("audio", "sentinel", 37)
	config.save(manager._get_settings_path())
	var original_size := get_tree().root.size
	var notices := {"count":0}
	manager.settings_changed.connect(func(): notices.count += 1)
	manager.set_resolution_index(5)
	manager.set_fullscreen(true)
	manager.set_resolution_index(4)
	manager.set_fullscreen(false)
	manager.set_resolution_index(6)
	manager.apply_current_settings()
	check(get_tree().root.size == original_size and notices.count == 0, "selection callback neither resizes nor emits UI notifications")
	check(manager.apply_count == 0, "no synchronous native apply")
	await frames()
	check(get_tree().root.size == Vector2i(2560,1440) and not manager.is_fullscreen(), "burst uses final resolution and mode")
	check(manager.apply_count == 1, "six requests produce one native apply")
	check(manager.save_count == 1 and notices.count == 1, "merged request saves and notifies once")
	config = saved_config()
	check(config.get_value("display", "resolution_width") == 2560 and config.get_value("audio", "sentinel") == 37, "only final preference saved; unrelated config preserved")
	await frames()
	check(manager.apply_count == 1, "no delayed second resize")
	var writes := manager.save_count
	get_tree().root.size = Vector2i(1280,720)
	manager.apply_current_settings()
	await frames()
	check(get_tree().root.size == Vector2i(2560,1440) and manager.save_count == writes, "explicit reapply restores size without writing preferences")
	# A native size_changed callback can submit a different target mid-apply.
	manager.set_resolution_index(5)
	await frames()
	var callback_state := {"submitted":false}
	var on_resize := func():
		if not callback_state.submitted and get_tree().root.size == Vector2i(2560,1440):
			callback_state.submitted = true
			manager.set_resolution_index(4)
	get_tree().root.size_changed.connect(on_resize)
	writes = manager.save_count
	var applies := manager.apply_count
	manager.set_resolution_index(6)
	await frames(12)
	get_tree().root.size_changed.disconnect(on_resize)
	check(callback_state.submitted and get_tree().root.size == Vector2i(1600,900), "resize callback queues its final target without losing it")
	check(manager.apply_count == applies + 2 and manager.save_count == writes + 1, "superseded target is not saved")
	config = saved_config()
	check(config.get_value("display", "resolution_width") == 1600, "reentrant final preference persisted")
	check(manager.apply_depth == 0 and manager.max_apply_depth == 1, "native transactions never nest")
	# UI observers may enqueue another choice while the completion signal fires.
	var notify_state := {"submitted":false}
	var on_notice := func():
		if not notify_state.submitted:
			notify_state.submitted = true
			manager.set_resolution_index(5)
			manager.set_resolution_index(6)
	manager.settings_changed.connect(on_notice)
	manager.set_resolution_index(3)
	await frames(12)
	manager.settings_changed.disconnect(on_notice)
	check(get_tree().root.size == Vector2i(2560,1440), "settings observer requests are deferred and merged")
	manager.set_fullscreen(true)
	await frames()
	manager.set_fullscreen(false)
	manager.set_resolution_index(5)
	await frames(12)
	# The dummy headless display reports a fixed mode; check native mode on GPU.
	var mode_ok := DisplayServer.get_name() == "headless" or get_tree().root.mode == Window.MODE_WINDOWED
	check(mode_ok and not manager.is_fullscreen() and get_tree().root.size == Vector2i(1920,1080), "fullscreen round trip restores requested window size")
	check(DirAccess.get_files_at(directory) == PackedStringArray(["settings.cfg"]), "display changes only write settings, with no diagnostic log files")
	manager.free()
	# Startup uses the same queue and applies the persisted state only once.
	manager = TestSettings.new()
	manager.directory = directory
	add_child(manager)
	manager._apply_startup_settings()
	check(manager.apply_count == 0, "startup applies asynchronously")
	await frames()
	check(manager.get_resolution() == Vector2i(1920,1080) and manager.apply_count == 1, "startup restores saved resolution once")
	manager._apply_startup_settings()
	await frames()
	check(manager.apply_count == 1, "startup is idempotent")
	manager.free()
	manager = TestSettings.new()
	manager.directory = directory
	add_child(manager)
	manager.set_resolution_index(4)
	manager._apply_startup_settings()
	await frames()
	check(manager.get_resolution() == Vector2i(1600,900) and get_tree().root.size == Vector2i(1600,900), "late startup cannot overwrite explicit input")
	print("WINDOW_SETTINGS_COMPLETE checks=%d failures=%d directory=%s" % [checks,failures,directory])
	get_tree().quit(1 if failures else 0)
