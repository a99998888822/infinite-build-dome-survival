extends Node2D

const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const TOME_LIFETIME := 0.60
const TOME_IMPACT_SCALE := 0.50
const COIN_LIFETIME := 0.40
var weapon: WeaponInstance
var tome := false
var age := 0.0
var cancelled := false


static func spawn(parent: Node, source: WeaponInstance, where: Vector2, is_tome: bool) -> void:
	var effect := new()
	effect.weapon = source
	effect.tome = is_tome
	parent.add_child(effect)
	effect.global_position = where
	effect.z_index = 70 if is_tome else 45
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.add_to_group("weapon_runtime_effects")


func _physics_process(delta: float) -> void:
	if cancelled or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	age += delta
	if age >= (TOME_LIFETIME if tome else COIN_LIFETIME):
		cancel()
	queue_redraw()


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	if cancelled:
		return
	if tome:
		_draw_tome_impact()
	else:
		var progress := age / COIN_LIFETIME
		for index in 10:
			var offset := Vector2.RIGHT.rotated(index * 2.4) * (4 + progress * (12 + index % 3 * 5))
			offset.y += progress * progress * 10
			draw_rect(Rect2(offset.round(), Vector2(2,2)), Color(0.94, 0.74, 0.35, 1.0 - progress))


func _draw_tome_impact() -> void:
	# Five open, offset ridges read as a fingerprint bursting from the hit target.
	# Render only: the attack still applies its damage once in RitualDomain.
	var center := Vector2(0, -4)
	# Scale the complete fingerprint around its hit center, including line widths.
	draw_set_transform(center * (1.0 - TOME_IMPACT_SCALE), 0.0, Vector2.ONE * TOME_IMPACT_SCALE)
	var progress := clampf(age / TOME_LIFETIME, 0.0, 1.0)
	var ridge_alpha := 1.0 - smoothstep(0.18, 0.48, age)
	var burst := 1.0 - pow(1.0 - minf(age / 0.16, 1.0), 3.0)
	var expansion := lerpf(0.68, 1.06, burst) + maxf(age - 0.16, 0.0) * 0.32
	var flash := 1.0 - smoothstep(0.02, 0.13, age)
	var ink := Color(0.035, 0.09, 0.16, ridge_alpha * 0.52)
	if ridge_alpha > 0.0:
		for ridge in 5:
			var points := _fingerprint_ridge(ridge, expansion, center)
			var color := Color(0.48, 0.83, 1.0).lerp(Color(0.91, 0.98, 1.0), maxf(flash, 0.55 - ridge * 0.1))
			color.a = ridge_alpha
			PIXEL.path(self, points, ink, 4)
			PIXEL.path(self, points, color, 2)
	# A few square flecks carry the burst outwards without adding another symbol.
	var scatter := 1.0 - pow(1.0 - progress, 2.0)
	for index in 6:
		var angle := index * TAU / 6.0 + sin(index * 2.7) * 0.25
		var offset := Vector2.from_angle(angle) * (19.0 + scatter * (17.0 + index % 3 * 5.0))
		offset.y -= progress * progress * 6.0
		var alpha := (1.0 - smoothstep(0.10, TOME_LIFETIME, age)) * 0.75
		PIXEL.block(self, center + offset, Vector2(2, 2), Color(0.78, 0.94, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)


func _fingerprint_ridge(ridge: int, expansion: float, center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := 4.0 + ridge * 6.0
	var start := PI * (0.61 + ridge * 0.035)
	var finish := PI * (2.43 - ridge * 0.028)
	for step in 37:
		var angle := lerpf(start, finish, step / 36.0)
		# Offset the core and bend the lower ends to avoid concentric target rings.
		var point := Vector2(cos(angle) * radius, sin(angle) * radius * 1.15)
		point.x += sin(angle * 2.0) * radius * 0.10 + (4 - ridge) * 0.9
		point.y += (4 - ridge) * 1.25
		points.append(center + (point * expansion).rotated(-0.20))
	return points
