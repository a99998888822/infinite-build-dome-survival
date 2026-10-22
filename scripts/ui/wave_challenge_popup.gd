extends Control
class_name WaveChallengePopup

const PORTRAIT_SIZE := 372.0
const MAX_CONTENT_WIDTH := 960.0
const MIN_CONTENT_WIDTH := 416.0

var flow: MainFlowCoordinator
var proposal: Dictionary = {}
var presentation: GoblinTradePresentation
var portrait: BankCounterPortrait
var _back: Button
var _scroll: ScrollContainer
var _content: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(FinanceFrameSkin.PALETTE.SHADOW, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	# Small logical viewports scroll the native art; normal windows use the
	# project's 1920x1080 canvas without adding a second UI scale.
	_scroll = ScrollContainer.new()
	FinanceUIStyle.scroll(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	add_child(_scroll)
	_content = Control.new()
	_scroll.add_child(_content)
	portrait = BankCounterPortrait.new()
	portrait.background_counter = true
	_content.add_child(portrait)
	presentation = GoblinTradePresentation.new()
	presentation.finance_skin = true
	presentation.speech_width = 360
	presentation.speech_padding = Vector2(24, 20)
	presentation.speech_font_size = 24
	_content.add_child(presentation)
	presentation.choice_made.connect(_choose)
	_back = Button.new()
	_back.text = "ui.shop.return_to_bank"
	FinanceUIStyle.bank_button(_back)
	_back.pressed.connect(func():
		if flow != null: flow.return_from_wave_challenge())
	_content.add_child(_back)
	resized.connect(_arrange)
	L10n.locale_changed.connect(_refresh_locale)
	hide()


func present(payload: Dictionary) -> void:
	proposal = payload.duplicate(true)
	presentation.present(L10n.record_text(payload, "speech"), L10n.record_text(payload, "body"))
	presentation.configure_challenge(int(payload.wave), str(payload.icon))
	show()
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0
	_arrange()
	_back.grab_focus()


func dismiss() -> void:
	presentation.cancel("closed")
	proposal.clear()
	hide()


func _arrange() -> void:
	if presentation == null or not is_node_ready(): return
	var available := (size - Vector2(32, 32)).max(Vector2.ONE).floor()
	var gutter := ceilf(_scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	var width := clampf(available.x - gutter, MIN_CONTENT_WIDTH, MAX_CONTENT_WIDTH)
	var side_by_side := width >= 800.0
	portrait.size = Vector2.ONE * PORTRAIT_SIZE
	portrait.position = Vector2.ZERO if side_by_side else Vector2(floorf((width - PORTRAIT_SIZE) * 0.5), 0)
	presentation.scale = Vector2.ONE
	presentation.speech_width = width - PORTRAIT_SIZE - 24 if side_by_side else width
	var height := maxf(200, ceilf(presentation.get_preferred_height(width)))
	var bounds := Rect2(Vector2.ZERO, Vector2(width, available.y))
	# Measure the speech with its final width before placing the card below it.
	presentation.arrange(Rect2(Vector2.ZERO, Vector2(width, height)), portrait.get_rect(), bounds)
	var speech_pos := Vector2(PORTRAIT_SIZE + 24, 16) if side_by_side else Vector2(0, PORTRAIT_SIZE + 16)
	var header := maxf(PORTRAIT_SIZE, speech_pos.y + presentation._speech.size.y)
	var card_rect := Rect2(Vector2(0, header + 16), Vector2(width, height))
	presentation.arrange(card_rect, portrait.get_rect(), bounds)
	presentation._speech.position = speech_pos
	_back.scale = Vector2.ONE
	_back.position = Vector2(width - 164, card_rect.end.y + 12)
	_back.size = Vector2(164, 44)
	_content.custom_minimum_size = Vector2(width, _back.position.y + _back.size.y)
	_scroll.size = (_content.custom_minimum_size + Vector2(gutter, 0)).min(available)
	_scroll.position = ((size - _scroll.size) * 0.5).floor()
	# Resizing keeps the decision controls reachable, including logical 640x360.
	if visible:
		_scroll.ensure_control_visible.call_deferred(_back)


func _refresh_locale() -> void:
	if proposal.is_empty(): return
	presentation.present(L10n.record_text(proposal, "speech"), L10n.record_text(proposal, "body"))
	presentation.configure_challenge(int(proposal.wave), str(proposal.icon))
	_arrange()


func _choose(accepted: bool) -> void:
	if flow == null or proposal.is_empty(): return
	var token := str(proposal.token)
	if not flow.decide_wave_challenge(token, accepted):
		present(proposal)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and flow != null:
		flow.return_from_wave_challenge()
		get_viewport().set_input_as_handled()
