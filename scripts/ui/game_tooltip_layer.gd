class_name GameTooltipLayer
extends CanvasLayer
## Custom tooltips share a viewport-space layer above drawers and modal panels.
## The layer belongs to its source UI and follows all of its ancestors' visibility.

const TOOLTIP_LAYER := 100
static var _pixel_font: FontFile
var _flow: MainFlowCoordinator
var _inside_utility := false


static func apply_pixel_text(control: Control) -> void:
	if _pixel_font == null:
		_pixel_font = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf").duplicate() as FontFile
		# Rasterize Ark on its native grid before scaling to the requested size.
		_pixel_font.fixed_size = 12
		_pixel_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
		_pixel_font.oversampling = 1.0
		_pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var keys := ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"] if control is RichTextLabel else ["font"]
	for key: String in keys: control.add_theme_font_override(key, _pixel_font)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func for_owner(source: Node) -> GameTooltipLayer:
	var existing := source.get_node_or_null("GameTooltipLayer") as GameTooltipLayer
	if existing != null: return existing
	var result := GameTooltipLayer.new()
	result.name = "GameTooltipLayer"
	result.layer = TOOLTIP_LAYER
	source.add_child(result)
	return result


func _ready() -> void:
	child_entered_tree.connect(_queue_tooltip_skin)
	L10n.locale_changed.connect(_clear_tooltips)
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CanvasItem or ancestor is CanvasLayer:
			ancestor.visibility_changed.connect(_sync_visibility)
		if ancestor is BattleUtilityOverlay: _inside_utility = true
		ancestor = ancestor.get_parent()
	_sync_visibility()
	_bind_flow.call_deferred()
	for child in get_children(): _queue_tooltip_skin(child)


func _queue_tooltip_skin(child: Node) -> void:
	# Owners finish building labels and applying their old overrides in this frame.
	# Apply once afterwards; reused hidden panels keep the same style.
	_skin_tooltip.call_deferred(child)


func _skin_tooltip(child: Node) -> void:
	if not is_instance_valid(child): return
	if child is Panel or child is PanelContainer:
		child.add_theme_stylebox_override("panel", PixelTooltipStyle.preserving(child.get_theme_stylebox("panel")))
	if child is Control:
		child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if child is Label:
			child.add_theme_color_override("font_color", PixelTooltipStyle.PALETTE.TEXT)
		elif child is RichTextLabel:
			child.add_theme_color_override("default_color", PixelTooltipStyle.PALETTE.TEXT)
	for nested in child.get_children(): _skin_tooltip(nested)


func _bind_flow() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is GameRoot:
			_flow = ancestor.get_main_flow_coordinator()
			_flow.state_changed.connect(_on_flow_changed)
			_sync_visibility()
			return
		ancestor = ancestor.get_parent()


func _on_flow_changed(_previous: String, _current: String) -> void:
	_clear_tooltips()
	_sync_visibility()


func _sync_visibility() -> void:
	# Settings retain the underlying finance/ESC widgets for their backdrop.
	var source_visible := _flow == null or _inside_utility or _flow.current_state != MainFlowCoordinator.STATE_BATTLE_UTILITY
	var ancestor := get_parent()
	while ancestor != null:
		if (ancestor is CanvasItem or ancestor is CanvasLayer) and not ancestor.visible:
			source_visible = false
			break
		ancestor = ancestor.get_parent()
	visible = source_visible
	# Closing and reopening a page must not resurrect an old hover tooltip.
	if not visible:
		_clear_tooltips()


func _clear_tooltips() -> void:
	for child in get_children():
		if child is CanvasItem: child.hide()
