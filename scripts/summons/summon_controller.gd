extends CharacterBody2D
class_name SummonController

signal damage_dealt(summon: SummonController, target: Node2D, raw_damage: int, dealt_damage: int, critical: bool)
signal died(summon: SummonController, reason: String)

const DEFAULT_SUMMON_ID: String = "summon_kinling"
const MIN_ATTACK_INTERVAL_SECONDS: float = 0.05
const ARRIVE_DISTANCE: float = 6.0
const INHERITED_PLAYER_STATS := {
	"summon_damage": true,
	"damage_percent": true,
	"attack_speed": true,
	"cooldown_reduction": true,
	"crit_chance": true,
	"crit_damage": true,
	"area_size": true,
}

@export var summon_id: String = DEFAULT_SUMMON_ID
@export var auto_register_groups: bool = true

var summon_data: Dictionary = {}
var modifier_stack: ModifierStack = ModifierStack.new()
var owner_player: PlayerController = null
var targeting_service: TargetingService = null
var current_hp: int = 0
var alive: bool = true
var attack_interval_ms: int = 700
var attack_radius: float = 72.0
var follow_distance: float = 96.0
var chase_radius: float = 320.0
var leash_distance: float = 420.0
var lifetime_seconds: float = -1.0
var use_cooldown_reduction_only: bool = false
var formation_index: int = 0
var formation_count: int = 1

var _attack_timer: float = 0.0
var _life_timer: float = -1.0

@onready var visual_anchor: Node2D = get_node_or_null("VisualAnchor")
@onready var sprite: Sprite2D = get_node_or_null("VisualAnchor/Sprite2D")


func _ready() -> void:
	if auto_register_groups:
		add_to_group("summons")
		add_to_group("friendly_entities")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	modifier_stack.tick(delta)
	if _tick_lifetime(delta):
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var target := _select_target()
	_process_movement(target)
	if target != null and global_position.distance_to(target.global_position) <= get_attack_radius():
		try_attack_target(target)


func initialize(player: PlayerController, service: TargetingService, data: Dictionary = {}, runtime_modifiers: Array = []) -> bool:
	# 初始化只写入本次召唤运行态，不修改玩家、武器或配置表。
	owner_player = player
	targeting_service = service
	summon_data = data.duplicate(true)
	summon_id = str(summon_data.get("id", DEFAULT_SUMMON_ID)).strip_edges()
	if summon_id.is_empty():
		summon_id = DEFAULT_SUMMON_ID
	modifier_stack.set_base_stats(_get_dictionary(summon_data.get("base_stats", {})))
	_apply_runtime_modifiers(runtime_modifiers)
	attack_interval_ms = maxi(1, int(summon_data.get("attack_interval_ms", attack_interval_ms)))
	attack_radius = maxf(float(summon_data.get("attack_radius", attack_radius)), 1.0)
	follow_distance = maxf(float(summon_data.get("follow_distance", follow_distance)), 0.0)
	chase_radius = maxf(float(summon_data.get("chase_radius", chase_radius)), 0.0)
	leash_distance = maxf(float(summon_data.get("leash_distance", leash_distance)), follow_distance)
	lifetime_seconds = float(summon_data.get("lifetime_seconds", lifetime_seconds))
	use_cooldown_reduction_only = bool(summon_data.get("use_cooldown_reduction_only", use_cooldown_reduction_only))
	formation_index = maxi(0, int(summon_data.get("formation_index", formation_index)))
	formation_count = maxi(1, int(summon_data.get("formation_count", formation_count)))
	current_hp = int(get_stat("max_hp"))
	alive = true
	_attack_timer = 0.0
	_life_timer = lifetime_seconds
	return true


func set_formation(index: int, count: int) -> void:
	formation_index = maxi(0, index)
	formation_count = maxi(1, count)


func add_runtime_modifier(modifier_data: Dictionary) -> bool:
	var modifier := modifier_stack.add_modifier_from_dictionary(modifier_data)
	return modifier != null


func add_runtime_modifiers(modifier_data_list: Array) -> void:
	_apply_runtime_modifiers(modifier_data_list)


func get_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	var local_value := modifier_stack.get_stat(stat_id, fallback_base_value)
	if owner_player == null or not INHERITED_PLAYER_STATS.has(stat_id):
		return local_value
	var default_value := StatDefinitions.get_default_value(stat_id)
	var owner_value := owner_player.get_stat(stat_id, default_value)
	return StatDefinitions.clamp_stat_value(stat_id, local_value + owner_value - default_value)


func get_attack_radius() -> float:
	return StatDefinitions.calculate_attack_radius(attack_radius, get_stat("area_size"))


func get_actual_attack_interval_seconds() -> float:
	var base_interval := maxf(float(attack_interval_ms) / 1000.0, MIN_ATTACK_INTERVAL_SECONDS)
	if use_cooldown_reduction_only:
		return maxf(StatDefinitions.calculate_cooldown(base_interval, get_stat("cooldown_reduction")), MIN_ATTACK_INTERVAL_SECONDS)
	return maxf(StatDefinitions.calculate_attack_interval(base_interval, get_stat("attack_speed")), MIN_ATTACK_INTERVAL_SECONDS)


func try_attack_target(target: Node2D = null, force_critical: bool = false, ignore_cooldown: bool = false) -> int:
	# 统一召唤物攻击入口，后续统计和特效都从这里接入。
	if not alive or (not ignore_cooldown and _attack_timer > 0.0):
		return 0
	var actual_target := target if target != null else _select_target()
	if not _is_valid_target(actual_target):
		return 0
	if global_position.distance_to(actual_target.global_position) > get_attack_radius():
		return 0
	var damage_payload := _calculate_attack_damage(force_critical)
	var raw_damage := int(damage_payload.get("damage", 0))
	if raw_damage <= 0 or not actual_target.has_method("take_damage"):
		return 0
	var dealt_damage := int(actual_target.call("take_damage", raw_damage, summon_id))
	_attack_timer = get_actual_attack_interval_seconds()
	damage_dealt.emit(self, actual_target, raw_damage, dealt_damage, bool(damage_payload.get("critical", false)))
	return dealt_damage


func take_damage(raw_damage: int, source_id: String = "") -> int:
	if not alive or raw_damage <= 0:
		return 0
	var damage_taken_percent := get_stat("damage_taken_percent", 100.0)
	var final_damage := maxi(1, int(roundi(float(raw_damage) * damage_taken_percent / 100.0)))
	current_hp = maxi(current_hp - final_damage, 0)
	if current_hp <= 0:
		_die("damage:%s" % source_id)
	return final_damage


func is_alive() -> bool:
	return alive


func _apply_runtime_modifiers(modifier_data_list: Array) -> void:
	for modifier_data in modifier_data_list:
		if modifier_data is Dictionary:
			add_runtime_modifier(modifier_data)


func _tick_lifetime(delta: float) -> bool:
	if _life_timer < 0.0:
		return false
	_life_timer = maxf(_life_timer - delta, 0.0)
	if _life_timer <= 0.0:
		_die("expired")
		return true
	return false


func _process_movement(target: Node2D) -> void:
	var desired_position := _get_follow_position()
	if _can_chase_target(target):
		desired_position = target.global_position
	var direction := global_position.direction_to(desired_position)
	if global_position.distance_to(desired_position) <= ARRIVE_DISTANCE:
		velocity = Vector2.ZERO
	else:
		velocity = direction * get_stat("move_speed")
	_update_facing(direction)
	move_and_slide()


func _can_chase_target(target: Node2D) -> bool:
	if not _is_valid_target(target) or owner_player == null:
		return false
	if global_position.distance_to(owner_player.global_position) > leash_distance:
		return false
	return global_position.distance_to(target.global_position) <= chase_radius


func _select_target() -> Node2D:
	if targeting_service == null:
		return null
	var nearest := targeting_service.find_nearest_enemy(global_position)
	return nearest if _is_valid_target(nearest) else null


func _is_valid_target(target: Node2D) -> bool:
	if target == null or not target.is_inside_tree():
		return false
	if target.has_method("is_alive") and not bool(target.call("is_alive")):
		return false
	return true


func _get_follow_position() -> Vector2:
	var origin := owner_player.global_position if owner_player != null else global_position
	if follow_distance <= 0.0:
		return origin
	var angle := TAU * float(formation_index % formation_count) / float(formation_count)
	return origin + Vector2.RIGHT.rotated(angle) * follow_distance


func _update_facing(direction: Vector2) -> void:
	if is_zero_approx(direction.x):
		return
	if visual_anchor != null:
		visual_anchor.scale.x = 1.0 if direction.x >= 0.0 else -1.0
	elif sprite != null:
		sprite.flip_h = direction.x < 0.0


func _calculate_attack_damage(force_critical: bool = false) -> Dictionary:
	var base_damage := get_stat("summon_damage")
	if base_damage <= 0.0:
		return {"damage": 0, "critical": false}
	var damage := base_damage * (1.0 + get_stat("damage_percent") / 100.0)
	var critical := force_critical or randf() * 100.0 < get_stat("crit_chance")
	if critical:
		damage *= get_stat("crit_damage") / 100.0
	return {
		"damage": maxi(1, int(roundi(damage))),
		"critical": critical,
	}


func _die(reason: String = "") -> void:
	if not alive:
		return
	alive = false
	velocity = Vector2.ZERO
	died.emit(self, reason)
	queue_free()


func _get_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
