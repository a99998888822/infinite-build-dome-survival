extends CanvasLayer
class_name BattleEnvironment

const SKY_TEXTURE_ASPECT_RATIO: float = 16.0
const TOP_BAR_HEIGHT: float = 56.0
const TOP_EDGE_HIGHLIGHT_HEIGHT: float = 2.0
const TOP_EDGE_SHADOW_HEIGHT: float = 7.0
const BOTTOM_EDGE_GLOW_OVERLAP: float = 4.0
const BOTTOM_EDGE_GLOW_HEIGHT: float = 6.0
const BOTTOM_EDGE_SHADOW_HEIGHT: float = 10.0

@onready var crt_overlay: ColorRect = get_node_or_null("../BattleAmbience/CrtOverlay")
@onready var sky: TextureRect = get_node_or_null("../BattleSky/Sky")
@onready var top_edge_highlight: ColorRect = get_node_or_null("../BattleSky/TopEdgeHighlight")
@onready var top_edge_shadow: ColorRect = get_node_or_null("../BattleSky/TopEdgeShadow")
@onready var bottom_edge_glow: ColorRect = get_node_or_null("../BattleSky/BottomEdgeGlow")
@onready var bottom_edge_shadow: ColorRect = get_node_or_null("../BattleSky/BottomEdgeShadow")


func _ready() -> void:
	_apply_sky_layout()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func _process(_delta: float) -> void:
	if crt_overlay != null and crt_overlay.material is ShaderMaterial:
		(crt_overlay.material as ShaderMaterial).set_shader_parameter("time_seconds", Time.get_ticks_msec() / 1000.0)


func _on_viewport_size_changed() -> void:
	_apply_sky_layout()


func _apply_sky_layout() -> void:
	if sky == null or get_viewport() == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var sky_bottom := TOP_BAR_HEIGHT + ceilf(viewport_width / SKY_TEXTURE_ASPECT_RATIO)
	sky.offset_top = TOP_BAR_HEIGHT
	sky.offset_bottom = sky_bottom
	if top_edge_highlight != null:
		top_edge_highlight.offset_top = TOP_BAR_HEIGHT
		top_edge_highlight.offset_bottom = TOP_BAR_HEIGHT + TOP_EDGE_HIGHLIGHT_HEIGHT
	if top_edge_shadow != null:
		top_edge_shadow.offset_top = TOP_BAR_HEIGHT + TOP_EDGE_HIGHLIGHT_HEIGHT
		top_edge_shadow.offset_bottom = top_edge_shadow.offset_top + TOP_EDGE_SHADOW_HEIGHT
	if bottom_edge_glow != null:
		bottom_edge_glow.offset_top = sky_bottom - BOTTOM_EDGE_GLOW_OVERLAP
		bottom_edge_glow.offset_bottom = bottom_edge_glow.offset_top + BOTTOM_EDGE_GLOW_HEIGHT
	if bottom_edge_shadow != null:
		bottom_edge_shadow.offset_top = sky_bottom
		bottom_edge_shadow.offset_bottom = sky_bottom + BOTTOM_EDGE_SHADOW_HEIGHT
