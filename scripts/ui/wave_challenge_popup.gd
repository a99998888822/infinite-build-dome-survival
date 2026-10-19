extends Control
class_name WaveChallengePopup

var flow: MainFlowCoordinator
var proposal: Dictionary = {}
var presentation: GoblinTradePresentation
var portrait: BankCounterPortrait
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(FinanceFrameSkin.PALETTE.SHADOW, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	portrait = BankCounterPortrait.new()
	portrait.background_counter = true
	add_child(portrait)
	presentation = GoblinTradePresentation.new()
	presentation.finance_skin = true
	presentation.speech_width = 360
	presentation.speech_padding = Vector2(24, 20)
	presentation.speech_font_size = 24
	add_child(presentation)
	presentation.choice_made.connect(_choose)
	_back = Button.new()
	_back.text = "ui.shop.return_to_bank"
	FinanceUIStyle.bank_button(_back)
	_back.pressed.connect(func():
		if flow != null: flow.return_from_wave_challenge())
	add_child(_back)
	resized.connect(_arrange)
	hide()


func present(payload: Dictionary) -> void:
	proposal = payload.duplicate(true)
	presentation.present(L10n.record_text(payload, "speech"), L10n.record_text(payload, "body"))
	presentation.configure_challenge(int(payload.wave), str(payload.icon))
	show()
	_arrange()
	_back.grab_focus()


func dismiss() -> void:
	presentation.cancel("closed")
	proposal.clear()
	hide()


func _arrange() -> void:
	if presentation == null or not is_node_ready(): return
	var ui_scale := clampf(minf(size.x / 1280.0, size.y / 720.0), 0.75, 1.25)
	var canvas := size / ui_scale
	var bounds := Rect2(Vector2(16, 16), canvas - Vector2(32, 32))
	var width := minf(760, bounds.size.x)
	var header := 136.0 if size.y < 450 else 256.0
	var height := minf(maxf(200, presentation.get_preferred_height(width)), maxf(110, bounds.size.y - header - 48))
	var origin := Vector2((canvas.x - width) * 0.5, maxf(16, (canvas.y - header - height - 48) * 0.5)).round()
	var portrait_rect := Rect2(origin + Vector2(maxf(0, width * 0.5 - header - 60), 0), Vector2.ONE * header)
	portrait.position = (portrait_rect.position * ui_scale).round()
	portrait.size = (portrait_rect.size * ui_scale).round()
	presentation.scale = Vector2.ONE * ui_scale
	presentation.arrange(Rect2(origin + Vector2(0, header), Vector2(width, height)), portrait_rect, bounds)
	_back.scale = Vector2.ONE * ui_scale
	_back.position = ((origin + Vector2(width - 132, header + height + 12)) * ui_scale).round()
	_back.size = Vector2(132, 36)


func _choose(accepted: bool) -> void:
	if flow == null or proposal.is_empty(): return
	var token := str(proposal.token)
	if not flow.decide_wave_challenge(token, accepted):
		present(proposal)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and flow != null:
		flow.return_from_wave_challenge()
		get_viewport().set_input_as_handled()
