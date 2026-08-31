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
const COIN_TEXTURE: Texture2D = preload("res://assets/ui/finance/finance_coin.svg")
const MODAL_TOP_OFFSET: float = 90.0
const MODAL_BOTTOM_MARGIN: float = 14.0
const MODAL_SIDE_MARGIN: float = 44.0
const WEAPON_STRIP_TOP_OFFSET: float = 12.0
const WEAPON_STRIP_HEIGHT: float = 62.0
const OFFER_LAYOUT_COLUMNS: int = 4
const OFFER_VISIBLE_ROWS: int = 2
const DRAWER_RESERVED_RIGHT: float = 336.0
const MAX_PANEL_HEIGHT: float = 620.0

var payload: Dictionary = {}
var _offer_cards: Array[RewardOption] = []
var _submitted: bool = false
var _refreshing: bool = false
var _loadout: WeaponLoadout = null
var _bond_player: PlayerController = null
var _active_preview_offer_id: String = ""
var _safe_rect: Rect2 = Rect2()
var _show_tween: Tween = null
var _scanline_overlay: TextureRect = null

@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var coin_particles: Control = get_node_or_null("CoinParticles")
@onready var weapon_strip: WeaponStrip = get_node_or_null("WeaponStrip")
@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleRow/TitleLabel")
@onready var gold_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SubtitleRow/GoldLabel")
@onready var offer_scroll: ScrollContainer = get_node_or_null("CenterContainer/MainPanel/Content/OfferScroll")
@onready var offer_grid: GridContainer = get_node_or_null("CenterContainer/MainPanel/Content/OfferScroll/OfferGrid")
@onready var error_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/ErrorLabel")
@onready var skip_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/Footer/SkipButton")
@onready var refresh_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/Footer/RefreshButton")


func _ready() -> void:
	_create_scanline_overlay()
	if skip_button != null and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if refresh_button != null and not refresh_button.pressed.is_connected(_on_refresh_pressed):
		refresh_button.pressed.connect(_on_refresh_pressed)
	if get_viewport() != null:
		var viewport_callable := Callable(self, "_on_viewport_resized")
		if not get_viewport().size_changed.is_connected(viewport_callable):
			get_viewport().size_changed.connect(viewport_callable)
	if offer_scroll != null:
		offer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		offer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if offer_grid != null:
		offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_grid.columns = OFFER_LAYOUT_COLUMNS
	_update_skip_button()
	_layout_popup()
	hide_popup()


func configure(next_payload: Dictionary) -> void:
	_clear_active_stat_preview()
	payload = next_payload.duplicate(true)
	_submitted = false
	_refreshing = false


func set_safe_rect(next_rect: Rect2) -> void:
	_safe_rect = next_rect
	_layout_popup()


func show_popup() -> void:
	_layout_popup()
	visible = true
	_submitted = false
	_refreshing = false
	if backdrop != null:
		backdrop.visible = true
	if main_panel != null:
		main_panel.pivot_offset = main_panel.size * 0.5
		main_panel.modulate.a = 0.0
		main_panel.scale = Vector2(0.96, 0.96)
	if weapon_strip != null:
		weapon_strip.modulate.a = 0.0
	if _show_tween != null:
		_show_tween.kill()
	_show_tween = create_tween().set_parallel(true)
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if backdrop != null:
		backdrop.modulate.a = 0.0
		_show_tween.tween_property(backdrop, "modulate:a", 1.0, 0.24)
	if main_panel != null:
		_show_tween.tween_property(main_panel, "modulate:a", 1.0, 0.28)
		_show_tween.tween_property(main_panel, "scale", Vector2.ONE, 0.32)
	if weapon_strip != null:
		_show_tween.tween_property(weapon_strip, "modulate:a", 1.0, 0.24).set_delay(0.08)
	_refresh_visual()
	_set_cards_locked(false)
	if weapon_strip != null and _loadout != null:
		weapon_strip.set_loadout(_loadout)


func hide_popup() -> void:
	if _show_tween != null:
		_show_tween.kill()
		_show_tween = null
	visible = false
	_submitted = false
	_refreshing = false
	_clear_active_stat_preview()
	_clear_cards()
	if backdrop != null:
		backdrop.visible = false
		backdrop.modulate.a = 1.0
	if main_panel != null:
		main_panel.modulate.a = 1.0
		main_panel.scale = Vector2.ONE


func show_error(reason: String) -> void:
	if error_label == null:
		return
	error_label.text = _translate_purchase_error(reason)
	error_label.visible = true
	var base_position := error_label.position
	var tween := create_tween()
	tween.tween_property(error_label, "position", base_position + Vector2(-4.0, 0.0), 0.04)
	tween.tween_property(error_label, "position", base_position + Vector2(4.0, 0.0), 0.08)
	tween.tween_property(error_label, "position", base_position, 0.06)


func _translate_purchase_error(reason: String) -> String:
	match reason:
		"insufficient_gold":
			return "购买失败  金币不足"
		"invalid_offer":
			return "购买失败  无效的选项"
		"purchase_failed":
			return "购买失败  升级未生效"
		"shop_not_active":
			return "购买失败  商店未开启"
		"insufficient_gold_for_refresh":
			return "刷新失败  金币不足"
		_:
			return "操作失败  请重试"


func reset_submission() -> void:
	_submitted = false
	_refreshing = false
	_set_cards_locked(false)
	_update_refresh_button()


func refresh_gold(current_gold: int) -> void:
	payload["gold"] = current_gold
	_update_gold_labels(current_gold)
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
		_spawn_coin_particles(card.get_global_rect().get_center())
		card.play_claim_animation()
		return


func get_mode() -> String:
	return str(payload.get("mode", ENTRY_FREE))


func _refresh_visual() -> void:
	var mode := get_mode()
	if title_label != null:
		title_label.text = "升级奖励" if mode == ENTRY_FREE else "局内商店"
	_update_gold_labels(int(payload.get("gold", 0)))
	if error_label != null:
		error_label.text = ""
		error_label.visible = false
	_update_refresh_button()
	_clear_cards()
	if offer_grid == null:
		return
	var index := 0
	for offer in payload.get("offers", []):
		if not (offer is Dictionary):
			continue
		var card := REWARD_OPTION_SCENE.instantiate() as RewardOption
		if card == null:
			continue
		offer_grid.add_child(card)
		card.configure(offer, RewardOption.ENTRY_SHOP if mode == ENTRY_SHOP else RewardOption.ENTRY_FREE)
		card.set_available_height(RewardOption.COMPACT_MINIMUM_HEIGHT)
		card.set_fill_width(false)
		card.set_bond_player(_bond_player)
		card.selected.connect(_on_offer_selected)
		card.stat_preview_requested.connect(_on_card_stat_preview_requested)
		card.stat_preview_cleared.connect(_on_card_stat_preview_cleared.bind(card))
		_offer_cards.append(card)
		if visible:
			card.animate_in(index)
		index += 1
	call_deferred("_fit_offer_grid")


func _update_gold_labels(current_gold: int) -> void:
	if gold_label != null:
		var show_gold := get_mode() == ENTRY_SHOP
		var subtitle_row := gold_label.get_parent() as Control
		if subtitle_row != null:
			subtitle_row.visible = show_gold
		if show_gold:
			gold_label.text = "金币 %d" % current_gold


func _update_refresh_button() -> void:
	if refresh_button == null:
		return
	var refresh_cost := int(payload.get("refresh_cost", 0))
	var current_gold := int(payload.get("gold", 0))
	refresh_button.text = "刷新 ￥%d" % refresh_cost if refresh_cost > 0 else "刷新"
	refresh_button.disabled = _submitted or _refreshing or refresh_cost <= 0 or current_gold < refresh_cost


func _on_offer_selected(offer: Dictionary) -> void:
	if _submitted:
		return
	_submitted = true
	var selected_id := str(offer.get("offer_id", ""))
	for card in _offer_cards:
		if not is_instance_valid(card):
			continue
		if str(card.offer_data.get("offer_id", "")) == selected_id:
			card.set_interaction_locked(true)
	_clear_active_stat_preview()
	offer_selected.emit(offer.duplicate(true))


func _on_card_stat_preview_requested(offer: Dictionary) -> void:
	if _submitted:
		return
	_active_preview_offer_id = str(offer.get("offer_id", ""))
	stat_preview_requested.emit(offer)


func _on_card_stat_preview_cleared(card: RewardOption) -> void:
	if _submitted or not is_instance_valid(card):
		return
	var offer_id := str(card.offer_data.get("offer_id", ""))
	if offer_id.is_empty() or offer_id != _active_preview_offer_id:
		return
	_clear_active_stat_preview()


func _clear_active_stat_preview() -> void:
	if _active_preview_offer_id.is_empty():
		return
	_active_preview_offer_id = ""
	stat_preview_cleared.emit()


func _on_skip_pressed() -> void:
	if _submitted:
		return
	_submitted = true
	_set_cards_locked(true)
	skipped.emit()


func _on_refresh_pressed() -> void:
	if _submitted or _refreshing:
		return
	_refreshing = true
	_update_refresh_button()
	refresh_requested.emit()


func _set_cards_locked(locked: bool) -> void:
	for card in _offer_cards:
		if is_instance_valid(card):
			card.set_interaction_locked(locked)
	_update_skip_button()
	_update_refresh_button()


func _update_skip_button() -> void:
	if skip_button == null:
		return
	# Skipping is always a valid exit from either reward or shop selection.
	skip_button.disabled = false
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.z_index = 2


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
	for card in _offer_cards:
		if is_instance_valid(card):
			card.set_bond_player(player)


func _on_viewport_resized() -> void:
	_layout_popup()


func _layout_popup() -> void:
	if center_container == null or get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := _get_layout_safe_rect(viewport_size)
	center_container.anchor_left = 0.0
	center_container.anchor_top = 0.0
	center_container.anchor_right = 0.0
	center_container.anchor_bottom = 0.0
	center_container.clip_contents = true
	var panel_width := minf(maxf(safe.size.x - MODAL_SIDE_MARGIN * 2.0, 0.0), 980.0)
	var panel_height := minf(maxf(safe.size.y - MODAL_TOP_OFFSET - MODAL_BOTTOM_MARGIN, 0.0), MAX_PANEL_HEIGHT)
	center_container.position = Vector2(safe.position.x + (safe.size.x - panel_width) * 0.5, safe.position.y + MODAL_TOP_OFFSET)
	center_container.size = Vector2(panel_width, panel_height)
	if offer_scroll != null:
		offer_scroll.custom_minimum_size.y = 0.0
	if main_panel != null:
		main_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	if backdrop != null:
		backdrop.anchor_left = 0.0
		backdrop.anchor_top = 0.0
		backdrop.anchor_right = 0.0
		backdrop.anchor_bottom = 0.0
		backdrop.position = Vector2.ZERO
		backdrop.size = Vector2(safe.end.x, viewport_size.y)
	if weapon_strip != null:
		var strip_width := minf(560.0, maxf(safe.size.x - 32.0, 0.0))
		weapon_strip.anchor_left = 0.0
		weapon_strip.anchor_top = 0.0
		weapon_strip.anchor_right = 0.0
		weapon_strip.anchor_bottom = 0.0
		weapon_strip.position = Vector2(safe.position.x + (safe.size.x - strip_width) * 0.5, safe.position.y + WEAPON_STRIP_TOP_OFFSET)
		weapon_strip.size = Vector2(strip_width, WEAPON_STRIP_HEIGHT)
	call_deferred("_fit_offer_grid")


func _fit_offer_grid() -> void:
	if offer_scroll == null or offer_grid == null or not is_instance_valid(offer_grid):
		return
	var scroll_width := offer_scroll.size.x
	if center_container != null and center_container.size.x > 0.0:
		# Keep the grid inside the panel's content width. Using the current
		# scroll width alone can create a self-reinforcing oversized minimum.
		var panel_content_width := maxf(center_container.size.x - 52.0, 0.0)
		scroll_width = panel_content_width if scroll_width <= 0.0 else minf(scroll_width, panel_content_width)
	if scroll_width <= 0.0:
		return
	var cards: Array[RewardOption] = []
	for child in offer_grid.get_children():
		if child is RewardOption:
			cards.append(child as RewardOption)
	if cards.is_empty():
		return
	var separation := float(offer_grid.get_theme_constant("h_separation"))
	var row_separation := float(offer_grid.get_theme_constant("v_separation"))
	var slot_width := maxf((scroll_width - separation * float(OFFER_LAYOUT_COLUMNS - 1)) / float(OFFER_LAYOUT_COLUMNS), 0.0)
	var available_height := offer_scroll.size.y
	var card_height := maxf((available_height - row_separation * float(OFFER_VISIBLE_ROWS - 1)) / float(OFFER_VISIBLE_ROWS), 0.0)
	for card in cards:
		card.set_available_size(slot_width, card_height)
		card.set_layout_width(slot_width)
	offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The scroll container supplies the width. Do not feed the current width
	# back into the panel's minimum-size calculation.
	offer_grid.custom_minimum_size.x = 0.0
	center_container.queue_sort()


func _build_fallback_safe_rect(viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := 16.0
	var right := minf(336.0, viewport_size.x * 0.30)
	var top := 16.0
	var bottom := 16.0
	var safe_left := clampf(left, 0.0, viewport_size.x)
	var safe_top := clampf(top, 0.0, viewport_size.y)
	var safe_right := clampf(right, 0.0, viewport_size.x - safe_left)
	return Rect2(Vector2(safe_left, safe_top), Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - bottom, 0.0)))


func _get_layout_safe_rect(viewport_size: Vector2) -> Rect2:
	var safe := _safe_rect
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = _build_fallback_safe_rect(viewport_size)
	if viewport_size.x <= 0.0:
		return safe
	# The stats drawer is above the shop layer, so reserve its full width even
	# if the controller has not received the drawer animation's latest rect yet.
	var reserved_right := minf(DRAWER_RESERVED_RIGHT, viewport_size.x * 0.30)
	var maximum_end_x := viewport_size.x - reserved_right
	if safe.end.x > maximum_end_x:
		safe.size.x = maxf(maximum_end_x - safe.position.x, 0.0)
	return safe


func _is_compact_layout() -> bool:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ZERO
	var safe := _get_layout_safe_rect(viewport_size)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return true
	return safe.size.x < 760.0 or safe.size.y < 620.0


func _create_scanline_overlay() -> void:
	if _scanline_overlay != null:
		return
	var scanline_image := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	scanline_image.fill(Color.TRANSPARENT)
	scanline_image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.08))
	scanline_image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 0.08))
	_scanline_overlay = TextureRect.new()
	_scanline_overlay.texture = ImageTexture.create_from_image(scanline_image)
	_scanline_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_scanline_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scanline_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scanline_overlay.stretch_mode = TextureRect.STRETCH_TILE
	_scanline_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scanline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanline_overlay.z_index = 1
	add_child(_scanline_overlay)


func _spawn_coin_particles(source_position: Vector2) -> void:
	if get_mode() != ENTRY_SHOP or coin_particles == null or gold_label == null:
		return
	var target := gold_label.get_global_rect().get_center()
	for index in range(7):
		var coin := TextureRect.new()
		coin.texture = COIN_TEXTURE
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(14.0, 14.0)
		coin.position = source_position - Vector2(7.0, 7.0)
		coin.modulate.a = 0.0
		coin_particles.add_child(coin)
		var offset := Vector2(randf_range(-34.0, 34.0), randf_range(-44.0, -12.0))
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "modulate:a", 1.0, 0.08).set_delay(index * 0.025)
		tween.tween_property(coin, "position", source_position + offset - Vector2(7.0, 7.0), 0.26).set_delay(index * 0.025)
		tween.chain().tween_property(coin, "position", target - Vector2(7.0, 7.0), 0.36)
		tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.16).set_delay(0.48 + index * 0.025)
		tween.tween_callback(coin.queue_free)
