extends CharacterBody2D
class_name EnemyController

signal died(enemy: EnemyController, drop_table_id: String, global_position: Vector2)
signal contact_damaged(player: PlayerController, damage: int)

const DEFAULT_ENEMY_ID: String = "enemy_mutated_grub"
const DEFAULT_KNOCKBACK_SPEED: float = 450.0
const DEFAULT_KNOCKBACK_SECONDS: float = 0.18
const CONTACT_RADIUS: float = 52.0
const CONTACT_RESET_RADIUS: float = 68.0
const CONTACT_DAMAGE_COOLDOWN_SECONDS: float = 0.55
const CONTACT_RECOVERY_SPEED: float = 180.0
const DAMAGE_NUMBER_FONT: Font = preload("res://assets/font/VT323-Regular.ttf")
const DAMAGE_NUMBER_FONT_SIZE: int = 18
const DAMAGE_NUMBER_CRITICAL_FONT_SIZE: int = 22
const DAMAGE_NUMBER_SIZE: Vector2 = Vector2(76.0, 34.0)
const DAMAGE_NUMBER_OFFSET: Vector2 = Vector2(0.0, -36.0)
const DAMAGE_NUMBER_RISE: float = 42.0
const DAMAGE_NUMBER_ANIMATION_SECONDS: float = 0.62
const HIT_KNOCKBACK_SPEED: float = 180.0
const HIT_KNOCKBACK_SECONDS: float = 0.1
const HIT_FLASH_SECONDS: float = 0.1
const HIT_SHAKE_ANGLE: float = 0.08
const DEATH_FADE_SECONDS: float = 0.2

@export var enemy_id: String = DEFAULT_ENEMY_ID
@export var auto_initialize_on_ready: bool = true
@export var knockback_speed: float = DEFAULT_KNOCKBACK_SPEED
@export var knockback_seconds: float = DEFAULT_KNOCKBACK_SECONDS

var enemy_data: Dictionary = {}
var modifier_stack: ModifierStack = ModifierStack.new()
var current_hp: int = 0
var alive: bool = true
var target_player: PlayerController = null

var _knockback_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _contact_damage_cooldown: float = 0.0
var _visual_tween: Tween = null
var _base_sprite_modulate: Color = Color.WHITE
var _base_sprite_modulate_captured: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("enemies")
	_capture_base_sprite_modulate()
	if auto_initialize_on_ready:
		initialize(enemy_id)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		velocity = Vector2.ZERO
		return
	_contact_damage_cooldown = maxf(_contact_damage_cooldown - delta, 0.0)
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(_knockback_timer - delta, 0.0)
		velocity = _knockback_velocity
		move_and_slide()
		return
	if _process_contact_recovery():
		return
	_process_chase()
	_process_contact_damage()


func initialize(target_enemy_id: String, player: PlayerController = null, runtime_modifiers: Array = []) -> bool:
	var data := DataRegistry.get_record("enemies", target_enemy_id)
	if data.is_empty():
		push_error("[EnemyController] missing enemy config: %s" % target_enemy_id)
		return false
	enemy_id = target_enemy_id
	enemy_data = data
	modifier_stack.set_base_stats(data.get("base_stats", {}))
	_apply_runtime_modifiers(runtime_modifiers)
	current_hp = int(get_stat("max_hp"))
	target_player = player
	alive = true
	_knockback_timer = 0.0
	_knockback_velocity = Vector2.ZERO
	_contact_damage_cooldown = 0.0
	return true


func set_target_player(player: PlayerController) -> void:
	target_player = player


func add_runtime_modifier(modifier_data: Dictionary) -> bool:
	var modifier := modifier_stack.add_modifier_from_dictionary(modifier_data)
	return modifier != null


func add_runtime_modifiers(modifier_data_list: Array) -> void:
	for modifier_data in modifier_data_list:
		if modifier_data is Dictionary:
			add_runtime_modifier(modifier_data)


func _apply_runtime_modifiers(modifier_data_list: Array) -> void:
	add_runtime_modifiers(modifier_data_list)


func get_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	return modifier_stack.get_stat(stat_id, fallback_base_value)


func take_damage(
	raw_damage: int,
	source_id: String = "",
	is_critical: bool = false,
	hit_direction: Vector2 = Vector2.ZERO,
	damage_components: Array[int] = []
) -> int:
	if not alive or raw_damage <= 0:
		return 0
	var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
	var final_damage := maxi(1, int(roundi(float(raw_damage) * damage_taken_percent / 100.0)))
	current_hp = maxi(current_hp - final_damage, 0)
	if damage_components.is_empty():
		_spawn_damage_number(final_damage, is_critical)
	else:
		var display_components := _split_damage_for_display(final_damage, damage_components)
		for index in range(display_components.size()):
			_spawn_damage_number(display_components[index], is_critical, index, display_components.size())
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
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	sprite.modulate = Color.WHITE
	sprite.rotation = randf_range(-HIT_SHAKE_ANGLE, HIT_SHAKE_ANGLE)
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
	_knockback_velocity = hit_direction.normalized() * HIT_KNOCKBACK_SPEED
	velocity = _knockback_velocity
	_knockback_timer = maxf(_knockback_timer, HIT_KNOCKBACK_SECONDS)


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
	display_count: int = 1
) -> void:
	var damage_number := Label.new()
	damage_number.name = "DamageNumber"
	damage_number.text = str(final_damage)
	damage_number.size = DAMAGE_NUMBER_SIZE
	damage_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_number.z_index = 100
	damage_number.pivot_offset = DAMAGE_NUMBER_SIZE * 0.5
	damage_number.scale = Vector2(0.84, 0.84) if not is_critical else Vector2(0.92, 0.92)
	damage_number.modulate.a = 0.0
	damage_number.add_theme_font_override("font", DAMAGE_NUMBER_FONT)
	damage_number.add_theme_font_size_override("font_size", DAMAGE_NUMBER_CRITICAL_FONT_SIZE if is_critical else DAMAGE_NUMBER_FONT_SIZE)
	damage_number.add_theme_color_override("font_color", _get_damage_number_color(final_damage))
	damage_number.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.015, 0.98))
	damage_number.add_theme_constant_override("outline_size", 4 if is_critical else 3)
	damage_number.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	damage_number.add_theme_constant_override("shadow_offset_x", 2)
	damage_number.add_theme_constant_override("shadow_offset_y", 3)
	damage_number.add_theme_constant_override("shadow_outline_size", 2)

	var damage_number_parent := get_parent()
	if damage_number_parent == null or not damage_number_parent.is_inside_tree():
		return
	damage_number_parent.add_child(damage_number)
	var spread_offset := Vector2(randf_range(-14.0, 14.0), randf_range(-4.0, 4.0))
	if display_count > 1:
		var centered_index := float(display_index) - float(display_count - 1) * 0.5
		spread_offset.x = centered_index * 30.0
	damage_number.global_position = global_position + DAMAGE_NUMBER_OFFSET + spread_offset - DAMAGE_NUMBER_SIZE * 0.5

	var target_position := damage_number.global_position + Vector2(0.0, -DAMAGE_NUMBER_RISE)
	var tween := damage_number.create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_number, "global_position", target_position, DAMAGE_NUMBER_ANIMATION_SECONDS)
	tween.tween_property(damage_number, "modulate:a", 1.0, 0.10)
	tween.tween_property(damage_number, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.10)
	tween.tween_property(damage_number, "modulate:a", 0.0, 0.28)
	tween.tween_callback(damage_number.queue_free)


func _get_damage_number_color(final_damage: int) -> Color:
	var digit_count := str(absi(final_damage)).length()
	if digit_count <= 4:
		return Color.WHITE
	if digit_count == 5:
		return Color(1.0, 0.78, 0.28, 1.0)
	if digit_count == 6:
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
		return
	var direction := global_position.direction_to(target_player.global_position)
	velocity = direction * get_stat("move_speed")
	if sprite != null and not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	move_and_slide()


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
	return true


func _process_contact_damage() -> void:
	if target_player == null or not target_player.alive or _contact_damage_cooldown > 0.0:
		return
	if global_position.distance_to(target_player.global_position) > CONTACT_RADIUS:
		return
	var base_damage := get_stat("melee_damage")
	var damage := int(roundf(base_damage * (1.0 + get_stat("damage_percent") / 100.0)))
	if damage <= 0:
		return
	var dealt_damage := target_player.take_damage(damage, enemy_id)
	_contact_damage_cooldown = CONTACT_DAMAGE_COOLDOWN_SECONDS
	if dealt_damage > 0:
		contact_damaged.emit(target_player, dealt_damage)
	_apply_contact_knockback()


func _apply_contact_knockback() -> void:
	if target_player == null:
		return
	var direction := target_player.global_position.direction_to(global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	_knockback_velocity = direction.normalized() * knockback_speed
	velocity = _knockback_velocity
	_knockback_timer = knockback_seconds


func _die(source_id: String = "") -> void:
	alive = false
	velocity = Vector2.ZERO
	died.emit(self, get_drop_table_id(), global_position)
	fade_out_and_free()
