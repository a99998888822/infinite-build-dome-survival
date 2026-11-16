extends Node2D
## Ground contact cue, flattened only by the shared battlefield tilt.
const FOOTPRINT = preload("res://scripts/battle/attack_footprint.gd")
var mobile_emphasis := true


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	# Small static ground contact cue, independent of the baked altar lighting.
	draw_set_transform(Vector2(0, 22), 0.0, Vector2(1.0, FOOTPRINT.ELLIPSE_RATIO))
	draw_circle(Vector2.ZERO, 12.0, Color(0.015, 0.022, 0.02, 0.6))
	var front_alpha := 0.82 if MobileProfile.is_mobile() and mobile_emphasis else 0.65
	var back_alpha := 0.62 if MobileProfile.is_mobile() and mobile_emphasis else 0.48
	draw_arc(Vector2.ZERO, 13.0, 0.12, 2.8, 14, Color(0.67, 0.77, 0.58, front_alpha), 1.0, false)
	draw_arc(Vector2.ZERO, 13.0, 3.35, 5.7, 12, Color(0.49, 0.64, 0.53, back_alpha), 1.0, false)
