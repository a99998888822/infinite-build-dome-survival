extends PanelContainer
class_name PreparationOfferCard

signal purchase_requested(offer: Dictionary)
signal preview_requested(offer: Dictionary)
signal preview_cleared
var offer: Dictionary = {}
var _icon: TextureRect
var _rarity_glow: TextureRect
var _name_label: Label
var _kind_label: Label
var _description: RichTextLabel
var _price: Label
var buy_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", FinanceUIStyle.box("232a21", "576048", 6))
	mouse_filter = Control.MOUSE_FILTER_PASS
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	add_child(body)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	body.add_child(heading)
	var icon_frame := Control.new()
	icon_frame.custom_minimum_size = Vector2(36, 36)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(icon_frame)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.width = 64
	glow_texture.height = 64
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	_rarity_glow = TextureRect.new()
	_rarity_glow.texture = glow_texture
	_rarity_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rarity_glow.position = Vector2(-12, -12)
	_rarity_glow.size = Vector2(60, 60)
	_rarity_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rarity_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(_rarity_glow)
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	FinanceUIStyle.label(_name_label, 12)
	titles.add_child(_name_label)
	_kind_label = Label.new()
	FinanceUIStyle.label(_kind_label, 10, FinanceUIStyle.MUTED)
	titles.add_child(_kind_label)
	var description_margin := MarginContainer.new()
	description_margin.add_theme_constant_override("margin_top", 8)
	description_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(description_margin)
	_description = RichTextLabel.new()
	_description.bbcode_enabled = true
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description.scroll_active = false
	_description.custom_minimum_size.y = 32
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.add_theme_font_size_override("normal_font_size", 11)
	_description.add_theme_color_override("default_color", FinanceUIStyle.MUTED)
	description_margin.add_child(_description)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_price = WrappedTooltipLabel.new()
	_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_price, 11, FinanceUIStyle.GOLD)
	footer.add_child(_price)
	buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(58, 26)
	FinanceUIStyle.button(buy_button)
	buy_button.add_theme_font_size_override("font_size", 11)
	buy_button.clip_text = true
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
	var rarity := str(offer.get("rarity", "common"))
	var rarity_color: Color = ItemInventoryCard.RARITY_COLORS.get(rarity, ItemInventoryCard.RARITY_COLORS["common"])
	_rarity_glow.visible = str(offer.get("offer_type", "")) == "relic"
	_rarity_glow.modulate = rarity_color
	var rarity_label := str(ItemInventoryCard.RARITY_LABELS.get(rarity, "普通"))
	_kind_label.text = rarity_label if str(offer.get("offer_type", "")) == "relic" else _kind_label.text + " · " + rarity_label
	_kind_label.add_theme_color_override("font_color", rarity_color)
	var panel := FinanceUIStyle.box("232a21", "576048", 6)
	panel.border_color = Color("576048").lerp(rarity_color, 0.55)
	add_theme_stylebox_override("panel", panel)
	var cost := int(offer.get("shop_cost", 0))
	_price.text = "%s 金币" % HumanityEconomy.price_text(cost, int(offer.get("shop_cost_without_humanity", cost)))
	_price.mouse_filter = Control.MOUSE_FILTER_PASS
	_price.tooltip_text = HumanityEconomy.purchase_tooltip(offer)
	buy_button.disabled = not unavailable.is_empty()
	buy_button.text = "购买" if unavailable.is_empty() else ("已购买" if unavailable == "already_purchased" else "不可购买")
	buy_button.tooltip_text = HumanityEconomy.purchase_tooltip(offer) if unavailable.is_empty() else FinanceUIStyle.reason(unavailable)
	if unavailable == "insufficient_gold":
		buy_button.text = "差 %d" % maxi(0, cost - gold)
	modulate = Color(0.62, 0.66, 0.58) if bool(offer.get("purchased", false)) else Color.WHITE
