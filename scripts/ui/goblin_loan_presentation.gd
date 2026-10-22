extends Control
class_name GoblinLoanPresentation
## Displays authoritative loan state; no money or debt is owned by this control.

signal error_requested(reason: String)
const ART := "res://assets/ui/finance/loan/"
const SPEECH := "钱不够？先拿去，后面再还！"
const GOLD := FinanceUIStyle.GOLD
const TEXT := FinanceUIStyle.TEXT
const MUTED := FinanceUIStyle.MUTED
const DEBT := Color("d39a72")
var flow: MainFlowCoordinator
var state := "hidden"
var borrowed := 0
var due := 0
var wallet := 0
var elapsed := 0.0
var _quote: Dictionary = {}
var _modal: Control
var _modal_scroll: ScrollContainer
var _modal_content: Control
var _box: Panel
var _dimmer: ColorRect
var _title: Label
var _seal: TextureRect
var _close: Button
var _portrait: TextureRect
var _bubble: Panel
var _speech: Label
var _tail: TextureRect
var _rule: Label
var _decline: Button
var _cards: Array[Dictionary] = []
var _strip: Panel
var _strip_icon: TextureRect
var _strip_label: Label
var _strip_detail: Label
var repay: Button
var reopen: Button
var _line: ColorRect
var _audio: AudioStreamPlayer
var _last_tick := 0
var _return_focus: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_strip()
	_build_modal()
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX"
	_audio.volume_db = -18
	add_child(_audio)
	resized.connect(_layout_modal)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _audio.stop()
	)
	_modal.hide()
	_strip.hide()
	_strip_detail.clip_text = true
	for card: Dictionary in _cards:
		card.due.clip_text = true
		card.rate.clip_text = true


func configure(data: Dictionary) -> void:
	state = str(data.get("state","hidden"))
	wallet = int(data.get("gold",0))
	var active: Dictionary = data.get("debt",{})
	borrowed = int(active.get("amount",0))
	due = int(active.get("due",0))
	_quote = data.get("quote",{}).duplicate(true)
	if not _quote.is_empty():
		_speech.text = L10n.source(str(_quote.get("speech",SPEECH)))
		var options: Array = _quote.get("options",[])
		for i in _cards.size():
			var card: Dictionary = _cards[i]
			card.panel.visible = i < options.size()
			if i >= options.size(): continue
			var entry: Dictionary = options[i]
			card.amount_value = int(entry.amount)
			card.repayment = int(entry.due)
			card.value.text = "+ %d" % int(entry.amount)
			card.due.text = L10n.text("ui.loan.gold_amount") % int(entry.due)
			card.rate.text = L10n.text("ui.loan.interest_rate") % HumanityEconomy.number(float(entry.rate_percent))
			card.button.text = L10n.text("ui.loan.borrow_amount") % int(entry.amount)
			card.icon.texture = load(str(entry.icon))
			var terms := L10n.text("ui.loan.terms") % [entry.amount,int(_quote.due_wave),entry.due,HumanityEconomy.number(float(entry.rate_percent))]
			if bool(entry.get("adjusted",false)): terms += L10n.text("ui.loan.terms_relic_adjustment")
			card.button.tooltip_text = terms
			card.due.tooltip_text = terms
			card.rate.tooltip_text = terms
	var opening := bool(data.get("dialog_open",false)) and not _modal.visible
	var closing := not bool(data.get("dialog_open",false)) and _modal.visible
	_modal.visible = bool(data.get("dialog_open",false))
	_strip.visible = state != "hidden"
	if opening:
		_return_focus = get_viewport().gui_get_focus_owner()
		elapsed = 0
		_last_tick = 0
		_decline.grab_focus.call_deferred()
	if closing:
		_audio.stop()
		if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree(): _return_focus.grab_focus.call_deferred()
	_layout_strip()
	_strip_detail.tooltip_text = L10n.text("ui.loan.repayment_rules") % [due,int(active.get("due_wave",0))]
	_layout_modal()
	_seek()


func has_strip() -> bool:
	return state != "hidden"


func is_active() -> bool:
	return is_visible_in_tree() and _modal.visible


func reserved_height() -> float:
	return (34.0 if get_viewport_rect().size.y < 480 else 54.0) if has_strip() else 0.0


func arrange(bank_rect: Rect2) -> void:
	var short := get_viewport_rect().size.y < 480
	_strip.position = bank_rect.position + Vector2(20,bank_rect.size.y-(34 if short else 54))
	_strip.size = Vector2(maxf(0,bank_rect.size.x-40),42)
	_layout_strip()
	_layout_modal()


func show_quote() -> void:
	if flow != null: flow.reopen_goblin_loan()


func dismiss_quote() -> void:
	if flow != null: flow.dismiss_goblin_loan()


func _choose(index: int) -> void:
	if flow == null: return
	var result := flow.accept_goblin_loan(str(_quote.get("token","")),index)
	if not bool(result.get("success",false)): error_requested.emit(str(result.get("reason","loan_expired")))


func _repay() -> void:
	if flow == null: return
	var result := flow.repay_goblin_loan()
	if not bool(result.get("success",false)): error_requested.emit(str(result.get("reason","loan_not_active")))


func _process(delta: float) -> void:
	if not is_active(): return
	elapsed += delta
	_seek()
	var tick := _speech.visible_characters / 2
	if tick > _last_tick:
		_last_tick = tick
		_audio.stream = load("res://assets/audio/sfx/ui/trade_type_%02d.wav" % (tick%3+1))
		_audio.play()


func _seek() -> void:
	_speech.visible_characters = mini(_speech.text.length(),maxi(0,int(elapsed*15)))
	_portrait.position.y = float(_portrait.get_meta("rest_y",_portrait.position.y))+roundf(sin(elapsed*2))


func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_dimmer = ColorRect.new()
	_dimmer.color = Color(FinanceFrameSkin.PALETTE.SHADOW, 0.73)
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(_dimmer)
	# Keep the portrait native-sized. Small logical viewports scroll the complete
	# modal; physical window resizing normally scales the project canvas instead.
	_modal_scroll = ScrollContainer.new()
	_modal.add_child(_modal_scroll)
	FinanceUIStyle.scroll(_modal_scroll)
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_modal_scroll.follow_focus = true
	_modal_content = Control.new()
	_modal_content.custom_minimum_size = Vector2(1160, 552)
	_modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_scroll.add_child(_modal_content)
	_box = _panel(_modal_content, "232d23", "ad905d")
	var inner := NinePatchRect.new()
	inner.texture = load("res://assets/ui/finance/trade_panel.png")
	inner.patch_margin_left = 12
	inner.patch_margin_top = 12
	inner.patch_margin_right = 12
	inner.patch_margin_bottom = 12
	FinanceFrameSkin.nine_patch(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(inner)
	_seal = _image(_box, ART + "loan_note.png")
	_title = _label(_box, "ui.loan.title", 40, GOLD)
	_close = _button(_box, "×")
	_close.pressed.connect(dismiss_quote)
	_portrait = _image(_box, "")
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/finance/goblin_banker_states.png")
	var frame_size := atlas.atlas.get_height()
	atlas.region = Rect2(3 * frame_size, 0, frame_size, frame_size)
	_portrait.texture = atlas
	_bubble = _panel(_box, "303c2c", "778463")
	_bubble.add_theme_stylebox_override("panel", FinanceUIStyle.box("2a3023", "998252", 0))
	_speech = _label(_bubble, SPEECH, 30, TEXT)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tail = _image(_box, "res://assets/ui/finance/trade_bubble_tail.png")
	for i in 3:
		var amount: int = [100, 200, 500][i]
		var card := _panel(_box, "283326" if i < 2 else "343724", "67734f" if i < 2 else "bba066")
		card.add_theme_stylebox_override("panel", FinanceFrameSkin.box("card"))
		var gain := _label(card, "ui.loan.receive_now", 20, MUTED)
		var value := _label(card, "+ %d" % amount, 50, GOLD)
		var money := _label(card, "stat.gold.name", 20, MUTED)
		var icon := _image(card, ART + "loan_%d.png" % amount)
		var line := ColorRect.new()
		line.color = FinanceFrameSkin.PALETTE.LINE_IDLE
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(line)
		var caption := _label(card, "ui.loan.repay_next_wave", 20, MUTED)
		var repayment := _label(card, L10n.text("ui.loan.gold_amount") % [140,260,600][i], 30, TEXT)
		repayment.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var rate := _label(card, L10n.text("ui.loan.integer_interest_rate") % [40,30,20][i], 20, DEBT)
		var button := _button(card, L10n.text("ui.loan.borrow_amount") % amount)
		FinanceUIStyle.button(button, i == 2)
		FinanceFrameSkin.button(button, i == 2)
		button.pressed.connect(_choose.bind(i))
		_cards.append({"panel":card,"icon":icon,"gain":gain,"value":value,"money":money,
			"line":line,"caption":caption,"due":repayment,"rate":rate,"button":button,
			"amount_value":amount,"repayment":[140,260,600][i]})
	_rule = _label(_box, "ui.loan.automatic_repayment_hint", 20, MUTED)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decline = _button(_box, "ui.loan.decline")
	_decline.pressed.connect(dismiss_quote)


func _layout_modal() -> void:
	if _box == null: return
	var viewport := get_viewport_rect().size
	_modal_scroll.position = Vector2(12, 12)
	_modal_scroll.size = (viewport - Vector2(24, 24)).max(Vector2.ONE)
	_box.size = Vector2(1160, 552)
	_box.position = ((_modal_scroll.size - _box.size).max(Vector2.ZERO) * 0.5).floor()
	var w := _box.size.x
	_rect(_seal, 24, 20, 24, 24)
	_text(_title, Rect2(60, 16, w-132, 36), 24)
	_rect(_close, w-54, 18, 30, 30)
	_portrait.size = Vector2.ONE * BankCounterPortrait.FRAME_SIZE
	_portrait.position = Vector2(24, 140)
	_portrait.set_meta("rest_y", _portrait.position.y)
	_rect(_bubble, 24, 68, 372, 64)
	_text(_speech, Rect2(16, 8, 340, 48), 20)
	_rect(_tail, 334, 127, 18, 12)
	var work_x := 420.0
	var card_w := floorf((w-work_x-24-24)/3.0)
	var card_h := 300.0
	for i in _cards.size():
		var c := _cards[i]
		_rect(c.panel, work_x+i*(card_w+12), 88, card_w, card_h)
		c.line.show()
		_rect(c.icon, 16, 20, 48, 48)
		_text(c.gain, Rect2(76,16,card_w-92,24),16)
		_text(c.value, Rect2(74,44,card_w-90,42),30)
		_text(c.money, Rect2(16,82,card_w-32,24),16)
		_rect(c.line,16,118,card_w-32,1)
		_text(c.caption,Rect2(16,132,card_w-32,24),16)
		_text(c.due,Rect2(16,160,card_w-32,32),24)
		_text(c.rate,Rect2(16,200,card_w-32,24),16)
		_rect(c.button,16,248,card_w-32,36)
	_text(_rule,Rect2(work_x,412,w-work_x-24,64),16)
	_rect(_decline,w-160,492,136,36)


func _build_strip() -> void:
	_strip = _panel(self, "1d281fd9", "706446")
	_strip_icon = _image(_strip, ART+"loan_note.png")
	_strip_label = _label(_strip, "ui.loan.title", 23, GOLD)
	_strip_detail = _label(_strip, "", 20, MUTED)
	reopen = _button(_strip,"ui.loan.view_terms")
	reopen.pressed.connect(show_quote)
	repay = _button(_strip,"ui.loan.repay")
	repay.pressed.connect(_repay)
	_line = ColorRect.new()
	_line.color = FinanceFrameSkin.PALETTE.LINE_IDLE
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_line)


func _layout_strip() -> void:
	if _strip == null: return
	var w := _strip.size.x
	var narrow := w < 430
	var short := get_viewport_rect().size.y < 480
	_strip.size.y = 28 if short else (46 if narrow else 42)
	_rect(_strip_icon, 8, 9 if not narrow else 5, 24,24)
	reopen.visible = state == "available"
	repay.visible = state in ["borrowed","compound","ready"]
	_strip_detail.visible = repay.visible
	_line.visible = repay.visible and not narrow
	var text := L10n.text("ui.loan.title")
	if repay.visible: text = L10n.text("ui.loan.borrowed_amount") % borrowed
	if state == "paid": text = "贷款已还清"
	_strip_label.text = text
	var label_width := 164.0 if not narrow else 148.0
	_text(_strip_label,Rect2(40,3 if narrow else 6,label_width,28),12 if narrow else 14)
	_rect(reopen,w-100,7,90,28)
	_rect(repay,40+label_width,6,44,28)
	repay.disabled = wallet < due
	repay.tooltip_text = L10n.text("ui.loan.repay_amount") % due if not repay.disabled else L10n.text("ui.loan.repay_required") % due
	_strip_detail.text = L10n.text("ui.loan.amount_due_status") % [due, L10n.text("ui.loan.status.compounded" if state in ["compound","ready"] else "ui.loan.status.next_wave")]
	_strip_detail.add_theme_color_override("font_color",DEBT if state in ["compound","ready"] else MUTED)
	_strip_icon.texture = load(ART+("loan_rollover.png" if state in ["compound","ready"] else "loan_note.png"))
	_rect(_line,40+label_width+60,12,1,18)
	_text(_strip_detail,Rect2(40 if narrow else 40+label_width+74,28 if narrow else 6,w-48 if narrow else w-label_width-122,16 if narrow else 28),12)
	if short:
		_rect(_strip_icon,6,4,20,20)
		_text(_strip_label,Rect2(34,0,148,28),12)
		_rect(repay,182,2,44,24)
		_rect(reopen,w-100,2,90,24)
		_rect(_line,242,6,1,16)
		_text(_strip_detail,Rect2(254,0,w-262,28),12)


func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FinanceUIStyle.label(node,font_size,color)
	parent.add_child(node)
	return node


func _button(parent: Node, value: String) -> Button:
	var node := Button.new()
	node.text = value
	FinanceUIStyle.button(node)
	FinanceFrameSkin.button(node)
	parent.add_child(node)
	return node


func _panel(parent: Node, _fill: String, _edge: String) -> Panel:
	var node := Panel.new()
	node.add_theme_stylebox_override("panel", FinanceFrameSkin.box())
	parent.add_child(node)
	return node


func _image(parent: Node, path: String) -> TextureRect:
	var node := TextureRect.new()
	if not path.is_empty(): node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func _rect(node: Control, x: float, y: float, w: float, h: float) -> void:
	node.position = Vector2(x,y)
	node.size = Vector2(w,h)


func _text(node: Label, bounds: Rect2, font_size: int) -> void:
	node.add_theme_font_size_override("font_size",font_size)
	node.position = bounds.position
	node.size = bounds.size
