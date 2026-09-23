extends Control
class_name VirtualShopGrid

signal purchase_requested(offer: Dictionary)
signal preview_requested(offer: Dictionary)
signal preview_cleared
const CARD_HEIGHT := 132.0
const CARD_MIN_WIDTH := 136.0
const GAP := 8.0
var offers: Array = []
var flow: MainFlowCoordinator
var scroll: ScrollContainer
var canvas: Control
var _pool: Array[PreparationOfferCard] = []
var _columns := 3
var _last_start := -1
var _logical_focus := 0


func _ready() -> void:
	scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	FinanceUIStyle.scroll(scroll)
	add_child(scroll)
	canvas = Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): _refresh_pool())
	resized.connect(_layout)
	call_deferred("_layout")


func set_offers(next_offers: Array, reset_scroll: bool = false) -> void:
	offers = next_offers
	if reset_scroll:
		_logical_focus = 0
		scroll.scroll_vertical = 0
	_last_start = -1
	_layout()


func refresh_availability() -> void:
	_refresh_pool(true)


func _layout() -> void:
	if scroll == null:
		return
	var usable := maxf(100.0, size.x - 16.0)
	_columns = clampi(floori((usable + GAP) / (CARD_MIN_WIDTH + GAP)), 1, 3)
	canvas.custom_minimum_size.y = maxf(0, ceilf(float(offers.size()) / float(_columns)) * (CARD_HEIGHT + GAP) - GAP)
	_last_start = -1
	_refresh_pool(true)


func _refresh_pool(force: bool = false) -> void:
	if not is_inside_tree() or canvas == null:
		return
	var first_row := maxi(0, floori(float(scroll.scroll_vertical) / (CARD_HEIGHT + GAP)) - 1)
	var start := first_row * _columns
	if not force and start == _last_start:
		return
	_last_start = start
	var rows := maxi(1, ceili(size.y / (CARD_HEIGHT + GAP))) + 3
	var count := mini(rows * _columns, offers.size())
	while _pool.size() < count:
		var card := PreparationOfferCard.new()
		canvas.add_child(card)
		card.purchase_requested.connect(func(offer): purchase_requested.emit(offer))
		card.preview_requested.connect(func(offer): preview_requested.emit(offer))
		card.preview_cleared.connect(func(): preview_cleared.emit())
		card.buy_button.gui_input.connect(_on_card_key.bind(card))
		card.buy_button.focus_entered.connect(func(): _logical_focus = int(card.get_meta("offer_index", 0)))
		_pool.append(card)
	var width := (maxf(100, size.x - 16) - GAP * float(_columns - 1)) / float(_columns)
	for slot in _pool.size():
		var index := start + slot
		var card := _pool[slot]
		card.visible = slot < count and index < offers.size()
		if not card.visible:
			continue
		card.set_meta("offer_index", index)
		card.position = Vector2((index % _columns) * (width + GAP), (index / _columns) * (CARD_HEIGHT + GAP))
		card.size = Vector2(width, CARD_HEIGHT)
		card.configure(offers[index], flow.get_offer_unavailable_reason(offers[index]) if flow != null else "", flow.get_current_gold() if flow != null else 0)


func _on_card_key(event: InputEvent, card: PreparationOfferCard) -> void:
	if not event is InputEventKey or not event.is_pressed():
		return
	var step := 0
	if event.is_action_pressed("ui_down"): step = _columns
	elif event.is_action_pressed("ui_up"): step = -_columns
	elif event.is_action_pressed("ui_right"): step = 1
	elif event.is_action_pressed("ui_left"): step = -1
	if step == 0:
		return
	_logical_focus = clampi(int(card.get_meta("offer_index", 0)) + step, 0, maxi(0, offers.size() - 1))
	scroll.scroll_vertical = maxi(0, floori(float(_logical_focus / _columns) * (CARD_HEIGHT + GAP)))
	_refresh_pool(true)
	for candidate in _pool:
		if candidate.visible and int(candidate.get_meta("offer_index", -1)) == _logical_focus:
			candidate.buy_button.grab_focus()
			break
	accept_event()
