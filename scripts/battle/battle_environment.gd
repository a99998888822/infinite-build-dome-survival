extends CanvasLayer
class_name BattleEnvironment

const SKY_TEXTURE_ASPECT_RATIO: float = 16.0
const SKY_HEIGHT_SCALE: float = 0.5
const TOP_BAR_HEIGHT: float = 56.0
const TOP_EDGE_HIGHLIGHT_HEIGHT: float = 2.0
const TOP_EDGE_SHADOW_HEIGHT: float = 7.0
const BOTTOM_EDGE_GLOW_OVERLAP: float = 4.0
const BOTTOM_EDGE_GLOW_HEIGHT: float = 6.0
const BOTTOM_EDGE_SHADOW_HEIGHT: float = 10.0
const FOLD_HEIGHT: float = 44.0

var horizon_y := 128.0
var fold_height := FOLD_HEIGHT

@onready var crt_overlay: ColorRect = get_node_or_null("../BattleAmbience/CrtOverlay")
@onready var sky: TextureRect = get_node_or_null("../BattleSky/Sky")
@onready var top_edge_highlight: ColorRect = get_node_or_null("../BattleSky/TopEdgeHighlight")
@onready var top_edge_shadow: ColorRect = get_node_or_null("../BattleSky/TopEdgeShadow")
@onready var bottom_edge_glow: ColorRect = get_node_or_null("../BattleSky/BottomEdgeGlow")
@onready var bottom_edge_shadow: ColorRect = get_node_or_null("../BattleSky/BottomEdgeShadow")
@onready var ruins: Node2D = get_node_or_null("../BattleSky/DistantRuins")
@onready var ground: Node2D = get_node_or_null("../CombatRenderWorld/Backdrop")
@onready var fold: WetlandHorizonFold = get_node_or_null("../CombatRenderWorld/HorizonFold")


func _ready() -> void:
	# Update after the camera and wetland clock, including while combat is paused.
	process_priority = 50
	_apply_sky_layout()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func _process(_delta: float) -> void:
	if crt_overlay != null and crt_overlay.material is ShaderMaterial:
		(crt_overlay.material as ShaderMaterial).set_shader_parameter("time_seconds", Time.get_ticks_msec() / 1000.0)
	_update_horizon_view()


func _on_viewport_size_changed() -> void:
	_apply_sky_layout()


static func get_sky_height(view_width: float) -> float:
	return ceilf(view_width / SKY_TEXTURE_ASPECT_RATIO * SKY_HEIGHT_SCALE)


func _apply_sky_layout() -> void:
	if sky == null or get_viewport() == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	var top_height := 0.0 if ground is MeadowBattleBackdrop else TOP_BAR_HEIGHT
	var sky_bottom := top_height + get_sky_height(view_size.x)
	horizon_y = sky_bottom
	fold_height = clampf(view_size.y * FOLD_HEIGHT / 648.0, 30.0, 48.0)
	sky.offset_top = top_height
	sky.offset_bottom = sky_bottom
	if sky.material is ShaderMaterial:
		(sky.material as ShaderMaterial).set_shader_parameter("sky_height", sky_bottom - top_height)
	if top_edge_highlight != null:
		top_edge_highlight.visible = top_height > 0.0
		top_edge_highlight.offset_top = TOP_BAR_HEIGHT
		top_edge_highlight.offset_bottom = TOP_BAR_HEIGHT + TOP_EDGE_HIGHLIGHT_HEIGHT
	if top_edge_shadow != null:
		top_edge_shadow.visible = top_height > 0.0
		top_edge_shadow.offset_top = TOP_BAR_HEIGHT + TOP_EDGE_HIGHLIGHT_HEIGHT
		top_edge_shadow.offset_bottom = top_edge_shadow.offset_top + TOP_EDGE_SHADOW_HEIGHT
	if bottom_edge_glow != null:
		bottom_edge_glow.offset_top = sky_bottom - BOTTOM_EDGE_GLOW_OVERLAP
		bottom_edge_glow.offset_bottom = bottom_edge_glow.offset_top + BOTTOM_EDGE_GLOW_HEIGHT
	if bottom_edge_shadow != null:
		bottom_edge_shadow.offset_top = sky_bottom
		bottom_edge_shadow.offset_bottom = sky_bottom + BOTTOM_EDGE_SHADOW_HEIGHT


func _update_horizon_view() -> void:
	if ground == null or fold == null or ruins == null or not ground.is_node_ready():
		return
	if ground is MeadowBattleBackdrop:
		# The meadow owns the exact terrain projection shared by its ruin roots.
		fold.hide()
		return
	var view_size := get_viewport().get_visible_rect().size
	ruins.configure_view(horizon_y, view_size, ground.camera_position.x)
	if ground is GreenBattleBackdrop:
		fold.hide()
		return
	fold.configure_view(horizon_y, fold_height, view_size, ground, ruins.get_placements(), sky.texture)
