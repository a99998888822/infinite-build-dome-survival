extends Node
## Separate from window settings; review/test runs never write user preferences.
signal settings_changed
const PATH := "user://combat_settings.cfg"
var keyboard_movement := false
var quick_cast := false
var show_hints := true
var combat_guide_seen := false
var weapon_auto_cast: Dictionary = {}

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	load_config(config)
	if config.has_section_key("combat", "wheelchair_mode"):
		_save(true)

func load_config(config: ConfigFile) -> void:
	combat_guide_seen = bool(config.get_value("onboarding", "combat_guide_seen", false))
	keyboard_movement = bool(config.get_value("combat", "keyboard_movement", false))
	quick_cast = bool(config.get_value("combat", "quick_cast", false))
	show_hints = bool(config.get_value("combat", "show_hints", true))
	weapon_auto_cast.clear()
	for id in config.get_section_keys("weapon_auto_cast") if config.has_section("weapon_auto_cast") else PackedStringArray():
		var value: Variant = config.get_value("weapon_auto_cast", id)
		if value is bool: weapon_auto_cast[id] = value
	# Migrate the effective legacy policy, including unequipped weapons. The old
	# key is omitted on save, so later per-skill edits are never overwritten.
	if config.has_section_key("combat", "wheelchair_mode") and not bool(config.get_value("combat", "wheelchair_mode")):
		for record: Dictionary in DataRegistry.get_table("weapons"):
			weapon_auto_cast[str(record.id)] = false

func build_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("onboarding", "combat_guide_seen", combat_guide_seen)
	for option in ["keyboard_movement", "quick_cast", "show_hints"]:
		config.set_value("combat", option, get(option))
	for id: String in weapon_auto_cast:
		config.set_value("weapon_auto_cast", id, weapon_auto_cast[id])
	return config

func should_show_combat_guide() -> bool:
	if combat_guide_seen or OS.has_feature("mobile"):
		return false
	# Automated runs opt in explicitly; they never consume the player's first visit.
	var args := OS.get_cmdline_user_args()
	return "--show-combat-guide" in args or (DisplayServer.get_name() != "headless" and not "--transient-session" in args)

func complete_combat_guide() -> void:
	combat_guide_seen = true
	_save(true)

func prefers_auto_cast(id: String, mobility: bool) -> bool:
	return bool(weapon_auto_cast.get(id, not mobility))

func is_weapon_automatic(weapon: WeaponInstance) -> bool:
	return prefers_auto_cast(weapon.weapon_id, weapon.is_mobility_weapon())

func set_weapon_auto_cast(id: String, value: bool, persist: bool = true) -> void:
	if not DataRegistry.has_record("weapons", id): return
	weapon_auto_cast[id] = value
	_save(persist)
	settings_changed.emit()

func reset_weapon_auto_cast(persist: bool = true) -> void:
	weapon_auto_cast.clear()
	_save(persist)
	settings_changed.emit()

func set_option(key: String, value: bool, persist: bool = true) -> void:
	if key not in ["keyboard_movement", "quick_cast", "show_hints"]:
		return
	set(key, value)
	_save(persist)
	settings_changed.emit()

func _save(persist: bool) -> void:
	if persist and not "--transient-session" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		if build_config().save(PATH) != OK:
			push_warning("Combat settings could not be saved.")
