extends Control
class_name BattleSpecializationPanel

signal purchase_requested(token: String, choice_id: String)

var offer: Dictionary = {}
var principal := 0
var selected := -1
var heading: Label
var card_row: HBoxContainer
var cards: Array[Button] = []
var names: Array[Label] = []
var details: Array[Label] = []
var marks: Array[Label] = []
var quote: Label
var note: Label
var confirm: Button
var _scroll: ScrollContainer
var _body: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := Panel.new()
	background.add_theme_stylebox_override("panel", FinanceFrameSkin.box("panel"))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.bank_scroll(_scroll)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scroll)
	_body = Control.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	heading = _label("", FinanceUIStyle.TEXT)
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	_body.add_child(card_row)
	for i in 3:
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("normal", FinanceFrameSkin.box("card", 8))
		card.add_theme_stylebox_override("hover", FinanceFrameSkin.box("card_hover", 8))
		card.add_theme_stylebox_override("pressed", FinanceFrameSkin.box("selected", 8))
		card.add_theme_stylebox_override("disabled", FinanceFrameSkin.box("card", 8))
		card_row.add_child(card)
		cards.append(card)
		var title := _label("", FinanceUIStyle.TEXT, card)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.append(title)
		var body := _label("", FinanceUIStyle.GREEN, card)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		details.append(body)
		var mark := _label("", FinanceUIStyle.MUTED, card)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marks.append(mark)
		card.pressed.connect(choose.bind(i))
		card.resized.connect(arrange)
	quote = _label("", FinanceUIStyle.GOLD)
	note = _label("", FinanceUIStyle.MUTED)
	confirm = Button.new()
	confirm.name = "ConfirmSpecialization"
	_body.add_child(confirm)
	FinanceUIStyle.bank_button(confirm, true)
	confirm.pressed.connect(_submit)
	resized.connect(arrange)
	_body.resized.connect(arrange)
	refresh()


func _label(value: String, color: Color, parent: Control = null) -> Label:
	var item := Label.new()
	item.text = value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.clip_text = true
	FinanceUIStyle.label(item, 23, color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if parent == null: _body.add_child(item)
	else: parent.add_child(item)
	return item


func configure(next_offer: Dictionary, next_principal: int) -> void:
	if str(next_offer.get("token", "")) != str(offer.get("token", "")):
		selected = -1
		_scroll.scroll_vertical = 0
	offer = next_offer.duplicate(true)
	principal = next_principal
	if bool(offer.get("purchased", false)):
		for i in offer.choices.size():
			if str(offer.choices[i].id) == str(offer.selected_id): selected = i
	refresh()


func choose(index: int) -> void:
	if bool(offer.get("purchased", false)) or index >= offer.get("choices", []).size(): return
	selected = index
	refresh()


func _submit() -> void:
	if confirm.disabled or selected < 0: return
	confirm.disabled = true
	purchase_requested.emit(str(offer.token), str(offer.choices[selected].id))


func refresh() -> void:
	if heading == null: return
	var choices: Array = offer.get("choices", [])
	var purchased := bool(offer.get("purchased", false))
	var price := int(offer.get("price", 0))
	var enough := principal >= price
	heading.text = L10n.text("ui.bank.specialization.completed") % L10n.text(str(choices[selected].name_key)) if purchased and selected >= 0 else L10n.text("ui.bank.specialization.title")
	for i in cards.size():
		cards[i].visible = i < choices.size()
		if i >= choices.size(): continue
		var choice: Dictionary = choices[i]
		names[i].text = L10n.text(str(choice.name_key))
		var lines: PackedStringArray = []
		for stat: String in choice.stats:
			var stat_name := StatDefinitions.get_display_name(stat)
			if stat in ["currency_gain_percent", "exp_gain_percent", "revive_count"]:
				stat_name = L10n.text("ui.bank.specialization.stat." + stat)
			var unit := "%" if stat in ["currency_gain_percent", "exp_gain_percent"] else ""
			lines.append("%s +%s%s" % [stat_name, HumanityEconomy.number(float(choice.stats[stat])), unit])
		details[i].text = "\n".join(lines)
		cards[i].tooltip_text = names[i].text + "\n" + details[i].text
		cards[i].disabled = purchased
		var active := i == selected
		var box := FinanceFrameSkin.box("selected" if active else "card", 8)
		cards[i].add_theme_stylebox_override("normal", box)
		cards[i].add_theme_stylebox_override("disabled", box)
		marks[i].text = L10n.text("ui.bank.specialization." + (("obtained" if active else "not_chosen") if purchased else ("selected" if active else "choose")))
		FinanceUIStyle.label(marks[i], 20, FinanceUIStyle.GOLD if active else FinanceUIStyle.MUTED)
		cards[i].modulate = Color.WHITE if not purchased or active else Color(0.72, 0.72, 0.72)
	if purchased:
		quote.text = L10n.text("ui.bank.specialization.paid") % [price, principal]
		note.text = L10n.text("ui.bank.specialization.done_hint")
	elif not enough:
		quote.text = L10n.text("ui.bank.specialization.shortfall") % [principal, price, price - principal]
		note.text = L10n.text("ui.bank.specialization.shortfall_hint")
	else:
		quote.text = L10n.text("ui.bank.specialization.principal_preview") % [principal, int(offer.get("principal_after_payment", principal - price))]
		note.text = L10n.text("ui.bank.specialization.select_hint" if selected < 0 else "ui.bank.specialization.confirm_hint")
	confirm.disabled = purchased or selected < 0 or not enough or choices.is_empty()
	confirm.text = L10n.text("ui.bank.specialization.purchased") if purchased else (L10n.text("ui.bank.specialization.insufficient") if not enough else (L10n.text("ui.bank.specialization.select_first") if selected < 0 else L10n.text("ui.bank.specialization.confirm") % price))
	note.tooltip_text = note.text
	arrange()


func arrange() -> void:
	if heading == null or size.x < 1 or size.y < 1: return
	# Only very short loan layouts scroll. The approved normal layout stays intact.
	_body.custom_minimum_size.y = 154
	var width := _body.size.x
	var height := maxf(154, size.y)
	var compact := width < 430 or height < 255
	var short := height < 200
	var margin := 8.0 if compact else 12.0
	var title_h := 21.0 if compact else 26.0
	var header_h := 28.0 if compact else 39.0
	var footer_h := 52.0 if short else (78.0 if compact else 88.0)
	var font := 18 if compact else 22
	FinanceUIStyle.label(heading, 23 if compact else 28, FinanceUIStyle.TEXT)
	FinanceUIStyle.label(quote, font, FinanceUIStyle.GOLD)
	FinanceUIStyle.label(note, 18 if compact else 20, FinanceUIStyle.MUTED)
	_place(heading, Rect2(margin, margin - 3, width - margin * 2, title_h))
	_place(card_row, Rect2(margin, header_h, width - margin * 2, maxf(70, height - header_h - footer_h)))
	card_row.add_theme_constant_override("separation", 5 if compact else 8)
	for i in cards.size():
		var card := cards[i]
		var w := card.size.x
		var h := card.size.y
		FinanceUIStyle.label(names[i], 20 if compact else 25, FinanceUIStyle.TEXT)
		FinanceUIStyle.label(details[i], font, FinanceUIStyle.GREEN)
		details[i].add_theme_constant_override("line_spacing", 3 if compact else 6)
		_place(names[i], Rect2(3, 2 if short else (4 if compact else 10), w - 6, 18 if short else 22))
		_place(details[i], Rect2(3, 21 if short else (26 if compact else 38), w - 6, maxf(36, h - (24 if short else (48 if compact else 66)))))
		_place(marks[i], Rect2(3, h - 22, w - 6, 18))
		marks[i].visible = h >= 100
	var footer_y := height - footer_h
	_place(quote, Rect2(margin, footer_y + (1 if short else 6), width - margin * 2, 18 if short else 20))
	_place(note, Rect2(margin, footer_y + 28, width - margin * 2, 18))
	note.visible = not short
	_place(confirm, Rect2(margin, height - 34, width - margin * 2, 28))
	confirm.add_theme_font_size_override("font_size", 12 if compact else 14)


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
