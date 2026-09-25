extends Area2D
class_name RelicPickup

signal collected(pickup: RelicPickup)
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

var target_player: PlayerController = null
var collected_once: bool = false
var reward_snapshot: RewardSnapshot = null
var _age: float = 0.0
var _collect_request: Callable = Callable()


func _ready() -> void:
	add_to_group("reward_pickups")
	add_to_group("relic_pickups")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	queue_redraw()


func initialize_choice(player: PlayerController, request: Callable, snapshot: RewardSnapshot = null) -> void:
	target_player = player
	reward_snapshot = snapshot
	_collect_request = request
	queue_redraw()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) or collected_once:
		return
	_age += delta
	queue_redraw()
	if not is_instance_valid(target_player) or not target_player.is_alive():
		return
	if global_position.distance_to(target_player.global_position) <= target_player.get_stat("pickup_radius"):
		global_position = global_position.move_toward(target_player.global_position, 360.0 * delta)
		if global_position.distance_to(target_player.global_position) <= 16.0:
			collect()


func collect() -> bool:
	if collected_once or not is_instance_valid(target_player) or not target_player.is_alive():
		return false
	if not _collect_request.is_valid():
		return false
	# A pickup queues one choice; only the popup grants a selected relic.
	collected_once = true
	if not bool(_collect_request.call()):
		collected_once = false
		return false
	if reward_snapshot != null:
		reward_snapshot.collected_relics += 1
	collected.emit(self)
	queue_free()
	return true


func _on_body_entered(body: Node) -> void:
	if body == target_player and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		collect()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_age * 2.6)
	draw_set_transform(Vector2(0, 11))
	PIXEL.ellipse(self, Vector2(24, 8), Color(0.025, 0.045, 0.04, 0.7))
	PIXEL.arc(self, 25, 0.15, PI - 0.15, Color(0.62, 0.49, 0.24, 0.45 + pulse * 0.2), 2, Vector2(1, 0.32))
	PIXEL.arc(self, 25, PI + 0.15, TAU - 0.15, Color(0.86, 0.75, 0.42, 0.45 + pulse * 0.2), 2, Vector2(1, 0.32))
	# A hovering, brass-bound reliquary with a luminous seal and carved lid.
	draw_set_transform(Vector2(0, -5 + roundf(sin(_age * 2.6) * 2)))
	PIXEL.polygon(self, PackedVector2Array([Vector2(-19,-22), Vector2(13,-25), Vector2(22,-17), Vector2(20,6), Vector2(-12,10), Vector2(-21,2)]), Color("161e1b"))
	PIXEL.polygon(self, PackedVector2Array([Vector2(-18,-11), Vector2(11,-14), Vector2(11,6), Vector2(-17,7)]), Color("34453b"))
	PIXEL.polygon(self, PackedVector2Array([Vector2(11,-14), Vector2(20,-18), Vector2(18,2), Vector2(11,6)]), Color("172b2a"))
	PIXEL.polygon(self, PackedVector2Array([Vector2(-20,-19), Vector2(10,-23), Vector2(22,-17), Vector2(11,-11), Vector2(-19,-8)]), Color("b29352"))
	PIXEL.polygon(self, PackedVector2Array([Vector2(-15,-18), Vector2(9,-21), Vector2(16,-17), Vector2(9,-14), Vector2(-14,-12)]), Color("4b6555"))
	PIXEL.path(self, PackedVector2Array([Vector2(-20,-8), Vector2(11,-11), Vector2(22,-17)]), Color("ffe7a4"), 2)
	PIXEL.path(self, PackedVector2Array([Vector2(-18,-7), Vector2(-18,7), Vector2(11,7), Vector2(19,2), Vector2(20,-12)]), Color("8e723e"), 3)
	for x in [-12, 6]:
		PIXEL.line(self, Vector2(x,-10), Vector2(x,6), Color("d5b574"), 3)
		PIXEL.block(self, Vector2(x,3), Vector2(2,2), Color("fff0bd"))
	# The split seal opens into three glints: this pickup still grants a choice.
	PIXEL.polygon(self, PackedVector2Array([Vector2(-3,-9),Vector2(2,-4),Vector2(-3,2),Vector2(-8,-4)]), Color("e5c77f"))
	PIXEL.polygon(self, PackedVector2Array([Vector2(-3,-7),Vector2(0,-4),Vector2(-3,0),Vector2(-6,-4)]), Color("73d6b5"))
	PIXEL.block(self, Vector2(-3,-4), Vector2(2,2), Color("e5fff0"))
	for index in 3:
		var age := fmod(_age * 0.35 + index / 3.0, 1.0)
		var point := Vector2((index - 1) * 13 + sin(age * TAU + index) * 3, -25 - age * 18)
		var alpha := sin(age * PI) * 0.9
		PIXEL.line(self, point - Vector2(3,0), point + Vector2(3,0), Color(0.97,0.88,0.57,alpha), 2)
		PIXEL.line(self, point - Vector2(0,4), point + Vector2(0,4), Color(0.97,0.95,0.77,alpha), 2)
	draw_set_transform(Vector2.ZERO)
