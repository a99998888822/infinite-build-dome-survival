extends Node2D
class_name ParticleLightField

const MAX_LIGHTS: int = 96

var _lights: Array[Dictionary] = []


func _ready() -> void:
	z_index = 15
	queue_redraw()


func add_light(global_position: Vector2, color: Color, energy: float, radius: float, duration: float = 0.18) -> void:
	if energy <= 0.0 or radius <= 0.0:
		return
	_lights.append({
		"position": to_local(global_position),
		"color": color,
		"energy": energy,
		"radius": radius,
		"remaining": maxf(duration, 0.02),
		"duration": maxf(duration, 0.02),
	})
	if _lights.size() > MAX_LIGHTS:
		_lights.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for index in range(_lights.size() - 1, -1, -1):
		var light: Dictionary = _lights[index]
		light["remaining"] = float(light["remaining"]) - delta
		_lights[index] = light
		if float(light["remaining"]) <= 0.0:
			_lights.remove_at(index)
	queue_redraw()


func _draw() -> void:
	for light in _lights:
		var duration := maxf(float(light["duration"]), 0.02)
		var remaining := clampf(float(light["remaining"]) / duration, 0.0, 1.0)
		var energy := clampf(float(light["energy"]) * remaining, 0.0, 2.5)
		var position: Vector2 = light["position"]
		var radius := float(light["radius"])
		var base: Color = light["color"]
		draw_circle(position, radius, Color(base.r, base.g, base.b, 0.012 * energy))
		draw_circle(position, radius * 0.68, Color(base.r, base.g, base.b, 0.028 * energy))
		draw_circle(position, radius * 0.36, Color(base.r, base.g, base.b, 0.07 * energy))
		draw_circle(position, radius * 0.13, Color(1.0, 1.0, 1.0, 0.08 * energy))
