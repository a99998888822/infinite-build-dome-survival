extends Area2D
class_name RelicPickup

signal collected(pickup: RelicPickup)

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
	# A gold reliquary pedestal distinguishes relics from scrolls and XP orbs.
	var lift := Vector2(0, -4.0 + sin(_age * 3.0) * 2.0)
	draw_rect(Rect2(-20, 11, 40, 6), Color(0.08, 0.06, 0.12, 0.65))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 5), Vector2(0, -7), Vector2(20, 5), Vector2(0, 17)]), Color("8b692d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 5), Vector2(0, -4), Vector2(16, 5), Vector2(0, 13)]), Color("ead391"))
	draw_rect(Rect2(Vector2(-18, -29) + lift, Vector2(36, 36)), Color(0.77, 0.53, 0.94, 0.18))
	# Three tablets communicate a choice instead of a predetermined relic.
	for index in 3:
		var x := -15.0 + float(index) * 9.0
		draw_rect(Rect2(Vector2(x, -23 - (3 if index == 1 else 0)) + lift, Vector2(12, 23)), Color("ffe5a4"))
		draw_rect(Rect2(Vector2(x + 2, -21 - (3 if index == 1 else 0)) + lift, Vector2(8, 19)), Color("756084"))
	draw_rect(Rect2(Vector2(-22, -18) + lift, Vector2(3, 3)), Color("ffe5a4"))
	draw_rect(Rect2(Vector2(20, -8) + lift, Vector2(3, 3)), Color("ffe5a4"))
