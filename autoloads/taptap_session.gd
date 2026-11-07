extends Node
## Android login boundary. SDK initialization is only permitted after consent.
## Login and cached accounts must pass compliance before gameplay is allowed.

signal state_changed
signal login_required

const CONFIG_PATH := "res://data_config/platform/taptap.json"
const CONSENT_PATH := "user://taptap_consent.cfg"

var state := "desktop"
var status_message := ""
var account: Dictionary = {}
var _config: Dictionary = {}
var _bridge: Object
var _required := false
var _consented := false
var _initialized := false
var _login_after_init := false
var _compliance_passed := false
var _compliance_request := 0


func _ready() -> void:
	if not OS.has_feature("android"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var configuration: Dictionary = parsed if parsed is Dictionary else {}
	var bridge: Object = Engine.get_singleton("TapTapGodot") if Engine.has_singleton("TapTapGodot") else null
	configure(bridge, configuration, true, _read_consent(configuration))


func configure(bridge: Object, configuration: Dictionary, required: bool, consented: bool) -> void:
	# Also used by isolated test instances, never to bypass Android production login.
	_bridge = bridge
	_config = configuration.duplicate(true)
	_required = required
	_consented = consented
	_initialized = false
	_login_after_init = false
	_compliance_passed = false
	_compliance_request += 1
	account.clear()
	if not required:
		_set_state("desktop", "")
		return
	if bridge == null:
		_set_state("unavailable", "未找到 TapTap 原生插件，请重新安装支持登录的 Android 包。")
		return
	for binding in [
		["initializationCompleted", _on_initialization_completed],
		["accountRestored", _on_account_restored],
		["loginCompleted", _on_login_completed],
		["loginFailed", _on_login_failed],
		["loginCancelled", _on_login_cancelled],
		["logoutCompleted", _on_logout_completed],
		["logoutFailed", _on_logout_failed],
		["complianceResult", _on_compliance_result],
	]:
		if not bridge.has_signal(binding[0]):
			_set_state("unavailable", "TapTap 插件版本过旧，请重新安装支持防沉迷的 Android 包。")
			return
		bridge.connect(binding[0], binding[1])
	if not configuration_ready():
		_set_state("configuration_required", "登录配置尚未完成，请补齐应用参数和隐私政策链接。")
	elif not _consented:
		_set_state("consent_required", "请先阅读并同意隐私政策和用户协议。" if has_user_agreement() else "请先阅读并同意隐私政策。")
	else:
		_initialize()


func is_required() -> bool:
	return _required


func can_enter_game() -> bool:
	return not _required or (state == "logged_in" and _compliance_passed and has_account())


func has_account() -> bool:
	return not str(account.get("open_id", "")).is_empty()


func require_login() -> bool:
	if can_enter_game():
		return true
	login_required.emit()
	return false


func configuration_ready() -> bool:
	return not str(_config.get("client_id", "")).strip_edges().is_empty() \
		and not str(_config.get("client_token", "")).strip_edges().is_empty() \
		and _valid_url(policy_url())


func has_user_agreement() -> bool:
	return _valid_url(agreement_url())


func policy_url() -> String:
	return str(_config.get("privacy_policy_url", ""))


func agreement_url() -> String:
	return str(_config.get("user_agreement_url", ""))


func has_consent() -> bool:
	return _consented


func is_busy() -> bool:
	return state in ["initializing", "restoring", "logging_in", "logging_out", "checking_compliance"]


func accept_consent(persist: bool = true) -> void:
	if not _required or _bridge == null or not configuration_ready() or is_busy():
		return
	if persist:
		var consent := ConfigFile.new()
		consent.set_value("privacy", "revision", str(_config.get("consent_revision", "1")))
		if consent.save(CONSENT_PATH) != OK:
			_set_state("error", "无法保存隐私授权，请检查设备存储后重试。")
			return
	_consented = true
	_initialize()


func login() -> void:
	if not _consented or not configuration_ready() or _bridge == null or is_busy():
		return
	if not _initialized:
		_login_after_init = true
		_initialize()
		return
	if has_account():
		_start_compliance()
		return
	_set_state("logging_in", "正在打开 TapTap 授权…")
	_bridge.call("login")


func retry() -> void:
	if is_busy() or _bridge == null or not _consented or not configuration_ready():
		return
	if _initialized:
		if has_account():
			_start_compliance()
		else:
			_set_state("logged_out", "请点击下方按钮登录 TapTap。")
	else:
		_initialize()


func logout() -> void:
	if not _initialized or is_busy():
		return
	_compliance_passed = false
	_compliance_request += 1
	_set_state("logging_out", "正在退出登录…")
	_bridge.call("logout")


func _initialize() -> void:
	_set_state("initializing", "正在连接 TapTap…")
	_bridge.call("initialize", str(_config.get("client_id", "")), str(_config.get("client_token", "")))


func _on_initialization_completed(success: bool, code: int, _message: String) -> void:
	if state != "initializing":
		return
	_initialized = success
	if not success:
		_login_after_init = false
		_set_state("error", "TapTap 初始化失败（%d）。请检查网络、后台包名和签名配置后重试。" % code)
		return
	_set_state("restoring", "正在读取登录状态…")
	_bridge.call("restoreAccount")


func _on_account_restored(profile_json: String) -> void:
	if state != "restoring":
		return
	var restored := _parse_profile(profile_json)
	if not restored.is_empty():
		account = restored
		_login_after_init = false
		_start_compliance()
	else:
		_set_state("logged_out", "请点击下方按钮登录 TapTap。")
		if _login_after_init:
			_login_after_init = false
			login()


func _on_login_completed(profile_json: String) -> void:
	if state != "logging_in":
		return
	account = _parse_profile(profile_json)
	if account.is_empty():
		_set_state("error", "TapTap 未返回有效账号，请重新登录。")
	else:
		_start_compliance()


func _start_compliance() -> void:
	_compliance_passed = false
	_compliance_request += 1
	_set_state("checking_compliance", "正在进行实名认证与防沉迷检查…")
	_bridge.call("startCompliance", str(account["open_id"]), _compliance_request)


func _on_compliance_result(request_id: int, code: int) -> void:
	if request_id != _compliance_request or not has_account() or state == "logging_out":
		return
	# SDK also sends an informational healthy-play reminder after 500.
	# It neither grants access nor revokes an already valid compliance result.
	if code == 1095:
		return
	if code == 500:
		if state == "checking_compliance":
			_compliance_passed = true
			_set_state("logged_in", "已登录 TapTap，防沉迷检查通过")
		return
	_compliance_passed = false
	match code:
		1000, 1001, 9001:
			# End the check before logout, so the busy guard does not swallow it.
			_set_state("compliance_exited", "请重新登录 TapTap。")
			logout()
		1030, 1050:
			_set_state("restricted", "当前账号处于防沉迷限制中，暂时无法游戏。请按游戏健康提醒操作。")
		1100:
			_set_state("restricted", "当前账号未达到本游戏要求的可玩年龄，无法进入游戏。")
		9002:
			_set_state("compliance_cancelled", "实名认证尚未完成，请完成认证后再进入游戏。")
		_:
			_set_state("compliance_error", "防沉迷检查未通过（%d）。请检查网络和合规服务配置后重试。" % code)
	login_required.emit()


func _on_login_failed(_code: int, _message: String) -> void:
	if state == "logging_in":
		account.clear()
		_set_state("error", "TapTap 登录失败，请检查网络后重新授权。")


func _on_login_cancelled() -> void:
	if state == "logging_in":
		_set_state("logged_out", "已取消登录，可再次点击登录。")


func _on_logout_completed() -> void:
	if state != "logging_out":
		return
	account.clear()
	_set_state("logged_out", "已退出 TapTap，请重新登录。")
	login_required.emit()


func _on_logout_failed(_code: int, _message: String) -> void:
	if state == "logging_out":
		_set_state("compliance_error", "退出登录失败，请重试退出或重新进行防沉迷检查。")


func _parse_profile(profile_json: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(profile_json)
	if not parsed is Dictionary or not parsed.get("open_id") is String or parsed.get("open_id", "").strip_edges().is_empty():
		return {}
	# Only identifiers cross the bridge; never accept a token or account dump.
	return {"open_id": parsed["open_id"], "union_id": str(parsed.get("union_id", ""))}


func _set_state(next: String, message: String) -> void:
	state = next
	status_message = message
	state_changed.emit()


func _read_consent(configuration: Dictionary) -> bool:
	var consent := ConfigFile.new()
	return consent.load(CONSENT_PATH) == OK \
		and str(consent.get_value("privacy", "revision", "")) == str(configuration.get("consent_revision", "1"))


func _valid_url(url: String) -> bool:
	return url.begins_with("https://") and url.length() > 8
