extends Node2D

# Approval-only visual study. No damage, status changes or production hooks.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const REFERENCE_RADIUS := 92.4
const RADIUS_SCALE := 0.85
const MAX_RADIUS := REFERENCE_RADIUS * RADIUS_SCALE
var radius := MAX_RADIUS
var duration := 0.85
var elapsed := 0.0
var phase := 0.4


func _ready() -> void:
	z_index = -8


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()


func _edge_radius(angle: float, reach: float, time: float) -> float:
	# Small, unequal ripples keep the overall outline circular, with liquid
	# edges rather than a rigid circle or evenly spaced flower petals.
	var ripple := sin(angle * 5.0 - time * 4.8 + phase) * 0.031
	ripple += sin(angle * 9.0 + time * 5.5 + phase * 1.7) * 0.018
	ripple += sin(angle * 13.0 - time * 3.0 + 1.1) * 0.009
	return reach * (0.942 + ripple)


func _contour(reach: float, inset: float, time: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(97):
		var angle := float(index) * TAU / 96.0
		points.append(Vector2.from_angle(angle) * maxf(1.0, _edge_radius(angle, reach, time) - inset))
	return points


func _draw() -> void:
	var time := clampf(elapsed / duration, 0.0, 1.0)
	var growth := 1.0 - pow(1.0 - minf(time / 0.82, 1.0), 1.55)
	var reach := radius * lerpf(0.065, 1.0, growth)
	var fade := 1.0 - smoothstep(0.66, 1.0, time)
	var width := minf(reach * 0.40, lerpf(6.0, 13.0, growth) * RADIUS_SCALE)
	var outer := _contour(reach, 0.0, time)
	var inner := _contour(reach, width, time)
	var band := outer.duplicate()
	for index in range(inner.size() - 1, -1, -1): band.append(inner[index])
	# A quiet translucent surface follows the growing edge; most of the
	# contrast belongs to the outer front and its curling white-blue crests.
	PIXEL.polygon(self, outer, Color(0.10, 0.43, 0.57, fade * 0.11))
	PIXEL.polygon(self, band, Color(0.055, 0.29, 0.40, fade * 0.86))
	PIXEL.path(self, inner, Color(0.09, 0.39, 0.51, fade * 0.72), 2)
	var shoulder := _contour(reach, width * 0.35, time)
	PIXEL.path(self, shoulder, Color(0.20, 0.62, 0.74, fade * 0.93), maxf(2.0, width * 0.5))
	PIXEL.path(self, outer, Color(0.46, 0.83, 0.87, fade * 0.85), 2)
	# Foam follows short uneven sections of the rim, curling into the wake.
	for crest in range(7):
		var start := crest * TAU / 7.0 + sin(crest * 2.4) * 0.09 + time * 0.28
		var length := 0.36 + float(crest % 3) * 0.075
		var lip := PackedVector2Array()
		for index in range(15):
			var u := float(index) / 14.0
			var angle := start + u * length
			var bend := smoothstep(0.62, 1.0, u)
			var distance := _edge_radius(angle, reach, time) - width * (0.08 + bend * 0.74)
			angle -= bend * 0.08
			lip.append(Vector2.from_angle(angle) * maxf(distance, 1.0))
		PIXEL.path(self, lip, Color(0.65, 0.92, 0.93, fade * 0.98), 2)
		if reach > 25.0:
			PIXEL.path(self, lip.slice(2, 8), Color(0.88, 0.98, 0.95, fade * 0.94), 2)
	# The inner wake is subordinate to the single advancing outer wave.
	if time > 0.22:
		var wake_alpha := fade * smoothstep(0.22, 0.45, time) * 0.34
		for wake in range(3):
			var points := PackedVector2Array()
			for index in range(19):
				var angle := wake * TAU / 3.0 + index * 0.043 - time * 0.35
				var distance := reach * (0.70 + 0.018 * sin(angle * 8.0 + time * 4))
				points.append(Vector2.from_angle(angle) * distance)
			PIXEL.path(self, points, Color(0.38, 0.73, 0.80, wake_alpha), 2)
