extends CharacterBody2D
class_name PlayerController

signal hp_changed(current_hp: int, max_hp: int, current_shield: int)
signal health_damage_taken(previous_hp: int, remaining_hp: int, maximum_hp: int)
signal died
signal revived(remaining_revives: int)
signal lethal_damage
signal shield_broken
signal start_weapons_changed(weapon_ids: Array[String])
signal relics_changed(relic_ids: Array[String])
signal relic_added(relic_id: String)
signal stats_changed

const DEFAULT_CHARACTER_ID: String = "character_void_hunter"
const MAX_HP_PER_LEVEL: int = 1
const DEFAULT_INVINCIBILITY_SECONDS: float = 0.0
const REVIVE_HEALTH_PERCENT: float = 0.5
const REVIVE_INVINCIBILITY_SECONDS: float = 1.0
const PLAYER_VISUAL_SCALE: float = 1.2
const PLAYER_IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/player/combat/void_hunter_idle_right.png")
const PLAYER_WALK_TEXTURE: Texture2D = preload("res://assets/sprites/player/combat/void_hunter_walk_right_spritesheet.png")
const ITEM_INVENTORY_SCRIPT = preload("res://scripts/items/item_inventory.gd")

@export var character_id: String = DEFAULT_CHARACTER_ID
@export var auto_initialize_on_ready: bool = true
@export var invincibility_seconds: float = DEFAULT_INVINCIBILITY_SECONDS
@export var walk_animation_fps: float = 6.0
@export var walk_frame_count: int = 6

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
var active_controls := false
var keyboard_movement := false
var last_move_direction := Vector2.RIGHT
var move_destination := Vector2.ZERO
var has_move_destination := false
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
var _initial_wave_shield: int = 0
var _modifier_update_depth: int = 0
var _modifiers_before_update: Dictionary = {}
var _resolving_death: bool = false
var _stationary_seconds: float = 0.0
var _stationary_thresholds: Array[float] = []
var _stationary_position := Vector2.ZERO
var _starting_relics_granted: int = 0
var _idle_texture: Texture2D = PLAYER_IDLE_TEXTURE
var _walk_texture: Texture2D = PLAYER_WALK_TEXTURE

@onready var visual_anchor: Node2D = get_node_or_null("VisualAnchor")
@onready var sprite: Sprite2D = get_node_or_null("VisualAnchor/Sprite2D")
@onready var pickup_shape: CollisionShape2D = get_node_or_null("PickupArea/CollisionShape2D")
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D")


func _init() -> void:
	# Player and detached preview mutations use ModifierStack's invalidating API.
	modifier_stack.cache_enabled = true


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
	if active_controls and is_pressed:
		return # Active battle presses are accepted only after the UI has declined them.
	for key_code in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT, KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
		if key_event.keycode == key_code or key_event.physical_keycode == key_code:
			_held_move_keys[key_code] = is_pressed
			if is_pressed:
				reset_stationary_relic_state()


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
	_tick_stationary_relic_state(delta)
	_sync_camera()


func initialize_from_character(target_character_id: String, outgame_modifiers: Array = [], initial_weapon_ids: Array[String] = []) -> bool:
	# 角色初始化只写入本局运行状态，不回写 characters.json。
	var data := DataRegistry.get_record("characters", target_character_id)
	if data.is_empty():
		push_error("[PlayerController] missing character config: %s" % target_character_id)
		return false

	character_id = target_character_id
	character_data = data
	# A new character/run must not inherit old relic, trade, or camp modifiers.
	relic_system.owner_player = null
	relic_system.clear()
	modifier_stack.clear()
	_starting_relics_granted = 0
	_configured_revive_count = 0
	remaining_revives = 0
	modifier_stack.set_base_stats(data.get("base_stats", {}))
	_apply_modifier_list(data.get("passive_modifiers", []))
	_apply_modifier_list(outgame_modifiers)
	# Camp talents contribute to the shield granted at the start of every wave.
	# Capture this before relic modifiers are added so relic wave-start rewards
	# continue to be applied separately.
	_initial_wave_shield = maxi(0, int(roundf(get_stat("shield"))))

	start_weapon_ids = _resolve_start_weapons(data, initial_weapon_ids)
	item_inventory.clear()
	_initialize_starting_items(data)
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
	_resolving_death = false
	reset_stationary_relic_state()
	_clear_move_input()
	_configure_character_visuals(data.get("combat_visuals", {}))
	_update_pickup_radius()

	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	start_weapons_changed.emit(start_weapon_ids.duplicate())
	relics_changed.emit(get_relic_ids())
	return true


func grant_starting_relics() -> bool:
	# Call only after the run's bank and relic_added listener are ready.
	# Track successful grants so repeated calls cannot award principal twice.
	var ids: Array = character_data.get("start_relics", [])
	while _starting_relics_granted < ids.size():
		if not add_relic(str(ids[_starting_relics_granted]), true):
			return false
		_starting_relics_granted += 1
	return true


func set_run_level(level: int) -> void:
	# Replace the total contribution, so refreshes never duplicate level growth.
	# Fill newly gained HP capacity once; repeated level syncs cannot heal.
	var previous_max_hp := int(get_stat("max_hp"))
	add_runtime_modifier({
		"id": "mod_player_level_max_hp",
		"source_type": "level",
		"source_id": "run_level",
		"target_scope": "player",
		"stat": "max_hp",
		"operation": Modifier.OPERATION_ADD_FLAT,
		"value": maxi(0, level - 1) * MAX_HP_PER_LEVEL,
		"duration": Modifier.PERMANENT_DURATION,
		"stack_rule": Modifier.STACK_RULE_REPLACE_SAME_SOURCE,
	})
	heal(maxi(0, int(get_stat("max_hp")) - previous_max_hp))


func add_runtime_modifier(modifier_data: Dictionary) -> bool:
	var stat_id := str(modifier_data.get("stat", ""))
	var value := float(modifier_data.get("value", 0.0))
	if value > 0.0 and _is_stat_increase_blocked(stat_id) and not _is_existing_modifier_rebuild(modifier_data):
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


func get_shop_price_discount_layers() -> Array[float]:
	# 商店价格折扣逐层乘算：每个遗物/营地加成各占一层。
	var layers: Array[float] = []
	var modifiers := modifier_stack.get_all_modifiers("shop_price_percent")
	for modifier in modifiers:
		if modifier == null:
			continue
		if modifier.operation != Modifier.OPERATION_ADD_FLAT:
			# 出现非加算修饰时退回整体数值，避免静默丢失效果。
			var aggregate := get_stat("shop_price_percent")
			return [aggregate] if not is_zero_approx(aggregate) else []
	var base_value := modifier_stack.get_base_stat("shop_price_percent", 0.0)
	if not is_zero_approx(base_value):
		layers.append(base_value)
	for modifier in modifiers:
		if modifier != null and not is_zero_approx(modifier.value):
			layers.append(modifier.value)
	return layers


func get_effective_shop_discount() -> float:
	return (1.0 - StatDefinitions.calculate_shop_price_multiplier(get_shop_price_discount_layers())) * 100.0


func begin_modifier_update() -> void:
	if _modifier_update_depth == 0:
		_modifiers_before_update.clear()
		for modifier in modifier_stack.modifiers:
			_modifiers_before_update[modifier.id] = {"stat": modifier.stat, "operation": modifier.operation, "value": modifier.value}
	_modifier_update_depth += 1


func end_modifier_update() -> void:
	assert(_modifier_update_depth > 0)
	_modifier_update_depth -= 1
	if _modifier_update_depth == 0:
		_modifiers_before_update.clear()
		_update_after_stat_change()


func _is_existing_modifier_rebuild(data: Dictionary) -> bool:
	var previous: Dictionary = _modifiers_before_update.get(str(data.get("id", "")), {})
	return not previous.is_empty() and previous.get("stat") == data.get("stat") \
		and previous.get("operation") == data.get("operation") \
		and is_equal_approx(float(previous.get("value", 0.0)), float(data.get("value", 0.0)))


func create_stat_preview_copy() -> PlayerController:
	# Detached from the scene tree: no movement, pickups, or live UI signals.
	var preview := PlayerController.new()
	preview.auto_initialize_on_ready = false
	preview.character_id = character_id
	preview.character_data = character_data.duplicate(true)
	preview._starting_relics_granted = _starting_relics_granted
	preview.modifier_stack.base_stats = modifier_stack.base_stats.duplicate(true)
	preview.modifier_stack.modifiers = modifier_stack.get_all_modifiers()
	preview.current_hp = current_hp
	preview.current_shield = current_shield
	preview.current_shield_capacity = current_shield_capacity
	preview.remaining_revives = remaining_revives
	preview._configured_revive_count = _configured_revive_count
	preview._relic_runtime_sequence = _relic_runtime_sequence
	preview._stationary_seconds = _stationary_seconds
	preview._stationary_thresholds = _stationary_thresholds.duplicate()
	preview._stationary_position = _stationary_position
	preview.alive = alive
	preview.relic_system.owner_player = preview
	preview.relic_system.weapon_ids = relic_system.weapon_ids.duplicate()
	preview.relic_system.relic_instances = relic_system.relic_instances.duplicate(true)
	preview.relic_system.relic_ids_by_name = relic_system.relic_ids_by_name.duplicate(true)
	preview.relic_system.instance_sequence = relic_system.instance_sequence
	return preview


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


func add_relic(relic_id: String, character_innate: bool = false) -> bool:
	if not relic_system.add_relic(relic_id, character_innate):
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
	return not stat_id.is_empty() and relic_system.is_stat_increase_blocked(stat_id)


func sync_relic_weapon_ids(weapon_ids: Array[String]) -> void:
	relic_system.set_weapon_ids(weapon_ids)


func get_character_icon_path() -> String:
	return str(character_data.get("icon", ""))


func take_damage(raw_damage: int, source_id: String = "") -> int:
	# 护盾优先承伤且不受护甲影响；只有穿透护盾的生命伤害经过护甲换算。
	if not alive or _resolving_death or raw_damage <= 0 or _invincibility_timer > 0.0:
		return 0

	var had_shield := current_shield > 0
	var previous_hp := current_hp
	var damage_maximum_hp := int(get_stat("max_hp"))
	var shield_damage := mini(current_shield, raw_damage)
	current_shield -= shield_damage
	var remaining_damage := raw_damage - shield_damage
	var health_damage := 0
	if remaining_damage > 0:
		var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
		health_damage = maxi(1, int(roundi(float(remaining_damage) * damage_taken_percent / 100.0)))
	current_hp = maxi(current_hp - health_damage, 0)
	if health_damage > 0:
		health_damage_taken.emit(previous_hp, current_hp, damage_maximum_hp)
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
	# Ordinary healing cannot undo lethal damage while death is being resolved.
	# Revives restore HP through revive_from_lethal_damage instead.
	if not alive or current_hp <= 0 or amount <= 0:
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
	current_shield += amount
	# Refill damage first; only shield above the existing capacity grows it.
	current_shield_capacity = maxi(current_shield_capacity, current_shield)
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	return current_shield - old_shield


func reset_wave_shield() -> void:
	current_shield = _initial_wave_shield
	current_shield_capacity = _initial_wave_shield
	_shield_regen_remainder = 0.0
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)


func process_relic_runtime_trigger(trigger: String) -> void:
	if trigger in [BattleFinanceSystem.TRIGGER_WAVE_START, BattleFinanceSystem.TRIGGER_WAVE_END]:
		reset_stationary_relic_state()
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
	if active_controls and not keyboard_movement and has_move_destination:
		velocity = direction * minf(get_stat("move_speed"), global_position.distance_to(move_destination) / maxf(delta, 0.001))
	last_move_direction = direction.normalized()
	if not is_zero_approx(direction.x):
		_set_facing(direction.x > 0.0)
	move_and_slide()
	_update_walk_animation(direction, delta)


func _read_move_input() -> Vector2:
	if active_controls and not keyboard_movement and _mobile_move_direction.is_zero_approx():
		if has_move_destination:
			if global_position.distance_squared_to(move_destination) <= 4.0:
				has_move_destination = false
			else:
				return global_position.direction_to(move_destination)
		return Vector2.ZERO
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
	if not _mobile_move_direction.is_zero_approx():
		reset_stationary_relic_state()


func reset_stationary_relic_state() -> void:
	var had_bonus := _has_stationary_relic_bonus()
	_stationary_seconds = 0.0
	_stationary_position = global_position
	if had_bonus:
		_update_after_stat_change()


func _has_stationary_relic_bonus() -> bool:
	for threshold in _stationary_thresholds:
		if _stationary_seconds >= threshold:
			return true
	return false


func _tick_stationary_relic_state(delta: float) -> void:
	# Cache thresholds when relics change; do not rebuild modifiers every frame.
	if not alive or not _read_move_input().is_zero_approx() or not global_position.is_equal_approx(_stationary_position):
		reset_stationary_relic_state()
		return
	if _stationary_thresholds.is_empty():
		return
	var previous := _stationary_seconds
	_stationary_seconds = minf(_stationary_seconds + maxf(delta, 0.0), _stationary_thresholds.back())
	for threshold in _stationary_thresholds:
		if previous < threshold and _stationary_seconds >= threshold:
			_update_after_stat_change()
			break


func _clear_move_input() -> void:
	_held_move_keys.clear()
	_mobile_move_direction = Vector2.ZERO
	has_move_destination = false
	velocity = Vector2.ZERO


func request_move(point: Vector2) -> void:
	move_destination = point
	has_move_destination = true
	reset_stationary_relic_state()


func accept_move_key(event: InputEventKey) -> bool:
	if not keyboard_movement:
		return false
	var code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code not in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return false
	_held_move_keys[code] = event.pressed
	return true


func _process_regeneration(delta: float) -> void:
	if not alive or delta <= 0.0:
		return
	var max_hp := int(get_stat("max_hp"))
	# 负回血只在战斗结算时按 0 处理：面板仍显示真实负值，但不会掉血。
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
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_apply_idle_visual()


func _configure_character_visuals(visuals: Dictionary) -> void:
	_idle_texture = PLAYER_IDLE_TEXTURE
	_walk_texture = PLAYER_WALK_TEXTURE
	var idle_path := str(visuals.get("idle", ""))
	var walk_path := str(visuals.get("walk", ""))
	if not idle_path.is_empty() and ResourceLoader.exists(idle_path):
		_idle_texture = load(idle_path) as Texture2D
	if not walk_path.is_empty() and ResourceLoader.exists(walk_path):
		_walk_texture = load(walk_path) as Texture2D
	walk_frame_count = maxi(1, int(visuals.get("walk_frames", 6)))
	walk_animation_fps = maxf(0.0, float(visuals.get("walk_fps", 6.0)))
	_walk_animation_time = 0.0
	facing_right = true
	_setup_visuals()


func _sync_camera() -> void:
	if camera_2d != null:
		# Snap the view only; physics keeps its subpixel movement precision.
		camera_2d.global_position = global_position.round()


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
	sprite.texture = _idle_texture
	sprite.hframes = 1
	sprite.frame = 0


func _apply_walk_visual() -> void:
	if sprite != null:
		sprite.texture = _walk_texture
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
	# Compare completed modifier sets. A rebuild must not grant spent revives
	# when an existing relic is temporarily removed and reapplied.
	if _modifier_update_depth > 0:
		return
	var configured_revives := int(get_stat("revive_count"))
	if configured_revives > _configured_revive_count:
		remaining_revives += configured_revives - _configured_revive_count
	_configured_revive_count = configured_revives
	remaining_revives = mini(remaining_revives, configured_revives)
	current_hp = mini(current_hp, int(get_stat("max_hp")))
	_update_pickup_radius()
	_refresh_relic_dynamic_effects()
	hp_changed.emit(current_hp, int(get_stat("max_hp")), current_shield)
	stats_changed.emit()


func _refresh_relic_dynamic_effects() -> void:
	if _refreshing_relic_dynamic_effects or _modifier_update_depth > 0:
		return
	_refreshing_relic_dynamic_effects = true
	var previous_values := modifier_stack.get_values_by_source_type("relic_dynamic")
	modifier_stack.remove_by_source_type("relic_dynamic")
	var ordered_effects := _get_ordered_dynamic_effects()
	_stationary_thresholds.clear()
	for effect in ordered_effects:
		if str(effect.get("condition", "")) == "stationary_seconds":
			var threshold := maxf(float(effect.get("threshold", 1.0)), 0.001)
			if not _stationary_thresholds.has(threshold):
				_stationary_thresholds.append(threshold)
	_stationary_thresholds.sort()
	if _stationary_thresholds.is_empty():
		_stationary_seconds = 0.0
	for effect in ordered_effects:
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
			var source_value := get_stat(source_stat)
			if bool(effect.get("positive_source_only", false)):
				source_value = maxf(source_value, 0.0)
			value = floorf(source_value / divisor) * per_unit
		var instance_id := str(effect.get("relic_instance_id", "relic"))
		var effect_index := int(effect.get("relic_runtime_effect_index", 0))
		var modifier_id := "relic_dynamic_%s_%d" % [instance_id, effect_index]
		if _is_stat_increase_blocked(target_stat):
			value = minf(value, float(previous_values.get(modifier_id, 0.0)))
		if is_zero_approx(value):
			continue
		modifier_stack.add_modifier_from_dictionary({
			"id": modifier_id,
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


func _get_ordered_dynamic_effects() -> Array[Dictionary]:
	# Resolve all contributions to a source stat before any dependent stat.
	var groups := {}
	var dependencies := {}
	for effect in get_active_relic_runtime_effects(BattleFinanceSystem.TRIGGER_DYNAMIC):
		var kind := str(effect.get("effect", ""))
		if kind not in [BattleFinanceSystem.EFFECT_CONDITIONAL_STAT, BattleFinanceSystem.EFFECT_DERIVED_STAT_FROM_PLAYER_STAT]:
			continue
		var target := str(effect.get("stat", effect.get("target_stat", "")))
		if not groups.has(target):
			groups[target] = []
			dependencies[target] = []
		groups[target].append(effect)
		var source := str(effect.get("source_stat", ""))
		if str(effect.get("condition", "")) == "humanity_below":
			source = "humanity"
		elif str(effect.get("condition", "")) == "hp_percent_below":
			source = "max_hp"
		if not source.is_empty():
			dependencies[target].append(source)
	var ordered: Array[Dictionary] = []
	var pending: Array = groups.keys()
	pending.sort()
	while not pending.is_empty():
		var progressed := false
		for target in pending.duplicate():
			var ready := true
			for source in dependencies[target]:
				if pending.has(source):
					ready = false
			if not ready:
				continue
			for effect in groups[target]:
				ordered.append(effect)
			pending.erase(target)
			progressed = true
		if not progressed:
			push_warning("Cyclic relic stat dependencies: %s" % str(pending))
			break
	return ordered


func _is_relic_condition_active(effect: Dictionary) -> bool:
	var condition := str(effect.get("condition", ""))
	var threshold := float(effect.get("threshold", 0.0))
	match condition:
		"hp_percent_below":
			var max_hp := maxf(float(get_stat("max_hp")), 1.0)
			return float(current_hp) / max_hp * 100.0 < threshold
		"humanity_below":
			return get_stat("humanity") < threshold
		"stationary_seconds":
			return alive and _stationary_seconds >= threshold
	return false


func _process_relic_runtime_trigger(trigger: String) -> void:
	var effects := get_active_relic_runtime_effects(trigger)
	var values: Array[float] = []
	# Resolve conditional amounts before any effect changes the triggering stats.
	for effect in effects:
		var value := float(effect.get("value", 0.0))
		if str(effect.get("effect", "")) == BattleFinanceSystem.EFFECT_ADD_STAT and effect.has("condition"):
			if not _is_relic_condition_active(effect):
				value = float(effect.get("else_value", 0.0))
		values.append(value)
	for index in effects.size():
		var effect: Dictionary = effects[index]
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
					"value": values[index],
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
	if not alive or _resolving_death:
		return
	_resolving_death = true
	reset_stationary_relic_state()
	if _try_revive():
		_resolving_death = false
		return
	# Paid protection is a fallback after ordinary revive charges are exhausted.
	lethal_damage.emit()
	if current_hp <= 0:
		alive = false
		velocity = Vector2.ZERO
		died.emit()
		print("[PlayerController] player died, source=%s" % source_id)
	_resolving_death = false


func _try_revive() -> bool:
	if remaining_revives <= 0:
		return false
	remaining_revives -= 1
	return revive_from_lethal_damage(REVIVE_HEALTH_PERCENT * 100.0)


func revive_from_lethal_damage(health_percent: float) -> bool:
	if not alive or current_hp > 0 or health_percent <= 0.0:
		return false
	current_hp = maxi(1, ceili(get_stat("max_hp") * clampf(health_percent / 100.0, 0.0, 1.0)))
	current_shield = 0
	_invincibility_timer = REVIVE_INVINCIBILITY_SECONDS
	_update_after_stat_change()
	revived.emit(remaining_revives)
	_process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_ON_REVIVE)
	print("[PlayerController] player revived, remaining=%d" % remaining_revives)
	return true
