extends PanelContainer
class_name RewardOption

signal selected(offer: Dictionary)
signal stat_preview_requested(offer: Dictionary)
signal stat_preview_cleared

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
var _bond_player: PlayerController = null

@onready var top_rarity_line: ColorRect = get_node_or_null("Content/TopRarityLine")
@onready var type_label: Label = get_node_or_null("Content/TypeLabel")
@onready var icon_texture: TextureRect = get_node_or_null("Content/IconFrame/IconTexture")
@onready var icon_placeholder: ColorRect = get_node_or_null("Content/IconFrame/IconPlaceholder")
@onready var name_label: Label = get_node_or_null("Content/NameLabel")
@onready var description_label: RichTextLabel = get_node_or_null("Content/DescriptionLabel")
@onready var bottom_rarity_line: ColorRect = get_node_or_null("Content/BottomRarityLine")
@onready var select_button: Button = get_node_or_null("Content/SelectButton")
var bond_tooltip: PanelContainer = null
var bond_tooltip_label: RichTextLabel = null


func _ready() -> void:
	if select_button != null:
		if not select_button.pressed.is_connected(_on_select_button_pressed):
			select_button.pressed.connect(_on_select_button_pressed)
		if not select_button.mouse_entered.is_connected(_on_select_button_mouse_entered):
			select_button.mouse_entered.connect(_on_select_button_mouse_entered)
		if not select_button.mouse_exited.is_connected(_on_select_button_mouse_exited):
			select_button.mouse_exited.connect(_on_select_button_mouse_exited)
	if not mouse_entered.is_connected(_on_card_mouse_entered):
		mouse_entered.connect(_on_card_mouse_entered)
	if not mouse_exited.is_connected(_on_card_mouse_exited):
		mouse_exited.connect(_on_card_mouse_exited)
	_refresh_visual()


func configure(offer: Dictionary, mode: String = ENTRY_FREE, explicit_cost: int = -1) -> void:
	offer_data = offer.duplicate(true)
	entry_mode = mode
	_refresh_visual(explicit_cost)


func set_bond_player(player: PlayerController) -> void:
	_bond_player = player


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
	return str(offer.get("description", ""))


func _on_card_mouse_entered() -> void:
	_show_bond_tooltip()


func _on_card_mouse_exited() -> void:
	_hide_bond_tooltip()


func _show_bond_tooltip() -> void:
	var bond_text := BondDisplay.build_item_bond_text(offer_data, _bond_player.relic_system if _bond_player != null else null)
	if bond_text.is_empty():
		_hide_bond_tooltip()
		return
	_ensure_bond_tooltip()
	if bond_tooltip == null or bond_tooltip_label == null:
		return
	bond_tooltip_label.text = bond_text
	bond_tooltip.visible = true
	bond_tooltip.reset_size()
	var viewport_rect := get_viewport_rect()
	var target := global_position + Vector2(0, size.y + 6)
	if target.x + bond_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - bond_tooltip.size.x - 8, 0)
	if target.y + bond_tooltip.size.y > viewport_rect.size.y:
		target.y = maxf(global_position.y - bond_tooltip.size.y - 6, 0)
	bond_tooltip.global_position = target


func _hide_bond_tooltip() -> void:
	if bond_tooltip != null:
		bond_tooltip.visible = false


func _ensure_bond_tooltip() -> void:
	if bond_tooltip != null:
		return
	var layer := _get_tooltip_layer()
	if layer == null:
		return
	bond_tooltip = PanelContainer.new()
	bond_tooltip.name = "BondTooltip"
	bond_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bond_tooltip.z_index = 100
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	panel_style.border_color = Color(0.96, 0.84, 0.45, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	bond_tooltip.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	bond_tooltip.add_child(margin)
	bond_tooltip_label = RichTextLabel.new()
	bond_tooltip_label.bbcode_enabled = true
	bond_tooltip_label.fit_content = true
	bond_tooltip_label.scroll_active = false
	bond_tooltip_label.custom_minimum_size = Vector2(240, 0)
	margin.add_child(bond_tooltip_label)
	layer.add_child(bond_tooltip)


func _get_tooltip_layer() -> CanvasLayer:
	var current: Node = self
	while current != null:
		if current is CanvasLayer:
			return current as CanvasLayer
		current = current.get_parent()
	return null


func _exit_tree() -> void:
	if bond_tooltip != null and is_instance_valid(bond_tooltip):
		bond_tooltip.queue_free()
	bond_tooltip = null
	bond_tooltip_label = null


func _on_select_button_mouse_entered() -> void:
	stat_preview_requested.emit(offer_data.duplicate(true))


func _on_select_button_mouse_exited() -> void:
	stat_preview_cleared.emit()


func _on_select_button_pressed() -> void:
	selected.emit(offer_data.duplicate(true))
