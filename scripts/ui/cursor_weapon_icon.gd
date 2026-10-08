extends PanelContainer
class_name CursorWeaponIcon
## Screen-space display only; never consumes mouse input.

const ICON_SIZE := Vector2(38, 38)
var icon: TextureRect
var weapon: WeaponInstance
var _frame: StyleBoxFlat
var _icon_path := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color("14201ce8")
	_frame.border_color = Color("8d977d")
	_frame.set_border_width_all(1)
	_frame.set_corner_radius_all(3)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_frame.set_content_margin(side, 4)
	add_theme_stylebox_override("panel", _frame)
	icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	hide()


func update_weapon(source: WeaponInstance, aiming: bool, ready_to_cast: bool) -> void:
	var path := source.get_combat_icon_path() if source != null else ""
	if weapon != source or _icon_path != path:
		weapon = source
		_icon_path = path
		icon.texture = load(path) if not path.is_empty() else null
	_frame.border_color = Color("c5edff") if aiming else Color("8d977d")
	icon.modulate = Color.WHITE if ready_to_cast else Color(0.55, 0.55, 0.55, 0.9)


func follow_pointer(point: Vector2, viewport_size: Vector2) -> void:
	var target := point + Vector2(16, -ICON_SIZE.y - 10)
	if target.x + size.x > viewport_size.x - 4:
		target.x = point.x - size.x - 16
	if target.y < 4:
		target.y = point.y + 16
	position = target.clamp(Vector2(4, 4), (viewport_size - size - Vector2(4,4)).max(Vector2(4,4)))
