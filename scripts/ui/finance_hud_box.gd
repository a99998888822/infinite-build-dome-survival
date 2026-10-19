extends NativeHudTextureStyle
class_name FinanceHudBox
## Extra rules for dense bank dialogs and selected tabs, on the approved HUD art.

var inner_rule := false
var bottom_rail := false
var rule_color := Color("42474c")


func _draw(canvas_item: RID, rect: Rect2) -> void:
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
