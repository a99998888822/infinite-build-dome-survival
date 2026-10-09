extends Node2D
## The designated target remains identifiable among ordinary minibosses.
const ICON := preload("res://assets/ui/finance/challenge_debt.svg")
var target: EnemyController


func _ready() -> void:
	target = get_parent() as EnemyController
	position = Vector2(0, -155 if target is EliteRusher else -136)
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	visible = is_instance_valid(target) and target.is_alive()
	if visible: queue_redraw()


func _draw() -> void:
	if not is_instance_valid(target): return
	draw_texture_rect(ICON, Rect2(-10, -20, 20, 20), false)
