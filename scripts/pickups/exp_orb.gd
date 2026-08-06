extends Area2D
class_name ExpOrb

signal collected(orb: ExpOrb, exp_amount: int, gold_amount: int)

const DEFAULT_AMOUNT: int = 1
const DEFAULT_ATTRACT_SPEED: float = 480.0

@export var amount: int = DEFAULT_AMOUNT
@export var attract_speed: float = DEFAULT_ATTRACT_SPEED

var target_player: PlayerController = null
var collected_once: bool = false


func _ready() -> void:
	add_to_group("exp_orbs")
	body_entered.connect(_on_body_entered)


func initialize(exp_amount: int) -> void:
	amount = maxi(exp_amount, 0)
	collected_once = false


func set_target_player(player: PlayerController) -> void:
	target_player = player


func _physics_process(delta: float) -> void:
	if target_player == null or collected_once:
		return
	var pickup_radius := target_player.get_stat("pickup_radius")
	if global_position.distance_to(target_player.global_position) > pickup_radius:
		return
	global_position = global_position.move_toward(target_player.global_position, attract_speed * delta)
	if global_position.distance_to(target_player.global_position) <= 16.0:
		collect()


func collect() -> void:
	if collected_once:
		return
	collected_once = true
	collected.emit(self, amount, amount)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		target_player = body
		collect()
