extends Button
class_name TalentNodeButton
## Resolution-independent metal frames; original pixel icons stay untouched.
const PALETTE = preload("res://scripts/ui/hud_palette.gd")
var icon_texture: Texture2D
var background_texture: Texture2D
var gray_icon: Texture2D
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var active := selected and not disabled
	var hovered := is_hovered() and not disabled
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var edge := PALETTE.WARM_ACTIVE if active else PALETTE.ACTIVE if hovered else PALETTE.METAL if lit else PALETTE.BORDER
	draw_circle(center + Vector2(0, 2), radius + 2, PALETTE.SHADOW, true, -1, true)
	draw_circle(center, radius, PALETTE.NODE_FILL if lit else PALETTE.PANEL_FILL, true, -1, true)
	draw_arc(center, radius, 0, TAU, 128, edge, 1.5, true)
	draw_arc(center, radius - 4, 0, TAU, 128, PALETTE.BORDER, 1, true)
	draw_arc(center, radius - 2, PI * 1.05, PI * 1.9, 64, edge.lightened(0.15), 1, true)
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
