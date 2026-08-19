extends Control
class_name ShopPopup

signal offer_selected(offer: Dictionary)
signal skipped
signal refresh_requested
signal stat_preview_requested(offer: Dictionary)
signal stat_preview_cleared

const ENTRY_FREE: String = "free"
const ENTRY_SHOP: String = "shop"
const REWARD_OPTION_SCENE: PackedScene = preload("res://scenes/ui/rewards/reward_option.tscn")

var payload: Dictionary = {}
var _offer_cards: Array[RewardOption] = []
var _submitted: bool = false
var _loadout: WeaponLoadout = null
var _bond_player: PlayerController = null

@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var gold_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/GoldLabel")
@onready var error_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/ErrorLabel")
@onready var offer_grid: HBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content/OfferGrid")
@onready var skip_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/SkipButton")
@onready var refresh_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/RefreshButton")
@onready var weapon_strip: WeaponStrip = get_node_or_null("WeaponStrip")


func _ready() -> void:
	if skip_button != null and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if refresh_button != null and not refresh_button.pressed.is_connected(_on_refresh_pressed):
		refresh_button.pressed.connect(_on_refresh_pressed)
	hide_popup()


func configure(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)
	_submitted = false
	_refresh_visual()


func show_popup() -> void:
	visible = true
	_refresh_visual()
	if weapon_strip != null and _loadout != null:
		weapon_strip.set_loadout(_loadout)


func hide_popup() -> void:
	visible = false
	stat_preview_cleared.emit()
	_clear_cards()


func show_error(reason: String) -> void:
	if error_label != null:
		error_label.text = _translate_purchase_error(reason)


func _translate_purchase_error(reason: String) -> String:
	match reason:
		"insufficient_gold":
			return "购买失败 金币不足"
		"invalid_offer":
			return "购买失败 无效的选项"
		"purchase_failed":
			return "购买失败 升级未生效"
		"shop_not_active":
			return "购买失败 商店未开启"
		"insufficient_gold_for_refresh":
			return "刷新失败 金币不足"
		_:
			return "购买失败 请重试"


func reset_submission() -> void:
	_submitted = false


func refresh_gold(current_gold: int) -> void:
	payload["gold"] = current_gold
	if gold_label != null and get_mode() == ENTRY_SHOP:
		gold_label.text = "当前金币 %d" % current_gold
	_update_refresh_button()
	if weapon_strip != null and _loadout != null:
		weapon_strip.set_loadout(_loadout)


func remove_offer(offer_id: String) -> void:
	if offer_id.is_empty():
		return
	for card in _offer_cards.duplicate():
		if not is_instance_valid(card) or str(card.offer_data.get("offer_id", "")) != offer_id:
			continue
		_offer_cards.erase(card)
		card.queue_free()
		return


func get_mode() -> String:
	return str(payload.get("mode", ENTRY_FREE))


func _refresh_visual() -> void:
	var mode := get_mode()
	if title_label != null:
		title_label.text = "共享奖励" if mode == ENTRY_FREE else "局内商店"
	if gold_label != null:
		if mode == ENTRY_SHOP:
			gold_label.text = "当前金币 %d" % int(payload.get("gold", 0))
		else:
			gold_label.text = "免费选择一项奖励"
	if error_label != null:
		error_label.text = ""
	_update_refresh_button()
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
		card.set_bond_player(_bond_player)
		var card_callable := Callable(self, "_on_offer_selected")
		card.selected.connect(card_callable)
		card.stat_preview_requested.connect(_on_card_stat_preview_requested)
		card.stat_preview_cleared.connect(_on_card_stat_preview_cleared)
		_offer_cards.append(card)


func _on_offer_selected(offer: Dictionary) -> void:
	if _submitted:
		return
	_submitted = true
	offer_selected.emit(offer.duplicate(true))


func _on_card_stat_preview_requested(offer: Dictionary) -> void:
	stat_preview_requested.emit(offer)


func _on_card_stat_preview_cleared() -> void:
	stat_preview_cleared.emit()


func _on_skip_pressed() -> void:
	if _submitted:
		return
	_submitted = true
	skipped.emit()


func _on_refresh_pressed() -> void:
	if _submitted:
		return
	refresh_requested.emit()


func _update_refresh_button() -> void:
	if refresh_button == null:
		return
	var refresh_cost := int(payload.get("refresh_cost", 0))
	var current_gold := int(payload.get("gold", 0))
	refresh_button.text = "刷新（%d 金币）" % refresh_cost
	refresh_button.disabled = refresh_cost <= 0 or current_gold < refresh_cost


func _clear_cards() -> void:
	for card in _offer_cards:
		if is_instance_valid(card):
			card.queue_free()
	_offer_cards.clear()


func set_loadout(loadout: WeaponLoadout) -> void:
	_loadout = loadout
	if weapon_strip != null:
		weapon_strip.set_loadout(loadout)


func set_bond_player(player: PlayerController) -> void:
	_bond_player = player
	if weapon_strip != null:
		weapon_strip.set_bond_player(player)
	for card in _offer_cards:
		if is_instance_valid(card):
			card.set_bond_player(player)
