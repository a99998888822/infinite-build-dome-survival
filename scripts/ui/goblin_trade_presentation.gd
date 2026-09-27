extends Control
class_name GoblinTradePresentation
## Presentation only; eligibility and accepted effects belong to the run.

signal choice_made(accepted: bool)
signal cancelled(reason: String)

const PANEL := preload("res://assets/ui/finance/trade_panel.png")
const BUBBLE := preload("res://assets/ui/finance/trade_bubble.png")
const TAIL := preload("res://assets/ui/finance/trade_bubble_tail.png")
const SEAL := preload("res://assets/ui/finance/trade_seal.png")
const GLINTS := preload("res://assets/ui/finance/trade_glints.png")
const TICKS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/ui/trade_type_01.wav"),
	preload("res://assets/audio/sfx/ui/trade_type_02.wav"),
	preload("res://assets/audio/sfx/ui/trade_type_03.wav"),
]

var _card: Control
var _speech: Control
var _speech_text: Label
var _body: Label
var _body_scroll: ScrollContainer
var _terms: VBoxContainer
var _detail: Label
var _title: Label
var _seal: TextureRect
var _yes: Button
var _no: Button
var _audio: AudioStreamPlayer
var _accents: Control
var _card_rect := Rect2()
var _elapsed := 0.0
var _last_tick := -1
var _chosen := false
var _playing := false
var _compact := false
var sound_enabled := true
var start_wave_on_accept := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_frame(_card, PANEL)
	_seal = TextureRect.new()
	_seal.texture = SEAL
	_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_seal)
	_title = _label(_card, "交易", 18, FinanceUIStyle.GOLD)
	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	FinanceUIStyle.scroll(_body_scroll)
	_card.add_child(_body_scroll)
	_terms = VBoxContainer.new()
	_terms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terms.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_terms.add_theme_constant_override("separation", 8)
	_body_scroll.add_child(_terms)
	_body = _label(_terms, "", 12, FinanceUIStyle.TEXT)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = _label(_terms, "", 12, FinanceUIStyle.GREEN)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yes = _button("接受", true)
	_no = _button("拒绝", false)
	_accents = Control.new()
	_accents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accents.draw.connect(_draw_accents)
	add_child(_accents)
	_speech = Control.new()
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speech)
	_frame(_speech, BUBBLE)
	var tail := TextureRect.new()
	tail.texture = TAIL
	tail.position = Vector2(10, 53)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_child(tail)
	_speech_text = _label(_speech, "", 12, FinanceUIStyle.TEXT)
	_speech_text.position = Vector2(12, 10)
	_speech_text.size = Vector2(196, 40)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX"
	_audio.volume_db = -9.0
	add_child(_audio)
	_card.hide()
	_speech.hide()


func get_preferred_height(width: float) -> float:
	# Measure complete text so the typewriter never changes the card's height.
	var compact := width < 180
	var padding := 12.0 if compact else 16.0
	var text_width := maxf(1, floorf(width - padding * 2 - _body_scroll.get_v_scroll_bar().get_combined_minimum_size().x))
	var text_height := _text_height(_body, text_width)
	if not _detail.text.is_empty():
		text_height += _terms.get_theme_constant("separation") + _text_height(_detail, text_width)
	return (44 if compact else 60) + ceilf(text_height) + (24 if compact else 28) + (10 if compact else 12) + padding


func _text_height(label: Label, width: float) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(label.text, label.get_theme_font("font"), label.get_theme_font_size("font_size"))
	return paragraph.get_size().y + maxi(0, paragraph.get_line_count() - 1) * label.get_theme_constant("line_spacing")


func arrange(card_rect: Rect2, portrait_rect: Rect2, bounds: Rect2) -> void:
	_card_rect = card_rect
	_compact = card_rect.size.x < 180
	_card.position = card_rect.position
	_card.size = card_rect.size
	var w := card_rect.size.x
	var h := card_rect.size.y
	var padding := 12.0 if _compact else 16.0
	var text_button_gap := 10.0 if _compact else 12.0
	_seal.position = Vector2(padding, 10 if _compact else 12)
	_seal.size = Vector2(20, 20) if _compact else Vector2(28, 28)
	_title.position = Vector2(padding + (24 if _compact else 36), 10 if _compact else 12)
	_title.size = Vector2(w - _title.position.x - padding, 18 if _compact else 26)
	FinanceUIStyle.label(_title, 12 if _compact else 18, FinanceUIStyle.GOLD)
	_body_scroll.position = Vector2(padding, 44 if _compact else 60)
	var button_width := (w - padding * 2 - 10) * 0.5
	var button_height := 24.0 if _compact else 28.0
	_body_scroll.size = Vector2(w - padding * 2, maxf(1, h - _body_scroll.position.y - button_height - text_button_gap - padding))
	_no.position = Vector2(padding, h - button_height - padding)
	_yes.position = Vector2(padding + button_width + 10, h - button_height - padding)
	_no.size = Vector2(button_width, button_height)
	_yes.size = Vector2(button_width, button_height)
	_yes.text = ("开战" if _compact else "接受并开战") if start_wave_on_accept else "接受"
	_speech.size = Vector2(220, 58)
	_speech.position = Vector2(
		clampf(portrait_rect.end.x - 16, bounds.position.x, bounds.end.x - 224),
		maxf(bounds.position.y, portrait_rect.position.y + 6))
	_accents.queue_redraw()


func present(speech: String, body: String, detail: String = "") -> void:
	_speech_text.text = speech
	_body.text = body
	_body.visible_characters = -1
	_body.tooltip_text = body
	_body_scroll.scroll_vertical = 0
	_detail.text = detail
	_detail.visible = not detail.is_empty()
	_detail.modulate.a = 1.0
	_elapsed = 0.0
	_last_tick = -1
	_chosen = false
	_playing = true
	show()
	_title.text = "交易"
	_card.show()
	_card.scale = Vector2.ONE
	_card.modulate.a = 1.0
	_speech.show()
	seek(0.0)


func _process(delta: float) -> void:
	if _playing and is_visible_in_tree(): seek(_elapsed + delta)


func seek(seconds: float) -> void:
	if not _playing: return
	_elapsed = seconds
	var speech_chars := clampi(floori((seconds - 0.35) * 13), 0, _speech_text.text.length())
	_speech_text.visible_characters = speech_chars
	_speech.modulate.a = minf(clampf((seconds - 0.1) * 5, 0, 1), clampf((5.2 - seconds) / 0.45, 0, 1))
	_speech.visible = seconds < 5.2
	_yes.disabled = _chosen
	_no.disabled = _chosen
	var tick := speech_chars / 2
	if sound_enabled and tick > _last_tick and tick > 0:
		_audio.stream = TICKS[tick % TICKS.size()]
		_audio.pitch_scale = 1.0 + (tick % 3 - 1) * 0.035
		_audio.play()
	_last_tick = tick
	_accents.queue_redraw()


func _choose(accepted: bool) -> void:
	if not _playing or _chosen or (_yes.disabled if accepted else _no.disabled): return
	if not accepted:
		cancel("rejected")
		choice_made.emit(false)
		return
	_chosen = true
	_title.text = "已接受"
	_yes.disabled = true
	_no.disabled = true
	choice_made.emit(accepted)


func is_active() -> bool:
	return _playing


func cancel(reason: String = "cancelled") -> void:
	if not _playing: return
	_playing = false
	_chosen = true
	_audio.stop()
	_yes.disabled = true
	_no.disabled = true
	_card.hide()
	_speech.hide()
	hide()
	_accents.queue_redraw()
	cancelled.emit(reason)


func _draw_accents() -> void:
	if not _playing or _card.modulate.a < 0.99: return
	var rule_x := _body_scroll.position.x
	var rule_y := _body_scroll.position.y - (10 if _compact else 12)
	_accents.draw_line(_card_rect.position + Vector2(rule_x, rule_y), _card_rect.position + Vector2(_card_rect.size.x - rule_x, rule_y), Color("76623f"))
	var phase := fmod(maxf(0, _elapsed - 1.2), 3.0)
	if phase < 0.8:
		var frame := clampi(int(phase * 10), 0, 7)
		var point := _card_rect.position + Vector2(lerpf(16, _card_rect.size.x - 16, phase / 0.8), 3)
		_accents.draw_texture_rect_region(GLINTS, Rect2(point - Vector2(8, 8), Vector2(16, 16)), Rect2(frame * 16, 0, 16, 16))


func _frame(parent: Control, texture: Texture2D) -> void:
	var frame := NinePatchRect.new()
	frame.texture = texture
	frame.patch_margin_left = 12
	frame.patch_margin_right = 12
	frame.patch_margin_top = 12
	frame.patch_margin_bottom = 12
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FinanceUIStyle.label(label, font_size, color)
	parent.add_child(label)
	return label


func _button(text: String, accepted: bool) -> Button:
	var button := Button.new()
	button.text = text
	FinanceUIStyle.button(button, accepted)
	if accepted:
		button.add_theme_stylebox_override("normal", FinanceUIStyle.box("655432", "c4a368", 3))
		button.add_theme_stylebox_override("hover", FinanceUIStyle.box("7c653b", "edd59a", 3))
	button.pressed.connect(_choose.bind(accepted))
	_card.add_child(button)
	return button
