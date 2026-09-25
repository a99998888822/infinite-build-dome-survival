extends Node2D

## Short, render-only reaction cues. They never own damage or status timing.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")
const GROUP := "element_reaction_cues"
const MAX_CUES := 96
const STEAM_SCALE := 0.6
var kind := ""
var elapsed := 0.0
var duration := 0.6
var options: Dictionary = {}
var detail := 2


static func spawn(parent: Node, reaction: String, origin: Vector2, settings: Dictionary = {}) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var peers := parent.get_tree().get_nodes_in_group(GROUP)
	# Merge simultaneous cues at the same location before reducing decoration.
	for peer in peers:
		if not peer.is_queued_for_deletion() and peer.kind == reaction and peer.elapsed < 0.08 and peer.global_position.distance_squared_to(origin) < 64.0 and reaction != "wet_spread":
			return
	if peers.size() >= MAX_CUES:
		return
	var effect := new()
	effect.kind = reaction
	effect.options = settings.duplicate()
	effect.duration = 1.1 if reaction in ["steam", "dark_flame", "holy"] else 0.72
	if reaction == "freeze": effect.duration = 0.62
	parent.add_child(effect)
	effect.global_position = origin
	effect.add_to_group(GROUP)
	effect.detail = PIXEL.register(effect, "reaction_" + reaction)
	effect.z_index = -5 if reaction in ["ice_expand", "thaw"] else 83


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed += delta
	if elapsed >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var fade := (1.0 - smoothstep(0.5, 1.0, t)) * (0.7 if detail == 0 else 1.0)
	match kind:
		"steam": _draw_steam(t, fade)
		"freeze": _draw_freeze(t, fade)
		"thaw": _draw_thaw(t, fade)
		"holy": _draw_holy(t, fade)
		"dark_flame": _draw_dark(t, fade)
		"cancel": _draw_cancel(t, fade)
		"conduct": _draw_conduct(t, fade)
		"wet_spread": _draw_water_ribbon(t, fade)
		"ice_expand": _draw_frost_front(t, fade)
		"thunder_fire": _draw_thunder_fire(t, fade)


func _draw_steam(t: float, fade: float) -> void:
	# Faceted, uneven puffs retain the old smoke silhouette, without side streaks.
	# Scale positions and radii before pixel snapping to preserve crisp pixels.
	for index in range(3 if detail > 0 else 2):
		var age := clampf((t - index * 0.07) * 1.18, 0.0, 1.0)
		var x := (index - 1) * (14.0 + age * 14.0)
		var center := Vector2(x, -10.0 - age * (42.0 + index * 7.0)) * STEAM_SCALE
		var radius := lerpf(3.0, 19.0, age) * STEAM_SCALE
		var cloud := PackedVector2Array()
		for point in range(17):
			var angle := point * TAU / 16.0
			var lobe := 1.0 + 0.18 * sin(angle * 5.0 + index)
			cloud.append(center + Vector2(cos(angle), sin(angle) * 0.80) * radius * lobe)
		PIXEL.polygon(self, cloud, Color(0.45, 0.59, 0.59, fade * 0.48))
		PIXEL.path(self, cloud, Color(0.84, 0.91, 0.86, fade * 0.84), 2)


func _draw_freeze(t: float, fade: float) -> void:
	var reach := 14.0 + ease(t, 0.4) * 25.0
	for index in range(6 if detail > 0 else 4):
		var angle := index * TAU / 6.0
		var direction := Vector2.from_angle(angle)
		var point := direction * reach
		point.y = point.y * 0.65 + 8.0 - sin(t * PI) * 7.0
		SHAPES.shard(self, point, direction, 15.0 * (1.0 - t * 0.5), 4.0, fade)
	if t < 0.4:
		for side in [-1.0, 1.0]:
			PIXEL.line(self, Vector2(side * 10, 14), Vector2(side * 17, -16 - t * 25), Color(0.77, 0.98, 1.0, fade), 3)


func _draw_thaw(t: float, fade: float) -> void:
	for index in range(6):
		var angle := index * TAU / 6.0
		var point := Vector2.from_angle(angle) * (15.0 + t * 21.0)
		point.y = point.y * 0.4 + 12.0 - sin(t * PI) * 12.0
		SHAPES.shard(self, point, Vector2.from_angle(angle), 9.0 * (1.0 - t), 2.0, fade)
	PIXEL.arc(self, 16 + t * 21, 0, TAU, Color(0.37, 0.75, 0.88, fade * 0.7), 2, Vector2(1, 0.4))


func _draw_holy(t: float, fade: float) -> void:
	var growth := smoothstep(0.0, 0.25, t)
	for index in range(3):
		var foot := Vector2((index - 1) * 19.0, 14)
		SHAPES.flame(self, foot, (40 + index % 2 * 18) * growth, 9, t * 5 + index, true, fade * 0.92)
	var crown := Vector2(0, -44 - t * 8)
	SHAPES.star(self, crown, 12.0 * growth, Color(1.0, 0.96, 0.68, fade))
	for side in [-1.0, 1.0]:
		SHAPES.star(self, crown + Vector2(side * 17, 9), 5, Color(1.0, 0.79, 0.27, fade))
	if detail > 0:
		PIXEL.path(self, PackedVector2Array([crown + Vector2(-21, 13), crown + Vector2(-10, 18), crown + Vector2(10, 18), crown + Vector2(21, 13)]), Color(0.98, 0.68, 0.2, fade * 0.8), 2)


func _draw_dark(t: float, fade: float) -> void:
	for side in [-1.0, 1.0]:
		var spiral := PackedVector2Array()
		for point in range(19):
			var u := float(point) / 18.0
			var angle := u * PI * 1.4 + t * 1.4
			spiral.append(Vector2(side * (22.0 + sin(angle) * (10.0 - u * 7)), 13.0 - u * 50.0))
		PIXEL.path(self, spiral, Color(0.025, 0.018, 0.065, fade), 8)
		PIXEL.path(self, spiral, Color(0.48, 0.29, 0.71, fade * 0.92), 3)
		SHAPES.flame(self, Vector2(side * 17, 16), 30, 11, t * 6 + side, false, fade)
	if t > 0.18 and t < 0.75:
		var eye_fade := fade * sin((t - 0.18) / 0.57 * PI)
		SHAPES.eye(self, Vector2(0, -38), 13, 5, eye_fade)


func _draw_cancel(t: float, fade: float) -> void:
	var separation := lerpf(33.0, 0.0, smoothstep(0.05, 0.7, t))
	for side in [-1.0, 1.0]:
		var curve := PackedVector2Array()
		for point in range(13):
			var u := float(point) / 12.0
			curve.append(Vector2(side * (separation + sin(u * PI) * 12), -31 + u * 58))
		var core := Color(0.98, 0.97, 0.80, fade) if side < 0 else Color(0.05, 0.025, 0.10, fade)
		var rim := Color(0.69, 0.80, 0.81, fade * 0.75) if side < 0 else Color(0.60, 0.42, 0.8, fade)
		PIXEL.path(self, curve, rim, 7)
		PIXEL.path(self, curve, core, 3)
	if t > 0.5:
		var slit := (1.0 - smoothstep(0.7, 1.0, t)) * 28
		PIXEL.line(self, Vector2(0, -slit), Vector2(0, slit), Color(0.92, 0.95, 0.94, fade), 2)
		for index in range(6):
			var point := Vector2((index % 2 * 2 - 1) * (t - 0.5) * 40, (index - 3) * 8)
			PIXEL.block(self, point, Vector2(4, 2), Color(0.64, 0.53, 0.77, fade))


func _draw_conduct(t: float, fade: float) -> void:
	var pulse := 0.65 + 0.35 * absf(sin(t * TAU * 1.6))
	var clock := floorf(t * 14)
	for side in [-1.0, 1.0]:
		var wire := PackedVector2Array()
		for point in range(7):
			var x: float = side * (15.0 + float(posmod(point + int(clock), 3)) * 5)
			wire.append(Vector2(x, -29.0 + point * 8))
		PIXEL.path(self, wire, Color(0.08, 0.40, 0.58, fade * pulse), 6)
		PIXEL.path(self, wire, Color(0.41, 0.96, 1.0, fade * pulse), 2)
		PIXEL.path(self, PackedVector2Array([Vector2(side * 18, 17), Vector2(side * 34, 20), Vector2(side * 29, 12), Vector2(side * 43, 17)]), Color(0.39, 0.87, 0.98, fade * pulse), 2)
	var top := PackedVector2Array([Vector2(-18, -28), Vector2(-5, -36), Vector2(0, -29), Vector2(12, -34), Vector2(22, -26)])
	PIXEL.path(self, top, Color(0.80, 1.0, 1.0, fade * pulse), 2)


func _draw_water_ribbon(t: float, fade: float) -> void:
	var target: Vector2 = options.get("target", global_position)
	var offset := target - global_position
	var head := minf(t * 1.7, 1.0)
	var tail := maxf(head - 0.5, 0.0)
	var path := PackedVector2Array()
	var foam := PackedVector2Array()
	for index in range(15):
		var u := lerpf(tail, head, float(index) / 14.0)
		var point := offset * u + Vector2(0, -sin(u * PI) * 22.0)
		path.append(point)
		foam.append(point + Vector2(0, -3 + sin(u * 18 + t * 8) * 2))
	PIXEL.path(self, path, Color(0.10, 0.40, 0.58, fade * 0.82), 8)
	PIXEL.path(self, path, Color(0.24, 0.77, 0.90, fade), 4)
	PIXEL.path(self, foam, Color(0.80, 0.97, 0.95, fade * 0.95), 2)
	if t > 0.5:
		var impact := (t - 0.5) * 2
		for side in [-1.0, 1.0]:
			var drop := offset + Vector2(side * (6 + impact * 16), -sin(impact * PI) * 17)
			PIXEL.block(self, drop, Vector2(4, 6), Color(0.50, 0.87, 0.94, fade))


func _draw_frost_front(t: float, fade: float) -> void:
	var old_radius := float(options.get("from_radius", 64))
	var radius := lerpf(old_radius, float(options.get("radius", 86)), smoothstep(0, 0.65, t))
	for index in range(10 if detail > 0 else 6):
		var angle := index * TAU / 10.0
		var axis := Vector2.from_angle(angle)
		var side := axis.orthogonal()
		var a := axis * (old_radius - 8)
		var b := axis * radius
		PIXEL.line(self, a, b, Color(0.60, 0.91, 0.96, fade), 2)
		for branch in [-1.0, 1.0]:
			PIXEL.line(self, b - axis * 5, b - axis * 12 + side * branch * 7, Color(0.60, 0.91, 0.96, fade * 0.9), 2)
		SHAPES.shard(self, b, axis, 10, 3, fade)
		PIXEL.arc(self, radius, angle + 0.05, angle + 0.40, Color(0.27, 0.68, 0.85, fade * 0.85), 3)


func _draw_thunder_fire(t: float, fade: float) -> void:
	var radius := float(options.get("radius", 72))
	var front := radius * (0.16 + ease(t, 0.45) * 0.68)
	var rim := PackedVector2Array()
	for index in range(25):
		var angle := index * TAU / 24.0
		var distance := front * (1.0 if index % 2 == 0 else 0.83)
		rim.append(Vector2.from_angle(angle) * distance)
	PIXEL.path(self, rim, Color(0.82, 0.20, 0.045, fade * 0.9), 6)
	PIXEL.path(self, rim, Color(1.0, 0.64, 0.14, fade), 2)
	for index in range(5 if detail > 0 else 3):
		var axis := Vector2.from_angle(index * TAU / 5.0 + 0.2)
		var side := axis.orthogonal()
		var bolt := PackedVector2Array([axis * 9, axis * front * 0.36 + side * 6, axis * front * 0.50 - side * 5, axis * front])
		PIXEL.path(self, bolt, Color(0.95, 0.88, 0.55, fade), 4)
		PIXEL.path(self, bolt, Color(1, 1, 0.94, fade), 2)
		PIXEL.block(self, axis * (front + 9), Vector2(4, 6), Color(0.98, 0.36, 0.07, fade))
	if t < 0.20:
		SHAPES.star(self, Vector2.ZERO, 24 * (1 - t / 0.20), Color(1.0, 0.94, 0.73, 0.9))
