extends Control
class_name GoblinLoanPresentation
## Displays authoritative loan state; no money or debt is owned by this control.

signal error_requested(reason: String)
const ART := "res://assets/ui/finance/loan/"
const SPEECH := "钱不够？先拿去，后面再还！"
const GOLD := Color("d9b675")
const TEXT := Color("e4dcc5")
const MUTED := Color("a5ad94")
const DEBT := Color("d39a72")
var flow: MainFlowCoordinator
var state := "hidden"
var borrowed := 0
var due := 0
var wallet := 0
var elapsed := 0.0
var _quote: Dictionary = {}
var _modal: Control
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
		_speech.text = str(_quote.get("speech",SPEECH))
		var options: Array = _quote.get("options",[])
		for i in _cards.size():
			var card: Dictionary = _cards[i]
			card.panel.visible = i < options.size()
			if i >= options.size(): continue
			var entry: Dictionary = options[i]
			card.amount_value = int(entry.amount)
			card.repayment = int(entry.due)
			card.value.text = "+ %d" % int(entry.amount)
			card.due.text = "%d 金币" % int(entry.due)
			card.rate.text = "每波利息 %s%%" % HumanityEconomy.number(float(entry.rate_percent))
			card.button.text = "借 %d" % int(entry.amount)
			card.icon.texture = load(str(entry.icon))
			var terms := "获得 %d 金币；第%d波结束应还 %d 金币。每波利息 %s%%。" % [entry.amount,int(_quote.due_wave),entry.due,HumanityEconomy.number(float(entry.rate_percent))]
			if bool(entry.get("adjusted",false)): terms += "\n已依据当前遗物的预计新增利息调整；本次条款已固定。"
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
	_strip_detail.tooltip_text = "当前应还 %d 金币；第%d波结束，在全部结息后检查钱包。\n不足不扣款，按合同利率计复利。" % [due,int(active.get("due_wave",0))]
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
	_dimmer.color = Color(0.025, 0.04, 0.03, 0.73)
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(_dimmer)
	_box = _panel(_modal, "232d23", "ad905d")
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
	_title = _label(_box, "哥布林贷款", 24, GOLD)
	_close = _button(_box, "×")
	_close.pressed.connect(dismiss_quote)
	_portrait = _image(_box, "")
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/finance/goblin_banker_states.png")
	atlas.region = Rect2(3 * 128, 0, 128, 128)
	_portrait.texture = atlas
	_bubble = _panel(_box, "303c2c", "778463")
	_bubble.add_theme_stylebox_override("panel", FinanceFrameSkin.box("slim"))
	_speech = _label(_bubble, SPEECH, 18, TEXT)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tail = _image(_box, "res://assets/ui/finance/trade_bubble_tail.png")
	for i in 3:
		var amount: int = [100, 200, 500][i]
		var card := _panel(_box, "283326" if i < 2 else "343724", "67734f" if i < 2 else "bba066")
		card.add_theme_stylebox_override("panel", FinanceFrameSkin.box("card"))
		var gain := _label(card, "立即获得", 12, MUTED)
		var value := _label(card, "+ %d" % amount, 30, Color("ecce8a"))
		var money := _label(card, "金币", 12, MUTED)
		var icon := _image(card, ART + "loan_%d.png" % amount)
		var line := ColorRect.new()
		line.color = Color("526043")
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(line)
		var caption := _label(card, "下波归还", 12, MUTED)
		var repayment := _label(card, "%d 金币" % [140,260,600][i], 18, TEXT)
		repayment.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var rate := _label(card, "每波利息 %d%%" % [40,30,20][i], 12, DEBT)
		var button := _button(card, "借 %d" % amount)
		FinanceUIStyle.button(button, i == 2)
		FinanceFrameSkin.button(button, i == 2)
		button.pressed.connect(_choose.bind(i))
		_cards.append({"panel":card,"icon":icon,"gain":gain,"value":value,"money":money,
			"line":line,"caption":caption,"due":repayment,"rate":rate,"button":button,
			"amount_value":amount,"repayment":[140,260,600][i]})
	_rule = _label(_box, "下一波结束，全部结息后自动还款。\n余额不足不扣款，欠款计复利。", 12, MUTED)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decline = _button(_box, "暂时不用")
	_decline.pressed.connect(dismiss_quote)


func _layout_modal() -> void:
	if _box == null: return
	var viewport := get_viewport_rect().size
	var short := viewport.y < 480
	var narrow := viewport.x < 520
	_box.size = Vector2(minf(720, viewport.x - 24), 578 if narrow else (336 if short else 472))
	_box.position = ((viewport - _box.size) * 0.5).floor()
	var w := _box.size.x
	_rect(_seal, 20, 14, 24, 28)
	_text(_title, Rect2(54, 12, w-116, 32), 18 if short or narrow else 24)
	_rect(_close, w-46, 14, 26, 26)
	var portrait_size := Vector2(72,72) if narrow else (Vector2(72,63) if short else Vector2(112,98))
	_portrait.size = portrait_size
	_portrait.position = Vector2(20, 49 if narrow else (40 if short else 53))
	_portrait.set_meta("rest_y", _portrait.position.y)
	var bubble_x := 100.0 if short or narrow else 146.0
	_rect(_bubble, bubble_x, 53 if narrow else (51 if short else 68), w-bubble_x-24, 72 if narrow else (42 if short else 66))
	_text(_speech, Rect2(12, 4, _bubble.size.x-24, _bubble.size.y-8), 14 if short or narrow else 18)
	_rect(_tail, bubble_x-11, 91 if narrow else (75 if short else 111), 18, 12)
	var card_top := 143.0 if narrow else (112.0 if short else 164.0)
	var card_w := w-32 if narrow else floorf((w-48)/3.0)
	var card_h := 100.0 if narrow else (150.0 if short else 222.0)
	for i in _cards.size():
		var c := _cards[i]
		_rect(c.panel, 16 if narrow else 16+i*(card_w+8), card_top+i*(card_h+8) if narrow else card_top, card_w, card_h)
		c.line.visible = not narrow
		if narrow:
			_rect(c.icon, 10, 24, 44, 44)
			_text(c.gain, Rect2(64,7,130,18),12)
			_text(c.value, Rect2(64,24,98,30),24)
			_text(c.money, Rect2(163,30,40,22),12)
			_text(c.caption, Rect2(64,57,68,18),12)
			_text(c.due, Rect2(132,57,70,18),12)
			_text(c.rate, Rect2(64,78,144,16),12)
			_rect(c.button, card_w-86,34,74,32)
		else:
			_rect(c.icon, 12, 14, 40 if short else 48, 40 if short else 48)
			_text(c.gain, Rect2(62 if short else 74,8,card_w-80,20),12)
			_text(c.value, Rect2(60 if short else 72,28,card_w-80,38),24 if short else 30)
			_text(c.money, Rect2(card_w-40,37 if short else 40,32,24),12)
			_rect(c.line,12,66 if short else 82,card_w-24,1)
			_text(c.caption,Rect2(12,72 if short else 94,70,24),12)
			_text(c.due,Rect2(74,72 if short else 92,card_w-86,28),16 if short else 18)
			_text(c.rate,Rect2(12,98 if short else 127,card_w-24,20),12)
			_rect(c.button,12,120 if short else 174,card_w-24,26 if short else 34)
	if narrow:
		_text(_rule,Rect2(20,474,w-40,54),12)
		_rect(_decline,w-124,534,104,30)
	elif short:
		_text(_rule,Rect2(20,270,w-162,50),12)
		_rect(_decline,w-126,282,106,32)
	else:
		_text(_rule,Rect2(22,404,w-174,48),12)
		_rect(_decline,w-130,414,108,34)


func _build_strip() -> void:
	_strip = _panel(self, "1d281fd9", "706446")
	_strip_icon = _image(_strip, ART+"loan_note.png")
	_strip_label = _label(_strip, "哥布林贷款", 14, GOLD)
	_strip_detail = _label(_strip, "", 12, MUTED)
	reopen = _button(_strip,"查看条款")
	reopen.pressed.connect(show_quote)
	repay = _button(_strip,"还清")
	repay.pressed.connect(_repay)
	_line = ColorRect.new()
	_line.color = Color("675b3a")
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
	var text := "哥布林贷款"
	if repay.visible: text = "已贷款：%d 金币" % borrowed
	if state == "paid": text = "贷款已还清"
	_strip_label.text = text
	var label_width := 164.0 if not narrow else 148.0
	_text(_strip_label,Rect2(40,3 if narrow else 6,label_width,28),12 if narrow else 14)
	_rect(reopen,w-100,7,90,28)
	_rect(repay,40+label_width,6,44,28)
	repay.disabled = wallet < due
	repay.tooltip_text = "一次性还清 %d 金币" % due if not repay.disabled else "还清需要 %d 金币" % due
	_strip_detail.text = "应还 %d 金币 · %s" % [due, "已计复利" if state in ["compound","ready"] else "下波结束结算"]
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
