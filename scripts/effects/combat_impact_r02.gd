extends Node2D
## A small batch of hard-edged blocks per contact, with no particle nodes or RNG.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SETTINGS = preload("res://scripts/effects/combat_feedback_settings.gd")
const GROUP := &"combat_impacts_r02"
var kind := &"light"
var direction := Vector2.RIGHT
var age := 0.0
var lifetime := 0.18
var power := 1.0


static func spawn(parent: Node, point: Vector2, style: StringName, heading: Vector2, strength: float = 1.0) -> void:
	if not SETTINGS.enabled() or parent == null:
		return
	if parent.get_tree().get_nodes_in_group(GROUP).size() >= 96:
		return
	var effect := new()
	effect.kind = style
	effect.direction = heading.normalized()
	effect.power = strength
	effect.lifetime = 0.30 if style == &"ground" else 0.24 if style == &"heavy" else 0.22 if style == &"ritual" else 0.14
	parent.add_child(effect)
	effect.global_position = point
	effect.z_index = 55 if style != &"ground" else -1
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.add_to_group(GROUP)
	# Contact decoration has no weapon snapshot; keep it out of weapon ownership.


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	age += delta
	if age >= lifetime:
		cancel()
	queue_redraw()


func cancel() -> void:
	hide()
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	# Quantize decorative motion, while simulation and contact times stay exact.
	var t := floorf(age * 30.0) / 30.0
	var p := clampf(t / lifetime, 0, 1)
	var ink := Color("243239")
	var mid := Color("79988f")
	var edge := Color("ecf0cf")
	if kind in [&"heavy", &"ground"]:
		mid = Color("b4a77a")
		edge = Color("f6e5b3")
	elif kind == &"ritual":
		mid = Color("7bacc0")
		edge = Color("e0f3f0")
	elif kind == &"sustain":
		mid = Color("d78b50")
		edge = Color("ffdc92")
	if kind == &"ground":
		for i in 8:
			var radial := direction.rotated((i - 3.5) * 0.42)
			var point := radial * (8 + p * (22 + i % 3 * 8)) * power
			point.y *= 0.65
			var size := Vector2(6 if i % 2 == 0 else 4, 4) if p < 0.5 else Vector2(4, 2)
			PIXEL.block(self, point + Vector2(0, 2), size + Vector2(2, 2), ink)
			PIXEL.block(self, point + Vector2(0, -sin(p * PI) * 8), size, mid if p > 0.2 else edge)
		if p < 0.3:
			PIXEL.line(self, -direction * 6, direction * 16, edge, 4)
		return
	if kind == &"ritual":
		var spread := 10.0 + (1.0 - pow(1.0 - p, 3)) * 10.0
		for i in 4:
			var axis := Vector2.from_angle(i * PI * 0.5 + PI * 0.25)
			var point := axis * spread
			PIXEL.line(self, point, point + axis * 6, ink, 6)
			PIXEL.line(self, point, point + axis * 4, edge if p < 0.5 else mid, 2)
		return
	var heavy := kind == &"heavy"
	var radius := (16.0 if heavy else 9.0) * (1.0 - p * 0.65)
	if heavy and p < 0.45:
		var outline := PackedVector2Array()
		var interior := PackedVector2Array()
		for vertex in [Vector2(0,-12),Vector2(4,-5),Vector2(12,-7),Vector2(8,0),Vector2(14,4),Vector2(4,5),Vector2(2,12),Vector2(-3,6),Vector2(-10,8),Vector2(-6,0),Vector2(-12,-4),Vector2(-3,-4)]:
			var point: Vector2 = vertex.rotated(direction.angle()) * (1.0 - p * 0.5)
			outline.append(point)
			interior.append(point * 0.72)
		PIXEL.polygon(self, outline, ink)
		PIXEL.polygon(self, interior, mid)
		PIXEL.block(self, Vector2(-2,-2), Vector2(6,4), edge)
	elif not heavy and p < 0.50:
		var tangent := direction.orthogonal()
		PIXEL.line(self, -tangent * radius, tangent * radius, ink, 6 if heavy else 4)
		PIXEL.line(self, -tangent * radius, tangent * radius, edge, 4 if heavy else 2)
		PIXEL.line(self, -direction * radius * 0.6, direction * radius * 0.8, mid, 4)
		PIXEL.block(self, Vector2.ZERO, Vector2(6, 4) if heavy else Vector2(4, 2), edge)
	for i in (5 if heavy else 3):
		var radial := direction.rotated((i - (2.0 if heavy else 1.0)) * 0.65)
		var offset := radial * (8 + p * (24 if heavy else 14))
		PIXEL.block(self, offset, Vector2(4, 2) if p < 0.55 else Vector2(2, 2), mid if p > 0.4 else edge)
