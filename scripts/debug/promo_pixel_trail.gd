extends Node2D
## Screen-space blade ribbon: hard 2px cells, sampled along the icon's curve.
## Kept independent of combat pause and world projection for the finance page.

var points := PackedVector2Array()
var progress := -1.0
var opacity := 1.0
var impact := -1.0
var target_rect := Rect2()
const GRID := 2.0
const PALETTE := [Color("294b50"), Color("51939a"), Color("83ced1"), Color("d8f5eb")]


func at(t: float) -> Vector2:
	return points[0].bezier_interpolate(points[1], points[2], points[3], clampf(t, 0.0, 1.0))


func seek(value: float, fade: float = 1.0) -> void:
	progress = value
	opacity = fade
	queue_redraw()


func _cell(point: Vector2, width: float, color: Color) -> void:
	var extent := maxf(GRID, roundf(width / GRID) * GRID)
	var origin := ((point - Vector2.ONE * extent * 0.5) / GRID).round() * GRID
	draw_rect(Rect2(origin, Vector2.ONE * extent), color)


func _draw() -> void:
	if progress >= 0.0 and opacity > 0.0:
		var tail := maxf(0.0, progress - 0.36)
		for layer in 4:
			var color: Color = PALETTE[layer]
			color.a = opacity
			for i in 145:
				var ratio := float(i) / 144.0
				var t := lerpf(tail, progress, ratio)
				var point := at(t)
				# A broad blade behind a narrow leading tip, tapering to a fine tail.
				var width := sin(ratio * PI) * (15.0 - layer * 3.7)
				if width < 1.0: continue
				_cell(point, width, color)
		# Broken parallel filaments give the slash its pixel-art silhouette.
		for i in 38:
			var ratio := float(i) / 37.0
			if i % 9 > 5: continue
			var t := lerpf(tail, progress, ratio)
			var tangent := (at(t + 0.003) - at(t - 0.003)).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			for side in [-1.0, 1.0]:
				var color := PALETTE[1]
				color.a = opacity * 0.8
				_cell(at(t) + normal * side * (9.0 + sin(ratio * PI) * 7.0), 2.0, color)
	if impact >= 0.0 and impact < 1.0:
		var color := Color("d8f5b9")
		color.a = (1.0 - impact) * 0.8
		var border := target_rect.grow(2.0)
		draw_rect(Rect2(border.position.round(), border.size.round()), color, false, 2.0)
		var center := target_rect.get_center()
		for i in 8:
			var direction := Vector2.from_angle(float(i) * TAU / 8.0)
			_cell(center + direction * (24.0 + impact * 21.0), 4.0 if i % 2 == 0 else 2.0, color)
