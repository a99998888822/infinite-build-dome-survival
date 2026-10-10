extends Node
## Review-gated sprite response. Never moves the body or changes damage/control.
const IMPACT = preload("res://scripts/effects/combat_impact_r02.gd")
const META := &"combat_feedback_r02"
var enemy: Node2D
var sprite: Sprite2D
var origin := Vector2.ZERO
var base_color := Color.WHITE
var clock := 0.0
var last_sustain := -10.0
var last_visible := -10.0
var age := 1.0
var duration := 0.0
var active_kind := &""
var direction := Vector2.RIGHT
var shake := 0.0
var response_count := 0
var suppressed_count := 0


static func enabled() -> bool:
	return bool(GameGlobal.get_runtime_flag("combat_feedback_r02_review", false))


static func handles(kind: StringName) -> bool:
	return kind in [&"light", &"heavy", &"ritual", &"sustain"]


static func apply(target: Node2D, kind: StringName, incoming: Vector2, legacy_shake: float) -> void:
	var response = target.get_meta(META) if target.has_meta(META) else null
	if not is_instance_valid(response):
		response = new()
		response.enemy = target
		response.sprite = target.sprite
		response.origin = target.sprite.position
		response.base_color = target._base_sprite_modulate
		target.add_child(response)
		target.set_meta(META, response)
	response.pulse(kind, incoming, legacy_shake)


static func interrupt(target: Node2D) -> void:
	var response = target.get_meta(META) if target.has_meta(META) else null
	if is_instance_valid(response):
		response.restore()
		response.age = response.duration


func pulse(kind: StringName, incoming: Vector2, legacy_shake: float) -> void:
	var gap := clock - last_sustain
	if kind == &"sustain":
		last_sustain = clock
		# First contact is clear; uninterrupted fire only accents every 280 ms.
		if gap < 0.45 and clock - last_visible < 0.28:
			suppressed_count += 1
			return
	# A stream of small hits must not erase a heavy impact already in progress.
	if age < duration and ((active_kind == &"heavy" and kind != &"heavy") or (kind == &"sustain" and active_kind != &"sustain") or age < 0.025 and kind == active_kind):
		suppressed_count += 1
		return
	if enemy._visual_tween != null and enemy._visual_tween.is_valid():
		enemy._visual_tween.kill()
	restore()
	active_kind = kind
	direction = incoming.normalized() if not incoming.is_zero_approx() else Vector2.RIGHT
	shake = legacy_shake
	last_visible = clock
	age = 0.0
	duration = 0.24 if kind == &"heavy" else 0.12 if kind == &"light" else 0.16 if kind == &"ritual" else 0.08
	response_count += 1
	# Preserve the corpse fade: the response starts before take_damage calls _die.
	if kind != &"sustain" or gap >= 0.45:
		IMPACT.spawn(enemy.get_parent(), enemy.global_position + Vector2(0, -10), kind, direction)
	paint()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	clock += delta
	if not is_instance_valid(enemy) or not is_instance_valid(sprite):
		queue_free()
		return
	if not enemy.is_alive():
		# Death owns modulation and scale from this point on.
		sprite.position = origin
		set_physics_process(false)
		return
	if age >= duration:
		return
	age += delta
	if not enabled() or age >= duration:
		restore()
	else:
		paint()


func paint() -> void:
	var p := clampf(age / duration, 0, 1)
	var kick := pow(1.0 - p, 2.0)
	var displacement := 4.0 if active_kind == &"heavy" else 2.0 if active_kind == &"light" else 0.0
	var recoil := kick if p < 0.45 else -sin((p - 0.45) / 0.55 * PI) * 0.15
	sprite.position = origin + (direction * displacement * recoil).round()
	sprite.rotation = shake * (1.6 if active_kind == &"heavy" else 0.55 if active_kind == &"light" else 0.0) * recoil
	var strength := 0.55 if active_kind == &"heavy" else 0.38 if active_kind == &"light" else 0.30 if active_kind == &"ritual" else 0.13
	var flash := 1.0 - clampf(age / (0.075 if active_kind == &"heavy" else 0.05), 0, 1)
	sprite.modulate = base_color.lerp(Color(1.0 + strength, 1.0 + strength, 1.0 + strength, base_color.a), flash)


func restore() -> void:
	if is_instance_valid(sprite):
		sprite.position = origin
		sprite.rotation = 0.0
		sprite.modulate = base_color
