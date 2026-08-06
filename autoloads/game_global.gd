extends Node

signal game_mode_changed(previous_mode: String, current_mode: String)
signal debug_message(message: String)
signal runtime_state_reset

var game_mode: String = "bootstrap"
var debug_enabled: bool = true
var build_name: String = "infinite-build-dome-survival"
var runtime_flags: Dictionary = {}


func set_game_mode(new_mode: String) -> void:
	# 切换全局模式，仅处理状态变化，不承载玩法逻辑。
	var sanitized_mode := new_mode.strip_edges()
	if sanitized_mode.is_empty() or game_mode == sanitized_mode:
		return
	var previous_mode := game_mode
	game_mode = sanitized_mode
	emit_signal("game_mode_changed", previous_mode, game_mode)


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled


func set_runtime_flag(flag_name: String, flag_value: Variant) -> void:
	# 运行时标记用于调试或临时开关，不写入配置表。
	var sanitized_flag := flag_name.strip_edges()
	if sanitized_flag.is_empty():
		return
	runtime_flags[sanitized_flag] = flag_value


func get_runtime_flag(flag_name: String, default_value: Variant = null) -> Variant:
	var sanitized_flag := flag_name.strip_edges()
	if sanitized_flag.is_empty():
		return default_value
	return runtime_flags.get(sanitized_flag, default_value)


func has_runtime_flag(flag_name: String) -> bool:
	var sanitized_flag := flag_name.strip_edges()
	return not sanitized_flag.is_empty() and runtime_flags.has(sanitized_flag)


func clear_runtime_flag(flag_name: String) -> void:
	var sanitized_flag := flag_name.strip_edges()
	if sanitized_flag.is_empty():
		return
	runtime_flags.erase(sanitized_flag)


func reset_runtime_state() -> void:
	# 重置临时运行态，供启动自检和切场景复用。
	runtime_flags.clear()
	game_mode = "bootstrap"
	emit_signal("runtime_state_reset")


func log_debug(message: String) -> void:
	# 统一输出调试日志，便于后续挂接更复杂的调试面板。
	if not debug_enabled:
		return
	var sanitized_message := message.strip_edges()
	if sanitized_message.is_empty():
		return
	print("[GameGlobal] %s" % sanitized_message)
	emit_signal("debug_message", sanitized_message)
