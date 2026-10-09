extends Node
## Language services only. Never reloads gameplay data or rerolls a run.

signal locale_changed

const PREFERENCE_PATH := "user://localization.cfg"
const LOCALE_MANIFEST := "res://localization/locales.json"
const SOURCE_MAP := "res://localization/generated/source_keys.json"
var supported_locales: Array[String] = []
var locale_definitions: Dictionary = {}
var fallback_locale := "en"
var locale := "zh_CN"
var revision := 0
var _source_keys: Dictionary = {}


func _enter_tree() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOCALE_MANIFEST))
	fallback_locale = str(manifest.get("fallback_locale", "en"))
	for definition: Dictionary in manifest.get("locales", []):
		var id := str(definition.id)
		supported_locales.append(id)
		locale_definitions[id] = definition
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_MAP))
	if parsed is Dictionary:
		_source_keys = parsed
	var requested := OS.get_locale_language()
	var isolated := _is_transient()
	if isolated:
		requested = "zh_CN"
	else:
		var config := ConfigFile.new()
		if config.load(PREFERENCE_PATH) == OK:
			requested = str(config.get_value("language", "locale", requested))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			requested = argument.trim_prefix("--locale=")
	set_locale(requested, false)


func normalize_locale(value: String) -> String:
	var requested := value.to_lower().replace("-", "_")
	for id in supported_locales:
		if requested == id.to_lower(): return id
	for id in supported_locales:
		if requested.get_slice("_", 0) == id.to_lower().get_slice("_", 0): return id
	return fallback_locale


func set_locale(value: String, persist := true) -> void:
	var resolved := normalize_locale(value)
	var changed := locale != resolved
	locale = resolved
	TranslationServer.set_locale(locale)
	if get_tree() != null:
		get_tree().root.title = text("ui.main_menu.game_title")
	if persist and not _is_transient():
		var config := ConfigFile.new()
		config.set_value("language", "locale", locale)
		if config.save(PREFERENCE_PATH) != OK:
			push_warning("Language preference could not be saved.")
	if changed:
		revision += 1
		locale_changed.emit()


func text(key: String, arguments: Array = []) -> String:
	var result := str(TranslationServer.translate(StringName(key)))
	return result % arguments if not arguments.is_empty() else result


func source(value: Variant) -> String:
	var original := str(value)
	return text(str(_source_keys.get(original, original)))


func key_for_source(value: String) -> String:
	return str(_source_keys.get(value, value))


func message(key: String, arguments: Array = []) -> Dictionary:
	return {"message_key": key, "message_args": arguments.duplicate(true)}


func render_message(value: Variant) -> String:
	if not value is Dictionary:
		return source(value)
	if value.has("message_parts"):
		var parts := PackedStringArray()
		for part in value.message_parts:
			parts.append(render_message(part))
		return "".join(parts)
	var arguments: Array = []
	for argument in value.get("message_args", []):
		arguments.append(render_message(argument) if argument is Dictionary else source(argument) if argument is String else argument)
	return text(str(value.get("message_key", "")), arguments).format(value.get("message_replacements", {}))


func record_text(record: Dictionary, field: String, fallback: String = "") -> String:
	if record.has(field + "_message"):
		return render_message(record[field + "_message"])
	return source(record.get(field, fallback))


func _is_transient() -> bool:
	return DisplayServer.get_name() == "headless" or "--transient-session" in OS.get_cmdline_user_args() or "--background-capture" in OS.get_cmdline_user_args()
