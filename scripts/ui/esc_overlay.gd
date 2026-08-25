extends Control
class_name EscOverlay

signal back_pressed

const RELIC_GRID_COLUMNS: int = 6
const RELIC_CELL_SIZE: Vector2 = Vector2(64, 64)
const MODAL_SAFE_EDGE_MARGIN: float = 16.0
const MODAL_FALLBACK_TOP: float = 16.0
const MODAL_FALLBACK_RIGHT: float = 336.0
const MODAL_TOP_OFFSET: float = 90.0
const MODAL_BOTTOM_MARGIN: float = 14.0
const WEAPON_STRIP_TOP_OFFSET: float = 12.0
const WEAPON_STRIP_HEIGHT: float = 62.0
const RARITY_ORDER: Array[String] = ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
const RARITY_COLORS: Dictionary = {
	"common": Color(0.86, 0.86, 0.86, 1.0),
	"uncommon": Color(0.35, 0.92, 0.45, 1.0),
	"rare": Color(0.35, 0.62, 1.0, 1.0),
	"epic": Color(0.72, 0.42, 1.0, 1.0),
	"mythic": Color(1.0, 0.58, 0.22, 1.0),
	"legendary": Color(1.0, 0.24, 0.22, 1.0),
}

var _player: PlayerController = null
var _relic_cells: Array[Control] = []
var _item_cards: Array[Control] = []
var _relic_tweens: Dictionary = {}
var _relic_pulse_tweens: Dictionary = {}
var _backdrop: ColorRect = null
var _show_tween: Tween = null

@onready var weapon_strip: WeaponStrip = get_node_or_null("WeaponStrip")
@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var relic_grid: GridContainer = get_node_or_null("CenterContainer/RelicPanel/Content/RelicScroll/RelicGrid")
@onready var total_label: Label = get_node_or_null("CenterContainer/RelicPanel/Content/TitleRow/TotalLabel")
@onready var back_button: Button = get_node_or_null("CenterContainer/RelicPanel/Content/TitleRow/BackButton")
@onready var relic_tooltip: PanelContainer = get_node_or_null("RelicTooltip")
@onready var relic_tooltip_label: RichTextLabel = get_node_or_null("RelicTooltip/TooltipMargin/TooltipLabel")
@onready var item_grid: GridContainer = get_node_or_null("CenterContainer/RelicPanel/Content/ItemScroll/ItemGrid")
@onready var item_total_label: Label = get_node_or_null("CenterContainer/RelicPanel/Content/ItemTitleRow/ItemTotalLabel")


func _ready() -> void:
	_ensure_backdrop()
	if back_button != null and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if relic_grid != null:
		relic_grid.columns = RELIC_GRID_COLUMNS
	if item_grid != null:
		item_grid.columns = 4
	if get_viewport() != null:
		var viewport_callable := Callable(self, "_on_viewport_resized")
		if not get_viewport().size_changed.is_connected(viewport_callable):
			get_viewport().size_changed.connect(viewport_callable)
	_layout_overlay()


func show_overlay() -> void:
	_layout_overlay()
	visible = true
	if center_container == null:
		return
	center_container.pivot_offset = center_container.size * 0.5
	center_container.modulate.a = 0.0
	center_container.scale = Vector2(0.96, 0.96)
	if weapon_strip != null:
		weapon_strip.modulate.a = 0.0
	if _backdrop != null:
		_backdrop.modulate.a = 0.0
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _backdrop != null:
		_show_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.20)
	_show_tween.parallel().tween_property(center_container, "modulate:a", 1.0, 0.24)
	_show_tween.parallel().tween_property(center_container, "scale", Vector2.ONE, 0.32)
	if weapon_strip != null:
		_show_tween.parallel().tween_property(weapon_strip, "modulate:a", 1.0, 0.22).set_delay(0.10)
	if AudioManager != null:
		AudioManager.play_ui_sfx("modal_open")


func hide_overlay() -> void:
	if not visible:
		return
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _backdrop != null:
		_show_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.16)
	if center_container != null:
		_show_tween.parallel().tween_property(center_container, "modulate:a", 0.0, 0.16)
	_show_tween.tween_callback(func() -> void:
		visible = false
		if center_container != null:
			center_container.modulate.a = 1.0
			center_container.scale = Vector2.ONE
		if weapon_strip != null:
			weapon_strip.modulate.a = 1.0
	)


func _ensure_backdrop() -> void:
	if _backdrop != null:
		return
	_backdrop = ColorRect.new()
	_backdrop.name = "EscBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.01, 0.015, 0.02, 0.82)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = -5
	add_child(_backdrop)
	move_child(_backdrop, 0)


func configure(player: PlayerController, loadout: WeaponLoadout) -> void:
	_player = player
	if weapon_strip != null:
		weapon_strip.set_loadout(loadout, true)
	if is_instance_valid(_player) and _player.get_item_inventory() != null:
		var inventory := _player.get_item_inventory()
		if not inventory.items_changed.is_connected(_on_item_inventory_changed):
			inventory.items_changed.connect(_on_item_inventory_changed)
	_refresh_relic_list()
	_refresh_item_list()


func _on_item_inventory_changed() -> void:
	_refresh_item_list()


func _refresh_item_list() -> void:
	for card in _item_cards:
		if is_instance_valid(card):
			card.queue_free()
	_item_cards.clear()
	if item_grid == null:
		return
	var items: Array[Dictionary] = []
	if is_instance_valid(_player) and _player.get_item_inventory() != null:
		items = _player.get_item_inventory().get_items()
	for item in items:
		var card := preload("res://scripts/ui/item_inventory_card.gd").new() as ItemInventoryCard
		if card == null:
			continue
		card.configure(item, true)
		item_grid.add_child(card)
		_item_cards.append(card)
	if item_total_label != null:
		item_total_label.text = "共 %d 件" % items.size()


func _on_viewport_resized() -> void:
	_layout_overlay()


func _layout_overlay() -> void:
	if get_viewport() == null:
		return
	var safe := _get_modal_safe_rect()
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return
	if center_container != null:
		center_container.anchor_left = 0.0
		center_container.anchor_top = 0.0
		center_container.anchor_right = 0.0
		center_container.anchor_bottom = 0.0
		center_container.position = safe.position + Vector2(0.0, MODAL_TOP_OFFSET)
		center_container.size = Vector2(safe.size.x, minf(460.0, maxf(safe.size.y - MODAL_TOP_OFFSET - MODAL_BOTTOM_MARGIN, 0.0)))
	if _backdrop != null:
		_backdrop.anchor_left = 0.0
		_backdrop.anchor_top = 0.0
		_backdrop.anchor_right = 0.0
		_backdrop.anchor_bottom = 0.0
		_backdrop.position = Vector2.ZERO
		_backdrop.size = Vector2(safe.end.x, get_viewport().get_visible_rect().size.y)
	if weapon_strip != null:
		var strip_width := minf(560.0, maxf(safe.size.x - 32.0, 0.0))
		weapon_strip.anchor_left = 0.0
		weapon_strip.anchor_top = 0.0
		weapon_strip.anchor_right = 0.0
		weapon_strip.anchor_bottom = 0.0
		weapon_strip.position = Vector2(safe.position.x + (safe.size.x - strip_width) * 0.5, safe.position.y + WEAPON_STRIP_TOP_OFFSET)
		weapon_strip.size = Vector2(strip_width, WEAPON_STRIP_HEIGHT)


func _get_modal_safe_rect() -> Rect2:
	var battle_hud := get_node_or_null("../../HUD") as BattleHud
	if battle_hud != null and battle_hud.has_method("get_modal_safe_rect"):
		return battle_hud.get_modal_safe_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var safe_left := MODAL_SAFE_EDGE_MARGIN
	var safe_top := minf(MODAL_FALLBACK_TOP, viewport_size.y * 0.18)
	var safe_right := minf(MODAL_FALLBACK_RIGHT, viewport_size.x * 0.30)
	return Rect2(Vector2(safe_left, safe_top), Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - MODAL_SAFE_EDGE_MARGIN, 0.0)))


func _on_back_pressed() -> void:
	if AudioManager != null:
		AudioManager.play_ui_sfx("modal_close")
	back_pressed.emit()


func _refresh_relic_list() -> void:
	for cell in _relic_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	_relic_cells.clear()
	_relic_tweens.clear()
	for pulse in _relic_pulse_tweens.values():
		if pulse is Tween and pulse.is_valid():
			pulse.kill()
	_relic_pulse_tweens.clear()
	if relic_grid == null:
		return
	var counts := _player.get_relic_counts() if _player != null else {}
	var relic_ids: Array[String] = []
	for relic_id_variant in counts.keys():
		var relic_id := str(relic_id_variant)
		if int(counts[relic_id_variant]) > 0:
			relic_ids.append(relic_id)
	relic_ids.sort_custom(Callable(self, "_compare_relics"))
	var total := 0
	for relic_id in relic_ids:
		var count := int(counts[relic_id])
		total += count
		relic_grid.add_child(_create_relic_cell(relic_id, count))
	if total_label != null:
		total_label.text = "共 %d 个" % total


func _compare_relics(a: String, b: String) -> bool:
	var data_a := DataRegistry.get_record("relics", a)
	var data_b := DataRegistry.get_record("relics", b)
	var rank_a := RARITY_ORDER.find(str(data_a.get("rarity", "common")))
	var rank_b := RARITY_ORDER.find(str(data_b.get("rarity", "common")))
	if rank_a != rank_b:
		return rank_a < rank_b
	return str(data_a.get("display_name", a)) < str(data_b.get("display_name", b))


func _create_relic_cell(relic_id: String, count: int) -> Control:
	var relic_data := DataRegistry.get_record("relics", relic_id)
	var rarity := str(relic_data.get("rarity", "common"))
	var display_name := str(relic_data.get("display_name", relic_id))
	var cell := Button.new()
	cell.flat = true
	cell.custom_minimum_size = RELIC_CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon_path := str(relic_data.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var texture := load(icon_path)
		if texture is Texture2D:
			var icon_rect := TextureRect.new()
			icon_rect.texture = texture
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.anchor_left = 0.1
			icon_rect.anchor_top = 0.1
			icon_rect.anchor_right = 0.9
			icon_rect.anchor_bottom = 0.9
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon_rect)
	else:
		var placeholder := PanelContainer.new()
		placeholder.anchor_left = 0.1
		placeholder.anchor_top = 0.1
		placeholder.anchor_right = 0.9
		placeholder.anchor_bottom = 0.9
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
		style.set_corner_radius_all(6)
		placeholder.add_theme_stylebox_override("panel", style)
		cell.add_child(placeholder)
		var name_label := Label.new()
		name_label.text = display_name.substr(0, 1)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.06, 1.0))
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_child(name_label)
	if count > 1:
		var badge := Label.new()
		badge.text = str(count)
		badge.anchor_left = 1.0
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.offset_left = -20.0
		badge.offset_top = -22.0
		badge.offset_right = -4.0
		badge.offset_bottom = -4.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_constant_override("outline_size", 3)
		badge.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06, 0.95))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(badge)
	cell.pivot_offset = RELIC_CELL_SIZE * 0.5
	cell.mouse_entered.connect(_on_relic_cell_hovered.bind(cell, relic_data))
	cell.mouse_exited.connect(_on_relic_cell_unhovered.bind(cell))
	_relic_cells.append(cell)
	if RARITY_ORDER.find(rarity) >= RARITY_ORDER.find("epic"):
		var pulse := create_tween().set_loops()
		pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(cell, "modulate", Color(1.08, 1.04, 0.92, 1.0), 1.2)
		pulse.tween_property(cell, "modulate", Color.WHITE, 1.2)
		_relic_pulse_tweens[cell] = pulse
	return cell


func _on_relic_cell_hovered(cell: Control, relic_data: Dictionary) -> void:
	if cell == null:
		return
	var old_tween: Tween = _relic_tweens.get(cell)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var rarity := str(relic_data.get("rarity", "common"))
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	cell.modulate = Color(1.12, 1.08, 0.94, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "scale", Vector2(1.08, 1.08), 0.12)
	_relic_tweens[cell] = tween
	_show_relic_tooltip(relic_data, cell)


func _on_relic_cell_unhovered(cell: Control) -> void:
	_hide_relic_tooltip()
	if cell == null:
		return
	var old_tween: Tween = _relic_tweens.get(cell)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(cell, "modulate", Color.WHITE, 0.12)
	_relic_tweens[cell] = tween


func _show_relic_tooltip(relic_data: Dictionary, anchor_cell: Control) -> void:
	if relic_tooltip == null or relic_tooltip_label == null:
		return
	var rarity := str(relic_data.get("rarity", "common"))
	var display_name := str(relic_data.get("display_name", ""))
	var description := str(relic_data.get("description", ""))
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var tooltip_text := "[color=%s]%s[/color]\n%s" % [_color_to_bbcode(rarity_color), display_name, description]
	var bond_text := BondDisplay.build_item_bond_text(relic_data, _player.relic_system if _player != null else null)
	if not bond_text.is_empty():
		tooltip_text += "\n" + bond_text
	relic_tooltip_label.text = tooltip_text
	relic_tooltip.visible = true
	relic_tooltip.reset_size()
	var viewport_rect := get_viewport_rect()
	var target := anchor_cell.global_position + Vector2(0, anchor_cell.size.y + 6)
	if target.x + relic_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - relic_tooltip.size.x - 8, 0)
	if target.y + relic_tooltip.size.y > viewport_rect.size.y:
		target.y = maxf(anchor_cell.global_position.y - relic_tooltip.size.y - 6, 0)
	relic_tooltip.global_position = target


func _hide_relic_tooltip() -> void:
	if relic_tooltip != null:
		relic_tooltip.visible = false


func _color_to_bbcode(color: Color) -> String:
	return "#%02X%02X%02X" % [int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0)]
