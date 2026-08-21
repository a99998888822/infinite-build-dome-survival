extends Area2D
class_name ExpOrb

signal collected(orb: ExpOrb, exp_amount: int, gold_amount: int)

const DEFAULT_AMOUNT: int = 1
const DEFAULT_ATTRACT_SPEED: float = 480.0
const WAVE_END_ATTRACT_SPEED: float = 960.0

@export var amount: int = DEFAULT_AMOUNT
@export var attract_speed: float = DEFAULT_ATTRACT_SPEED

var target_player: PlayerController = null
var collected_once: bool = false
var force_collecting: bool = false
var forced_attract_speed: float = WAVE_END_ATTRACT_SPEED
var _collection_time: float = 0.0
var _collection_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("exp_orbs")
	add_to_group("reward_pickups")
	body_entered.connect(_on_body_entered)


func initialize(exp_amount: int) -> void:
	if not is_in_group("exp_orbs"):
		add_to_group("exp_orbs")
	if not is_in_group("reward_pickups"):
		add_to_group("reward_pickups")
	amount = maxi(exp_amount, 0)
	collected_once = false
	force_collecting = false


func set_target_player(player: PlayerController) -> void:
	target_player = player


func start_wave_end_collection(player: PlayerController) -> void:
	target_player = player
	force_collecting = true
	forced_attract_speed = WAVE_END_ATTRACT_SPEED
	_collection_time = 0.0
	_collection_start = global_position


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	if target_player == null or collected_once:
		return
	var pickup_radius := INF if force_collecting else target_player.get_stat("pickup_radius")
	var distance_to_player := global_position.distance_to(target_player.global_position)
	if distance_to_player > pickup_radius:
		return
	var speed := forced_attract_speed if force_collecting else attract_speed
	if force_collecting:
		_collection_time += delta
		var target_position := target_player.global_position
		var next_position := global_position.move_toward(target_position, speed * delta)
		var arc := sin(clampf(_collection_time * 5.0, 0.0, PI)) * 18.0
		global_position = next_position + Vector2(0.0, -arc)
		rotation += delta * 8.0
	else:
		global_position = global_position.move_toward(target_player.global_position, speed * delta)
	if global_position.distance_to(target_player.global_position) <= 16.0:
		collect()


func collect() -> void:
	if collected_once:
		return
	collected_once = true
	if AudioManager != null:
		AudioManager.play_exp_orb_collect_sfx()
	collected.emit(self, amount, amount)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		target_player = body
		collect()
