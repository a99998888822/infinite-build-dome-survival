extends Node2D
## Hammer ground debris only; enemy contact decorations have been removed.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SETTINGS = preload("res://scripts/effects/combat_feedback_settings.gd")
const GROUP := &"combat_impacts_r02"
var direction := Vector2.RIGHT
var age := 0.0
var lifetime := 0.30
var power := 1.0


static func spawn(parent: Node, point: Vector2, style: StringName, heading: Vector2, strength: float = 1.0) -> void:
	if style != &"ground" or not SETTINGS.enabled() or parent == null:
		return
	if parent.get_tree().get_nodes_in_group(GROUP).size() >= 96:
		return
	var effect := new()
	effect.direction = heading.normalized()
	effect.power = strength
	parent.add_child(effect)
	effect.global_position = point
	CombatRenderWorld.set_effect_layer(effect, -1)
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
	var mid := Color("b4a77a")
	var edge := Color("f6e5b3")
	for i in 8:
		var radial := direction.rotated((i - 3.5) * 0.42)
		var point := radial * (8 + p * (22 + i % 3 * 8)) * power
		point.y *= 0.65
		var size := Vector2(6 if i % 2 == 0 else 4, 4) if p < 0.5 else Vector2(4, 2)
		PIXEL.block(self, point + Vector2(0, 2), size + Vector2(2, 2), ink)
		PIXEL.block(self, point + Vector2(0, -sin(p * PI) * 8), size, mid if p > 0.2 else edge)
	if p < 0.3:
		PIXEL.line(self, -direction * 6, direction * 16, edge, 4)
