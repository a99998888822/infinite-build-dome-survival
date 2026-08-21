extends CharacterBody2D
class_name EnemyController

signal died(enemy: EnemyController, drop_table_id: String, global_position: Vector2)
signal contact_damaged(player: PlayerController, damage: int)

const DEFAULT_ENEMY_ID: String = "enemy_mutated_grub"
const DEFAULT_KNOCKBACK_SPEED: float = 450.0
const DEFAULT_KNOCKBACK_SECONDS: float = 0.18
const CONTACT_RADIUS: float = 52.0
const CONTACT_RESET_RADIUS: float = 68.0
const DAMAGE_NUMBER_FONT: Font = preload("res://assets/font/VT323-Regular.ttf")
const DAMAGE_NUMBER_FONT_SIZE: int = 16
const DAMAGE_NUMBER_SIZE: Vector2 = Vector2(44.0, 18.0)
const DAMAGE_NUMBER_OFFSET: Vector2 = Vector2(0.0, -28.0)
const DAMAGE_NUMBER_RISE: float = 30.0
const DAMAGE_NUMBER_ANIMATION_SECONDS: float = 0.55
const HIT_KNOCKBACK_SPEED: float = 180.0
const HIT_KNOCKBACK_SECONDS: float = 0.1
const HIT_FLASH_SECONDS: float = 0.1
const CRITICAL_FLASH_SECONDS: float = 0.18
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
var has_contact_damaged: bool = false

var _knockback_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _visual_tween: Tween = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("enemies")
	if auto_initialize_on_ready:
		initialize(enemy_id)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		velocity = Vector2.ZERO
		return
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(_knockback_timer - delta, 0.0)
		velocity = _knockback_velocity
		move_and_slide()
		return
	_process_contact_reset()
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
	has_contact_damaged = false
	_knockback_timer = 0.0
	_knockback_velocity = Vector2.ZERO
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


func take_damage(raw_damage: int, source_id: String = "", is_critical: bool = false, hit_direction: Vector2 = Vector2.ZERO) -> int:
	if not alive or raw_damage <= 0:
		return 0
	var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
	var final_damage := maxi(1, int(roundi(float(raw_damage) * damage_taken_percent / 100.0)))
	current_hp = maxi(current_hp - final_damage, 0)
	_spawn_damage_number(final_damage)
	_apply_hit_feedback(is_critical, hit_direction)
	if current_hp <= 0:
		_die(source_id)
	return final_damage


func _apply_hit_feedback(is_critical: bool, hit_direction: Vector2) -> void:
	if sprite == null:
		return
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	sprite.modulate = Color(1.0, 0.78, 0.25, 1.0) if is_critical else Color(0.88, 0.94, 1.0, 1.0)
	sprite.rotation = randf_range(-HIT_SHAKE_ANGLE, HIT_SHAKE_ANGLE)
	_visual_tween = create_tween()
	_visual_tween.tween_property(sprite, "modulate", Color.WHITE, CRITICAL_FLASH_SECONDS if is_critical else HIT_FLASH_SECONDS)
	_visual_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not hit_direction.is_zero_approx():
		_apply_weapon_knockback(hit_direction)


func _apply_weapon_knockback(hit_direction: Vector2) -> void:
	_knockback_velocity = hit_direction.normalized() * HIT_KNOCKBACK_SPEED
	velocity = _knockback_velocity
	_knockback_timer = maxf(_knockback_timer, HIT_KNOCKBACK_SECONDS)


func fade_out_and_free() -> void:
	if not is_inside_tree():
		return
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


func _spawn_damage_number(final_damage: int) -> void:
	var damage_number := Label.new()
	damage_number.name = "DamageNumber"
	damage_number.text = str(final_damage)
	damage_number.size = DAMAGE_NUMBER_SIZE
	damage_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_number.z_index = 100
	damage_number.pivot_offset = DAMAGE_NUMBER_SIZE * 0.5
	damage_number.scale = Vector2(0.8, 0.8)
	damage_number.modulate.a = 0.0
	damage_number.add_theme_font_override("font", DAMAGE_NUMBER_FONT)
	damage_number.add_theme_font_size_override("font_size", DAMAGE_NUMBER_FONT_SIZE)
	damage_number.add_theme_color_override("font_color", _get_damage_number_color(final_damage))
	damage_number.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.9))
	damage_number.add_theme_constant_override("outline_size", 2)

	var damage_number_parent := get_parent()
	if damage_number_parent == null or not damage_number_parent.is_inside_tree():
		return
	damage_number_parent.add_child(damage_number)
	damage_number.global_position = global_position + DAMAGE_NUMBER_OFFSET - DAMAGE_NUMBER_SIZE * 0.5

	var target_position := damage_number.global_position + Vector2(0.0, -DAMAGE_NUMBER_RISE)
	var tween := damage_number.create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_number, "global_position", target_position, DAMAGE_NUMBER_ANIMATION_SECONDS)
	tween.tween_property(damage_number, "modulate:a", 1.0, 0.08)
	tween.tween_property(damage_number, "scale", Vector2.ONE, 0.12)
	tween.chain().tween_property(damage_number, "modulate:a", 0.0, 0.22).set_delay(0.18)
	tween.chain().tween_callback(damage_number.queue_free)


func _get_damage_number_color(final_damage: int) -> Color:
	var digit_count := str(absi(final_damage)).length()
	if digit_count <= 2:
		return Color(0.64, 0.64, 0.64, 1.0)
	if digit_count == 3:
		return Color(0.95, 0.95, 0.95, 1.0)
	if digit_count == 4:
		return Color(0.31, 0.72, 0.94, 1.0)
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


func _process_contact_reset() -> void:
	if target_player == null or not has_contact_damaged:
		return
	if global_position.distance_to(target_player.global_position) >= CONTACT_RESET_RADIUS:
		has_contact_damaged = false


func _process_contact_damage() -> void:
	if target_player == null or has_contact_damaged:
		return
	if global_position.distance_to(target_player.global_position) > CONTACT_RADIUS:
		return
	var base_damage := get_stat("melee_damage")
	var damage := int(roundf(base_damage * (1.0 + get_stat("damage_percent") / 100.0)))
	if damage <= 0:
		return
	target_player.take_damage(damage, enemy_id)
	has_contact_damaged = true
	contact_damaged.emit(target_player, damage)
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
