extends StyleBox
class_name NativeHudFlatStyle
## Rectangular HUD borders with fractional native canvas widths.

@export var bg_color := Color.TRANSPARENT
@export var border_color := Color.TRANSPARENT
@export var border_widths := Vector4.ZERO # left, top, right, bottom


static func from_flat(source: StyleBoxFlat, widths: Vector4) -> NativeHudFlatStyle:
	var style := NativeHudFlatStyle.new()
	style.bg_color = source.bg_color
	style.border_color = source.border_color
	style.border_widths = widths
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, source.get_content_margin(side))
	return style


func _draw(canvas_item: RID, rect: Rect2) -> void:
	var inner := Rect2(rect.position + Vector2(border_widths.x, border_widths.y), rect.size - Vector2(border_widths.x + border_widths.z, border_widths.y + border_widths.w))
	RenderingServer.canvas_item_add_rect(canvas_item, inner, bg_color)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position, Vector2(rect.size.x, border_widths.y)), border_color)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position.x, inner.end.y, rect.size.x, border_widths.w), border_color)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position.x, inner.position.y, border_widths.x, inner.size.y), border_color)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(inner.end.x, inner.position.y, border_widths.z, inner.size.y), border_color)
