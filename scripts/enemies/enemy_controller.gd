extends CharacterBody2D
class_name EnemyController

signal died(enemy: EnemyController, drop_table_id: String, global_position: Vector2)
signal contact_damaged(player: PlayerController, damage: int)
signal damage_received(source_id: String, damage: int)

const DEFAULT_ENEMY_ID: String = "enemy_mutated_grub"
const DEFAULT_KNOCKBACK_SPEED: float = 450.0
const DEFAULT_KNOCKBACK_SECONDS: float = 0.18
const CONTACT_RESET_RADIUS: float = 68.0
const CONTACT_MARGIN: float = 1.0
const CONTACT_DAMAGE_COOLDOWN_SECONDS: float = 0.55
const CONTACT_RECOVERY_SPEED: float = 180.0
const CHASE_ACCELERATION: float = 900.0
const DAMAGE_NUMBER_FONT: Font = preload("res://assets/font/VT323-Regular.ttf")
const DAMAGE_NUMBER_FONT_SIZE: int = 18
const DAMAGE_NUMBER_CRITICAL_FONT_SIZE: int = 26
const DAMAGE_NUMBER_CRITICAL_SHAKE_SECONDS: float = 0.30
const DAMAGE_NUMBER_SIZE: Vector2 = Vector2(76.0, 34.0)
const DAMAGE_NUMBER_OFFSET: Vector2 = Vector2(0.0, -36.0)
const DAMAGE_NUMBER_RISE: float = 42.0
const DAMAGE_NUMBER_ANIMATION_SECONDS: float = 0.62
const MAX_DAMAGE_NUMBERS := 160
const DAMAGE_NUMBER_POOL_META := &"_idle_damage_numbers"
static var active_damage_numbers := 0
static var _damage_number_themes: Dictionary = {}
const HIT_KNOCKBACK_SPEED: float = 60.0
const HIT_KNOCKBACK_SECONDS: float = 0.06
const MAX_MOVE_SPEED_MULTIPLIER: float = 1.3
const HIT_FLASH_SECONDS: float = 0.1
const HIT_SHAKE_ANGLE: float = 0.08
const DEATH_FADE_SECONDS: float = 0.2
const LIGHTNING_STUN_MAX_SECONDS: float = 3.0
const LIGHTNING_STATUS_VISUAL_SCRIPT: Script = preload("res://scripts/effects/lightning_status_visual.gd")
const ENEMY_STATUS_VISUAL_SCRIPT: Script = preload("res://scripts/effects/enemy_status_visual.gd")

@export var enemy_id: String = DEFAULT_ENEMY_ID
@export var auto_initialize_on_ready: bool = true
@export var knockback_speed: float = DEFAULT_KNOCKBACK_SPEED
@export var knockback_seconds: float = DEFAULT_KNOCKBACK_SECONDS
@export var idle_texture: Texture2D
@export var move_texture: Texture2D
@export_range(1, 64, 1) var move_frame_count: int = 3
@export var move_frame_duration: float = 0.14

var enemy_data: Dictionary = {}
var modifier_stack: ModifierStack = ModifierStack.new()
var current_hp: int = 0
var alive: bool = true
var has_contact_damaged: bool = false
var target_player: PlayerController = null

var _knockback_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_deceleration: float = 0.0
var _contact_damage_cooldown: float = 0.0
var status_visual_revision := 0
var _burning_remaining: float = 0.0:
	set(value):
		if (_burning_remaining > 0.0) != (value > 0.0): status_visual_revision += 1
		_burning_remaining = value
var _burn_tick_timer: float = 0.0
var _burn_damage_per_tick: float = 0.0
var _burn_damage_remainder: float = 0.0
var _burn_source_id: String = ""
var _burn_sources: Dictionary = {}
var _holy_flame: bool = false:
	set(value):
		if _holy_flame != value: status_visual_revision += 1
		_holy_flame = value
var _dark_flame: bool = false:
	set(value):
		if _dark_flame != value: status_visual_revision += 1
		_dark_flame = value
var _stunned_remaining: float = 0.0
var _slowed_remaining: float = 0.0:
	set(value):
		if (_slowed_remaining > 0.0) != (value > 0.0): status_visual_revision += 1
		_slowed_remaining = value
var _slow_multiplier: float = 1.0
var _wet_remaining: float = 0.0:
	set(value):
		if (_wet_remaining > 0.0) != (value > 0.0): status_visual_revision += 1
		_wet_remaining = value
var _wet_slow_multiplier: float = 1.0
var _frozen_remaining: float = 0.0:
	set(value):
		if (_frozen_remaining > 0.0) != (value > 0.0): status_visual_revision += 1
		_frozen_remaining = value
var _thaw_reaction_data: Dictionary = {}
var _light_freeze_reacted: bool = false
var _light_remaining: float = 0.0:
	set(value):
		if (_light_remaining > 0.0) != (value > 0.0): status_visual_revision += 1
		_light_remaining = value
var _blinded_remaining: float = 0.0:
	set(value):
		if (_blinded_remaining > 0.0) != (value > 0.0): status_visual_revision += 1
		_blinded_remaining = value
var _visual_tween: Tween = null
var _base_sprite_modulate: Color = Color.WHITE
var _base_sprite_modulate_captured: bool = false
var _lightning_visual: Node2D = null
var _is_move_animation_active: bool = false
var _move_animation_frame: int = 0
var _move_animation_timer: float = 0.0
var _contact_probe := CircleShape2D.new()
var _contact_body: CollisionShape2D
var _contact_player_body: CollisionShape2D


@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("enemies")
	EnemyRegistry.register_enemy(self)
	if idle_texture == null and sprite != null:
		idle_texture = sprite.texture
	_set_movement_visual(false, 0.0)
	_capture_base_sprite_modulate()
	var status_visual: Node = ENEMY_STATUS_VISUAL_SCRIPT.new()
	status_visual.name = "EnemyStatusVisual"
	add_child(status_visual)
	if auto_initialize_on_ready:
		initialize(enemy_id)


func _exit_tree() -> void:
	if is_instance_valid(EnemyRegistry):
		EnemyRegistry.unregister_enemy(self)


func _physics_process(delta: float) -> void:
	if not alive:
		_set_movement_visual(false, delta)
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		velocity = Vector2.ZERO
		_set_movement_visual(false, delta)
		return
	_contact_damage_cooldown = maxf(_contact_damage_cooldown - delta, 0.0)
	_process_burning(delta)
	if not alive:
		return
	_stunned_remaining = maxf(_stunned_remaining - delta, 0.0)
	_slowed_remaining = maxf(_slowed_remaining - delta, 0.0)
	_wet_remaining = maxf(_wet_remaining - delta, 0.0)
	_process_freeze(delta)
	_light_remaining = maxf(_light_remaining - delta, 0.0)
	_blinded_remaining = maxf(_blinded_remaining - delta, 0.0)
	if _wet_remaining <= 0.0:
		_wet_slow_multiplier = 1.0
	if _slowed_remaining <= 0.0:
		_slow_multiplier = 1.0
	if _stunned_remaining > 0.0 or _frozen_remaining > 0.0 or _blinded_remaining > 0.0:
		_on_control_interrupted()
		velocity = Vector2.ZERO
		_set_movement_visual(false, delta)
		return
	if _process_special_behavior(delta):
		return
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(_knockback_timer - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, _knockback_deceleration * delta)
		_knockback_velocity = velocity
		move_and_slide()
		_set_movement_visual(true, delta)
		return
	if _process_contact_recovery():
		return
	_process_chase()
	_process_contact_damage()


func _process_special_behavior(_delta: float) -> bool:
	return false


func _on_control_interrupted() -> void:
	pass


func initialize(target_enemy_id: String, player: PlayerController = null, runtime_modifiers: Array = []) -> bool:
	var data: Dictionary = DataRegistry.get_record("enemies", target_enemy_id)
	if data.is_empty():
		push_error("[EnemyController] missing enemy config: %s" % target_enemy_id)
		return false
	enemy_id = target_enemy_id
	enemy_data = data
	modifier_stack.cache_enabled = true
	modifier_stack.set_base_stats(data.get("base_stats", {}))
	_apply_runtime_modifiers(runtime_modifiers)
	current_hp = int(get_stat("max_hp"))
	target_player = player
	alive = true
	_knockback_timer = 0.0
	_knockback_velocity = Vector2.ZERO
	_knockback_deceleration = 0.0
	_contact_damage_cooldown = 0.0
	has_contact_damaged = false
	_burning_remaining = 0.0
	_burn_tick_timer = 0.0
	_burn_damage_per_tick = 0.0
	_burn_damage_remainder = 0.0
	_burn_source_id = ""
	_burn_sources.clear()
	_holy_flame = false
	_dark_flame = false
	_stunned_remaining = 0.0
	_slowed_remaining = 0.0
	_slow_multiplier = 1.0
	_wet_remaining = 0.0
	_wet_slow_multiplier = 1.0
	_frozen_remaining = 0.0
	_thaw_reaction_data.clear()
	_light_freeze_reacted = false
	_light_remaining = 0.0
	_blinded_remaining = 0.0
	return true


func set_target_player(player: PlayerController) -> void:
	target_player = player


func add_runtime_modifier(modifier_data: Dictionary) -> bool:
	var modifier: Modifier = modifier_stack.add_modifier_from_dictionary(modifier_data)
	return modifier != null


func add_runtime_modifiers(modifier_data_list: Array) -> void:
	for modifier_data in modifier_data_list:
		if modifier_data is Dictionary:
			add_runtime_modifier(modifier_data)


func _apply_runtime_modifiers(modifier_data_list: Array) -> void:
	add_runtime_modifiers(modifier_data_list)


func get_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	return modifier_stack.get_stat(stat_id, fallback_base_value)


func apply_burning(duration: float, damage_per_tick: float, source_id: String = "", holy_flame: bool = false, dark_flame: bool = false) -> void:
	if not alive:
		return
	if _burning_remaining <= 0.0:
		clear_burning()
	_burning_remaining = maxf(_burning_remaining, duration)
	# One contribution per weapon for the lifetime of this burn. Reapplication
	# refreshes the shared duration without replacing or adding its damage.
	if not _burn_sources.has(source_id):
		_burn_sources[source_id] = {"damage": maxf(damage_per_tick, 0.0), "remainder": 0.0}
		_burn_damage_per_tick += maxf(damage_per_tick, 0.0)
	_burn_source_id = source_id if _burn_sources.size() == 1 else ""
	if dark_flame:
		_dark_flame = true
		_holy_flame = false
	elif holy_flame or _light_remaining > 0.0:
		_holy_flame = true
		_dark_flame = false
	_burn_tick_timer = minf(_burn_tick_timer, 0.5) if _burn_tick_timer > 0.0 else 0.5


func apply_slow(duration: float, multiplier: float) -> void:
	if not alive:
		return
	var susceptibility := get_control_multiplier()
	_slowed_remaining = maxf(_slowed_remaining, duration * susceptibility)
	_slow_multiplier = minf(_slow_multiplier, lerpf(1.0, clampf(multiplier, 0.05, 1.0), susceptibility))


func apply_wet(duration: float = 5.0, slow_multiplier: float = 0.8) -> void:
	if not alive:
		return
	var susceptibility := get_control_multiplier()
	_wet_remaining = maxf(_wet_remaining, duration * susceptibility)
	_wet_slow_multiplier = minf(_wet_slow_multiplier, lerpf(1.0, clampf(slow_multiplier, 0.05, 1.0), susceptibility))


func clear_wet() -> void:
	_wet_remaining = 0.0
	_wet_slow_multiplier = 1.0


func apply_freeze(duration: float = 1.0, thaw_reaction_data: Dictionary = {}) -> void:
	if not alive:
		return
	if _frozen_remaining <= 0.0:
		_light_freeze_reacted = false
	_frozen_remaining = maxf(_frozen_remaining, minf(duration, 3.0) * get_control_multiplier())
	_slowed_remaining = 0.0
	_slow_multiplier = 1.0
	_thaw_reaction_data = thaw_reaction_data.duplicate()


func _process_freeze(delta: float) -> void:
	if _frozen_remaining <= 0.0:
		return
	_frozen_remaining = maxf(_frozen_remaining - delta, 0.0)
	if _frozen_remaining > 0.0:
		return
	_light_freeze_reacted = false
	if not _thaw_reaction_data.is_empty():
		var data := _thaw_reaction_data.duplicate()
		_thaw_reaction_data.clear()
		data["parent"] = get_parent()
		data["hit_position"] = global_position
		var resolver: Script = load("res://scripts/effects/element_reaction_resolver.gd")
		resolver.apply_element(self, "water", data)
		resolver.emit_feedback(get_parent(), "thaw", global_position)


func claim_light_reflection() -> bool:
	if not has_status("frozen") or not has_status("light") or _light_freeze_reacted:
		return false
	_light_freeze_reacted = true
	return true


func apply_light(duration: float = 5.0) -> void:
	if not alive:
		return
	_light_remaining = maxf(_light_remaining, minf(duration, 10.0))
	if _burning_remaining > 0.0:
		_holy_flame = true
		_dark_flame = false


func clear_light() -> void:
	_light_remaining = 0.0
	_light_freeze_reacted = false
	_holy_flame = false


func apply_blind(duration: float = 2.0) -> void:
	if not alive:
		return
	_blinded_remaining = maxf(_blinded_remaining, minf(duration, 5.0) * get_control_multiplier())
	if _burning_remaining > 0.0:
		_burning_remaining = maxf(_burning_remaining, 10.0)
		_dark_flame = true
		_holy_flame = false


func clear_blind() -> void:
	_blinded_remaining = 0.0


func get_status_visual_mask() -> int:
	# Bit order matches EnemyStatusVisual.DRAW_STATUSES; bit 7 is normal fire.
	var mask := int(_wet_remaining > 0.0) | (int(_light_remaining > 0.0) << 1)
	mask |= int(_blinded_remaining > 0.0) << 2
	mask |= int(_frozen_remaining > 0.0) << 3
	mask |= int(_slowed_remaining > 0.0) << 4
	if _burning_remaining > 0.0:
		mask |= int(_holy_flame) << 5
		mask |= int(_dark_flame) << 6
		mask |= int(not _holy_flame and not _dark_flame) << 7
	return mask


func has_status(status_id: String) -> bool:
	if status_id == "slowed":
		return _slowed_remaining > 0.0
	if status_id == "wet":
		return _wet_remaining > 0.0
	if status_id == "frozen":
		return _frozen_remaining > 0.0
	if status_id == "light":
		return _light_remaining > 0.0
	if status_id == "dark" or status_id == "blinded":
		return _blinded_remaining > 0.0
	if status_id == "burning":
		return _burning_remaining > 0.0
	if status_id == "holy_flame":
		return _burning_remaining > 0.0 and _holy_flame
	if status_id == "dark_flame":
		return _burning_remaining > 0.0 and _dark_flame
	if status_id == "stunned" or status_id == "paralyzed":
		return _stunned_remaining > 0.0
	return false


func clear_burning() -> void:
	_burning_remaining = 0.0
	_burn_tick_timer = 0.0
	_burn_damage_per_tick = 0.0
	_burn_damage_remainder = 0.0
	_burn_source_id = ""
	_burn_sources.clear()
	_holy_flame = false
	_dark_flame = false


func get_control_multiplier() -> float:
	return 1.0


func can_be_pushed_by_wind() -> bool:
	return true


func apply_knockback(hit_direction: Vector2, speed: float, duration: float) -> void:
	if not alive:
		return
	var safe_direction := hit_direction.normalized() if not hit_direction.is_zero_approx() else Vector2.RIGHT
	_knockback_velocity = safe_direction * maxf(speed, 1.0) * get_control_multiplier()
	velocity = _knockback_velocity
	var safe_duration := maxf(duration, 0.05) * get_control_multiplier()
	_knockback_deceleration = _knockback_velocity.length() / safe_duration
	_knockback_timer = maxf(_knockback_timer, safe_duration)


func apply_lightning_visual(duration: float = 0.65) -> void:
	if not alive:
		return
	if is_instance_valid(_lightning_visual):
		_lightning_visual.show()
		_lightning_visual.call("refresh", duration)
		return
	_lightning_visual = LIGHTNING_STATUS_VISUAL_SCRIPT.attach(self, duration, LIGHTNING_STATUS_VISUAL_SCRIPT)


func apply_lightning_stun(duration: float = 0.65) -> void:
	if not alive:
		return
	var resisted_duration := minf(duration, LIGHTNING_STUN_MAX_SECONDS) * get_control_multiplier()
	_stunned_remaining = maxf(_stunned_remaining, resisted_duration)
	apply_lightning_visual(resisted_duration)


func _process_burning(delta: float) -> void:
	if _burning_remaining <= 0.0:
		return
	var active_delta := minf(delta, _burning_remaining)
	_burning_remaining = maxf(_burning_remaining - delta, 0.0)
	_burn_tick_timer -= active_delta
	while _burn_tick_timer <= 0.0 and alive and not _burn_sources.is_empty():
		_burn_tick_timer += 0.5
		for source_id: String in _burn_sources.keys():
			if not alive or not _burn_sources.has(source_id):
				break
			var contribution: Dictionary = _burn_sources[source_id]
			contribution.remainder += float(contribution.damage)
			var damage := int(floor(float(contribution.remainder)))
			contribution.remainder -= damage
			if _holy_flame:
				damage *= 2
			if damage > 0:
				# Report each contribution to its own weapon, including holy fire.
				take_damage(damage, source_id, false, Vector2.ZERO, [], not _holy_flame)
	if _burning_remaining <= 0.0:
		clear_burning()


func take_damage(
	raw_damage: int,
	source_id: String = "",
	is_critical: bool = false,
	hit_direction: Vector2 = Vector2.ZERO,
	damage_components: Array[int] = [],
	allow_light_bonus: bool = true
) -> int:
	if not alive or raw_damage <= 0:
		return 0
	var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
	var light_multiplier := 1.0
	var light_amplified := false
	if allow_light_bonus and _light_remaining > 0.0:
		light_multiplier = 1.3
		light_amplified = true
		# Consume one exposure without removing the separate holy burning state.
		_light_remaining = 0.0
		_light_freeze_reacted = false
	var pre_light_damage := maxi(1, int(roundi(float(raw_damage) * damage_taken_percent / 100.0)))
	var final_damage := maxi(1, int(roundi(float(pre_light_damage) * light_multiplier)))
	current_hp = maxi(current_hp - final_damage, 0)
	# One notification after mitigation, shared by direct hits, effects and burn ticks.
	damage_received.emit(source_id, final_damage)
	if damage_components.is_empty():
		_spawn_damage_number(final_damage, is_critical, 0, 1, light_amplified, pre_light_damage)
	else:
		var display_components := _split_damage_for_display(final_damage, damage_components)
		for index in range(display_components.size()):
			_spawn_damage_number(display_components[index], is_critical, index, display_components.size(), light_amplified, roundi(display_components[index] / light_multiplier))
	_apply_hit_feedback(hit_direction)
	if current_hp <= 0:
		_die(source_id)
	return final_damage


func _split_damage_for_display(final_damage: int, damage_components: Array[int]) -> Array[int]:
	var positive_components: Array[int] = []
	var raw_total := 0
	for component_damage in damage_components:
		var safe_component := maxi(int(component_damage), 0)
		if safe_component <= 0:
			continue
		positive_components.append(safe_component)
		raw_total += safe_component
	if positive_components.is_empty() or raw_total <= 0:
		var fallback_components: Array[int] = [final_damage]
		return fallback_components

	var display_components: Array[int] = []
	var allocated := 0
	for index in range(positive_components.size()):
		var display_damage: int
		if index == positive_components.size() - 1:
			display_damage = final_damage - allocated
		else:
			display_damage = int(floor(float(final_damage * positive_components[index]) / float(raw_total)))
		if display_damage > 0:
			display_components.append(display_damage)
		allocated += display_damage
	if display_components.is_empty():
		display_components.append(final_damage)
	return display_components


func _apply_hit_feedback(hit_direction: Vector2) -> void:
	if sprite == null:
		return
	_capture_base_sprite_modulate()
	# A pending Tween reads its starting values when it first advances. Repeated
	# hits before that point only replace those values, not the animation itself.
	# Once it has advanced (or was stopped), retain the original restart behavior.
	var pending_feedback := _visual_tween != null and _visual_tween.is_valid() and _visual_tween.is_running() and _visual_tween.get_total_elapsed_time() == 0.0
	if not pending_feedback and _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	# The untinted sprite still needs a visible brightness pulse on impact.
	sprite.modulate = Color(1.35, 1.35, 1.35, _base_sprite_modulate.a)
	sprite.rotation = randf_range(-HIT_SHAKE_ANGLE, HIT_SHAKE_ANGLE)
	if not pending_feedback:
		_visual_tween = create_tween()
		_visual_tween.tween_property(sprite, "modulate", _base_sprite_modulate, HIT_FLASH_SECONDS)
		_visual_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not hit_direction.is_zero_approx():
		_apply_weapon_knockback(hit_direction)


func _capture_base_sprite_modulate() -> void:
	if sprite == null or _base_sprite_modulate_captured:
		return
	_base_sprite_modulate = sprite.modulate
	_base_sprite_modulate_captured = true


func _apply_weapon_knockback(hit_direction: Vector2) -> void:
	var safe_direction := hit_direction.normalized() if not hit_direction.is_zero_approx() else Vector2.RIGHT
	var regular_velocity := safe_direction * HIT_KNOCKBACK_SPEED * get_control_multiplier()
	if _knockback_timer <= 0.0 or _knockback_velocity.length_squared() < regular_velocity.length_squared():
		_knockback_velocity = regular_velocity
		velocity = _knockback_velocity
		var safe_duration := maxf(HIT_KNOCKBACK_SECONDS, 0.05) * get_control_multiplier()
		_knockback_deceleration = _knockback_velocity.length() / safe_duration
		_knockback_timer = maxf(_knockback_timer, safe_duration)


func fade_out_and_free() -> void:
	if not is_inside_tree():
		return
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	if sprite == null:
		queue_free()
		return
	set_physics_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_FADE_SECONDS)
	tween.tween_property(sprite, "scale", sprite.scale * 0.82, DEATH_FADE_SECONDS)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _spawn_damage_number(
	final_damage: int,
	is_critical: bool = false,
	display_index: int = 0,
	display_count: int = 1,
	light_amplified: bool = false,
	light_base_damage: int = 0
) -> void:
	# This is a display budget only. Damage, reactions and accounting have already
	# resolved. Reserve 32 slots for critical hits during dense area attacks.
	if active_damage_numbers >= (MAX_DAMAGE_NUMBERS if is_critical else MAX_DAMAGE_NUMBERS - 32):
		return
	var damage_number_parent := get_parent()
	if damage_number_parent == null or not damage_number_parent.is_inside_tree():
		return
	var damage_number := _acquire_damage_number(damage_number_parent)
	damage_number.text = str(final_damage)
	damage_number.scale = Vector2(0.84, 0.84) if not is_critical else Vector2(0.92, 0.92)
	damage_number.modulate.a = 0.0
	damage_number.theme = _get_damage_number_theme(final_damage, is_critical)
	damage_number.reset_size()
	damage_number.size = DAMAGE_NUMBER_SIZE

	active_damage_numbers += 1
	damage_number.tree_exiting.connect(EnemyController.release_damage_number, CONNECT_ONE_SHOT)
	damage_number.show()
	var spread_offset := Vector2(randf_range(-14.0, 14.0), randf_range(-4.0, 4.0))
	if display_count > 1:
		var centered_index := float(display_index) - float(display_count - 1) * 0.5
		spread_offset.x = centered_index * 30.0
	damage_number.global_position = global_position + DAMAGE_NUMBER_OFFSET + spread_offset - DAMAGE_NUMBER_SIZE * 0.5

	var target_position := damage_number.global_position + Vector2(0.0, -DAMAGE_NUMBER_RISE)
	var tween := damage_number.create_tween()
	tween.set_parallel(true)
	if is_critical:
		# One position track combines rise and shake; the label owns the tween even after a lethal hit.
		tween.tween_method(EnemyController._animate_critical_damage_number.bind(damage_number, damage_number.global_position), 0.0, DAMAGE_NUMBER_ANIMATION_SECONDS, DAMAGE_NUMBER_ANIMATION_SECONDS)
	else:
		tween.tween_property(damage_number, "global_position", target_position, DAMAGE_NUMBER_ANIMATION_SECONDS)
	tween.tween_property(damage_number, "modulate:a", 1.0, 0.10)
	tween.tween_property(damage_number, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.10)
	tween.tween_property(damage_number, "modulate:a", 0.0, 0.28)
	tween.tween_callback(_queue_recycle_damage_number.bind(damage_number))


static func _animate_critical_damage_number(elapsed: float, label: Label, origin: Vector2) -> void:
	var shake_strength := maxf(1.0 - elapsed / DAMAGE_NUMBER_CRITICAL_SHAKE_SECONDS, 0.0)
	var shake := Vector2(sin(elapsed * TAU * 14.0) * 5.0, sin(elapsed * TAU * 19.0) * 2.0) * shake_strength
	label.global_position = origin + Vector2(0.0, -DAMAGE_NUMBER_RISE * elapsed / DAMAGE_NUMBER_ANIMATION_SECONDS) + shake.round()


static func _acquire_damage_number(parent: Node) -> Label:
	var idle: Array = parent.get_meta(DAMAGE_NUMBER_POOL_META, [])
	while not idle.is_empty():
		var candidate: Variant = idle.pop_back()
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var label := candidate as Label
		# Reused numbers occupy the same painter position as newly added nodes.
		parent.move_child(label, -1)
		return label
	var label := Label.new()
	label.name = "DamageNumber"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	label.pivot_offset = DAMAGE_NUMBER_SIZE * 0.5
	parent.add_child(label)
	return label


static func _queue_recycle_damage_number(label: Label) -> void:
	# Match queue_free's end-of-frame budget release, after tween processing.
	_recycle_damage_number.call_deferred(label)


static func _recycle_damage_number(label: Variant) -> void:
	if not is_instance_valid(label) or label.is_queued_for_deletion():
		return
	if not label.tree_exiting.is_connected(EnemyController.release_damage_number):
		return
	label.tree_exiting.disconnect(EnemyController.release_damage_number)
	release_damage_number()
	label.hide()
	var parent: Node = label.get_parent()
	if parent == null or parent.is_queued_for_deletion():
		label.queue_free()
		return
	if not parent.has_meta(DAMAGE_NUMBER_POOL_META):
		parent.set_meta(DAMAGE_NUMBER_POOL_META, [])
	var idle: Array = parent.get_meta(DAMAGE_NUMBER_POOL_META)
	# The combat parent owns the pool and frees it when the encounter exits.
	if idle.size() < MAX_DAMAGE_NUMBERS:
		idle.append(label)
	else:
		label.queue_free()


static func release_damage_number() -> void:
	active_damage_numbers = maxi(0, active_damage_numbers - 1)


func _get_damage_number_theme(final_damage: int, is_critical: bool) -> Theme:
	# Four magnitude colors and two font/outline sizes: at most eight themes.
	var key := Vector2i(int(is_critical), clampi(ceili(str(absi(final_damage)).length() / 2.0), 1, 4))
	if _damage_number_themes.has(key): return _damage_number_themes[key]
	var style := Theme.new()
	style.set_font("font", "Label", DAMAGE_NUMBER_FONT)
	style.set_font_size("font_size", "Label", DAMAGE_NUMBER_CRITICAL_FONT_SIZE if is_critical else DAMAGE_NUMBER_FONT_SIZE)
	style.set_color("font_color", "Label", _get_damage_number_color(final_damage))
	style.set_color("font_outline_color", "Label", Color(0.01, 0.01, 0.015, 0.98))
	style.set_constant("outline_size", "Label", 4 if is_critical else 3)
	style.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.92))
	style.set_constant("shadow_offset_x", "Label", 2)
	style.set_constant("shadow_offset_y", "Label", 3)
	style.set_constant("shadow_outline_size", "Label", 2)
	_damage_number_themes[key] = style
	return style


func _get_damage_number_color(final_damage: int) -> Color:
	var digit_count := str(absi(final_damage)).length()
	if digit_count <= 2:
		return Color.WHITE
	if digit_count <= 4:
		return Color(1.0, 0.78, 0.28, 1.0)
	if digit_count <= 6:
		return Color(1.0, 0.57, 0.12, 1.0)
	return Color(0.95, 0.20, 0.20, 1.0)


func is_alive() -> bool:
	return alive


func get_drop_table_id() -> String:
	return str(enemy_data.get("drop_table_id", ""))


func _process_chase() -> void:
	if target_player == null or not target_player.alive:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_movement_visual(false, get_physics_process_delta_time())
		return
	var direction := global_position.direction_to(target_player.global_position)
	# Dictionary.get evaluates its default argument even when the key exists.
	var resolved_move_speed := get_stat("move_speed")
	var base_move_speed := float(enemy_data.get("base_stats", {}).get("move_speed", resolved_move_speed))
	var move_speed := minf(resolved_move_speed, base_move_speed * MAX_MOVE_SPEED_MULTIPLIER)
	if _slowed_remaining > 0.0:
		move_speed *= _slow_multiplier
	if _wet_remaining > 0.0:
		move_speed *= _wet_slow_multiplier
	var target_velocity := direction * move_speed
	velocity = velocity.move_toward(target_velocity, CHASE_ACCELERATION * get_physics_process_delta_time())
	if sprite != null and not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	move_and_slide()
	_set_movement_visual(true, get_physics_process_delta_time())


func _process_contact_recovery() -> bool:
	if target_player == null or not target_player.alive or _contact_damage_cooldown <= 0.0:
		return false
	if global_position.distance_to(target_player.global_position) >= CONTACT_RESET_RADIUS:
		return false
	var direction := target_player.global_position.direction_to(global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	velocity = direction.normalized() * CONTACT_RECOVERY_SPEED
	move_and_slide()
	_set_movement_visual(true, get_physics_process_delta_time())
	return true


func _set_movement_visual(is_moving: bool, delta: float) -> void:
	if sprite == null:
		return
	var can_animate_movement := is_moving and move_texture != null and move_frame_count > 0 and move_texture.get_width() >= move_frame_count
	if not can_animate_movement:
		if _is_move_animation_active or sprite.texture != idle_texture:
			sprite.texture = idle_texture
			sprite.hframes = 1
			sprite.frame = 0
			_is_move_animation_active = false
			_move_animation_frame = 0
			_move_animation_timer = 0.0
		return

	if not _is_move_animation_active:
		sprite.texture = move_texture
		sprite.hframes = move_frame_count
		sprite.frame = 0
		_is_move_animation_active = true
		_move_animation_frame = 0
		_move_animation_timer = 0.0

	_move_animation_timer += delta
	var frame_duration := maxf(move_frame_duration, 0.01)
	while _move_animation_timer >= frame_duration:
		_move_animation_timer -= frame_duration
		_move_animation_frame = (_move_animation_frame + 1) % sprite.hframes
		if sprite.frame != _move_animation_frame: sprite.frame = _move_animation_frame


func _process_contact_damage() -> void:
	if target_player == null or not target_player.alive or _contact_damage_cooldown > 0.0:
		return
	if not _is_touching_player():
		return
	var base_damage := get_stat("melee_damage")
	var damage := int(roundf(base_damage * (1.0 + get_stat("damage_percent") / 100.0)))
	if damage <= 0:
		return
	var dealt_damage := target_player.take_damage(damage, enemy_id)
	_contact_damage_cooldown = CONTACT_DAMAGE_COOLDOWN_SECONDS
	if dealt_damage > 0:
		has_contact_damaged = true
		contact_damaged.emit(target_player, dealt_damage)
	_apply_contact_knockback()


func _is_touching_player() -> bool:
	if not is_instance_valid(_contact_body) or _contact_body.get_parent() != self:
		_contact_body = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(_contact_player_body) or _contact_player_body.get_parent() != target_player:
		_contact_player_body = target_player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var body := _contact_body
	var player_body := _contact_player_body
	if body == null or player_body == null or body.disabled or player_body.disabled or body.shape == null or player_body.shape == null:
		return false
	# Conservative transformed bounds reject distant pairs; overlapping bounds
	# still use the original exact shape query, including offsets, scale and margin.
	var body_bounds: Rect2
	if body.shape is CircleShape2D:
		body_bounds = body.global_transform * body.shape.get_rect().grow(CONTACT_MARGIN)
	else:
		body_bounds = (body.global_transform * body.shape.get_rect()).grow(CONTACT_MARGIN)
	var player_bounds: Rect2 = player_body.global_transform * player_body.shape.get_rect()
	if not body_bounds.grow(0.001).intersects(player_bounds, true):
		return false
	if body.shape is CircleShape2D:
		# Include move_and_slide's tiny safe gap, rather than a fixed root radius.
		_contact_probe.radius = (body.shape as CircleShape2D).radius + CONTACT_MARGIN
		return _contact_probe.collide(body.global_transform, player_body.shape, player_body.global_transform)
	var motion := body.global_position.direction_to(player_body.global_position) * CONTACT_MARGIN
	return body.shape.collide_with_motion(body.global_transform, motion, player_body.shape, player_body.global_transform, Vector2.ZERO)


func _apply_contact_knockback() -> void:
	if target_player == null:
		return
	var direction := target_player.global_position.direction_to(global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	_knockback_velocity = direction.normalized() * knockback_speed * get_control_multiplier()
	velocity = _knockback_velocity
	var safe_duration := maxf(knockback_seconds, 0.05) * get_control_multiplier()
	_knockback_deceleration = _knockback_velocity.length() / safe_duration
	_knockback_timer = safe_duration


func _die(source_id: String = "") -> void:
	alive = false
	velocity = Vector2.ZERO
	died.emit(self, get_drop_table_id(), global_position)
	fade_out_and_free()
