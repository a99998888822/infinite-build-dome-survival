extends CharacterBody2D
class_name EnemyController

signal died(enemy: EnemyController, drop_table_id: String, global_position: Vector2)
signal contact_damaged(player: PlayerController, damage: int)

const DEFAULT_ENEMY_ID: String = "enemy_mutated_grub"
const DEFAULT_KNOCKBACK_SPEED: float = 450.0
const DEFAULT_KNOCKBACK_SECONDS: float = 0.18
const CONTACT_RADIUS: float = 28.0
const CONTACT_RESET_RADIUS: float = 44.0
const SEPARATION_RADIUS: float = 58.0
const SEPARATION_STRENGTH: float = 140.0

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


func take_damage(raw_damage: int, source_id: String = "") -> int:
	if not alive or raw_damage <= 0:
		return 0
	var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
	var final_damage := maxi(1, int(roundi(float(raw_damage) * damage_taken_percent / 100.0)))
	current_hp = maxi(current_hp - final_damage, 0)
	if current_hp <= 0:
		_die(source_id)
	return final_damage


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
	var separation := _calculate_enemy_separation()
	velocity = direction * get_stat("move_speed") + separation * SEPARATION_STRENGTH
	if sprite != null and not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	move_and_slide()


func _calculate_enemy_separation() -> Vector2:
	var push := Vector2.ZERO
	var radius_sq := SEPARATION_RADIUS * SEPARATION_RADIUS
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		var other := node as Node2D
		if other == null or not other.is_inside_tree():
			continue
		var offset := global_position - other.global_position
		var distance_sq := offset.length_squared()
		if distance_sq <= 0.01 or distance_sq > radius_sq:
			continue
		var distance := sqrt(distance_sq)
		push += offset.normalized() * (1.0 - distance / SEPARATION_RADIUS)
	return push.limit_length(1.0)


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
	var damage := int(get_stat("melee_damage"))
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
	queue_free()
