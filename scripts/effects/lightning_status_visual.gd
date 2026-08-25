extends Node2D

const FILAMENT_COUNT: int = 3
const FILAMENT_WIDTH: float = 34.0
const FILAMENT_HEIGHT: float = 15.0
const POINT_COUNT: int = 9

var _remaining: float = 0.65
var _elapsed: float = 0.0


static func attach(parent: Node2D, duration: float = 0.65) -> Node2D:
	if parent == null:
		return null
	var visual_script: Script = load("res://scripts/effects/lightning_status_visual.gd") as Script
	var visual: Node2D = visual_script.new() as Node2D
	parent.add_child(visual)
	visual.set("_remaining", maxf(duration, 0.15))
	return visual


func refresh(duration: float = 0.65) -> void:
	_remaining = maxf(_remaining, duration)


func _ready() -> void:
	z_index = 20
	position = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(_remaining / 0.65, 0.0, 1.0)
	for filament_index in FILAMENT_COUNT:
		var points := PackedVector2Array()
		var phase: float = float(filament_index) * 1.9
		var vertical_offset: float = (float(filament_index) - 1.0) * 4.0
		for point_index in POINT_COUNT:
			var ratio: float = float(point_index) / float(POINT_COUNT - 1)
			var x: float = lerpf(-FILAMENT_WIDTH * 0.5, FILAMENT_WIDTH * 0.5, ratio)
			var wave: float = sin(_elapsed * 17.0 + ratio * 9.0 + phase) * FILAMENT_HEIGHT * 0.42
			var kink: float = sin(ratio * 25.0 + phase * 2.0) * FILAMENT_HEIGHT * 0.18
			points.append(Vector2(x, vertical_offset + wave + kink))
		var blue_alpha: float = 0.72 * fade
		var white_alpha: float = 0.94 * fade
		draw_polyline(points, Color(0.20, 0.55, 1.0, blue_alpha), 2.4, true)
		draw_polyline(points, Color(0.88, 0.97, 1.0, white_alpha), 0.9, true)

	for spark_index in 5:
		var spark_phase: float = float(spark_index) * 1.7
		var spark_position := Vector2(
			sin(_elapsed * 11.0 + spark_phase) * 21.0,
			cos(_elapsed * 13.0 + spark_phase) * 15.0,
		)
		var spark_alpha: float = (0.45 + 0.45 * sin(_elapsed * 19.0 + spark_phase)) * fade
		draw_circle(spark_position, 1.3, Color(0.86, 0.96, 1.0, spark_alpha))
