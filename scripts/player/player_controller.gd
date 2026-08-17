extends CharacterBody2D
class_name PlayerController

signal hp_changed(current_hp: int, max_hp: int, current_shield: int)
signal died
signal revived(remaining_revives: int)
signal start_weapons_changed(weapon_ids: Array[String])
signal relics_changed(relic_ids: Array[String])
signal relic_added(relic_id: String)

const DEFAULT_CHARACTER_ID: String = "character_void_hunter"
const DEFAULT_INVINCIBILITY_SECONDS: float = 0.25
const REVIVE_HEALTH_PERCENT: float = 0.5
const REVIVE_INVINCIBILITY_SECONDS: float = 1.0
const PLAYER_VISUAL_SCALE: float = 0.3
const PLAYER_IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/player/player_void_hunter_right_base.png")
const PLAYER_WALK_TEXTURE: Texture2D = preload("res://assets/sprites/player/player_void_hunter_walk_right_spritesheet.png")

@export var character_id: String = DEFAULT_CHARACTER_ID
@export var auto_initialize_on_ready: bool = true
@export var invincibility_seconds: float = DEFAULT_INVINCIBILITY_SECONDS
@export var walk_animation_fps: float = 3.5
@export var walk_frame_count: int = 4

var character_data: Dictionary = {}
var modifier_stack: ModifierStack = ModifierStack.new()
var relic_system: RelicBondSystem = RelicBondSystem.new()
var current_hp: int = 0
var current_shield: int = 0
var remaining_revives: int = 0
var alive: bool = true
var facing_right: bool = true
var start_weapon_ids: Array[String] = []

var _invincibility_timer: float = 0.0
var _configured_revive_count: int = 0
var _walk_animation_time: float = 0.0

@onready var visual_anchor: Node2D = get_node_or_null("VisualAnchor")
@onready var sprite: Sprite2D = get_node_or_null("VisualAnchor/Sprite2D")
@onready var pickup_shape: CollisionShape2D = get_node_or_null("PickupArea/CollisionShape2D")
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D")


func _ready() -> void:
	_setup_visuals()
	if auto_initialize_on_ready:
		initialize_from_character(character_id)


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		velocity = Vector2.ZERO
		_apply_idle_visual()
		_sync_camera()
		return
	modifier_stack.tick(delta)
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_process_movement(delta)
	_sync_camera()


func initialize_from_character(target_character_id: String, outgame_modifiers: Array = [], initial_weapon_ids: Array[String] = []) -> bool:
	# 角色初始化只写入本局运行状态，不回写 characters.json。
	var data := DataRegistry.get_record("characters", target_character_id)
	if data.is_empty():
		push_error("[PlayerController] missing character config: %s" % target_character_id)
		return false

	character_id = target_character_id
	character_data = data
	modifier_stack.set_base_stats(data.get("base_stats", {}))
	_apply_modifier_list(data.get("passive_modifiers", []))
	_apply_modifier_list(outgame_modifiers)

	start_weapon_ids = _resolve_start_weapons(data, initial_weapon_ids)
	relic_system.clear()
	relic_system.initialize(self)
	relic_system.set_weapon_ids(start_weapon_ids)
	current_hp = int(get_stat("max_hp"))
	current_shield = int(get_stat("shield"))
	remaining_revives = int(get_stat("revive_count"))
	_configured_revive_count = remaining_revives
	alive = true
	_invincibility_timer = 0.0
	_update_pickup_radius()

	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	start_weapons_changed.emit(start_weapon_ids.duplicate())
	return true


func add_runtime_modifier(modifier_data: Dictionary) -> bool:
	var modifier := modifier_stack.add_modifier_from_dictionary(modifier_data)
	if modifier == null:
		return false
	_update_after_stat_change()
	return true


func add_runtime_modifiers(modifier_data_list: Array) -> void:
	for modifier_data in modifier_data_list:
		if modifier_data is Dictionary:
			add_runtime_modifier(modifier_data)


func remove_runtime_modifiers_by_source(source_type: String, source_id: String) -> void:
	modifier_stack.remove_by_source(source_type, source_id)
	_update_after_stat_change()


func remove_runtime_modifiers_by_source_type(source_type: String) -> void:
	modifier_stack.remove_by_source_type(source_type)
	_update_after_stat_change()


func clear_runtime_modifiers_by_scope(target_scope: String) -> void:
	modifier_stack.remove_by_target_scope(target_scope)
	_update_after_stat_change()


func get_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	return modifier_stack.get_stat(stat_id, fallback_base_value)


func get_start_weapon_ids() -> Array[String]:
	return start_weapon_ids.duplicate()


func add_relic(relic_id: String) -> bool:
	if not relic_system.add_relic(relic_id):
		return false
	relic_added.emit(relic_id)
	relics_changed.emit(get_relic_ids())
	return true


func can_add_relic(relic_id: String) -> bool:
	return relic_system.can_add_relic(relic_id)


func get_relic_count(relic_id: String) -> int:
	return relic_system.get_relic_count(relic_id)


func get_relic_ids() -> Array[String]:
	return relic_system.get_relic_ids()


func get_relic_counts() -> Dictionary:
	return relic_system.get_relic_counts()


func get_active_relic_runtime_effects(trigger: String = "") -> Array[Dictionary]:
	return relic_system.get_active_relic_runtime_effects(trigger)


func sync_relic_weapon_ids(weapon_ids: Array[String]) -> void:
	relic_system.set_weapon_ids(weapon_ids)


func get_character_icon_path() -> String:
	return str(character_data.get("icon", ""))


func take_damage(raw_damage: int, source_id: String = "") -> int:
	# 伤害入口统一经过护甲换算后的 damage_taken_percent。
	if not alive or raw_damage <= 0 or _invincibility_timer > 0.0:
		return 0

	var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
	var final_damage := maxi(1, int(roundi(float(raw_damage) * damage_taken_percent / 100.0)))
	var shield_damage := mini(current_shield, final_damage)
	current_shield -= shield_damage
	current_hp = maxi(current_hp - (final_damage - shield_damage), 0)
	_invincibility_timer = invincibility_seconds
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)

	if current_hp <= 0:
		_die(source_id)
	return final_damage


func heal(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var old_hp := current_hp
	current_hp = mini(current_hp + amount, int(get_stat("max_hp")))
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	return current_hp - old_hp


func is_alive() -> bool:
	return alive


func get_remaining_revives() -> int:
	return remaining_revives


func _process_movement(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		move_and_slide()
		_apply_idle_visual()
		return

	var direction := _read_move_input()
	velocity = direction * get_stat("move_speed")
	if not is_zero_approx(direction.x):
		_set_facing(direction.x > 0.0)
	move_and_slide()
	_update_walk_animation(direction, delta)


func _read_move_input() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	return direction.normalized() if direction.length_squared() > 1.0 else direction


func _set_facing(next_facing_right: bool) -> void:
	facing_right = next_facing_right
	if visual_anchor != null:
		visual_anchor.scale = Vector2(PLAYER_VISUAL_SCALE if facing_right else -PLAYER_VISUAL_SCALE, PLAYER_VISUAL_SCALE)
	elif sprite != null:
		sprite.flip_h = not facing_right


func _setup_visuals() -> void:
	if camera_2d != null:
		camera_2d.make_current()
	if visual_anchor != null:
		visual_anchor.scale = Vector2(PLAYER_VISUAL_SCALE if facing_right else -PLAYER_VISUAL_SCALE, PLAYER_VISUAL_SCALE)
	if sprite != null:
		_apply_idle_visual()


func _sync_camera() -> void:
	if camera_2d != null:
		camera_2d.global_position = global_position


func _update_walk_animation(direction: Vector2, delta: float) -> void:
	if sprite == null:
		return
	if direction.length_squared() <= 0.0:
		_walk_animation_time = 0.0
		_apply_idle_visual()
		return
	_apply_walk_visual()
	if walk_frame_count <= 1 or walk_animation_fps <= 0.0:
		sprite.frame = 0
		return

	_walk_animation_time += delta
	var frame_index := int(floorf(_walk_animation_time * walk_animation_fps)) % walk_frame_count
	sprite.frame = frame_index


func _apply_idle_visual() -> void:
	if sprite == null:
		return
	sprite.texture = PLAYER_IDLE_TEXTURE
	sprite.hframes = 1
	sprite.frame = 0


func _apply_walk_visual() -> void:
	if sprite != null:
		sprite.texture = PLAYER_WALK_TEXTURE
		sprite.hframes = maxi(walk_frame_count, 1)


func _resolve_start_weapons(data: Dictionary, override_weapon_ids: Array[String]) -> Array[String]:
	var resolved: Array[String] = []
	var raw_weapon_ids: Array = override_weapon_ids if not override_weapon_ids.is_empty() else data.get("start_weapons", [])
	for weapon_id in raw_weapon_ids:
		var text_id := str(weapon_id)
		if not text_id.is_empty():
			resolved.append(text_id)
	return resolved


func _apply_modifier_list(modifier_data_list: Array) -> void:
	for modifier_data in modifier_data_list:
		if modifier_data is Dictionary:
			modifier_stack.add_modifier_from_dictionary(modifier_data)


func _update_after_stat_change() -> void:
	var configured_revives := int(get_stat("revive_count"))
	if configured_revives > _configured_revive_count:
		remaining_revives += configured_revives - _configured_revive_count
	_configured_revive_count = configured_revives
	remaining_revives = mini(remaining_revives, configured_revives)
	current_hp = mini(current_hp, int(get_stat("max_hp")))
	current_shield = mini(current_shield, int(get_stat("shield")))
	_update_pickup_radius()
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)


func _update_pickup_radius() -> void:
	if pickup_shape == null:
		return
	var circle := pickup_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		pickup_shape.shape = circle
	circle.radius = maxf(get_stat("pickup_radius"), 1.0)


func _die(source_id: String = "") -> void:
	if not alive:
		return
	if _try_revive():
		return
	alive = false
	velocity = Vector2.ZERO
	died.emit()
	print("[PlayerController] player died, source=%s" % source_id)


func _try_revive() -> bool:
	if remaining_revives <= 0:
		return false
	remaining_revives -= 1
	current_hp = maxi(1, int(ceil(float(get_stat("max_hp")) * REVIVE_HEALTH_PERCENT)))
	current_shield = 0
	_invincibility_timer = REVIVE_INVINCIBILITY_SECONDS
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	revived.emit(remaining_revives)
	print("[PlayerController] player revived, remaining=%d" % remaining_revives)
	return true
