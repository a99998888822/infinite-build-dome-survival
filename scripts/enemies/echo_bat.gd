extends EnemyController
class_name EchoBat
## Ranged bat; shares the ordinary wave spawn pool with the original small enemy.

signal sonic_fired(projectile: Node2D)

const MOVE := preload("res://assets/sprites/enemies/echo_bat/move.png")
const ATTACK := preload("res://assets/sprites/enemies/echo_bat/attack.png")
const WARNING := preload("res://assets/sprites/enemies/echo_bat/sonic_warning.png")
const CHARGE := preload("res://assets/sprites/enemies/echo_bat/sonic_charge.png")
const SONIC := preload("res://scripts/enemies/echo_bat_sonic.gd")
const FLAP := [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]
# Lip opening on the approved 128px release frame. The warning and projectile
# share this socket, so the locked path still starts at the mouth on release.
const MOUTH_PIXEL := Vector2(83, 60)
const FRAME_CENTER := Vector2(64, 64)

var skill_state := "move"
var state_time := 0.0
var cooldown := 1.0
var profile: Dictionary = {}
var warning: Sprite2D
var charge: Sprite2D
var aim_direction := Vector2.RIGHT
var shot_origin := Vector2.ZERO
var _flap_time := 0.0
var _step_delta := 1.0 / 60.0


func _ready() -> void:
	warning = Sprite2D.new()
	warning.texture = WARNING
	warning.centered = false
	warning.top_level = true
	warning.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	warning.z_index = -1
	warning.hide()
	add_child(warning)
	charge = Sprite2D.new()
	charge.texture = CHARGE
	charge.hframes = 6
	charge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	charge.scale = Vector2.ONE * 0.52
	charge.hide()
	add_child(charge)
	super._ready()


func initialize(id: String, player: PlayerController = null, modifiers: Array = []) -> bool:
	if not super.initialize(id, player, modifiers): return false
	profile = enemy_data.get("bat_profile", {})
	skill_state = "move"
	state_time = 0.0
	cooldown = 1.0
	_flap_time = 0.0
	return true


func attack_range() -> float:
	return float(profile.get("attack_range", 320.0))


func mouth_position() -> Vector2:
	var local_socket := MOUTH_PIXEL - FRAME_CENTER
	if sprite.flip_h: local_socket.x = -local_socket.x
	return sprite.to_global(local_socket)


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	_step_delta = delta
	super._physics_process(delta)
	if not alive: return
	if has_status("frozen") or has_status("stunned") or has_status("blinded"): return
	if skill_state != "move": _process_contact_damage()
	_animate(delta)


func _process_special_behavior(delta: float) -> bool:
	if not is_instance_valid(target_player) or not target_player.is_alive():
		cancel_attack()
		return false
	if _knockback_timer > 0:
		if skill_state != "move": cancel_attack()
		return false
	cooldown = maxf(0.0, cooldown - delta)
	if skill_state == "move":
		var distance := global_position.distance_to(target_player.global_position)
		if cooldown <= 0 and distance >= attack_range() * 0.3 and distance <= attack_range() * 0.9:
			return begin_attack()
		return false
	velocity = Vector2.ZERO
	state_time += delta
	match skill_state:
		"charge":
			if state_time >= float(profile.get("charge_ms", 200)) / 1000.0 - 0.000001:
				skill_state = "warning"
				state_time = 0.0
				aim_direction = mouth_position().direction_to(target_player.global_position)
				if aim_direction.is_zero_approx(): aim_direction = Vector2.RIGHT
				shot_origin = mouth_position()
				warning.scale = Vector2(attack_range() / 320.0, float(profile.get("path_width", 20)) / 20.0)
				warning.global_rotation = aim_direction.angle()
				warning.global_position = shot_origin + Vector2(0, -float(profile.get("path_width", 20)) * 0.5).rotated(aim_direction.angle())
				warning.show()
		"warning":
			if state_time >= float(profile.get("warning_ms", 500)) / 1000.0 - 0.000001:
				warning.hide()
				charge.hide()
				var wave := SONIC.new()
				wave.target = target_player
				wave.direction = aim_direction
				wave.max_distance = attack_range()
				wave.speed = float(profile.get("sonic_speed", 300))
				wave.damage = maxi(1, roundi(get_stat("ranged_damage", 7) * (1.0 + get_stat("damage_percent") / 100.0)))
				# Owner-scoped lifetime also clears every projectile on wave cleanup.
				add_child(wave)
				wave.global_position = shot_origin
				sonic_fired.emit(wave)
				skill_state = "release"
				state_time = 0.0
		"release":
			if state_time >= 0.15:
				skill_state = "recover"
				state_time = 0.0
		"recover":
			if state_time >= 0.21:
				skill_state = "move"
				state_time = 0.0
	return true


func begin_attack() -> bool:
	if skill_state != "move" or not alive or not is_instance_valid(target_player): return false
	skill_state = "charge"
	state_time = 0.0
	cooldown = float(profile.get("cooldown_ms", 2400)) / 1000.0
	velocity = Vector2.ZERO
	sprite.flip_h = target_player.global_position.x < global_position.x
	charge.position = mouth_position() - global_position
	charge.show()
	return true


func cancel_attack() -> void:
	skill_state = "move"
	state_time = 0.0
	cooldown = maxf(cooldown, 0.5)
	if warning != null: warning.hide()
	if charge != null: charge.hide()


func _on_control_interrupted() -> void:
	cancel_attack()


func _process_chase() -> void:
	if not is_instance_valid(target_player) or not target_player.is_alive():
		velocity = Vector2.ZERO
		return
	var offset := target_player.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else Vector2.RIGHT
	var movement := Vector2.ZERO
	if distance > attack_range() * 0.9: movement = direction
	elif distance < attack_range() * 0.3: movement = -direction
	var speed := minf(get_stat("move_speed"), float(enemy_data.get("base_stats", {}).get("move_speed", 80)) * MAX_MOVE_SPEED_MULTIPLIER)
	if _slowed_remaining > 0: speed *= _slow_multiplier
	if _wet_remaining > 0: speed *= _wet_slow_multiplier
	velocity = velocity.move_toward(movement * speed, CHASE_ACCELERATION * _step_delta)
	if not is_zero_approx(offset.x): sprite.flip_h = offset.x < 0
	move_and_collide(velocity * _step_delta)


func _set_movement_visual(_moving: bool, _delta: float) -> void:
	# Flying in place also flaps; preserve the attack atlas during windup.
	pass


func _animate(delta: float) -> void:
	_flap_time += delta
	var index := 0
	if skill_state == "move":
		sprite.texture = MOVE
		sprite.hframes = 6
		index = FLAP[int(_flap_time * 14) % FLAP.size()]
	else:
		sprite.texture = ATTACK
		sprite.hframes = 9
		match skill_state:
			"charge": index = mini(2, int(state_time / 0.2 * 3))
			"warning": index = 3 + mini(4, int(state_time / 0.5 * 5))
			"release": index = 8
			"recover": index = 2 - mini(2, int(state_time / 0.21 * 3))
	if sprite.frame != index: sprite.frame = index
	if charge.visible: charge.frame = int(state_time * 24) % 6
	if warning.visible: warning.modulate.a = 0.78 + 0.22 * sin(state_time * TAU * 4)


func fade_out_and_free() -> void:
	cancel_attack()
	for child in get_children():
		if child is EchoBatSonic: child.queue_free()
	super.fade_out_and_free()
