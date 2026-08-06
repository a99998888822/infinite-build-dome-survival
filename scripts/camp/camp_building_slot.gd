extends Area2D
class_name CampBuildingSlot

signal pressed(building_id: String)

@export var building_id: String = ""

var display_name: String = ""
var _ruins_texture: Texture2D = null
var _building_texture: Texture2D = null

@onready var ruins_sprite: Sprite2D = get_node_or_null("RuinsSprite2D")
@onready var building_sprite: Sprite2D = get_node_or_null("BuildingSprite2D")
@onready var name_label: Label = get_node_or_null("NameLabel")


func _ready() -> void:
	input_pickable = true
	if name_label != null:
		name_label.text = display_name
	refresh_visual()


func configure(target_building_id: String, target_display_name: String) -> void:
	building_id = target_building_id
	display_name = target_display_name
	if name_label != null:
		name_label.text = display_name
	refresh_visual()


func refresh_visual() -> void:
	if building_id.is_empty():
		return
	var display_state := CampProgression.get_building_display_state(building_id)
	if ruins_sprite != null:
		var ruins_path := CampProgression.get_building_ruins_texture_path(building_id)
		if display_state == "ruins":
			ruins_sprite.texture = _load_texture_or_placeholder(ruins_path, Color(0.48, 0.48, 0.48, 1.0), Vector2i(64, 64))
			ruins_sprite.visible = true
		else:
			ruins_sprite.visible = false
	if building_sprite != null:
		var building_path := CampProgression.get_building_texture_path(building_id)
		building_sprite.texture = _load_texture_or_placeholder(building_path, Color(0.55, 0.80, 0.55, 1.0), Vector2i(64, 64))
		building_sprite.visible = display_state == "unlocked"


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(building_id)


func _load_texture_or_placeholder(texture_path: String, color: Color, size: Vector2i) -> Texture2D:
	if FileAccess.file_exists(texture_path):
		var loaded_texture := load(texture_path)
		if loaded_texture is Texture2D:
			return loaded_texture
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
