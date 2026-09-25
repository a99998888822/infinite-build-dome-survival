extends EnemyController
class_name EliteRusher

const FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/elite_rusher/elite_rusher_sprite_frames.tres")
const BODY_SCALE := 0.7
const CONTROL_MULTIPLIER := 0.1

var skill_state: String = "spawn"
var _state_time: float = 0.0
var _cooldown: float = 2.0
var _direction: Vector2 = Vector2.RIGHT
var _origin: Vector2 = Vector2.ZERO
var _travelled: float = 0.0
var _dash_hit: bool = false
var _animation: StringName = &"idle"
var _animation_time: float = 0.0
var _profile: Dictionary = {}


func initialize(id: String, player: PlayerController = null, modifiers: Array = []) -> bool:
	_profile = DataRegistry.get_record("enemies", id).get("elite_profile", {})
	var ranked := modifiers.duplicate(true)
	var factors := {"armor": float(_profile.get("armor_multiplier", 2)), "melee_damage": float(_profile.get("contact_damage_percent", 115)) / 100.0}
	for stat in factors:
		ranked.append({"id": "elite_rank_" + stat, "source_type": "enemy", "source_id": id, "target_scope": "enemy", "stat": stat, "operation": Modifier.OPERATION_MULTIPLY, "value": factors[stat], "duration": -1, "stack_rule": "unique"})
	if not super.initialize(id, player, ranked):
		return false
	_profile = enemy_data.get("elite_profile", {})
	skill_state = "spawn"
	_state_time = 0.0
	_cooldown = float(_profile.get("first_dash_delay_ms", 2000)) / 1000.0
	if sprite != null:
		sprite.visible = false
	_set_animation(&"idle")
	return true


func get_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	var value := super.get_stat(stat_id, fallback_base_value)
	# Use the rounded same-wave normal HP as the rank baseline.
	if stat_id == "max_hp":
		value *= float(enemy_data.get("elite_profile", {}).get("hp_multiplier", 20))
	return value


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	super._physics_process(delta)
	if not alive:
		return
	if not has_status("frozen") and not has_status("stunned") and not has_status("blinded"):
		_animate(delta)
	queue_redraw()


func _process_special_behavior(delta: float) -> bool:
	_state_time += delta
	if skill_state == "spawn":
		velocity = Vector2.ZERO
		if _state_time >= float(_profile.get("spawn_warning_ms", 750)) / 1000.0:
			skill_state = "chase"
			_state_time = 0.0
			sprite.visible = true
		return true
	if not is_instance_valid(target_player) or not target_player.is_alive():
		cancel_skill()
		return false
	if skill_state == "windup":
		velocity = Vector2.ZERO
		if _state_time >= float(_profile.get("windup_ms", 800)) / 1000.0:
			skill_state = "dash"
			_state_time = 0.0
			_set_animation(&"dash")
		return true
	if skill_state == "dash":
		var distance := float(_profile.get("dash_distance", 240))
		var duration := maxf(float(_profile.get("dash_ms", 400)) / 1000.0, 0.01)
		var step := minf(distance - _travelled, distance / duration * delta)
		var previous := _travelled
		var collision := move_and_collide(_direction * maxf(step, 0.0))
		_travelled = maxf(0.0, (global_position - _origin).dot(_direction))
		_try_dash_damage(previous, _travelled)
		if collision != null or _travelled >= distance - 0.01:
			skill_state = "recover"
			_state_time = 0.0
			_set_animation(&"recover")
		return true
	if skill_state == "recover":
		velocity = Vector2.ZERO
		if _state_time >= float(_profile.get("recover_ms", 500)) / 1000.0:
			cancel_skill()
		return true
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= 0.0:
		start_dash()
		return true
	return false


func start_dash() -> void:
	if not alive or not is_instance_valid(target_player):
		return
	# Stagger windups across elites; do not overlap their start times.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EliteRusher and node != self and node.skill_state == "windup" and node._state_time < 0.35:
			_cooldown = 0.35
			return
	_origin = global_position
	_direction = global_position.direction_to(target_player.global_position)
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	_travelled = 0.0
	_dash_hit = false
	_state_time = 0.0
	_knockback_timer = 0.0
	velocity = Vector2.ZERO
	skill_state = "windup"
	sprite.flip_h = _direction.x < 0.0
	_set_animation(&"windup")
	queue_redraw()


func cancel_skill() -> void:
	if skill_state == "spawn":
		return
	skill_state = "chase"
	_state_time = 0.0
	_cooldown = float(_profile.get("cooldown_ms", 6000)) / 1000.0
	_knockback_timer = 0.0
	velocity = Vector2.ZERO
	_set_animation(&"idle")
	queue_redraw()


func _on_control_interrupted() -> void:
	# Briefly pause the current action; resistance must not turn a short stun into
	# cancelling an entire dash and restarting its six-second cooldown.
	pass


func get_control_multiplier() -> float:
	return CONTROL_MULTIPLIER


func can_be_pushed_by_wind() -> bool:
	return false


func _try_dash_damage(from_distance: float, to_distance: float) -> void:
	if _dash_hit:
		return
	var local := (target_player.global_position - _origin).rotated(-_direction.angle())
	var half_width := float(_profile.get("dash_half_width", 32))
	var rect := Rect2(from_distance - half_width, -half_width, to_distance - from_distance + half_width * 2.0, half_width * 2.0)
	var closest := local.clamp(rect.position, rect.end)
	var player_radius := 0.0
	var shape := target_player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		player_radius = shape.shape.radius * maxf(absf(shape.global_scale.x), absf(shape.global_scale.y))
	if local.distance_squared_to(closest) > player_radius * player_radius:
		return
	_dash_hit = true
	var damage := roundi(get_stat("melee_damage") * (1.0 + get_stat("damage_percent") / 100.0) * float(_profile.get("dash_damage_percent", 120)) / 100.0)
	var dealt := target_player.take_damage(damage, enemy_id + "_dash")
	if dealt > 0:
		has_contact_damaged = true
		contact_damaged.emit(target_player, dealt)


func take_damage(raw_damage: int, source_id: String = "", is_critical: bool = false, hit_direction: Vector2 = Vector2.ZERO, damage_components: Array[int] = [], allow_light_bonus: bool = true) -> int:
	if skill_state == "spawn":
		return 0
	return super.take_damage(raw_damage, source_id, is_critical, hit_direction, damage_components, allow_light_bonus)


func _set_movement_visual(is_moving: bool, _delta: float) -> void:
	if skill_state in ["spawn", "chase"]:
		_set_animation(&"move" if is_moving else &"idle")


func _set_animation(animation: StringName) -> void:
	if _animation != animation:
		_animation = animation
		_animation_time = 0.0
	_animate(0.0)


func _animate(delta: float) -> void:
	if sprite == null:
		return
	_animation_time += delta
	var speed := FRAMES.get_animation_speed(_animation)
	var total := 0.0
	for index in FRAMES.get_frame_count(_animation):
		total += FRAMES.get_frame_duration(_animation, index) / speed
	var time := fmod(_animation_time, total) if FRAMES.get_animation_loop(_animation) else minf(_animation_time, total - 0.0001)
	for index in FRAMES.get_frame_count(_animation):
		time -= FRAMES.get_frame_duration(_animation, index) / speed
		if time < 0.0:
			sprite.texture = FRAMES.get_frame_texture(_animation, index)
			return


func fade_out_and_free() -> void:
	alive = false
	skill_state = "dead"
	velocity = Vector2.ZERO
	queue_redraw()
	super.fade_out_and_free()


func _die(_source_id: String = "") -> void:
	alive = false
	skill_state = "dead"
	velocity = Vector2.ZERO
	set_physics_process(false)
	queue_redraw()
	died.emit(self, get_drop_table_id(), global_position)
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	sprite.modulate = _base_sprite_modulate
	_set_animation(&"death")
	var tween := create_tween()
	tween.tween_method(_show_death_frame, 0.0, 1.2, 1.2)
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_FADE_SECONDS)
	tween.tween_callback(queue_free)


func _show_death_frame(time: float) -> void:
	_animation_time = time
	_animate(0.0)


func _draw() -> void:
	if not alive:
		return
	if skill_state == "windup":
		var half_width := float(_profile.get("dash_half_width", 32))
		draw_set_transform(_origin - global_position, _direction.angle())
		draw_rect(Rect2(-half_width, -half_width, float(_profile.get("dash_distance", 240)) + half_width * 2.0, half_width * 2.0), Color(1.0, 59.0 / 255.0, 48.0 / 255.0, 0.3))
		draw_set_transform(Vector2.ZERO)
	if skill_state == "spawn":
		draw_rect(Rect2(Vector2(-32, -20) * BODY_SCALE, Vector2(64, 40) * BODY_SCALE), Color(0.8, 0.65, 0.35, 0.3))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * BODY_SCALE)
		draw_rect(Rect2(-26, -72, 52, 4), Color("243232"))
		draw_rect(Rect2(-26, -72, 52 * clampf(float(current_hp) / maxf(get_stat("max_hp"), 1.0), 0.0, 1.0), 4), Color("dbc584"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -83), Vector2(4, -79), Vector2(0, -75), Vector2(-4, -79)]), Color("dbc584"))
		draw_set_transform(Vector2.ZERO)
