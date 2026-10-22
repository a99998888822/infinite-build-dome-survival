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
const HUD_STYLE = preload("res://scripts/ui/reward_hud_style.gd")
const PALETTE = HUD_STYLE.PALETTE
# Native 1920x1080 canvas pixels. Window scaling belongs to GameRoot.
const MODAL_TOP_OFFSET: float = 128.0
const MODAL_BOTTOM_MARGIN: float = 24.0
const MODAL_SIDE_MARGIN: float = 48.0
const WEAPON_STRIP_TOP_OFFSET: float = 20.0
const WEAPON_STRIP_HEIGHT: float = 128.0
const WEAPON_STRIP_WIDTH: float = 880.0
const OFFER_LAYOUT_COLUMNS: int = 4
const OFFER_VISIBLE_ROWS: int = 2
const DRAWER_RESERVED_RIGHT: float = 496.0
const MAX_PANEL_SIZE := Vector2(1312.0, 896.0)
const PANEL_HORIZONTAL_PADDING: float = 48.0

var payload: Dictionary = {}
var _offer_cards: Array[RewardOption] = []
var _card_pool: Array[RewardOption] = []
var _submitted: bool = false
var _refreshing: bool = false
var _loadout: WeaponLoadout = null
var _bond_player: PlayerController = null
var _active_preview_offer_id: String = ""
var _safe_rect: Rect2 = Rect2()
var _panel_layout_size := Vector2.ZERO
var _show_tween: Tween = null
var _fit_queued := false

@onready var backdrop: ColorRect = get_node_or_null("Backdrop")
@onready var coin_particles: Control = get_node_or_null("CoinParticles")
@onready var weapon_strip: WeaponStrip = get_node_or_null("WeaponStrip")
@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleRow/TitleLabel")
@onready var gold_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SubtitleRow/GoldLabel")
@onready var offer_scroll: ScrollContainer = get_node_or_null("CenterContainer/MainPanel/Content/OfferScroll")
@onready var offer_grid: GridContainer = get_node_or_null("CenterContainer/MainPanel/Content/OfferScroll/OfferGrid")
@onready var error_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/ErrorLabel")
@onready var skip_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/Footer/SkipButton")
@onready var refresh_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/Footer/RefreshButton")


func _ready() -> void:
	L10n.locale_changed.connect(_refresh_visual)
	_apply_hud_style()
	if weapon_strip != null:
		weapon_strip.minimum_height_changed.connect(_layout_popup, CONNECT_DEFERRED)
	if skip_button != null and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if refresh_button != null and not refresh_button.pressed.is_connected(_on_refresh_pressed):
		refresh_button.pressed.connect(_on_refresh_pressed)
	if get_viewport() != null:
		var viewport_callable := Callable(self, "_on_viewport_resized")
		if not get_viewport().size_changed.is_connected(viewport_callable):
			get_viewport().size_changed.connect(viewport_callable)
	if offer_scroll != null:
		# Containers settle after the popup opens; refit against the final area.
		offer_scroll.resized.connect(_queue_fit_offer_grid)
		offer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		offer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		# Hovered cards grow slightly beyond their grid cell. Let the card's z_index
		# control overlap instead of clipping the enlarged edge at the scroll viewport.
		offer_scroll.clip_contents = false
	if offer_grid != null:
		offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_grid.columns = OFFER_LAYOUT_COLUMNS
		offer_grid.clip_contents = false
	_update_skip_button()
	_layout_popup()
	hide_popup()
	# Build the usual page during UI setup, before the first combat reward.
	if offer_grid != null:
		for index in OFFER_LAYOUT_COLUMNS:
			_create_card()
	_preload_reward_icons()
	_warm_popup_rendering.call_deferred()


func _apply_hud_style() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main_panel.add_theme_stylebox_override("panel", HUD_STYLE.skin(true, false, Vector4(24, 24, 24, 24)))
	title_label.add_theme_color_override("font_color", PALETTE.TEXT)
	title_label.add_theme_color_override("font_shadow_color", PALETTE.SHADOW)
	get_node("CenterContainer/MainPanel/Content/Divider").color = PALETTE.BORDER
	backdrop.color = Color(PALETTE.SHADOW, 0.78)
	for button in [skip_button, refresh_button]:
		HUD_STYLE.apply_button(button, Vector4(14, 7, 14, 7))
	if weapon_strip != null:
		weapon_strip.icon_slot_theme = HUD_STYLE.weapon_slot_theme()
		weapon_strip.get_node("StripPanel").add_theme_stylebox_override("panel", HUD_STYLE.skin(true, false, Vector4(2, 2, 2, 2)))
		weapon_strip.load_label.add_theme_color_override("font_color", PALETTE.TEXT)
		weapon_strip.weapon_tooltip.add_theme_stylebox_override("panel", HUD_STYLE.skin(true, false, Vector4.ZERO))
		weapon_strip.weapon_tooltip_label.add_theme_color_override("default_color", PALETTE.TEXT)
	var scrollbar := offer_scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", HUD_STYLE.inset())
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(state, HUD_STYLE.skin(false, state != "grabber", Vector4(6, 6, 6, 6)))


func _warm_popup_rendering() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Draw the actual modal's fonts and panels during UI startup.
	# No scripts/signals on the duplicate: it cannot run a second shop or warmup.
	var preview := duplicate(0) as Control
	var viewport := SubViewport.new()
	viewport.size = Vector2i(get_viewport_rect().size)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(preview)
	preview.show()
	preview.get_node("Backdrop").show()
	var card := REWARD_OPTION_SCENE.instantiate() as RewardOption
	preview.get_node("CenterContainer/MainPanel/Content/OfferScroll/OfferGrid").add_child(card)
	var records := DataRegistry.get_table("relics")
	if not records.is_empty():
		var offer: Dictionary = records[0].duplicate(true)
		offer["offer_type"] = "relic"
		card.configure(offer)
	card.set_available_size(298, 350)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.queue_free()


func _preload_reward_icons() -> void:
	# Request from the loading/menu phase; never start a synchronous batch in
	# the combat event that opens a reward. The shared cache retains completion.
	for table in ["weapons", "relics"]:
		for record: Dictionary in DataRegistry.get_table(table):
			FinanceUIStyle.request_item_icon(str(record.get("icon", "")))
	set_process(true)


func _process(_delta: float) -> void:
	if FinanceUIStyle.collect_item_icons():
		set_process(false)


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
		main_panel.scale = Vector2.ONE
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
	if weapon_strip != null:
		_show_tween.tween_property(weapon_strip, "modulate:a", 1.0, 0.24).set_delay(0.08)
	_refresh_visual()
	_set_cards_locked(false)


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


func reset_run() -> void:
	# The popup outlives battle scenes. Release the old run before a locale
	# refresh or the next run can reuse its rewards, player or weapon strip.
	hide_popup()
	payload.clear()
	for card in _card_pool:
		card.release_offer()
	# Keep the prepared first page across runs. Clearing the pool here undoes
	# startup preparation and makes the next combat reward build every card.
	while _card_pool.size() > OFFER_LAYOUT_COLUMNS:
		var card := _card_pool.pop_back() as RewardOption
		offer_grid.remove_child(card)
		card.queue_free()
	set_bond_player(null)
	set_loadout(null)


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
			return L10n.text("error.shop.insufficient_gold")
		"invalid_offer":
			return L10n.text("error.shop.invalid_offer")
		"purchase_failed":
			return L10n.text("error.shop.upgrade_failed")
		"shop_not_active":
			return L10n.text("error.shop.closed")
		"insufficient_gold_for_refresh":
			return L10n.text("error.shop.reroll_insufficient_gold")
		_:
			return L10n.text("error.shop.operation_failed")


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
		weapon_strip.set_loadout(_loadout, false, true)


func remove_offer(offer_id: String) -> void:
	if offer_id.is_empty():
		return
	for card in _offer_cards.duplicate():
		if not is_instance_valid(card) or str(card.offer_data.get("offer_id", "")) != offer_id:
			continue
		_spawn_coin_particles(card.get_global_rect().get_center())
		card.play_claim_animation(true)
		return


func get_mode() -> String:
	return str(payload.get("mode", ENTRY_FREE))


func _refresh_visual() -> void:
	var mode := get_mode()
	if title_label != null:
		title_label.text = str(payload.get("title", "ui.shop.upgrade_reward" if mode == ENTRY_FREE else "局内商店"))
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
		var card := _card_pool[index] if index < _card_pool.size() else _create_card()
		if card == null:
			continue
		card.configure(offer, RewardOption.ENTRY_SHOP if mode == ENTRY_SHOP else RewardOption.ENTRY_FREE)
		card.set_bond_player(_bond_player)
		card.show()
		_offer_cards.append(card)
		if visible:
			card.animate_in(index)
		index += 1
	_queue_fit_offer_grid()


func _update_gold_labels(_current_gold: int) -> void:
	if gold_label != null:
		var subtitle_row := gold_label.get_parent() as Control
		if subtitle_row != null:
			# Keep reward and shop title blocks at the same height. Gold remains
			# in the payload for purchase and refresh checks, but is not displayed.
			subtitle_row.visible = false


func _update_refresh_button() -> void:
	if refresh_button == null:
		return
	var refresh_cost := int(payload.get("refresh_cost", 0))
	var current_gold := int(payload.get("gold", 0))
	refresh_button.text = L10n.text("ui.shop.reroll_price") % refresh_cost if refresh_cost > 0 else "ui.common.reroll"
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
			card.release_offer()
	_offer_cards.clear()


func _create_card() -> RewardOption:
	var card := REWARD_OPTION_SCENE.instantiate() as RewardOption
	if card == null:
		return null
	card.hide()
	offer_grid.add_child(card)
	card.set_available_height(RewardOption.COMPACT_MINIMUM_HEIGHT)
	card.set_fill_width(false)
	card.selected.connect(_on_offer_selected)
	card.stat_preview_requested.connect(_on_card_stat_preview_requested)
	card.stat_preview_cleared.connect(_on_card_stat_preview_cleared.bind(card))
	_card_pool.append(card)
	return card


func set_loadout(loadout: WeaponLoadout) -> void:
	_loadout = loadout
	if weapon_strip != null:
		weapon_strip.set_loadout(loadout, false, true)


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
	var strip_height := maxf(WEAPON_STRIP_HEIGHT, weapon_strip.get_required_height() if weapon_strip != null else WEAPON_STRIP_HEIGHT)
	var modal_top := maxf(MODAL_TOP_OFFSET, WEAPON_STRIP_TOP_OFFSET + strip_height + 16.0)
	center_container.anchor_left = 0.0
	center_container.anchor_top = 0.0
	center_container.anchor_right = 0.0
	center_container.anchor_bottom = 0.0
	# A hovered card is intentionally drawn slightly beyond its layout bounds.
	center_container.clip_contents = false
	var panel_width := floorf(minf(maxf(safe.size.x - MODAL_SIDE_MARGIN * 2.0, 0.0), MAX_PANEL_SIZE.x))
	var panel_height := floorf(minf(maxf(safe.size.y - modal_top - MODAL_BOTTOM_MARGIN, 0.0), MAX_PANEL_SIZE.y))
	center_container.position = Vector2(safe.position.x + (safe.size.x - panel_width) * 0.5, safe.position.y + modal_top).round()
	_panel_layout_size = Vector2(panel_width, panel_height)
	center_container.size = _panel_layout_size
	if offer_scroll != null:
		var content_width := maxf(panel_width - PANEL_HORIZONTAL_PADDING, 0.0)
		offer_scroll.custom_minimum_size = Vector2(content_width, 0.0)
		if content != null:
			content.custom_minimum_size.x = content_width
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
		var strip_width := minf(WEAPON_STRIP_WIDTH, maxf(safe.size.x - 32.0, 0.0))
		weapon_strip.anchor_left = 0.0
		weapon_strip.anchor_top = 0.0
		weapon_strip.anchor_right = 0.0
		weapon_strip.anchor_bottom = 0.0
		weapon_strip.position = Vector2(safe.position.x + (safe.size.x - strip_width) * 0.5, safe.position.y + WEAPON_STRIP_TOP_OFFSET).round()
		weapon_strip.size = Vector2(strip_width, strip_height)
	_queue_fit_offer_grid()


func _queue_fit_offer_grid() -> void:
	# Safe-rect, show and resize notifications often arrive together. Fit once
	# after them; a later container resize still schedules another settled fit.
	if _fit_queued:
		return
	_fit_queued = true
	_fit_offer_grid.call_deferred()


func _fit_offer_grid() -> void:
	_fit_queued = false
	if offer_scroll == null or offer_grid == null or not is_instance_valid(offer_grid):
		return
	var scroll_width := offer_scroll.size.x
	if _panel_layout_size.x > 0.0:
		# Keep the grid inside the panel's content width. Using the current
		# scroll width alone can create a self-reinforcing oversized minimum.
		var panel_content_width := maxf(_panel_layout_size.x - PANEL_HORIZONTAL_PADDING, 0.0)
		scroll_width = panel_content_width if not is_visible_in_tree() or scroll_width <= 0.0 else minf(scroll_width, panel_content_width)
	if scroll_width <= 0.0:
		return
	var cards: Array[RewardOption] = []
	for child in offer_grid.get_children():
		if child is RewardOption:
			cards.append(child as RewardOption)
	if cards.is_empty():
		return
	# Preserve the established four-column, two-row page even with fewer offers.
	# Empty slots must not enlarge or reposition the remaining reward cards.
	offer_grid.columns = OFFER_LAYOUT_COLUMNS
	var separation := float(offer_grid.get_theme_constant("h_separation"))
	var row_separation := float(offer_grid.get_theme_constant("v_separation"))
	var slot_width := maxf(floorf((scroll_width - separation * float(OFFER_LAYOUT_COLUMNS - 1)) / float(OFFER_LAYOUT_COLUMNS)), 0.0)
	var available_height := offer_scroll.size.y
	if not is_visible_in_tree() or available_height <= 0.0:
		available_height = _get_prepared_offer_height()
	var card_height := maxf(floorf((available_height - row_separation * float(OFFER_VISIBLE_ROWS - 1)) / float(OFFER_VISIBLE_ROWS)), 0.0)
	for card in cards:
		card.set_available_size(slot_width, card_height)
		card.set_layout_width(slot_width)
	offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The scroll container supplies the width. Do not feed the current width
	# back into the panel's minimum-size calculation.
	offer_grid.custom_minimum_size.x = 0.0
	# A previous card density can temporarily enlarge the CenterContainer's
	# minimum. Restore the requested bounds after new card minima propagate.
	center_container.set_deferred("size", _panel_layout_size)
	center_container.queue_sort()


func _get_prepared_offer_height() -> float:
	# Hidden containers have not settled their rectangles yet. Prepare the
	# pooled cards from the requested panel bounds and the actual fixed rows,
	# rather than treating an initial zero-height scroll area as a tiny screen.
	# Once visible, _fit_offer_grid uses the real container result as before.
	if main_panel == null or content == null:
		return 0.0
	var height := _panel_layout_size.y - main_panel.get_theme_stylebox("panel").get_minimum_size().y
	var fixed_rows := 0
	for child in content.get_children():
		if not child is Control or child == offer_scroll or child == error_label or not child.visible or child.is_set_as_top_level():
			continue
		height -= child.get_combined_minimum_size().y
		fixed_rows += 1
	# Each fixed row adds one separation alongside the expanding scroll row.
	# Opening always clears the previous purchase error before fitting.
	height -= float(content.get_theme_constant("separation") * fixed_rows)
	return maxf(height, 0.0)


func _build_fallback_safe_rect(viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := 16.0
	var right := minf(DRAWER_RESERVED_RIGHT, viewport_size.x * 0.30)
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


func _spawn_coin_particles(source_position: Vector2) -> void:
	if get_mode() != ENTRY_SHOP or coin_particles == null or title_label == null:
		return
	var target := title_label.get_global_rect().get_center()
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
