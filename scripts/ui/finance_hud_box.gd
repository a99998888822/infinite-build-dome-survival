extends NativeHudTextureStyle
class_name FinanceHudBox
## Extra rules for dense bank dialogs and selected tabs, on the approved HUD art.

var inner_rule := false
var bottom_rail := false
var rule_color := Color("42474c")
## One-pixel rectangle drawn under the art. The source frames are hairlines, so
## fractional HUD scaling can drop an edge; this keeps the frame closed.
var edge_color := Color("555b5e")
var edge_width := 1.0


func _draw(canvas_item: RID, rect: Rect2) -> void:
	_draw_closed_edge(canvas_item, rect)
	super._draw(canvas_item, rect)
	if inner_rule:
		var inner := rect.grow(-7)
		for edge in [Rect2(inner.position, Vector2(inner.size.x, 1)),
			Rect2(inner.position, Vector2(1, inner.size.y)),
			Rect2(inner.position.x, inner.end.y - 1, inner.size.x, 1),
			Rect2(inner.end.x - 1, inner.position.y, 1, inner.size.y)]:
			RenderingServer.canvas_item_add_rect(canvas_item, edge, rule_color * modulate_color)
	if bottom_rail:
		RenderingServer.canvas_item_add_rect(canvas_item,
			Rect2(rect.position.x + 7, rect.end.y - 4, maxf(0, rect.size.x - 14), 2), rule_color * modulate_color)


func _draw_closed_edge(canvas_item: RID, rect: Rect2) -> void:
	if edge_width <= 0.0:
		return
	var left := roundf(rect.position.x)
	var top := roundf(rect.position.y)
	var right := roundf(rect.end.x)
	var bottom := roundf(rect.end.y)
	var width := maxf(edge_width, right - left)
	var height := maxf(edge_width, bottom - top)
	var color := Color(edge_color, edge_color.a * modulate_color.a)
	for band in [Rect2(left, top, width, edge_width), Rect2(left, bottom - edge_width, width, edge_width),
			Rect2(left, top, edge_width, height), Rect2(right - edge_width, top, edge_width, height)]:
		RenderingServer.canvas_item_add_rect(canvas_item, band, color)
