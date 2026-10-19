extends StyleBox
class_name NativeHudTextureStyle
## Nine-patch skin with independent source texels and native canvas border widths.
## Source art stays untouched when a HUD uses fractional pixel-art border widths.

@export var texture: Texture2D
@export var modulate_color := Color.WHITE
@export var _source_margins := PackedFloat32Array([0, 0, 0, 0])
@export var _native_margins := PackedFloat32Array([0, 0, 0, 0])


func set_texture_margin(side: Side, value: float) -> void:
	_source_margins[side] = value


func set_native_margin(side: Side, value: float) -> void:
	_native_margins[side] = value


func _draw(canvas_item: RID, rect: Rect2) -> void:
	if texture == null: return
	var source_size := texture.get_size()
	var sx := [0.0, _source_margins[SIDE_LEFT], source_size.x - _source_margins[SIDE_RIGHT], source_size.x]
	var sy := [0.0, _source_margins[SIDE_TOP], source_size.y - _source_margins[SIDE_BOTTOM], source_size.y]
	var dx := [rect.position.x, rect.position.x + _native_margins[SIDE_LEFT], rect.end.x - _native_margins[SIDE_RIGHT], rect.end.x]
	var dy := [rect.position.y, rect.position.y + _native_margins[SIDE_TOP], rect.end.y - _native_margins[SIDE_BOTTOM], rect.end.y]
	for y in 3:
		for x in 3:
			var source := Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y])
			var target := Rect2(dx[x], dy[y], dx[x + 1] - dx[x], dy[y + 1] - dy[y])
			texture.draw_rect_region(canvas_item, target, source, modulate_color)
