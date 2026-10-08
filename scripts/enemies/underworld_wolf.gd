extends EnemyController
class_name UnderworldWolf
## Telegraphed leap and ghost fire; shares the normal elite lifecycle and rewards.
const FRAMES: SpriteFrames = preload("res://assets/sprites/enemies/underworld_wolf/wolf_sprite_frames.tres")
static var FRAME_TRANSFORMS: Dictionary = FRAMES.get_meta("frame_transforms")
static var SEQUENCES: Dictionary = FRAMES.get_meta("animation_sequences")
const GHOST_FLAME = preload("res://scripts/enemies/underworld_wolf_flame.gd")
const KNOCKBACK = preload("res://scripts/player/enemy_knockback.gd")

var profile: Dictionary
var state := "spawn"
var state_time := 0.0
var breath_cooldown := 1.5
var leap_cooldown := 2.0
var locked_point := Vector2.ZERO
var leap_origin := Vector2.ZERO
var animation: StringName = &"idle"
var animation_time := 0.0
var animation_index := 0
var damage_events := 0
var floor_art: Node2D
var flame: Node2D
var push_controller: PlayerEnemyKnockback
var breath_origin := Vector2.ZERO
var breath_direction := Vector2.RIGHT
var breath_hits := 0
var breath_pulses := 0
var breath_shape := ConvexPolygonShape2D.new()
var breath_polygon := PackedVector2Array()
var impact_time := 0.0
var air_height := 0.0


class GroundArt extends Node2D:
	var owner_wolf: Node2D
	func _draw() -> void:
		if is_instance_valid(owner_wolf): owner_wolf.draw_ground(self)


func _ready() -> void:
	floor_art = GroundArt.new()
	floor_art.owner_wolf = self
	floor_art.z_index = -1
	add_child(floor_art)
	flame = GHOST_FLAME.new()
	add_child(flame)
	flame.hide()
	super._ready()


func initialize(id: String, player: PlayerController = null, modifiers: Array = []) -> bool:
	_clear_skill_effects()
	if not super.initialize(id, player, modifiers): return false
	profile = enemy_data.wolf_profile
	# Configuration stores integer milliseconds/percent, like the other enemies.
	var times := {"spawn_seconds":"spawn_warning_ms", "breath_tick_seconds":"breath_tick_ms",
		"breath_charge":"breath_charge_ms", "breath_seconds":"breath_duration_ms",
		"breath_recover":"breath_recover_ms", "breath_cooldown":"breath_cooldown_ms",
		"breath_knockback_seconds":"breath_knockback_ms", "leap_charge":"leap_charge_ms",
		"leap_seconds":"leap_duration_ms", "land_seconds":"landing_ms",
		"leap_recover":"leap_recover_ms", "leap_cooldown":"leap_cooldown_ms",
		"leap_knockback_seconds":"leap_knockback_ms"}
	profile = profile.duplicate(true)
	for key: String in times: profile[key] = float(profile[times[key]])/1000.0
	profile.control_multiplier = float(profile.control_duration_percent)/100.0
	push_controller = null
	if is_instance_valid(player):
		push_controller = player.get_node_or_null("EnemyKnockback") as PlayerEnemyKnockback
		if push_controller == null:
			push_controller = KNOCKBACK.new()
			push_controller.name = "EnemyKnockback"
			push_controller.player = player
			player.add_child(push_controller)
	breath_polygon = PackedVector2Array([Vector2.ZERO])
	var half_angle := deg_to_rad(float(profile.breath_cone_degrees))*0.5
	for i in 49:
		breath_polygon.append(Vector2.from_angle(lerpf(-half_angle,half_angle,i/48.0))*float(profile.breath_range))
	breath_shape.points = breath_polygon
	alive = true
	state = "spawn"
	state_time = 0.0
	air_height = 0.0
	animation_time = 0.0
	breath_cooldown = 1.5
	leap_cooldown = 2.0
	breath_hits = 0
	breath_pulses = 0
	damage_events = 0
	sprite.visible = false
	floor_art.show()
	set_animation(&"idle")
	return true


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	super._physics_process(delta)
	if not alive: return
	impact_time = maxf(0,impact_time-delta)
	if not has_status("stunned") and not has_status("frozen") and not has_status("blinded"):
		animate(delta)
	queue_redraw()
	if is_instance_valid(floor_art): floor_art.queue_redraw()


func _process_special_behavior(delta: float) -> bool:
	state_time += delta
	if state == "spawn":
		velocity = Vector2.ZERO
		if state_time >= float(profile.spawn_seconds):
			transition("chase", &"idle")
			sprite.visible = true
		return true
	if not is_instance_valid(target_player) or not target_player.is_alive():
		_clear_skill_effects()
		transition("chase", &"idle")
		return true
	if state == "chase":
		breath_cooldown = maxf(0, breath_cooldown - delta)
		leap_cooldown = maxf(0, leap_cooldown - delta)
		var distance := global_position.distance_to(target_player.global_position)
		if mouth_position().distance_to(target_player.global_position) <= float(profile.breath_range) and breath_cooldown <= 0:
			return begin_skill("breath")
		if distance >= float(profile.leap_min_range) and distance <= float(profile.leap_max_range) and leap_cooldown <= 0:
			return begin_skill("leap")
		return false
	velocity = Vector2.ZERO
	match state:
		"breath_charge":
			if state_time + 0.00001 >= float(profile.breath_charge):
				transition("breath", &"breath")
				flame.show()
				flame.global_position = breath_origin
				flame.configure(breath_direction,float(profile.breath_range),float(profile.breath_cone_degrees),0)
				try_breath_pulse()
		"breath":
			flame.configure(breath_direction,float(profile.breath_range),float(profile.breath_cone_degrees),state_time)
			while breath_pulses < int(profile.breath_max_hits) and state_time + 0.00001 >= breath_pulses*float(profile.breath_tick_seconds):
				try_breath_pulse()
			if state_time + 0.00001 >= float(profile.breath_seconds):
				flame.hide()
				transition("breath_recover", &"idle")
		"breath_recover":
			if state_time + 0.00001 >= float(profile.breath_recover):
				breath_cooldown = float(profile.breath_cooldown)
				leap_cooldown = maxf(leap_cooldown, 0.8)
				transition("chase", &"idle")
		"leap_charge":
			if state_time + 0.00001 >= float(profile.leap_charge):
				add_collision_exception_with(target_player)
				transition("leap", &"leap")
		"leap":
			var progress := clampf(state_time / float(profile.leap_seconds), 0, 1)
			var desired := leap_origin.lerp(locked_point, progress)
			# Collides with arena walls; contact with the player is ignored in air.
			move_and_collide(desired - global_position)
			air_height = sin(progress * PI) * 66.0
			if progress >= 1.0 - 0.00001:
				remove_collision_exception_with(target_player)
				air_height = 0.0
				transition("land", &"land")
				impact_time = 0.3
				# Damage and warning share the locked point. Never silently retarget.
				if global_position.distance_to(locked_point) <= 4:
					area_damage(locked_point, float(profile.leap_radius), roundi(get_stat("element_damage")))
		"land":
			if state_time + 0.00001 >= float(profile.land_seconds): transition("recover", &"idle")
		"recover":
			if state_time + 0.00001 >= float(profile.leap_recover):
				leap_cooldown = float(profile.leap_cooldown)
				breath_cooldown = maxf(breath_cooldown, 0.8)
				transition("chase", &"idle")
	return true


func begin_skill(kind: String) -> bool:
	if not alive or state != "chase" or not is_instance_valid(target_player) or not target_player.is_alive(): return false
	var distance := global_position.distance_to(target_player.global_position)
	if kind == "leap" and (leap_cooldown > 0 or distance < float(profile.leap_min_range) or distance > float(profile.leap_max_range)): return false
	if kind == "breath" and (breath_cooldown > 0 or mouth_position().distance_to(target_player.global_position) > float(profile.breath_range)): return false
	if kind not in ["leap", "breath"]: return false
	locked_point = target_player.global_position
	leap_origin = global_position
	sprite.flip_h = locked_point.x < global_position.x
	if kind == "breath":
		breath_origin = mouth_position()
		breath_direction = breath_origin.direction_to(target_player.global_position)
		if breath_direction.is_zero_approx(): breath_direction = Vector2.RIGHT
		breath_hits = 0
		breath_pulses = 0
	_knockback_timer = 0
	velocity = Vector2.ZERO
	transition(kind + "_charge", StringName(kind + "_charge"))
	return true


func mouth_position() -> Vector2:
	var left := is_instance_valid(target_player) and target_player.global_position.x < global_position.x
	# Attachment measured from the supplied attack-04 open-mouth pose.
	return global_position + Vector2(-48 if left else 48,-54)


func try_breath_pulse() -> void:
	breath_pulses += 1
	if breath_hits >= int(profile.breath_max_hits) or not is_instance_valid(target_player) or not target_player.alive: return
	var body := target_player.get_node("CollisionShape2D") as CollisionShape2D
	if body.disabled or not breath_shape.collide(Transform2D(breath_direction.angle(),breath_origin),body.shape,body.global_transform): return
	var dealt := target_player.take_damage(roundi(get_stat("ranged_damage")*(1.0+get_stat("damage_percent")/100.0)),enemy_id+"_breath")
	if dealt > 0:
		breath_hits += 1
		damage_events += 1
		has_contact_damaged = true
		contact_damaged.emit(target_player,dealt)
		push_controller.impulse(self,breath_direction,float(profile.breath_knockback_speed),float(profile.breath_knockback_seconds))


func area_damage(center: Vector2, radius: float, amount: int) -> void:
	if not is_instance_valid(target_player) or not target_player.is_alive(): return
	# Compare the warning disk with the player's real capsule, not its origin.
	var body := target_player.get_node("CollisionShape2D") as CollisionShape2D
	if body.disabled: return
	var capsule := body.shape as CapsuleShape2D
	var half_segment := maxf(0, capsule.height * 0.5 - capsule.radius)
	var nearest := Geometry2D.get_closest_point_to_segment(center, body.to_global(Vector2(0,-half_segment)), body.to_global(Vector2(0,half_segment)))
	var body_radius := capsule.radius * maxf(absf(body.global_scale.x),absf(body.global_scale.y))
	if nearest.distance_to(center) > radius + body_radius: return
	var dealt := target_player.take_damage(roundi(amount * (1.0 + get_stat("damage_percent") / 100.0)), enemy_id + "_" + state)
	if dealt > 0:
		damage_events += 1
		has_contact_damaged = true
		contact_damaged.emit(target_player, dealt)
		var direction := center.direction_to(target_player.global_position)
		if direction.is_zero_approx(): direction = leap_origin.direction_to(locked_point)
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		push_controller.impulse(self,direction,float(profile.leap_knockback_speed),float(profile.leap_knockback_seconds))


func transition(next: String, action: StringName) -> void:
	state = next
	state_time = 0
	set_animation(action)


func set_animation(action: StringName) -> void:
	if animation != action:
		animation = action
		animation_time = 0
	animate(0)


func animate(delta: float) -> void:
	if sprite == null: return
	animation_time += delta
	var count := FRAMES.get_frame_count(animation)
	var index := int(animation_time * FRAMES.get_animation_speed(animation) + 0.00001)
	animation_index = index % count if FRAMES.get_animation_loop(animation) else mini(index, count-1)
	sprite.texture = FRAMES.get_frame_texture(animation, animation_index)
	var sequence: Array = SEQUENCES[animation]
	var record: Dictionary = FRAME_TRANSFORMS[str(sequence[0])+":"+str(int(sequence[1][animation_index]))]
	# Undo Picxel's per-pose fit in the shared original coordinate system.
	# Mirroring includes the registered offset; gameplay air height is separate.
	sprite.scale = Vector2.ONE*float(record.sprite_scale)
	var offset: Array = record.sprite_offset
	sprite.position = Vector2(float(offset[0])*(-1 if sprite.flip_h else 1),float(offset[1])-air_height)


func _set_movement_visual(moving: bool, _delta: float) -> void:
	if state == "chase": set_animation(&"move" if moving else &"idle")


func get_control_multiplier() -> float:
	return float(profile.get("control_multiplier", 0.25))


func can_be_pushed_by_wind() -> bool:
	return false


func _on_control_interrupted() -> void:
	# Timers and animation pause together; resume the already visible warning.
	pass


func take_damage(amount: int, source_id: String = "", critical: bool = false, direction: Vector2 = Vector2.ZERO, components: Array[int] = [], light: bool = true) -> int:
	if state == "spawn": return 0
	return super.take_damage(amount, source_id, critical, direction, components, light)


func _die(source_id: String = "") -> void:
	if not alive: return
	state = "dead"
	_clear_skill_effects()
	if is_instance_valid(floor_art): floor_art.hide()
	queue_redraw()
	super._die(source_id)


func _clear_skill_effects() -> void:
	if is_instance_valid(flame): flame.hide()
	if is_instance_valid(target_player): remove_collision_exception_with(target_player)
	if is_instance_valid(push_controller): push_controller.cancel_source(self)
	air_height = 0.0
	impact_time = 0.0
	velocity = Vector2.ZERO
	_knockback_timer = 0.0


func fade_out_and_free() -> void:
	alive = false
	state = "dead"
	_clear_skill_effects()
	if is_instance_valid(floor_art): floor_art.hide()
	queue_redraw()
	super.fade_out_and_free()


func _exit_tree() -> void:
	_clear_skill_effects()
	super._exit_tree()


func draw_ground(canvas: Node2D) -> void:
	if not alive: return
	canvas.draw_set_transform(Vector2(0,-2),0,Vector2(1,0.3))
	canvas.draw_circle(Vector2.ZERO, 33.6, Color(0.02,0.04,0.08,0.28))
	canvas.draw_set_transform(Vector2.ZERO)
	if state == "spawn":
		canvas.draw_arc(Vector2.ZERO,36,0,TAU,64,Color(0.5,0.85,1,0.55),2)
	if state in ["breath_charge","breath"]:
		canvas.draw_set_transform(breath_origin-global_position,breath_direction.angle())
		canvas.draw_colored_polygon(breath_polygon,Color(1,0.19,0.13,0.12 if state == "breath_charge" else 0.04))
		var outline := PackedVector2Array(breath_polygon)
		outline.append(Vector2.ZERO)
		canvas.draw_polyline(outline,Color(1,0.43,0.27,0.8 if state == "breath_charge" else 0.45),1.5)
		if state == "breath_charge":
			var half := deg_to_rad(float(profile.breath_cone_degrees))*0.5
			var progress := clampf(state_time/float(profile.breath_charge),0,1)
			canvas.draw_arc(Vector2.ZERO,float(profile.breath_range)+3,-half,lerpf(-half,half,progress),48,Color(1,0.8,0.48,0.95),2)
		canvas.draw_set_transform(Vector2.ZERO)
	if state in ["leap_charge", "leap"]:
		var center := locked_point - global_position
		var radius := float(profile.leap_radius)
		var progress := clampf(state_time / float(profile.leap_charge),0,1)
		if state == "leap": progress = 1
		canvas.draw_circle(center,radius,Color(1,0.19,0.13,0.12))
		canvas.draw_arc(center,radius,0,TAU,80,Color(1,0.38,0.26,0.78),1.5)
		canvas.draw_arc(center,radius+4,-PI*.5,-PI*.5+TAU*progress,80,Color(1,0.75,0.45,0.95),2)
		for offset in [Vector2(-7,0),Vector2(0,-7)]:
			canvas.draw_line(center+offset,center-offset,Color(1,0.55,0.4,0.8),1)
	if impact_time > 0:
		var radius := float(profile.leap_radius)
		var progress := 1.0-impact_time/0.3
		canvas.draw_arc(Vector2.ZERO,radius*(0.7+progress*.3),0,TAU,64,Color(0.45,0.9,1,1-progress),3)
		for i in 12:
			var pos := Vector2.from_angle(i*TAU/12)*(radius*(0.6+progress*.5))
			canvas.draw_rect(Rect2(pos-Vector2(2,2),Vector2(4,4)),Color(0.5,0.9,1,1-progress))


func _draw() -> void:
	if not alive or state == "spawn": return
	var y := -113.6 - air_height
	draw_rect(Rect2(-25.6,y,51.2,4),Color("243232"))
	draw_rect(Rect2(-25.6,y,51.2*clampf(float(current_hp)/get_stat("max_hp"),0,1),4),Color("8cddf0"))
