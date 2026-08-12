extends PanelContainer
class_name RewardOption

signal selected(offer: Dictionary)

const ENTRY_FREE: String = "free"
const ENTRY_SHOP: String = "shop"

const OFFER_TYPE_TITLES: Dictionary = {
	"weapon_upgrade": "武器升级",
	"new_weapon": "新武器",
	"relic": "遗物",
}

const RARITY_COLORS: Dictionary = {
	"common": Color(0.86, 0.86, 0.86, 1.0),
	"uncommon": Color(0.35, 0.92, 0.45, 1.0),
	"rare": Color(0.35, 0.62, 1.0, 1.0),
	"epic": Color(0.72, 0.42, 1.0, 1.0),
	"mythic": Color(1.0, 0.58, 0.22, 1.0),
	"legendary": Color(1.0, 0.24, 0.22, 1.0),
}

var offer_data: Dictionary = {}
var entry_mode: String = ENTRY_FREE

@onready var top_rarity_line: ColorRect = get_node_or_null("Content/TopRarityLine")
@onready var type_label: Label = get_node_or_null("Content/TypeLabel")
@onready var icon_texture: TextureRect = get_node_or_null("Content/IconFrame/IconTexture")
@onready var icon_placeholder: ColorRect = get_node_or_null("Content/IconFrame/IconPlaceholder")
@onready var name_label: Label = get_node_or_null("Content/NameLabel")
@onready var description_label: Label = get_node_or_null("Content/DescriptionLabel")
@onready var bottom_rarity_line: ColorRect = get_node_or_null("Content/BottomRarityLine")
@onready var select_button: Button = get_node_or_null("Content/SelectButton")


func _ready() -> void:
	if select_button != null and not select_button.pressed.is_connected(_on_select_button_pressed):
		select_button.pressed.connect(_on_select_button_pressed)
	_refresh_visual()


func configure(offer: Dictionary, mode: String = ENTRY_FREE, explicit_cost: int = -1) -> void:
	offer_data = offer.duplicate(true)
	entry_mode = mode
	_refresh_visual(explicit_cost)


func get_button_text_for_offer(offer: Dictionary, mode: String = ENTRY_FREE, explicit_cost: int = -1) -> String:
	if mode == ENTRY_FREE:
		return "选择"
	if explicit_cost >= 0:
		return str(explicit_cost)
	if offer.has("shop_cost"):
		return str(int(offer.get("shop_cost", 0)))
	if offer.has("price"):
		return str(int(offer.get("price", 0)))
	return str(int(offer.get("load_cost", 0)))


func get_title_for_offer_type(offer_type: String) -> String:
	return str(OFFER_TYPE_TITLES.get(offer_type, offer_type))


func get_color_for_rarity(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


func _refresh_visual(explicit_cost: int = -1) -> void:
	var rarity := str(offer_data.get("rarity", "common"))
	var rarity_color := get_color_for_rarity(rarity)
	_update_panel_style(rarity_color)
	_update_rarity_lines(rarity_color)

	if type_label != null:
		type_label.text = get_title_for_offer_type(str(offer_data.get("offer_type", "")))
		type_label.add_theme_color_override("font_color", rarity_color)
	if name_label != null:
		name_label.text = str(offer_data.get("display_name", offer_data.get("target_id", "")))
	if description_label != null:
		description_label.text = _build_description_text(offer_data)
	if select_button != null:
		select_button.text = get_button_text_for_offer(offer_data, entry_mode, explicit_cost)
	_update_icon(str(offer_data.get("icon", "")))


func _update_panel_style(rarity_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.10, 0.88)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)


func _update_rarity_lines(rarity_color: Color) -> void:
	if top_rarity_line != null:
		top_rarity_line.color = rarity_color
	if bottom_rarity_line != null:
		bottom_rarity_line.color = rarity_color


func _update_icon(icon_path: String) -> void:
	var loaded_texture: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var resource := load(icon_path)
		if resource is Texture2D:
			loaded_texture = resource
	if icon_texture != null:
		icon_texture.texture = loaded_texture
		icon_texture.visible = loaded_texture != null
	if icon_placeholder != null:
		icon_placeholder.visible = loaded_texture == null


func _build_description_text(offer: Dictionary) -> String:
	if offer.has("description"):
		var description := str(offer.get("description", ""))
		if not description.is_empty():
			return description
	if offer.has("effects"):
		var effect_texts: Array[String] = []
		for effect in offer.get("effects", []):
			if effect is Dictionary:
				effect_texts.append(_format_effect(effect))
		if not effect_texts.is_empty():
			return "\n".join(effect_texts)
	if offer.has("runtime_effects"):
		var runtime_texts: Array[String] = []
		for effect in offer.get("runtime_effects", []):
			if effect is Dictionary:
				var effect_data: Dictionary = effect
				runtime_texts.append(str(effect_data.get("effect", "runtime_effect")))
		if not runtime_texts.is_empty():
			return "；".join(runtime_texts)
	match str(offer.get("offer_type", "")):
		"weapon_upgrade":
			return "提升到 %d 级。" % int(offer.get("to_level", 0))
		"new_weapon":
			return "获得新的武器。负载：%d" % int(offer.get("load_cost", 0))
		"relic":
			return "获得遗物效果。"
		_:
			return ""


func _format_effect(effect: Dictionary) -> String:
	var stat := str(effect.get("stat", ""))
	var operation := str(effect.get("operation", ""))
	var value := effect.get("value", 0)
	if stat.is_empty():
		return str(effect)
	return "%s %s %s" % [stat, operation, str(value)]


func _on_select_button_pressed() -> void:
	selected.emit(offer_data.duplicate(true))
