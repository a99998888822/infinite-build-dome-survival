extends Control
## One pulse per primary tome mark, attached to the actual weapon-bar icon.
const SETTINGS = preload("res://scripts/effects/combat_feedback_settings.gd")
var icon: TextureRect
var age := 1.0
var pulses := 0


func configure(target: TextureRect, source: WeaponInstance) -> void:
	icon = target
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.feedback_mark.connect(pulse)
	set_physics_process(false)


func pulse(_sequence: int) -> void:
	if not SETTINGS.enabled():
		return
	age = 0.0
	pulses += 1
	set_physics_process(true)
	paint()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	age += delta
	if age >= 0.23:
		icon.scale = Vector2.ONE
		icon.modulate = Color.WHITE
		set_physics_process(false)
		queue_redraw()
	else:
		paint()


func paint() -> void:
	icon.pivot_offset = icon.size * 0.5
	var factor := lerpf(0.88, 1.10, age / 0.06) if age < 0.06 else lerpf(1.10, 1.0, ease(clampf((age - 0.06) / 0.17, 0, 1), 0.4))
	icon.scale = Vector2.ONE * factor
	icon.modulate = Color(1.25, 1.30, 1.30).lerp(Color.WHITE, clampf(age / 0.14, 0, 1))
	queue_redraw()


func _draw() -> void:
	if age >= 0.23 or not is_instance_valid(icon):
		return
	var extent: Vector2 = get_parent().size
	var color := Color(0.78, 0.90, 0.88, 1.0 - age / 0.23)
	for x in [2.0, extent.x - 10.0]:
		for y in [2.0, extent.y - 4.0]:
			draw_rect(Rect2(x, y, 8, 2), color)
