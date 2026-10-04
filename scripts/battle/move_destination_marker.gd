extends Node2D
class_name MoveDestinationMarker

const SHEET := preload("res://assets/ui/combat/move_destination.png")
const FRAME_SIZE := 64
const FRAME_COUNT := 8
const FRAME_SECONDS := 0.065
var elapsed := 0.0
var active := false


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hide()


func show_destination(point: Vector2) -> void:
	global_position = point
	elapsed = 0
	active = true
	show()
	queue_redraw()


func clear_destination() -> void:
	active = false
	hide()


func _process(delta: float) -> void:
	if not active or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var frame := mini(FRAME_COUNT - 1, int(elapsed / FRAME_SECONDS))
	draw_texture_rect_region(SHEET, Rect2(-32, -32, 64, 64), Rect2(frame * 64, 0, 64, 64))
