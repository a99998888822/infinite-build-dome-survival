extends RefCounted

## Shared silhouettes for reaction cues and persistent status visuals.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")


static func shard(canvas: CanvasItem, center: Vector2, direction: Vector2, length: float, width: float, fade: float = 1.0) -> void:
	var axis := direction.normalized()
	var side := axis.orthogonal() * width
	var base := center - axis * length * 0.35
	var tip := center + axis * length * 0.65
	PIXEL.polygon(canvas, PackedVector2Array([base, center + side, tip, center - side]), Color(0.19, 0.48, 0.67, fade * 0.9))
	PIXEL.polygon(canvas, PackedVector2Array([base, tip, center - side]), Color(0.54, 0.86, 0.96, fade * 0.92))
	PIXEL.line(canvas, center - side, tip, Color(0.91, 1.0, 0.97, fade), 2)


static func flame(canvas: CanvasItem, foot: Vector2, height: float, width: float, phase: float, holy: bool, fade: float = 1.0) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var ridge := PackedVector2Array()
	var core_left := PackedVector2Array()
	var core_right := PackedVector2Array()
	for row in range(9):
		var t := float(row) / 8.0
		var bend := sin(t * (4.8 if holy else 6.3) + phase) * width * t * (0.7 if holy else 1.2)
		var middle := foot + Vector2(bend, -height * t)
		var half_width := width * (1.0 - t) * (0.52 + 0.18 * sin(t * PI))
		left.append(middle - Vector2(half_width, 0))
		right.append(middle + Vector2(half_width, 0))
		ridge.append(middle - Vector2(half_width, 0))
		core_left.append(middle - Vector2(half_width * 0.48, -2))
		core_right.append(middle + Vector2(half_width * 0.48, 2))
	right.reverse()
	core_right.reverse()
	var edge := Color(0.91, 0.60, 0.17, 0.94 * fade) if holy else Color(0.42, 0.22, 0.65, 0.94 * fade)
	var core := Color(1.0, 0.98, 0.73, fade) if holy else Color(0.035, 0.025, 0.075, fade)
	var rim := Color(1.0, 0.89, 0.39, fade) if holy else Color(0.65, 0.53, 0.89, fade)
	PIXEL.polygon(canvas, left + right, edge)
	PIXEL.polygon(canvas, core_left + core_right, core)
	PIXEL.path(canvas, ridge, rim, 2)


static func star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	PIXEL.polygon(canvas, PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(2, -2),
		center + Vector2(radius * 0.55, 0), center + Vector2(2, 2),
		center + Vector2(0, radius), center + Vector2(-2, 2),
		center + Vector2(-radius * 0.55, 0), center + Vector2(-2, -2),
	]), color)


static func eye(canvas: CanvasItem, center: Vector2, width: float, opening: float, fade: float) -> void:
	var outline := PackedVector2Array([
		center + Vector2(-width, 0), center + Vector2(-width * 0.45, -opening),
		center + Vector2(width * 0.4, -opening), center + Vector2(width, 0),
		center + Vector2(width * 0.4, opening), center + Vector2(-width * 0.45, opening),
		center + Vector2(-width, 0),
	])
	PIXEL.polygon(canvas, outline, Color(0.05, 0.03, 0.10, fade * 0.85))
	PIXEL.path(canvas, outline, Color(0.55, 0.43, 0.78, fade), 2)
	PIXEL.block(canvas, center, Vector2(2, maxf(opening * 1.5, 2)), Color(0.57, 0.83, 0.76, fade))
