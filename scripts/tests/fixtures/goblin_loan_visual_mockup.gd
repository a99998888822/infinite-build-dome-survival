extends Control
## Isolated visual prototype. This does not create, price, or settle real loans.

signal preview_accepted(amount: int)
signal preview_repaid(amount: int)

const ART := "res://assets/ui/finance/loan/"
const SPEECH := "钱不够？先拿去，后面再还！"
const GOLD := Color("d9b675")
const TEXT := Color("e4dcc5")
const MUTED := Color("a5ad94")
const DEBT := Color("d39a72")

var bank: FinancePopup
var base_rect := Rect2()
var state := "hidden"
var borrowed := 500
var due := 600
var wallet := 18
var elapsed := 0.0
var clicks := 0
var automatic_shown := false
var animate := true
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
var _pointer := Vector2(-100, -100)
var _click_progress := -1.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()
	_build_strip()
	_build_modal()
	resized.connect(_layout_modal)
	_modal.hide()
	_strip.hide()


func attach(popup: FinancePopup, bounds: Rect2) -> void:
	bank = popup
	base_rect = bounds
	arrange_bank()
	_layout_modal()


func arrange_bank() -> void:
	if bank == null: return
	var short := get_viewport_rect().size.y < 480
	var reserve := (34.0 if short else 54.0) if state != "hidden" else 0.0
	bank.set_safe_rect(Rect2(base_rect.position, base_rect.size - Vector2(0, reserve)))
	# Only the review rearranges the live bank, reserving a new bottom row.
	bank.main_panel.size = base_rect.size
	bank._feedback.visible = false if state != "hidden" else get_viewport_rect().size.y >= 480
	if short and bank._compact and state != "hidden":
		bank._title.position.y = 4
		bank._title.size.y = 22
		bank._summary.position.y = 27
		bank._summary.size.y = 18
		bank._tabs.position.y -= 8
		for content: Control in [bank._bank, bank._shop, bank._enchant_scroll]:
			content.position.y -= 8
			content.size.y += 8
		bank.shop_grid.size.y += 8
		bank._refresh.position.y += 8
		bank._stock.position.y += 8
	_strip.position = base_rect.position + Vector2(20, base_rect.size.y - (34 if short else 54))
	_strip.size = Vector2(base_rect.size.x - 40, 42)
	_strip.visible = state != "hidden"
	_layout_strip()


func show_quote(replay := true) -> void:
	automatic_shown = true
	_modal.show()
	if replay: elapsed = 0.0
	_layout_modal()
	seek(elapsed)


func dismiss_quote() -> void:
	_modal.hide()
	if state == "hidden": state = "available"
	arrange_bank()
	_layout_strip()


func show_state(value: String, amount := 500, repayment := 600, balance := 18) -> void:
	state = value
	borrowed = amount
	due = repayment
	wallet = balance
	_modal.hide()
	arrange_bank()
	_layout_strip()


func set_quote_amounts(repayments: Array, rates: Array) -> void:
	for i in _cards.size():
		_cards[i].due.text = "%d 金币" % int(repayments[i])
		_cards[i].rate.text = "每波利息 %s%%" % str(rates[i])
		_cards[i].repayment = int(repayments[i])


func _choose(index: int) -> void:
	var entry: Dictionary = _cards[index]
	borrowed = int(entry.amount_value)
	due = int(entry.repayment)
	wallet += borrowed
	show_state("borrowed", borrowed, due, wallet)
	preview_accepted.emit(borrowed)


func _repay() -> void:
	if wallet < due: return
	var paid := due
	wallet -= paid
	show_state("paid", borrowed, 0, wallet)
	preview_repaid.emit(paid)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _modal.visible:
		dismiss_quote()
		get_viewport().set_input_as_handled()
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _modal.visible or automatic_shown or bank == null: return
	# The actual Button stays disabled. Observe its hit region only in this preview.
	for card: PreparationOfferCard in bank.shop_grid._pool:
		if card.is_visible_in_tree() and card.buy_button.disabled and card.buy_button.get_global_rect().has_point(event.position):
			if int(card.offer.get("shop_cost", 0)) <= wallet or bool(card.offer.get("purchased", false)): continue
			clicks += 1
			if clicks >= 3: show_quote()
			break


func _process(delta: float) -> void:
	if animate and _modal.visible: seek(elapsed + delta)


func seek(seconds: float) -> void:
	elapsed = seconds
	_speech.visible_characters = mini(SPEECH.length(), maxi(0, int(seconds * 15.0)))
	_portrait.position.y = _portrait.get_meta("rest_y", _portrait.position.y) + roundf(sin(seconds * 2) * 1.0)
	queue_redraw()


func cursor(at: Vector2, progress := -1.0) -> void:
	_pointer = at
	_click_progress = progress
	queue_redraw()


func _draw() -> void:
	if _pointer.x < 0: return
	var points := PackedVector2Array([_pointer, _pointer + Vector2(0, 15), _pointer + Vector2(4, 11), _pointer + Vector2(11, 16), _pointer + Vector2(7, 9), _pointer + Vector2(13, 9)])
	draw_colored_polygon(points, Color("f1e4bb"))
	if _click_progress >= 0 and _click_progress <= 1:
		draw_arc(_pointer + Vector2(2, 3), 5 + _click_progress * 15, 0, TAU, 24, Color(GOLD, 1 - _click_progress), 1.5)


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
	var frame_size := atlas.atlas.get_height()
	atlas.region = Rect2(3 * frame_size, 0, frame_size, frame_size)
	_portrait.texture = atlas
	_bubble = _panel(_box, "303c2c", "778463")
	_speech = _label(_bubble, SPEECH, 18, TEXT)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tail = _image(_box, "res://assets/ui/finance/trade_bubble_tail.png")
	for i in 3:
		var amount: int = [100, 200, 500][i]
		var card := _panel(_box, "283326" if i < 2 else "343724", "67734f" if i < 2 else "bba066")
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
	parent.add_child(node)
	return node


func _panel(parent: Node, fill: String, edge: String) -> Panel:
	var node := Panel.new()
	node.add_theme_stylebox_override("panel",FinanceUIStyle.box(fill,edge,0))
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
