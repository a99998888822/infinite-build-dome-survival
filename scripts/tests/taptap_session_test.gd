extends Node

const SESSION := preload("res://autoloads/taptap_session.gd")
const PANEL := preload("res://scripts/ui/taptap_account_panel.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var resolution := Vector2i(1920, 1080)


class FakeBridge extends RefCounted:
	signal initializationCompleted(success: bool, code: int, message: String)
	signal accountRestored(profile: String)
	signal loginCompleted(profile: String)
	signal loginFailed(code: int, message: String)
	signal loginCancelled
	signal logoutCompleted
	signal logoutFailed(code: int, message: String)
	signal complianceResult(request_id: int, code: int)
	var init_count := 0
	var login_count := 0
	var restore_count := 0
	var logout_count := 0
	var compliance_count := 0
	var compliance_request := 0
	var compliance_open_id := ""
	func initialize(_client_id: String, _client_token: String) -> void: init_count += 1
	func restoreAccount() -> void: restore_count += 1
	func login() -> void: login_count += 1
	func logout() -> void: logout_count += 1
	func startCompliance(open_id: String, request_id: int) -> void:
		compliance_count += 1
		compliance_request = request_id
		compliance_open_id = open_id


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + note)


func _run() -> void:
	check(not TapTapSession.is_required() and TapTapSession.can_enter_game(), "desktop flow unchanged")
	var config := {"client_id": "test", "client_token": "test", "privacy_policy_url": "https://example.com/privacy", "user_agreement_url": "https://example.com/terms", "consent_revision": "test"}
	var bridge := FakeBridge.new()
	var session := SESSION.new()
	session.configure(bridge, config, true, false)
	check(session.state == "consent_required" and bridge.init_count == 0, "no SDK init before consent")
	session.login()
	check(bridge.login_count == 0 and not session.can_enter_game(), "no login/gameplay before consent")
	session.accept_consent(false)
	check(bridge.init_count == 1 and session.state == "initializing", "consent initializes SDK once")
	session.accept_consent(false)
	session.login()
	check(bridge.init_count == 1 and bridge.login_count == 0, "busy state prevents duplicate requests")
	bridge.initializationCompleted.emit(false, -1001, "test")
	check(session.state == "error" and not session.can_enter_game(), "init configuration error blocks gameplay")
	session.retry()
	bridge.initializationCompleted.emit(true, 0, "")
	check(session.state == "restoring" and bridge.restore_count == 1, "init success restores SDK session")
	bridge.accountRestored.emit("{}")
	check(session.state == "logged_out" and bridge.login_count == 0, "fresh user waits for explicit login click")
	session.login()
	session.login()
	check(session.state == "logging_in" and bridge.login_count == 1, "only one native authorization at a time")
	bridge.loginCancelled.emit()
	check(session.state == "logged_out" and not session.can_enter_game(), "cancel allows retry without login")
	session.login()
	bridge.loginFailed.emit(-1, "test")
	check(session.state == "error" and not session.can_enter_game(), "authorization failure blocks gameplay")
	session.login()
	bridge.loginCompleted.emit('{"access_token":"invalid"}')
	check(session.state == "error" and not session.can_enter_game(), "token alone cannot create a session")
	session.login()
	bridge.loginCompleted.emit('{"open_id":"test-player","union_id":"test-union","access_token":"must-not-pass"}')
	check(not session.can_enter_game() and session.state == "checking_compliance" and not session.account.has("access_token"), "login waits for compliance without token exposure")
	check(bridge.compliance_count == 1 and bridge.compliance_open_id == "test-player", "compliance uses the TapTap account identifier")
	session.login()
	session.retry()
	check(bridge.compliance_count == 1, "pending compliance cannot be started twice")
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	check(session.can_enter_game(), "only compliance success unlocks gameplay")
	bridge.complianceResult.emit(bridge.compliance_request, 1095)
	check(session.can_enter_game(), "SDK healthy-play reminder does not revoke a valid grant")
	bridge.loginCancelled.emit()
	check(session.can_enter_game(), "late cancellation cannot clear a completed login")
	session.logout()
	check(not session.can_enter_game() and bridge.logout_count == 1, "logout blocks new gameplay immediately")
	bridge.logoutFailed.emit(-1, "test")
	check(not session.can_enter_game() and session.has_account(), "failed logout cannot restore a cleared compliance grant")
	var old_request := bridge.compliance_request
	bridge.complianceResult.emit(old_request, 500)
	check(not session.can_enter_game(), "late success after logout is ignored")
	session.retry()
	check(session.state == "checking_compliance", "failed logout permits compliance retry")
	bridge.complianceResult.emit(old_request, 500)
	check(not session.can_enter_game(), "old request cannot approve a new check")
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	check(session.can_enter_game(), "fresh compliance result restores access")
	session.logout()
	bridge.logoutCompleted.emit()
	check(session.account.is_empty() and not session.can_enter_game(), "successful logout clears game identity")
	var restored_bridge := FakeBridge.new()
	var restored := SESSION.new()
	restored.configure(restored_bridge, config, true, true)
	restored_bridge.initializationCompleted.emit(true, 0, "")
	restored_bridge.accountRestored.emit('{"open_id":"returning-player"}')
	check(not restored.can_enter_game() and restored_bridge.compliance_count == 1 and restored_bridge.login_count == 0, "cold start restores account but always checks compliance")
	restored_bridge.complianceResult.emit(restored_bridge.compliance_request, 1030)
	check(restored.state == "restricted" and not restored.can_enter_game(), "cold start cannot bypass a restricted account")
	restored_bridge.complianceResult.emit(restored_bridge.compliance_request, 1095)
	check(not restored.can_enter_game(), "SDK reminder cannot grant gameplay to a restricted account")
	restored_bridge.complianceResult.emit(restored_bridge.compliance_request, 500)
	check(not restored.can_enter_game(), "late success cannot dismiss a restriction")
	restored.retry()
	restored_bridge.complianceResult.emit(restored_bridge.compliance_request, 500)
	check(restored.can_enter_game(), "cached account can pass a new compliance check")
	var missing := SESSION.new()
	missing.configure(null, config, true, true)
	check(not missing.can_enter_game() and missing.state == "unavailable", "missing native plugin never permits gameplay")
	var incomplete := SESSION.new()
	var incomplete_bridge := FakeBridge.new()
	var incomplete_config := config.duplicate()
	incomplete_config["privacy_policy_url"] = ""
	incomplete.configure(incomplete_bridge, incomplete_config, true, true)
	incomplete.accept_consent(false)
	check(incomplete.state == "configuration_required" and incomplete_bridge.init_count == 0, "missing legal link cannot initialize SDK")
	var privacy_only := SESSION.new()
	var privacy_bridge := FakeBridge.new()
	var privacy_config := config.duplicate()
	privacy_config["user_agreement_url"] = ""
	privacy_only.configure(privacy_bridge, privacy_config, true, false)
	check(privacy_only.configuration_ready() and not privacy_only.has_user_agreement(), "pending user agreement does not block SDK integration")
	check(privacy_only.state == "consent_required" and privacy_bridge.init_count == 0, "privacy-only configuration still requires explicit consent")
	var privacy_panel := PANEL.new()
	privacy_panel.session = privacy_only
	add_child(privacy_panel)
	await frames()
	check(not privacy_panel._agreement.visible and privacy_panel._consent.text == "我已阅读并同意隐私政策", "no consent requested for missing user agreement")
	check(privacy_panel._consent.button_pressed and not privacy_panel._primary.disabled, "privacy checkbox defaults selected")
	check(privacy_bridge.init_count == 0 and not privacy_only.has_consent(), "selected checkbox alone does not initialize SDK or persist consent")
	privacy_panel._consent.button_pressed = false
	check(privacy_panel._primary.disabled, "unchecking privacy disables continue")
	privacy_panel._consent.button_pressed = true
	check(not privacy_panel._primary.disabled, "checking privacy enables continue again")
	await capture("privacy-only", privacy_panel)
	privacy_only.accept_consent(false)
	check(privacy_bridge.init_count == 1, "privacy-only consent permits SDK initialization")
	privacy_panel.queue_free()
	# Validate the actual modal, including safe cancellation and account entry.
	var panel := PANEL.new()
	panel.session = session
	add_child(panel)
	await frames()
	check(panel.is_open(), "logged out user sees account modal")
	panel.handle_back()
	check(panel.is_open(), "Android Back cannot dismiss required login")
	await capture("login", panel)
	session.login()
	bridge.loginCompleted.emit('{"open_id":"test-player"}')
	check(panel.is_open() and panel._primary.disabled, "login keeps the modal blocked while compliance is pending")
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	check(not panel.is_open(), "compliance success dismisses modal")
	panel.show_panel()
	check(panel.is_open() and panel._primary.text.contains("TapTap"), "account entry remains open for logout")
	await capture("account", panel)
	panel.handle_back()
	bridge.complianceResult.emit(bridge.compliance_request, 1050)
	check(panel.is_open() and not session.can_enter_game(), "runtime duration limit revokes access and reopens modal")
	panel.handle_back()
	check(panel.is_open() and not panel._close.visible, "Back cannot dismiss a restriction into gameplay")
	check(panel._logout.visible and not panel._logout.disabled, "restricted account can switch accounts")
	await capture("restricted", panel)
	panel._on_primary()
	check(session.state == "checking_compliance" and panel._primary.disabled, "restricted primary action retries compliance")
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	panel.show_panel()
	panel._on_primary()
	bridge.logoutCompleted.emit()
	check(panel.is_open() and not session.can_enter_game(), "logout returns to login modal")
	panel.queue_free()
	var consent_session := SESSION.new()
	consent_session.configure(FakeBridge.new(), config, true, false)
	var consent_panel := PANEL.new()
	consent_panel.session = consent_session
	add_child(consent_panel)
	await frames()
	check(not consent_panel._primary.disabled and consent_panel._consent.button_pressed, "privacy consent defaults selected with user agreement configured")
	consent_panel._consent.button_pressed = false
	check(consent_panel._primary.disabled, "unchecking consent disables continue with user agreement configured")
	consent_panel._consent.button_pressed = true
	check(not consent_panel._primary.disabled, "consent explicitly enables continue")
	await capture("privacy", consent_panel)
	consent_panel.queue_free()
	for code in [1030, 1050, 1100, 1200, 9002, 9999]:
		restored_bridge.complianceResult.emit(restored_bridge.compliance_request, code)
		check(not restored.can_enter_game(), "non-success compliance blocks gameplay: %d" % code)
		restored.retry()
		restored_bridge.complianceResult.emit(restored_bridge.compliance_request, 500)
		check(restored.can_enter_game(), "explicit retry can recover: %d" % code)
	for code in [1000, 1001, 9001]:
		restored_bridge.complianceResult.emit(restored_bridge.compliance_request, code)
		check(restored.state == "logging_out" and not restored.can_enter_game(), "compliance exit/switch immediately invalidates access: %d" % code)
		restored_bridge.logoutCompleted.emit()
		check(not restored.has_account(), "compliance exit/switch clears the old identity")
		restored.login()
		restored_bridge.loginCompleted.emit('{"open_id":"another-player"}')
		restored_bridge.complianceResult.emit(restored_bridge.compliance_request, 500)
	await _test_gameplay_gate(config)
	await frames(2)
	for node in [session, restored, missing, incomplete, consent_session, privacy_only]: node.free()
	print("TAPTAP_SESSION_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_gameplay_gate(config: Dictionary) -> void:
	var bridge := FakeBridge.new()
	TapTapSession.configure(bridge, config, true, true)
	var game := GameRoot.new()
	# This gate test does not exercise audio; avoid the headless Ogg shutdown leak.
	var bgm_player: AudioStreamPlayer = AudioManager._bgm_player
	AudioManager._bgm_player = null
	add_child(game)
	AudioManager._bgm_player = bgm_player
	check(game.process_mode == Node.PROCESS_MODE_DISABLED, "root gameplay and input disabled before compliance")
	bridge.initializationCompleted.emit(true, 0, "")
	bridge.accountRestored.emit('{"open_id":"runtime-player"}')
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	check(game.process_mode == Node.PROCESS_MODE_INHERIT, "approved root can process gameplay")
	check(not bool(GameGlobal.get_runtime_flag("battle_runtime_paused")), "initial approval clears the compliance pause from boot")
	var flow := game.get_main_flow_coordinator()
	flow._set_battle_runtime_paused(false)
	bridge.complianceResult.emit(bridge.compliance_request, 1030)
	check(game.process_mode == Node.PROCESS_MODE_DISABLED and bool(GameGlobal.get_runtime_flag("battle_runtime_paused")), "runtime restriction disables gameplay immediately")
	flow._set_battle_runtime_paused(false)
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused")), "ordinary menu unpause cannot bypass compliance")
	check(game._taptap_account_panel.process_mode == Node.PROCESS_MODE_ALWAYS and game._taptap_account_panel.is_open(), "restriction controls still work while gameplay is disabled")
	TapTapSession.retry()
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	check(game.process_mode == Node.PROCESS_MODE_INHERIT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused")), "fresh approval restores the previous runtime pause state")
	flow._set_battle_runtime_paused(true)
	bridge.complianceResult.emit(bridge.compliance_request, 1050)
	TapTapSession.retry()
	bridge.complianceResult.emit(bridge.compliance_request, 500)
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused")), "approval preserves a gameplay menu pause that already existed")
	game.queue_free()
	await frames(2)
	TapTapSession.configure(null, {}, false, false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func capture(page: String, panel: CanvasLayer) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	get_tree().root.borderless = true
	get_tree().root.size = resolution
	MobileProfile.apply_to_window(get_tree().root)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	var bounds: Rect2 = panel._primary.get_global_rect()
	check(get_viewport().get_visible_rect().encloses(bounds), "primary action fits phone viewport")
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(image.save_png(capture_dir.path_join(page + ".png")) == OK, "capture " + page)
