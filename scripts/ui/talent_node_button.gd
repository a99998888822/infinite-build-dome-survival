extends Button
class_name TalentNodeButton
## Palette-matched rings communicate state without tinting the item artwork.
const PALETTE = preload("res://scripts/ui/hud_palette.gd")
var icon_texture: Texture2D
var background_texture: Texture2D
var gray_icon: Texture2D
var gray_background: Texture2D
var lit := false
var selected := false
var building := false
# The circular HUD has a smaller inner face than its rectangular texture bounds.
const BUILDING_ICON_EXTENT := 64.0
const UPGRADE_ICON_EXTENT := 64.0
const NODE_EXTENT := 104.0

func configure(record: Dictionary, is_building: bool, background: Texture2D) -> void:
	building = is_building
	icon_texture = load(str(record.icon)) as Texture2D
	background_texture = background
	gray_icon = _grayscale(icon_texture)
	gray_background = _grayscale(background_texture)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	if background_texture == null: return
	var ring: Texture2D = background_texture if lit else PALETTE.NODE_LOCKED
	if selected and not disabled:
		ring = PALETTE.WARM_NODE
	elif is_hovered() and not disabled:
		ring = PALETTE.NODE_SELECTED
	draw_texture_rect(ring, Rect2(Vector2.ZERO, size), false)
	draw_texture_rect(icon_texture if lit else gray_icon, get_icon_rect(), false)

func get_icon_rect() -> Rect2:
	var extent := BUILDING_ICON_EXTENT if building else UPGRADE_ICON_EXTENT
	return Rect2(((size - Vector2.ONE * extent) * 0.5).round(), Vector2.ONE * extent)

static func _grayscale(texture: Texture2D) -> Texture2D:
	var source := texture.get_image()
	if source.is_compressed(): source.decompress()
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(x, y)
			var value := (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 0.70
			source.set_pixel(x, y, Color(value, value, value, c.a))
	return ImageTexture.create_from_image(source)
