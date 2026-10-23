extends Node2D

# Share the lamp's 2px grid, four-color shading and 18fps visual cadence.
# The player advances this clock so battle pause freezes the entire revival.
const SHADER = preload("res://shaders/effects/revive_angel_wings.gdshader")
const OPEN_SECONDS := 0.95
const FADE_START := 1.05
const DURATION := 1.5
var elapsed := 0.0
var opening := 0.0
var active := false
var _material: ShaderMaterial

func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	CombatRenderWorld.set_actor_local(self)
	show_behind_parent = true
	position = Vector2(0, -5)
	hide()

func restart() -> void:
	elapsed = 0.0
	active = true
	show()
	_update_visual()

func advance(delta: float) -> void:
	if not active: return
	elapsed += maxf(delta, 0.0)
	if elapsed >= DURATION:
		clear()
		return
	_update_visual()

func clear() -> void:
	active = false
	elapsed = 0.0
	opening = 0.0
	hide()

func _update_visual() -> void:
	var visual_time := floorf(elapsed * 18.0) / 18.0
	opening = smoothstep(0.0, OPEN_SECONDS, visual_time)
	_material.set_shader_parameter("opening", opening)
	_material.set_shader_parameter("effect_time", visual_time)
	_material.set_shader_parameter("opacity", minf(1.0, (elapsed + 0.06) / 0.16) * (1.0 - smoothstep(FADE_START, DURATION, elapsed)))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-70, -78, 140, 114), Color.WHITE)
