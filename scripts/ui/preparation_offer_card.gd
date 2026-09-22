extends PanelContainer
class_name PreparationOfferCard

signal purchase_requested(offer: Dictionary)
signal preview_requested(offer: Dictionary)
signal preview_cleared
var offer: Dictionary = {}
var _icon: TextureRect
var _name_label: Label
var _kind_label: Label
var _description: RichTextLabel
var _price: Label
var buy_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", FinanceUIStyle.box())
	mouse_filter = Control.MOUSE_FILTER_PASS
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var icon_frame := PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", FinanceUIStyle.box("151f19", "8c845c", 3))
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(icon_frame)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(_icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	_name_label = Label.new()
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_name_label, 14)
	titles.add_child(_name_label)
	_kind_label = Label.new()
	FinanceUIStyle.label(_kind_label, 12, FinanceUIStyle.MUTED)
	titles.add_child(_kind_label)
	_description = RichTextLabel.new()
	_description.bbcode_enabled = true
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description.scroll_active = false
	_description.custom_minimum_size.y = 38
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.add_theme_font_size_override("normal_font_size", 12)
	_description.add_theme_color_override("default_color", FinanceUIStyle.MUTED)
	body.add_child(_description)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_price = Label.new()
	_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FinanceUIStyle.label(_price, 14, FinanceUIStyle.GOLD)
	footer.add_child(_price)
	buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(82, 26)
	FinanceUIStyle.button(buy_button)
	footer.add_child(buy_button)
	buy_button.pressed.connect(func(): purchase_requested.emit(offer))
	buy_button.mouse_entered.connect(func(): preview_requested.emit(offer))
	buy_button.mouse_exited.connect(func(): preview_cleared.emit())
	buy_button.focus_entered.connect(func(): preview_requested.emit(offer))
	buy_button.focus_exited.connect(func(): preview_cleared.emit())
	mouse_entered.connect(func(): preview_requested.emit(offer))
	mouse_exited.connect(func(): preview_cleared.emit())


func configure(value: Dictionary, unavailable: String, gold: int) -> void:
	offer = value
	var title := str(offer.get("display_name", ""))
	_name_label.text = title
	_kind_label.text = str({"new_weapon": "武器", "relic": "遗物", "weapon_upgrade": "武器升级"}.get(offer.get("offer_type", ""), ""))
	_description.text = str(offer.get("description", ""))
	tooltip_text = title + "\n" + _description.get_parsed_text()
	_name_label.tooltip_text = tooltip_text
	var path := str(offer.get("icon", ""))
	_icon.texture = FinanceUIStyle.item_icon(path, "relics" if str(offer.get("offer_type", "")) == "relic" else "weapons", str(offer.get("target_id", "")))
	var cost := int(offer.get("shop_cost", 0))
	_price.text = "%d 金币" % cost
	buy_button.disabled = not unavailable.is_empty()
	buy_button.text = "购买" if unavailable.is_empty() else ("已购买" if unavailable == "already_purchased" else "不可购买")
	buy_button.tooltip_text = "" if unavailable.is_empty() else FinanceUIStyle.reason(unavailable)
	if unavailable == "insufficient_gold":
		buy_button.text = "差 %d" % maxi(0, cost - gold)
	modulate = Color(0.62, 0.66, 0.58) if bool(offer.get("purchased", false)) else Color.WHITE
