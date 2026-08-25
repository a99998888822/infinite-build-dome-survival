extends CharacterBody2D
class_name PlayerController

signal hp_changed(current_hp: int, max_hp: int, current_shield: int)
signal died
signal revived(remaining_revives: int)
signal shield_broken
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
const ITEM_INVENTORY_SCRIPT = preload("res://scripts/items/item_inventory.gd")

@export var character_id: String = DEFAULT_CHARACTER_ID
@export var auto_initialize_on_ready: bool = true
@export var invincibility_seconds: float = DEFAULT_INVINCIBILITY_SECONDS
@export var walk_animation_fps: float = 3.5
@export var walk_frame_count: int = 4

var character_data: Dictionary = {}
var modifier_stack: ModifierStack = ModifierStack.new()
var relic_system: RelicBondSystem = RelicBondSystem.new()
var item_inventory: ItemInventory = ITEM_INVENTORY_SCRIPT.new()
var current_hp: int = 0
var current_shield: int = 0
var current_shield_capacity: int = 0
var remaining_revives: int = 0
var alive: bool = true
var facing_right: bool = true
var start_weapon_ids: Array[String] = []

var _invincibility_timer: float = 0.0
var _configured_revive_count: int = 0
var _walk_animation_time: float = 0.0
var _held_move_keys: Dictionary = {}
var _mobile_move_direction := Vector2.ZERO
var _hp_regen_remainder: float = 0.0
var _shield_regen_remainder: float = 0.0
var _relic_runtime_sequence: int = 0
var _refreshing_relic_dynamic_effects: bool = false

@onready var visual_anchor: Node2D = get_node_or_null("VisualAnchor")
@onready var sprite: Sprite2D = get_node_or_null("VisualAnchor/Sprite2D")
@onready var pickup_shape: CollisionShape2D = get_node_or_null("PickupArea/CollisionShape2D")
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D")


func _ready() -> void:
	_clear_move_input()
	_setup_visuals()
	if auto_initialize_on_ready:
		initialize_from_character(character_id)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	var is_pressed := key_event.pressed
	for key_code in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
		if key_event.keycode == key_code or key_event.physical_keycode == key_code:
			_held_move_keys[key_code] = is_pressed


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_move_input()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		velocity = Vector2.ZERO
		_apply_idle_visual()
		_sync_camera()
		return
	modifier_stack.tick(delta)
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_process_regeneration(delta)
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
	item_inventory.clear()
	_initialize_starting_items(data)
	relic_system.clear()
	relic_system.initialize(self)
	relic_system.set_weapon_ids(start_weapon_ids)
	current_hp = int(get_stat("max_hp"))
	current_shield = 0
	current_shield_capacity = 0
	remaining_revives = int(get_stat("revive_count"))
	_configured_revive_count = remaining_revives
	alive = true
	_invincibility_timer = 0.0
	_hp_regen_remainder = 0.0
	_shield_regen_remainder = 0.0
	_relic_runtime_sequence = 0
	_refreshing_relic_dynamic_effects = false
	_clear_move_input()
	_update_pickup_radius()

	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	start_weapons_changed.emit(start_weapon_ids.duplicate())
	return true


func add_runtime_modifier(modifier_data: Dictionary) -> bool:
	var stat_id := str(modifier_data.get("stat", ""))
	var value := float(modifier_data.get("value", 0.0))
	if value > 0.0 and _is_stat_increase_blocked(stat_id):
		return false
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


func get_stat_with_extra_modifier(stat_id: String, modifier_data: Dictionary, fallback_base_value: float = 0.0) -> float:
	return modifier_stack.get_stat_with_extra_modifier(stat_id, modifier_data, fallback_base_value)


func get_item_inventory() -> ItemInventory:
	return item_inventory


func _initialize_starting_items(data: Dictionary) -> void:
	var raw_attachments: Variant = data.get("start_weapon_attachments", [])
	if not (raw_attachments is Array):
		return
	for attachment in raw_attachments:
		if not (attachment is Dictionary):
			continue
		var weapon_id := str(attachment.get("weapon_id", ""))
		var item_id := str(attachment.get("item_id", ""))
		if weapon_id.is_empty() or item_id.is_empty() or not start_weapon_ids.has(weapon_id):
			continue
		item_inventory.add_item_from_base(item_id, "starter", weapon_id)


func get_start_weapon_ids() -> Array[String]:
	return start_weapon_ids.duplicate()


func add_relic(relic_id: String) -> bool:
	if not relic_system.add_relic(relic_id):
		return false
	_refresh_relic_dynamic_effects()
	_process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_ON_ACQUIRE)
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


func _is_stat_increase_blocked(stat_id: String) -> bool:
	if stat_id.is_empty():
		return false
	for effect in get_active_relic_runtime_effects():
		if str(effect.get("effect", "")) != BattleFinanceSystem.EFFECT_BLOCK_STAT_INCREASE:
			continue
		if str(effect.get("stat", "")) == stat_id:
			return true
	return false


func sync_relic_weapon_ids(weapon_ids: Array[String]) -> void:
	relic_system.set_weapon_ids(weapon_ids)


func get_character_icon_path() -> String:
	return str(character_data.get("icon", ""))


func take_damage(raw_damage: int, source_id: String = "") -> int:
	# 护盾优先承伤且不受护甲影响；只有穿透护盾的生命伤害经过护甲换算。
	if not alive or raw_damage <= 0 or _invincibility_timer > 0.0:
		return 0

	var had_shield := current_shield > 0
	var shield_damage := mini(current_shield, raw_damage)
	current_shield -= shield_damage
	var remaining_damage := raw_damage - shield_damage
	var health_damage := 0
	if remaining_damage > 0:
		var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
		health_damage = maxi(1, int(roundi(float(remaining_damage) * damage_taken_percent / 100.0)))
	current_hp = maxi(current_hp - health_damage, 0)
	_invincibility_timer = invincibility_seconds
	_apply_damage_flash()
	_refresh_relic_dynamic_effects()
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	if had_shield and current_shield <= 0:
		shield_broken.emit()
		_process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_SHIELD_BREAK)

	if current_hp <= 0:
		_die(source_id)
	return shield_damage + health_damage


func _apply_damage_flash() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)


func heal(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var old_hp := current_hp
	current_hp = mini(current_hp + amount, int(get_stat("max_hp")))
	_refresh_relic_dynamic_effects()
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	return current_hp - old_hp


func restore_full_health() -> int:
	if not alive:
		return 0
	var max_hp := int(get_stat("max_hp"))
	var old_hp := current_hp
	current_hp = max_hp
	_hp_regen_remainder = 0.0
	_refresh_relic_dynamic_effects()
	hp_changed.emit(current_hp, max_hp, current_shield)
	return current_hp - old_hp


func grant_shield(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var old_shield := current_shield
	current_shield_capacity += amount
	current_shield += amount
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	return current_shield - old_shield


func reset_wave_shield() -> void:
	current_shield = 0
	current_shield_capacity = 0
	_shield_regen_remainder = 0.0
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)


func process_relic_runtime_trigger(trigger: String) -> void:
	_process_relic_runtime_trigger(trigger)


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
	if direction.is_zero_approx():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_walk_animation(Vector2.ZERO, delta)
		return
	velocity = direction * get_stat("move_speed")
	if not is_zero_approx(direction.x):
		_set_facing(direction.x > 0.0)
	move_and_slide()
	_update_walk_animation(direction, delta)


func _read_move_input() -> Vector2:
	var direction := _mobile_move_direction
	if bool(_held_move_keys.get(KEY_A, false)) or bool(_held_move_keys.get(KEY_LEFT, false)):
		direction.x -= 1.0
	if bool(_held_move_keys.get(KEY_D, false)) or bool(_held_move_keys.get(KEY_RIGHT, false)):
		direction.x += 1.0
	if bool(_held_move_keys.get(KEY_W, false)) or bool(_held_move_keys.get(KEY_UP, false)):
		direction.y -= 1.0
	if bool(_held_move_keys.get(KEY_S, false)) or bool(_held_move_keys.get(KEY_DOWN, false)):
		direction.y += 1.0
	return direction.normalized() if direction.length_squared() > 1.0 else direction


func set_mobile_move_direction(direction: Vector2) -> void:
	_mobile_move_direction = direction.limit_length(1.0)


func _clear_move_input() -> void:
	_held_move_keys.clear()
	_mobile_move_direction = Vector2.ZERO


func _process_regeneration(delta: float) -> void:
	if not alive or delta <= 0.0:
		return
	var max_hp := int(get_stat("max_hp"))
	if current_hp < max_hp:
		_hp_regen_remainder += maxf(get_stat("hp_regen"), 0.0) * delta
		var hp_amount := floori(_hp_regen_remainder)
		if hp_amount > 0:
			_hp_regen_remainder -= float(hp_amount)
			heal(hp_amount)
	else:
		_hp_regen_remainder = 0.0

	var shield_regen := maxf(get_stat("shield_regen"), 0.0)
	if shield_regen <= 0.0:
		_shield_regen_remainder = 0.0
		return
	if current_shield_capacity > 0 and current_shield >= current_shield_capacity:
		_shield_regen_remainder = 0.0
		return
	_shield_regen_remainder += shield_regen * delta
	var shield_amount := floori(_shield_regen_remainder)
	if shield_amount > 0:
		_shield_regen_remainder -= float(shield_amount)
		grant_shield(shield_amount)


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
	_update_pickup_radius()
	_refresh_relic_dynamic_effects()
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)


func _refresh_relic_dynamic_effects() -> void:
	if _refreshing_relic_dynamic_effects:
		return
	_refreshing_relic_dynamic_effects = true
	modifier_stack.remove_by_source_type("relic_dynamic")
	for effect in get_active_relic_runtime_effects(BattleFinanceSystem.TRIGGER_DYNAMIC):
		var effect_type := str(effect.get("effect", ""))
		var target_stat := str(effect.get("stat", effect.get("target_stat", "")))
		if not StatDefinitions.has_stat(target_stat):
			continue
		var active := false
		if effect_type == BattleFinanceSystem.EFFECT_CONDITIONAL_STAT:
			active = _is_relic_condition_active(effect)
		elif effect_type == BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PLAYER_STAT:
			active = true
		if not active:
			continue
		var value := float(effect.get("value", 0.0))
		if effect_type == BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PLAYER_STAT:
			var source_stat := str(effect.get("source_stat", ""))
			if not StatDefinitions.has_stat(source_stat):
				continue
			var divisor := maxf(float(effect.get("divisor", 1.0)), 0.0001)
			var per_unit := float(effect.get("per_unit", 1.0))
			value = floorf(get_stat(source_stat) / divisor) * per_unit
		if is_zero_approx(value):
			continue
		var instance_id := str(effect.get("relic_instance_id", "relic"))
		var effect_index := int(effect.get("relic_runtime_effect_index", 0))
		modifier_stack.add_modifier_from_dictionary({
			"id": "relic_dynamic_%s_%d" % [instance_id, effect_index],
			"source_type": "relic_dynamic",
			"source_id": instance_id,
			"target_scope": "player",
			"stat": target_stat,
			"operation": Modifier.OPERATION_ADD_FLAT,
			"value": value,
			"duration": Modifier.PERMANENT_DURATION,
			"stack_rule": Modifier.STACK_RULE_UNIQUE,
		})
	_refreshing_relic_dynamic_effects = false


func _is_relic_condition_active(effect: Dictionary) -> bool:
	var condition := str(effect.get("condition", ""))
	var threshold := float(effect.get("threshold", 0.0))
	match condition:
		"hp_percent_below":
			var max_hp := maxf(float(get_stat("max_hp")), 1.0)
			return float(current_hp) / max_hp * 100.0 < threshold
		"humanity_below":
			return get_stat("humanity") < threshold
	return false


func _process_relic_runtime_trigger(trigger: String) -> void:
	for effect in get_active_relic_runtime_effects(trigger):
		var effect_type := str(effect.get("effect", ""))
		match effect_type:
			BattleFinanceSystem.EFFECT_ADD_STAT:
				var target_stat := str(effect.get("stat", ""))
				if not StatDefinitions.has_stat(target_stat):
					continue
				_relic_runtime_sequence += 1
				add_runtime_modifier({
					"id": "relic_runtime_%d" % _relic_runtime_sequence,
					"source_type": "relic_runtime",
					"source_id": str(effect.get("relic_instance_id", "")),
					"target_scope": "player",
					"stat": target_stat,
					"operation": str(effect.get("operation", Modifier.OPERATION_ADD_FLAT)),
					"value": float(effect.get("value", 0.0)),
					"duration": Modifier.PERMANENT_DURATION,
					"stack_rule": Modifier.STACK_RULE_STACK_ADD,
				})
			BattleFinanceSystem.EFFECT_GRANT_SHIELD:
				grant_shield(int(effect.get("value", 0)))
			BattleFinanceSystem.EFFECT_HEAL:
				heal(int(effect.get("value", 0)))


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
	_process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_ON_REVIVE)
	print("[PlayerController] player revived, remaining=%d" % remaining_revives)
	return true
