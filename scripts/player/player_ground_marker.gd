extends Node2D

func _ready() -> void:
	z_index = -1


func _draw() -> void:
	# Small static ground contact cue, independent of the baked altar lighting.
	draw_set_transform(Vector2(0, 22), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 12.0, Color(0.015, 0.022, 0.02, 0.6))
	draw_arc(Vector2.ZERO, 13.0, 0.12, 2.8, 14, Color(0.67, 0.77, 0.58, 0.65), 1.0, false)
	draw_arc(Vector2.ZERO, 13.0, 3.35, 5.7, 12, Color(0.49, 0.64, 0.53, 0.48), 1.0, false)
