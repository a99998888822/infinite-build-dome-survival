extends Area2D
class_name AugmentationPickup

signal collected(pickup: AugmentationPickup, item_instance_id: String)

const DEFAULT_ATTRACT_SPEED: float = 300.0
const RARITY_COLORS: Dictionary = ItemInventoryCard.RARITY_COLORS
const ICON_SCALE := Vector2.ONE
const GLOW_RADIUS := 20.0

@export var attract_speed: float = DEFAULT_ATTRACT_SPEED

var augmentation_id: String = ""
var amount: int = 1
var target_player: PlayerController = null
var collected_once: bool = false
var _display_color: Color = Color.WHITE
var _age: float = 0.0
var _icon_sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("reward_pickups")
	add_to_group("augmentation_pickups")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_icon_sprite = Sprite2D.new()
	_icon_sprite.name = "IconSprite"
	_icon_sprite.z_index = 1
	_icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_sprite.centered = true
	_icon_sprite.scale = ICON_SCALE
	add_child(_icon_sprite)
	queue_redraw()


func initialize(target_augmentation_id: String, pickup_amount: int = 1) -> void:
	augmentation_id = target_augmentation_id
	amount = maxi(pickup_amount, 1)
	collected_once = false
	var data := DataRegistry.get_record("augmentations", augmentation_id)
	_display_color = RARITY_COLORS.get(str(data.get("rarity", "common")), Color.WHITE)
	_update_icon(str(data.get("icon", "")))
	queue_redraw()


func set_target_player(player: PlayerController) -> void:
	target_player = player


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_age += delta
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


func _update_icon(icon_path: String) -> void:
	if _icon_sprite == null:
		return
	_icon_sprite.texture = null
	_icon_sprite.visible = false
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return
	var resource := load(icon_path)
	if resource is Texture2D:
		_icon_sprite.texture = resource as Texture2D
		_icon_sprite.visible = true


func _draw() -> void:
	var pulse := 0.9 + sin(_age * 2.6) * 0.1
	# A faint falloff behind the actual inventory icon; no opaque badge or spin.
	for layer in 6:
		var radius := GLOW_RADIUS * (1.0 - float(layer) * 0.12)
		draw_circle(Vector2.ZERO, radius, Color(_display_color, (0.012 + float(layer) * 0.006) * pulse))
