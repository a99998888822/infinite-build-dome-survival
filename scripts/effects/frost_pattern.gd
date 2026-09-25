extends RefCounted
## Six-fold crystal growth shared by the ice field and frost under slowed feet.

const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")


static func draw_crystal(canvas: CanvasItem, center: Vector2, radius: float, growth: float, fade: float, rotation_angle: float = 0.0, flatten: float = 1.0) -> void:
	var reach := radius * clampf(growth, 0.0, 1.0)
	if reach < 2.0:
		return
	var ground := PackedVector2Array()
	for index in 24:
		var angle := rotation_angle + index * TAU / 24.0
		var length := reach * (0.96 if index % 4 == 0 else (0.48 if index % 2 == 0 else 0.64))
		ground.append(center + Vector2(cos(angle), sin(angle) * flatten) * length)
	PIXEL.polygon(canvas, ground, Color(0.46, 0.77, 0.84, fade * 0.18))
	for arm in 6:
		var axis := Vector2.from_angle(rotation_angle + arm * TAU / 6.0)
		var side := axis.orthogonal()
		var tip := center + axis * Vector2(1, flatten) * reach
		PIXEL.line(canvas, center, tip, Color(0.18, 0.47, 0.61, fade * 0.72), 4)
		PIXEL.line(canvas, center, tip, Color(0.76, 0.95, 0.97, fade * 0.90), 2)
		for tier in [0.40, 0.68]:
			var joint: Vector2 = axis * reach * tier
			for sign_value in [-1.0, 1.0]:
				var branch: Vector2 = joint - axis * reach * 0.19 + side * sign_value * reach * 0.18
				PIXEL.line(canvas, center + joint * Vector2(1, flatten), center + branch * Vector2(1, flatten), Color(0.66, 0.89, 0.95, fade * 0.9), 2)
		if radius >= 28:
			var facet := PackedVector2Array([
				center + axis * reach * 0.25 * Vector2(1, flatten),
				center + (axis * 0.58 + side * 0.08) * reach * Vector2(1, flatten),
				tip,
				center + (axis * 0.58 - side * 0.08) * reach * Vector2(1, flatten),
			])
			PIXEL.polygon(canvas, facet, Color(0.55, 0.84, 0.92, fade * 0.28))
	PIXEL.block(canvas, center, Vector2(4, 4), Color(0.90, 0.99, 1.0, fade * 0.85))
