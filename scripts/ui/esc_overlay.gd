extends Control
class_name EscOverlay

signal back_pressed

const RELIC_GRID_COLUMNS: int = 6
const RELIC_CELL_SIZE: Vector2 = Vector2(64, 64)
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

@onready var weapon_strip: WeaponStrip = get_node_or_null("WeaponStrip")
@onready var relic_grid: GridContainer = get_node_or_null("CenterContainer/RelicPanel/Content/RelicScroll/RelicGrid")
@onready var total_label: Label = get_node_or_null("CenterContainer/RelicPanel/Content/TitleRow/TotalLabel")
@onready var back_button: Button = get_node_or_null("CenterContainer/RelicPanel/Content/TitleRow/BackButton")
@onready var relic_tooltip: PanelContainer = get_node_or_null("RelicTooltip")
@onready var relic_tooltip_label: RichTextLabel = get_node_or_null("RelicTooltip/TooltipMargin/TooltipLabel")


func _ready() -> void:
	if back_button != null and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if relic_grid != null:
		relic_grid.columns = RELIC_GRID_COLUMNS


func configure(player: PlayerController, loadout: WeaponLoadout) -> void:
	_player = player
	if weapon_strip != null:
		weapon_strip.set_loadout(loadout)
		weapon_strip.set_bond_player(player)
	_refresh_relic_list()


func _on_back_pressed() -> void:
	back_pressed.emit()


func _refresh_relic_list() -> void:
	for cell in _relic_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	_relic_cells.clear()
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
			icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon_rect)
	else:
		var placeholder := PanelContainer.new()
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	cell.mouse_entered.connect(_show_relic_tooltip.bind(relic_data, cell))
	cell.mouse_exited.connect(_hide_relic_tooltip)
	_relic_cells.append(cell)
	return cell


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
