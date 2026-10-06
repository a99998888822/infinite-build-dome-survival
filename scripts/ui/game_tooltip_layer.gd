class_name GameTooltipLayer
extends CanvasLayer
## Custom tooltips share a viewport-space layer above drawers and modal panels.
## The layer belongs to its source UI and follows all of its ancestors' visibility.

const TOOLTIP_LAYER := 100
var _flow: MainFlowCoordinator
var _inside_utility := false


static func for_owner(source: Node) -> GameTooltipLayer:
	var existing := source.get_node_or_null("GameTooltipLayer") as GameTooltipLayer
	if existing != null: return existing
	var result := GameTooltipLayer.new()
	result.name = "GameTooltipLayer"
	result.layer = TOOLTIP_LAYER
	source.add_child(result)
	return result


func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CanvasItem or ancestor is CanvasLayer:
			ancestor.visibility_changed.connect(_sync_visibility)
		if ancestor is BattleUtilityOverlay: _inside_utility = true
		ancestor = ancestor.get_parent()
	_sync_visibility()
	_bind_flow.call_deferred()


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
