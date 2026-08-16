extends Control
class_name ShopPopup

signal offer_selected(offer: Dictionary)
signal skipped

const ENTRY_FREE: String = "free"
const ENTRY_SHOP: String = "shop"
const REWARD_OPTION_SCENE: PackedScene = preload("res://scenes/ui/rewards/reward_option.tscn")

var payload: Dictionary = {}
var _offer_cards: Array[RewardOption] = []
var _submitted: bool = false

@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var gold_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/GoldLabel")
@onready var error_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/ErrorLabel")
@onready var offer_grid: HBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content/OfferGrid")
@onready var skip_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/SkipButton")


func _ready() -> void:
	if skip_button != null and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	hide_popup()


func configure(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)
	_submitted = false
	_refresh_visual()


func show_popup() -> void:
	visible = true
	_refresh_visual()


func hide_popup() -> void:
	visible = false
	_clear_cards()


func show_error(reason: String) -> void:
	if error_label != null:
		error_label.text = "购买失败：%s" % reason


func reset_submission() -> void:
	_submitted = false


func get_mode() -> String:
	return str(payload.get("mode", ENTRY_FREE))


func _refresh_visual() -> void:
	var mode := get_mode()
	if title_label != null:
		title_label.text = "共享奖励" if mode == ENTRY_FREE else "局内商店"
	if gold_label != null:
		if mode == ENTRY_SHOP:
			gold_label.text = "当前金币：%d" % int(payload.get("gold", 0))
		else:
			gold_label.text = "免费选择一项奖励"
	if error_label != null:
		error_label.text = ""
	_clear_cards()
	if offer_grid == null:
		return
	for offer in payload.get("offers", []):
		if not (offer is Dictionary):
			continue
		var card := REWARD_OPTION_SCENE.instantiate() as RewardOption
		if card == null:
			continue
		offer_grid.add_child(card)
		card.configure(offer, RewardOption.ENTRY_SHOP if mode == ENTRY_SHOP else RewardOption.ENTRY_FREE)
		var card_callable := Callable(self, "_on_offer_selected")
		card.selected.connect(card_callable)
		_offer_cards.append(card)


func _on_offer_selected(offer: Dictionary) -> void:
	if _submitted:
		return
	_submitted = true
	offer_selected.emit(offer.duplicate(true))


func _on_skip_pressed() -> void:
	if _submitted:
		return
	_submitted = true
	skipped.emit()


func _clear_cards() -> void:
	for card in _offer_cards:
		if is_instance_valid(card):
			card.queue_free()
	_offer_cards.clear()
