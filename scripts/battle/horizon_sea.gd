extends Node2D
class_name HorizonSea

@export var top_bar_height: float = 56.0
@export var sky_texture_aspect_ratio: float = 16.0
@export_range(0.1, 0.35, 0.01) var band_height_ratio: float = 0.19
@export var minimum_band_height: float = 64.0
@export var maximum_band_height: float = 96.0

@onready var sea_band: ColorRect = get_node_or_null("SeaBand")

var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2.ZERO


func _ready() -> void:
	top_level = true
	_update_layout(true)


func _process(_delta: float) -> void:
	_update_layout(false)


func _update_layout(force: bool) -> void:
	var world_viewport := get_viewport()
	var root_window := get_tree().root
	if world_viewport == null or root_window == null or sea_band == null:
		return
	var viewport_size := world_viewport.get_visible_rect().size
	var window_size := root_window.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	var camera := world_viewport.get_camera_2d()
	var camera_center := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var sky_bottom_ratio := (top_bar_height + window_size.x / sky_texture_aspect_ratio) / window_size.y
	var horizon_y := roundf(viewport_size.y * clampf(sky_bottom_ratio, 0.12, 0.34))
	var band_height := roundf(clampf(viewport_size.y * band_height_ratio, minimum_band_height, maximum_band_height))
	global_position = camera_center + Vector2(-viewport_size.x * 0.5, -viewport_size.y * 0.5 + horizon_y - 1.0)
	if force or not viewport_size.is_equal_approx(_last_viewport_size) or not window_size.is_equal_approx(_last_window_size):
		sea_band.position = Vector2.ZERO
		sea_band.size = Vector2(viewport_size.x, band_height)
		if sea_band.material is ShaderMaterial:
			(sea_band.material as ShaderMaterial).set_shader_parameter("band_size", sea_band.size)
		_last_viewport_size = viewport_size
		_last_window_size = window_size
