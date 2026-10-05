extends Node
## Separate from window settings; review/test runs never write user preferences.
signal settings_changed
const PATH := "user://combat_settings.cfg"
var keyboard_movement := false
var quick_cast := false
var show_hints := true

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		keyboard_movement = bool(config.get_value("combat", "keyboard_movement", false))
		quick_cast = bool(config.get_value("combat", "quick_cast", false))
		show_hints = bool(config.get_value("combat", "show_hints", true))

func set_option(key: String, value: bool, persist: bool = true) -> void:
	if key not in ["keyboard_movement", "quick_cast", "show_hints"]:
		return
	set(key, value)
	if persist and not "--transient-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var config := ConfigFile.new()
		for option in ["keyboard_movement", "quick_cast", "show_hints"]:
			config.set_value("combat", option, get(option))
		if config.save(PATH) != OK:
			push_warning("Combat settings could not be saved.")
	settings_changed.emit()
