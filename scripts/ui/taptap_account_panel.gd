extends CanvasLayer
## A modal on Android only; the native SDK owns its authorization screens.

const ACCOUNT_FONT := preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
var session: Node
var _overlay: Control
var _status: Label
var _consent: CheckBox
var _primary: Button
var _logout: Button
var _close: Button
var _policy: Button
var _agreement: Button
var _last_state := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	if session == null:
		session = TapTapSession
	_build_ui()
	session.state_changed.connect(_refresh)
	session.login_required.connect(show_panel)
	_refresh()
	if not session.can_enter_game():
		show_panel()


func show_panel() -> void:
	_overlay.show()
	_refresh()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func handle_back() -> void:
	if session.can_enter_game():
		_overlay.hide()
	# Pending authentication belongs to TapSDK; never dismiss into gameplay.


func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.hide()
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.02, 0.015, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1020, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("282a23")
	style.border_color = Color("b5ab7a")
	style.set_border_width_all(3)
	style.content_margin_left = 42
	style.content_margin_right = 42
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	panel.add_theme_font_override("font", ACCOUNT_FONT)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "TapTap 账号"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", ACCOUNT_FONT)
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(900, 108)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", ACCOUNT_FONT)
	_status.add_theme_font_size_override("font_size", 30)
	column.add_child(_status)
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 24)
	column.add_child(links)
	_policy = _button("隐私政策", links, func(): _open_url(session.policy_url()))
	_agreement = _button("用户协议", links, func(): _open_url(session.agreement_url()))
	_consent = CheckBox.new()
	_consent.text = "我已阅读并同意隐私政策与用户协议"
	# This selects the UI only; consent is persisted after the Continue click.
	_consent.button_pressed = true
	_consent.custom_minimum_size.y = 68
	_consent.add_theme_font_override("font", ACCOUNT_FONT)
	_consent.add_theme_font_size_override("font_size", 30)
	_consent.toggled.connect(func(_checked: bool): _refresh())
	column.add_child(_consent)
	_primary = _button("TapTap 登录", column, _on_primary)
	_logout = _button("切换 TapTap 账号", column, func(): session.logout())
	_close = _button("返回游戏", column, handle_back)
	_button("退出游戏", column, func(): get_tree().quit())


func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 68
	button.add_theme_font_override("font", ACCOUNT_FONT)
	button.add_theme_font_size_override("font_size", 30)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh() -> void:
	if _status == null:
		return
	_status.text = session.status_message
	_consent.visible = not session.has_consent()
	_consent.disabled = not session.configuration_ready() or session.is_busy()
	_policy.disabled = session.policy_url().is_empty()
	_agreement.visible = session.has_user_agreement()
	_consent.text = "我已阅读并同意隐私政策与用户协议" if session.has_user_agreement() else "我已阅读并同意隐私政策"
	_close.visible = session.can_enter_game()
	_primary.text = "退出 TapTap 登录" if session.can_enter_game() else "TapTap 登录"
	if session.has_account() and not session.can_enter_game():
		_primary.text = "重新检查防沉迷"
	if session.state == "checking_compliance":
		_primary.text = "正在进行防沉迷检查…"
	_logout.visible = session.has_account() and not session.can_enter_game()
	_logout.disabled = session.is_busy()
	if not session.has_consent():
		_primary.text = "同意并继续"
	_primary.disabled = session.is_busy() or not session.configuration_ready() \
		or session.state == "unavailable" or (not session.has_consent() and not _consent.button_pressed)
	if not session.can_enter_game():
		_overlay.show()
	elif session.state == "logged_in" and _last_state != "logged_in":
		_overlay.hide()
	_last_state = session.state


func _on_primary() -> void:
	if session.can_enter_game():
		session.logout()
	elif not session.has_consent():
		session.accept_consent()
	else:
		session.login()


func _open_url(url: String) -> void:
	if url.begins_with("https://"):
		OS.shell_open(url)
