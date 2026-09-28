extends EnemyController
class_name EliteRusher

const FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/iron_knight/iron_knight_sprite_frames.tres")
const BODY_SCALE := 0.7
const CONTROL_MULTIPLIER := 0.1

var skill_state: String = "spawn"
var _state_time: float = 0.0
var _cooldown: float = 2.0
var _direction: Vector2 = Vector2.RIGHT
var _origin: Vector2 = Vector2.ZERO
var _travelled: float = 0.0
var _dash_hit: bool = false
var _dash_blocked: bool = false
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
		var duration := maxf(float(_profile.get("dash_ms", 160)) / 1000.0, 0.01)
		if not _dash_blocked:
			var step := minf(distance - _travelled, distance / duration * delta)
			var previous := _travelled
			var collision := move_and_collide(_direction * maxf(step, 0.0))
			_travelled = clampf((global_position - _origin).dot(_direction), 0.0, distance)
			_try_dash_damage(previous, _travelled)
			_dash_blocked = collision != null
		# A collision stops travel, but the hammer still completes its fast swing.
		if _state_time >= duration - 0.000001:
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
		return start_dash()
	return false


func start_dash() -> bool:
	if not alive or skill_state != "chase" or _cooldown > 0.0:
		return false
	if not is_instance_valid(target_player) or not target_player.is_alive():
		return false
	var distance := float(_profile.get("dash_distance", 240))
	if global_position.distance_squared_to(target_player.global_position) > distance * distance:
		return false
	# Stagger windups across elites; do not overlap their start times.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EliteRusher and node != self and node.skill_state == "windup" and node._state_time < 0.35:
			_cooldown = 0.35
			return false
	_origin = global_position
	_direction = global_position.direction_to(target_player.global_position)
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	_travelled = 0.0
	_dash_hit = false
	_dash_blocked = false
	_state_time = 0.0
	_knockback_timer = 0.0
	velocity = Vector2.ZERO
	skill_state = "windup"
	sprite.flip_h = _direction.x < 0.0
	_set_animation(&"windup")
	queue_redraw()
	return true


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
	var half_width := float(_profile.get("dash_half_width", 22.4))
	var rect := Rect2(from_distance - half_width, -half_width, to_distance - from_distance + half_width * 2.0, half_width * 2.0)
	if not _sweep_overlaps_player(rect):
		return
	_dash_hit = true
	var damage := roundi(get_stat("melee_damage") * (1.0 + get_stat("damage_percent") / 100.0) * float(_profile.get("dash_damage_percent", 120)) / 100.0)
	var dealt := target_player.take_damage(damage, enemy_id + "_dash")
	if dealt > 0:
		has_contact_damaged = true
		contact_damaged.emit(target_player, dealt)


func _sweep_overlaps_player(rect: Rect2) -> bool:
	# Compare the entire travelled segment, including the player's actual capsule.
	var first := target_player.global_position
	var second := first
	var radius := 0.0
	var body := target_player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body != null and not body.disabled:
		first = body.global_position
		second = first
		var scale_factor := maxf(absf(body.global_scale.x), absf(body.global_scale.y))
		if body.shape is CapsuleShape2D:
			var capsule := body.shape as CapsuleShape2D
			var half_segment := maxf(0.0, capsule.height * 0.5 - capsule.radius)
			first = body.to_global(Vector2(0.0, -half_segment))
			second = body.to_global(Vector2(0.0, half_segment))
			radius = capsule.radius * scale_factor
		elif body.shape is CircleShape2D:
			radius = (body.shape as CircleShape2D).radius * scale_factor
	first = (first - _origin).rotated(-_direction.angle())
	second = (second - _origin).rotated(-_direction.angle())
	var radius_squared := radius * radius
	for point in [first, second]:
		if point.distance_squared_to(point.clamp(rect.position, rect.end)) <= radius_squared:
			return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in 4:
		var corner: Vector2 = corners[index]
		if corner.distance_squared_to(Geometry2D.get_closest_point_to_segment(corner, first, second)) <= radius_squared:
			return true
		if Geometry2D.segment_intersects_segment(first, second, corner, corners[(index + 1) % 4]) != null:
			return true
	return false


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
	# Skill time also pauses under control effects. Normalize to the configured
	# duration so faster dashes cannot leave a slow hammer animation behind.
	var duration_key := {&"windup": "windup_ms", &"dash": "dash_ms", &"recover": "recover_ms"}
	if duration_key.has(_animation):
		var configured := maxf(float(_profile.get(duration_key[_animation], total * 1000.0)) / 1000.0, 0.001)
		_animation_time = clampf(_state_time / configured, 0.0, 1.0) * total
	var time := fmod(_animation_time, total) if FRAMES.get_animation_loop(_animation) else minf(_animation_time, total - 0.0001)
	time += 0.0000001
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
	if not alive:
		return
	alive = false
	skill_state = "dead"
	velocity = Vector2.ZERO
	set_physics_process(false)
	queue_redraw()
	died.emit(self, get_drop_table_id(), global_position)
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	sprite.modulate = _base_sprite_modulate
	# No death poses were supplied. Keep the current approved pose and fade it.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_FADE_SECONDS)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if not alive:
		return
	if skill_state == "windup":
		_draw_dash_telegraph()
	if skill_state == "spawn":
		draw_rect(Rect2(Vector2(-32, -20) * BODY_SCALE, Vector2(64, 40) * BODY_SCALE), Color(0.8, 0.65, 0.35, 0.3))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * BODY_SCALE)
		draw_rect(Rect2(-26, -118, 52, 4), Color("243232"))
		draw_rect(Rect2(-26, -118, 52 * clampf(float(current_hp) / maxf(get_stat("max_hp"), 1.0), 0.0, 1.0), 4), Color("dbc584"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -129), Vector2(4, -125), Vector2(0, -121), Vector2(-4, -125)]), Color("dbc584"))
		draw_set_transform(Vector2.ZERO)


func _draw_dash_telegraph() -> void:
	var half_width := float(_profile.get("dash_half_width", 22.4))
	var length := float(_profile.get("dash_distance", 240)) + half_width * 2.0
	var progress := clampf(_state_time / maxf(float(_profile.get("windup_ms", 800)) / 1000.0, 0.001), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(progress * TAU * 2.0)
	var fill_alpha := float(_profile.get("telegraph_fill_percent", 12)) / 100.0
	var edge_alpha := lerpf(float(_profile.get("telegraph_edge_min_percent", 42)), float(_profile.get("telegraph_edge_max_percent", 55)), pulse) / 100.0
	var particle_alpha := lerpf(float(_profile.get("telegraph_particle_min_percent", 48)), float(_profile.get("telegraph_particle_max_percent", 60)), pulse) / 100.0
	draw_set_transform(_origin - global_position, _direction.angle())
	draw_rect(Rect2(-half_width, -half_width, length, half_width * 2.0), Color(1.0, 59.0 / 255.0, 48.0 / 255.0, fill_alpha))
	for side in [-1.0, 1.0]:
		var y: float = side * half_width
		draw_line(Vector2(-half_width, y), Vector2(length - half_width, y), Color(1.0, 80.0 / 255.0, 65.0 / 255.0, edge_alpha), 1.0)
		draw_line(Vector2(-half_width, y - side), Vector2(length - half_width, y - side), Color(1.0, 60.0 / 255.0, 50.0 / 255.0, 0.18), 1.0)
		for index in ceili(length / 21.0):
			if (index + int(progress * 8.0)) % 3 != 0:
				continue
			var x := -half_width + fposmod(index * 21.0 + progress * 46.0, maxf(length - 3.0, 1.0))
			var top := y if side < 0.0 else y - 2.0
			draw_rect(Rect2(x, top, 3.0, 2.0), Color(1.0, 125.0 / 255.0, 99.0 / 255.0, particle_alpha))
	draw_set_transform(Vector2.ZERO)
