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
	shade.color = Color("080e0be8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	portrait = BankCounterPortrait.new()
	add_child(portrait)
	presentation = GoblinTradePresentation.new()
	add_child(presentation)
	presentation.choice_made.connect(_choose)
	_back = Button.new()
	_back.text = "ui.shop.return_to_bank"
	FinanceUIStyle.button(_back)
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
	var bounds := Rect2(Vector2(12, 12), size - Vector2(24, 24))
	var width := minf(560, bounds.size.x)
	var header := 94.0 if size.y < 450 else 142.0
	var height := minf(presentation.get_preferred_height(width), maxf(110, bounds.size.y - header - 34))
	var origin := Vector2((size.x - width) * 0.5, maxf(12, (size.y - header - height - 34) * 0.5))
	var portrait_rect := Rect2(origin + Vector2(width * 0.5 - 160, 0), Vector2(170, header))
	portrait.position = portrait_rect.position
	portrait.size = portrait_rect.size
	presentation.arrange(Rect2(origin + Vector2(0, header), Vector2(width, height)), portrait_rect, bounds)
	_back.position = origin + Vector2(width - 100, header + height + 6)
	_back.size = Vector2(100, 28)


func _choose(accepted: bool) -> void:
	if flow == null or proposal.is_empty(): return
	var token := str(proposal.token)
	if not flow.decide_wave_challenge(token, accepted):
		present(proposal)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and flow != null:
		flow.return_from_wave_challenge()
		get_viewport().set_input_as_handled()
