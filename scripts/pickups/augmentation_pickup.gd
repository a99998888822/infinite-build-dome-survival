extends Area2D
class_name AugmentationPickup

signal collected(pickup: AugmentationPickup, item_instance_id: String)

const DEFAULT_ATTRACT_SPEED: float = 300.0
const RARITY_COLORS: Dictionary = {
	"common": Color(0.43, 0.72, 0.48, 1.0),
	"uncommon": Color(0.34, 0.82, 0.78, 1.0),
	"rare": Color(0.34, 0.55, 0.95, 1.0),
	"epic": Color(0.72, 0.42, 0.94, 1.0),
	"mythic": Color(1.0, 0.54, 0.25, 1.0),
	"legendary": Color(1.0, 0.82, 0.28, 1.0),
}

@export var attract_speed: float = DEFAULT_ATTRACT_SPEED

var augmentation_id: String = ""
var amount: int = 1
var target_player: PlayerController = null
var collected_once: bool = false
var _display_color: Color = Color.WHITE
var _rotation_time: float = 0.0


func _ready() -> void:
	add_to_group("reward_pickups")
	add_to_group("augmentation_pickups")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	queue_redraw()


func initialize(target_augmentation_id: String, pickup_amount: int = 1) -> void:
	augmentation_id = target_augmentation_id
	amount = maxi(pickup_amount, 1)
	collected_once = false
	var data := DataRegistry.get_record("augmentations", augmentation_id)
	_display_color = RARITY_COLORS.get(str(data.get("rarity", "common")), Color.WHITE)
	queue_redraw()


func set_target_player(player: PlayerController) -> void:
	target_player = player


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_rotation_time += delta
	rotation = _rotation_time * 2.2
	queue_redraw()
	if target_player == null or collected_once:
		return
	var pickup_radius := target_player.get_stat("pickup_radius")
	if global_position.distance_to(target_player.global_position) > pickup_radius:
		return
	global_position = global_position.move_toward(target_player.global_position, attract_speed * delta)
	if global_position.distance_to(target_player.global_position) <= 16.0:
		collect()


func collect() -> void:
	if collected_once or target_player == null or target_player.item_inventory == null:
		return
	var first_item_instance_id := ""
	for index in amount:
		var item := target_player.item_inventory.add_item_from_base(augmentation_id, "drop")
		if item.is_empty():
			return
		if first_item_instance_id.is_empty():
			first_item_instance_id = str(item.get("item_instance_id", ""))
	collected_once = true
	collected.emit(self, first_item_instance_id)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		target_player = body as PlayerController
		collect()


func _draw() -> void:
	var pulse := 1.0 + sin(_rotation_time * 7.0) * 0.10
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color(_display_color.r, _display_color.g, _display_color.b, 0.14))
	draw_circle(Vector2.ZERO, 6.5 * pulse, Color(_display_color.r, _display_color.g, _display_color.b, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(6, 0), Vector2(0, 7), Vector2(-6, 0)]), Color.WHITE)
