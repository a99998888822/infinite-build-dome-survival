extends PanelContainer
class_name RewardOption

signal selected(offer: Dictionary)
signal stat_preview_requested(offer: Dictionary)
signal stat_preview_cleared

const ENTRY_FREE: String = "free"
const ENTRY_SHOP: String = "shop"
const COIN_TEXTURE: Texture2D = preload("res://assets/ui/finance/finance_coin.svg")
const NORMAL_MINIMUM_HEIGHT: float = 360.0
const COMPACT_MINIMUM_HEIGHT: float = 272.0
const SMALL_MINIMUM_HEIGHT: float = 156.0
const RELIC_ICON_SCALE := 0.75
const HUD_STYLE = preload("res://scripts/ui/reward_hud_style.gd")
const PALETTE = HUD_STYLE.PALETTE

const OFFER_TYPE_TITLES: Dictionary = {
	"weapon_upgrade": "武器升级",
	"new_weapon": "新武器",
	"relic": "遗物",
}

const RARITY_COLORS: Dictionary = {
	"common": Color("a5a69f"),
	"uncommon": Color("8fa990"),
	"rare": Color("7e9fb8"),
	"epic": Color("a28aae"),
	"mythic": Color("c2a174"),
	"legendary": Color("bf827a"),
}

var offer_data: Dictionary = {}
var entry_mode: String = ENTRY_FREE
var _bond_player: PlayerController = null
var _hovered: bool = false
var _button_hovered: bool = false
var _interaction_locked: bool = false
var _animation_tween: Tween = null
var _hover_tween: Tween = null
var _icon_float_tween: Tween = null
var _icon_float_base_offsets := Vector2.ZERO
var _compact_layout: bool = false
var _small_layout: bool = false
var _layout_width: float = 0.0
var _layout_height: float = 0.0

@onready var top_rarity_line: ColorRect = get_node_or_null("Content/TopRarityLine")
@onready var content: VBoxContainer = get_node_or_null("Content")
@onready var type_badge: PanelContainer = get_node_or_null("Content/IconFrame/IconOverlay/TypeBadge")
@onready var type_label: Label = get_node_or_null("Content/IconFrame/IconOverlay/TypeBadge/TypeLabel")
@onready var icon_frame: PanelContainer = get_node_or_null("Content/IconFrame")
@onready var icon_texture: TextureRect = get_node_or_null("Content/IconFrame/IconVisual/IconTexture")
@onready var icon_placeholder: ColorRect = get_node_or_null("Content/IconFrame/IconPlaceholder")
@onready var name_label: Label = get_node_or_null("Content/NameLabel")
@onready var description_label: RichTextLabel = get_node_or_null("Content/DescriptionLabel")
@onready var bottom_rarity_line: ColorRect = get_node_or_null("Content/BottomRarityLine")
@onready var select_button: Button = get_node_or_null("Content/SelectButton")
var bond_tooltip: PanelContainer = null
var bond_tooltip_label: RichTextLabel = null
var _rarity_label: Label
var _rarity_rule: ColorRect


func _ready() -> void:
	L10n.locale_changed.connect(_refresh_visual)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_create_rarity_marker()
	if select_button != null:
		if not select_button.pressed.is_connected(_on_select_button_pressed):
			select_button.pressed.connect(_on_select_button_pressed)
		if not select_button.mouse_entered.is_connected(_on_select_button_mouse_entered):
			select_button.mouse_entered.connect(_on_select_button_mouse_entered)
		if not select_button.mouse_exited.is_connected(_on_select_button_mouse_exited):
			select_button.mouse_exited.connect(_on_select_button_mouse_exited)
		select_button.focus_entered.connect(_update_interaction_style)
		select_button.focus_exited.connect(_update_interaction_style)
	if not mouse_entered.is_connected(_on_card_mouse_entered):
		mouse_entered.connect(_on_card_mouse_entered)
	if not mouse_exited.is_connected(_on_card_mouse_exited):
		mouse_exited.connect(_on_card_mouse_exited)
	_refresh_visual()


func _create_rarity_marker() -> void:
	var overlay := get_node("Content/IconFrame/IconOverlay")
	_rarity_label = Label.new()
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rarity_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rarity_label.offset_left = -110
	_rarity_label.offset_right = -8
	_rarity_label.offset_top = 5
	overlay.add_child(_rarity_label)
	_rarity_rule = ColorRect.new()
	_rarity_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_rule.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_rarity_rule.offset_top = -2
	overlay.add_child(_rarity_rule)


func configure(offer: Dictionary, mode: String = ENTRY_FREE, explicit_cost: int = -1) -> void:
	_reset_animation_state()
	offer_data = offer.duplicate(true)
	entry_mode = mode
	_hovered = false
	_button_hovered = false
	_interaction_locked = false
	_refresh_visual(explicit_cost)
	set_interaction_locked(false)


func release_offer() -> void:
	hide()
	_reset_animation_state()
	offer_data.clear()
	_bond_player = null
	set_interaction_locked(true)


func _reset_animation_state() -> void:
	for tween in [_animation_tween, _hover_tween]:
		if tween != null:
			tween.kill()
	_animation_tween = null
	_hover_tween = null
	_stop_icon_float()
	_hide_bond_tooltip()
	_hovered = false
	_button_hovered = false
	z_index = 0
	scale = Vector2.ONE
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_bond_player(player: PlayerController) -> void:
	_bond_player = player


func set_compact(compact: bool) -> void:
	_compact_layout = compact
	_small_layout = false
	_apply_layout_density()


func set_available_height(available_height: float) -> void:
	_layout_height = maxf(available_height, 0.0)
	_small_layout = available_height < COMPACT_MINIMUM_HEIGHT
	_compact_layout = available_height < NORMAL_MINIMUM_HEIGHT
	_apply_layout_density()


func set_available_size(available_width: float, available_height: float) -> void:
	_layout_height = maxf(available_height, 0.0)
	_small_layout = available_height < COMPACT_MINIMUM_HEIGHT or available_width < 180.0
	_compact_layout = available_height < NORMAL_MINIMUM_HEIGHT or available_width < 220.0
	_apply_layout_density()


func _apply_layout_density() -> void:
	if not offer_data.is_empty():
		_update_panel_style()
	if content != null:
		content.add_theme_constant_override("separation", 5 if _small_layout else (8 if _compact_layout else 10))
	if type_badge != null:
		type_badge.custom_minimum_size = Vector2(28.0, 12.0) if _small_layout else Vector2(48.0, 24.0)
	if type_label != null:
		type_label.add_theme_font_size_override("font_size", 9 if _small_layout else 14)
	if not offer_data.is_empty():
		var offer_type := str(offer_data.get("offer_type", ""))
		_update_type_style()
		_update_type_badge_layout(offer_type)
	if _rarity_label != null:
		_rarity_label.add_theme_font_size_override("font_size", 9 if _small_layout else 12)
	if icon_frame != null:
		icon_frame.custom_minimum_size.y = 50.0 if _small_layout else (112.0 if _compact_layout else 128.0)
		if icon_texture != null and FinanceUIStyle.is_native_relic_icon(icon_texture.texture):
			# Reserve space for the displayed icon, not its full source dimensions.
			icon_frame.custom_minimum_size.y = maxf(icon_frame.custom_minimum_size.y, ceilf(FinanceUIStyle.relic_icon_size(icon_texture.texture, RELIC_ICON_SCALE).y / 0.8) + 4.0)
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", _get_name_font_size())
	if description_label != null:
		description_label.add_theme_font_size_override("normal_font_size", 10 if _small_layout else 18)
		# Leave a little more room below the description so the action stays
		# visually clear while keeping the button higher in the card.
		description_label.custom_minimum_size.y = 28.0 if _small_layout else (76.0 if _compact_layout else 98.0)
	if select_button != null:
		select_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		select_button.custom_minimum_size = _get_select_button_size()
		select_button.add_theme_font_size_override("font_size", 10 if _small_layout else 18)
	_update_card_minimum_size()


func set_fill_width(fill_width: bool) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if fill_width else Control.SIZE_SHRINK_CENTER


func set_layout_width(width: float) -> void:
	_layout_width = maxf(width, 0.0)
	_update_card_minimum_size()


func _update_card_minimum_size() -> void:
	var base_width := 160.0 if _small_layout else (180.0 if _compact_layout else 220.0)
	var base_height := SMALL_MINIMUM_HEIGHT if _small_layout else (COMPACT_MINIMUM_HEIGHT if _compact_layout else NORMAL_MINIMUM_HEIGHT)
	# The popup owns the available width. Never let an extra card expand it.
	var width := _layout_width if _layout_width > 0.0 else base_width
	var height := _layout_height if _layout_height > 0.0 else base_height
	custom_minimum_size = Vector2(width, height)
	if select_button != null:
		select_button.custom_minimum_size = _get_select_button_size()


func _get_select_button_size() -> Vector2:
	var card_width := _layout_width if _layout_width > 0.0 else (160.0 if _small_layout else (180.0 if _compact_layout else 220.0))
	var content_width := maxf(card_width - (12.0 if _small_layout else 24.0), 0.0)
	return Vector2(floorf(content_width * 0.8), 19.2 if _small_layout else 36.0)


func set_interaction_locked(locked: bool) -> void:
	_interaction_locked = locked
	if select_button != null:
		select_button.disabled = locked


func animate_in(index: int = 0) -> void:
	if not is_inside_tree():
		return
	if _animation_tween != null:
		_animation_tween.kill()
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	_animation_tween = create_tween().set_parallel(true)
	_animation_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_property(self, "modulate:a", 1.0, 0.24).set_delay(index * 0.08)
	_animation_tween.tween_property(self, "scale", Vector2.ONE, 0.30).set_delay(index * 0.08)


func play_claim_animation(preserve_slot: bool = false) -> void:
	if _animation_tween != null:
		_animation_tween.kill()
	set_interaction_locked(true)
	if preserve_slot:
		# Keep this Control in the container so later purchases do not shift
		# the remaining offers into a different slot.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_tween = create_tween().set_parallel(true)
	_animation_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation_tween.tween_property(self, "modulate:a", 0.0, 0.20)
	_animation_tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.20)
	if not preserve_slot:
		_animation_tween.chain().tween_callback(queue_free)


func get_button_text_for_offer(offer: Dictionary, mode: String = ENTRY_FREE, explicit_cost: int = -1) -> String:
	if mode == ENTRY_FREE:
		return L10n.text("ui.common.select")
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
	if offer_data.is_empty():
		return
	var rarity := str(offer_data.get("rarity", "common"))
	var rarity_color := get_color_for_rarity(rarity)
	var offer_type := str(offer_data.get("offer_type", ""))
	_update_rarity_lines(rarity_color)
	if type_label != null:
		type_label.text = get_title_for_offer_type(offer_type)
	_update_type_badge_layout(offer_type)
	if name_label != null:
		name_label.text = L10n.record_text(offer_data, "display_name", str(offer_data.get("target_id", "")))
		name_label.add_theme_font_size_override("font_size", _get_name_font_size())
	if description_label != null:
		description_label.text = _build_description_text(offer_data)
	if select_button != null:
		select_button.text = get_button_text_for_offer(offer_data, entry_mode, explicit_cost)
		select_button.icon = COIN_TEXTURE if entry_mode == ENTRY_SHOP else null
		select_button.expand_icon = entry_mode == ENTRY_SHOP
		if entry_mode == ENTRY_SHOP:
			select_button.add_theme_constant_override("icon_max_width", 11)
		else:
			select_button.remove_theme_constant_override("icon_max_width")
		_update_button_style()
	_update_icon(str(offer_data.get("icon", "")))
	_update_interaction_style()


func _get_name_font_size() -> int:
	# Keep relic, new-weapon, and weapon-upgrade titles at the same visual size.
	return 10 if _small_layout else 18


func _is_highlighted() -> bool:
	return _hovered or (select_button != null and select_button.has_focus())


func _update_interaction_style() -> void:
	if offer_data.is_empty(): return
	_update_panel_style()
	_update_type_style()
	_update_button_style()
	var warm := _is_highlighted()
	if icon_frame != null: icon_frame.add_theme_stylebox_override("panel", HUD_STYLE.inset(warm))
	if name_label != null: name_label.add_theme_color_override("font_color", PALETTE.WARM_TEXT if warm else PALETTE.TEXT)
	if description_label != null: description_label.add_theme_color_override("default_color", PALETTE.WARM_TEXT if warm else PALETTE.TEXT)


func _update_panel_style() -> void:
	var padding := Vector4(6, 6, 6, 6) if _small_layout else Vector4(12, 14, 12, 12)
	add_theme_stylebox_override("panel", HUD_STYLE.skin(true, _is_highlighted(), padding))


func _update_type_style() -> void:
	if type_badge == null:
		return
	var style := HUD_STYLE.inset(_is_highlighted())
	style.content_margin_left = 2.0 if _small_layout else 8.0
	style.content_margin_top = 0.0 if _small_layout else 3.0
	style.content_margin_right = 2.0 if _small_layout else 8.0
	style.content_margin_bottom = 0.0 if _small_layout else 3.0
	type_badge.add_theme_stylebox_override("panel", style)
	if type_label != null:
		type_label.add_theme_color_override("font_color", PALETTE.WARM_ACTIVE if _is_highlighted() else PALETTE.MUTED)


func _update_type_badge_layout(offer_type: String) -> void:
	if type_badge == null:
		return
	var badge_width := 28.0
	if offer_type == "new_weapon":
		badge_width = 42.0
	elif offer_type == "weapon_upgrade":
		badge_width = 50.0
	if not _small_layout:
		badge_width = 48.0
		if offer_type == "new_weapon":
			badge_width = 80.0
		elif offer_type == "weapon_upgrade":
			badge_width = 96.0
	type_badge.offset_right = badge_width
	type_badge.custom_minimum_size.x = badge_width


func _update_button_style() -> void:
	if select_button == null:
		return
	HUD_STYLE.apply_button(select_button, Vector4(10, 0, 10, 0), _is_highlighted())


func _update_rarity_lines(rarity_color: Color) -> void:
	if top_rarity_line != null:
		top_rarity_line.color = rarity_color
	if bottom_rarity_line != null:
		bottom_rarity_line.color = rarity_color
	if _rarity_label != null:
		_rarity_label.text = L10n.text("rarity." + str(offer_data.get("rarity", "common")))
		_rarity_label.add_theme_color_override("font_color", rarity_color)
	if _rarity_rule != null: _rarity_rule.color = rarity_color


func _update_icon(icon_path: String) -> void:
	_stop_icon_float()
	var loaded_texture := FinanceUIStyle.item_icon(icon_path)
	if icon_texture != null:
		FinanceUIStyle.set_item_icon(icon_texture, loaded_texture, RELIC_ICON_SCALE)
		if not FinanceUIStyle.is_native_relic_icon(loaded_texture):
			# A reused card must restore the weapon's original inset layout.
			icon_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_texture.anchor_left = 0.1
			icon_texture.anchor_top = 0.1
			icon_texture.anchor_right = 0.9
			icon_texture.anchor_bottom = 0.9
		icon_texture.visible = loaded_texture != null
	if icon_placeholder != null:
		icon_placeholder.visible = loaded_texture == null
	_apply_layout_density()
	if loaded_texture != null:
		call_deferred("_start_icon_float")


func _start_icon_float() -> void:
	if icon_texture == null or not icon_texture.is_visible_in_tree() or offer_data.is_empty():
		return
	_stop_icon_float()
	var base_top := icon_texture.offset_top
	var base_bottom := icon_texture.offset_bottom
	_icon_float_base_offsets = Vector2(base_top, base_bottom)
	_icon_float_tween = create_tween()
	_icon_float_tween.set_loops()
	_icon_float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_icon_float_tween.tween_property(icon_texture, "offset_top", base_top - 2.5, 1.05)
	_icon_float_tween.parallel().tween_property(icon_texture, "offset_bottom", base_bottom - 2.5, 1.05)
	_icon_float_tween.tween_property(icon_texture, "offset_top", base_top + 2.5, 1.20)
	_icon_float_tween.parallel().tween_property(icon_texture, "offset_bottom", base_bottom + 2.5, 1.20)
	_icon_float_tween.tween_property(icon_texture, "offset_top", base_top, 1.05)
	_icon_float_tween.parallel().tween_property(icon_texture, "offset_bottom", base_bottom, 1.05)


func _stop_icon_float() -> void:
	if _icon_float_tween != null:
		_icon_float_tween.kill()
		_icon_float_tween = null
		if icon_texture != null:
			icon_texture.offset_top = _icon_float_base_offsets.x
			icon_texture.offset_bottom = _icon_float_base_offsets.y


func _build_description_text(offer: Dictionary) -> String:
	return L10n.source(str(offer.get("description", "")))


func _on_card_mouse_entered() -> void:
	_set_card_hovered(true)


func _on_card_mouse_exited() -> void:
	call_deferred("_refresh_card_hover_from_pointer")


func _refresh_card_hover_from_pointer() -> void:
	if not is_visible_in_tree() or offer_data.is_empty():
		return
	var pointer_inside := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	_set_card_hovered(pointer_inside)


func _set_card_hovered(hovered: bool) -> void:
	if _hovered == hovered:
		return
	if _interaction_locked and hovered:
		return
	_hovered = hovered
	_update_interaction_style()
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _hovered:
		z_index = 10
		pivot_offset = size * 0.5
		_hover_tween.tween_property(self, "scale", Vector2(1.025, 1.025), 0.12)
		_show_bond_tooltip()
		stat_preview_requested.emit(offer_data.duplicate(true))
	else:
		_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
		_hover_tween.tween_callback(func() -> void:
			if not _hovered:
				z_index = 0
		)
		_hide_bond_tooltip()
		call_deferred("_clear_stat_preview_if_not_hovered")


func _clear_stat_preview_if_not_hovered() -> void:
	if not _hovered and not _button_hovered:
		stat_preview_cleared.emit()


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
	var card_rect := get_global_rect()
	var target := Vector2(card_rect.position.x, card_rect.end.y + 6)
	if target.x + bond_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - bond_tooltip.size.x - 8, 0)
	if target.y + bond_tooltip.size.y > viewport_rect.size.y:
		target.y = maxf(card_rect.position.y - bond_tooltip.size.y - 6, 0)
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
	bond_tooltip.add_theme_stylebox_override("panel", HUD_STYLE.skin(true, false, Vector4.ZERO))
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
	bond_tooltip_label.add_theme_color_override("default_color", PALETTE.TEXT)
	bond_tooltip_label.custom_minimum_size = Vector2(240, 0)
	margin.add_child(bond_tooltip_label)
	layer.add_child(bond_tooltip)


func _get_tooltip_layer() -> CanvasLayer:
	return GameTooltipLayer.for_owner(self)


func _exit_tree() -> void:
	_stop_icon_float()
	if bond_tooltip != null and is_instance_valid(bond_tooltip):
		bond_tooltip.queue_free()
	bond_tooltip = null
	bond_tooltip_label = null


func _on_select_button_mouse_entered() -> void:
	if _interaction_locked:
		return
	_button_hovered = true
	_set_card_hovered(true)


func _on_select_button_mouse_exited() -> void:
	_button_hovered = false
	call_deferred("_refresh_card_hover_from_pointer")


func _on_select_button_pressed() -> void:
	if _interaction_locked:
		return
	selected.emit(offer_data.duplicate(true))
