extends StyleBox
class_name CombatHudFrame
## Pixel-cut ironwork: compact brackets, wave crest, then engraved vital frame.
## Drawn only when the owning control redraws; no ornament animation or textures.

const PALETTE = preload("res://scripts/ui/hud_palette.gd")
@export_range(1, 3) var detail := 1
@export var warm := false
var bg_color: Color:
	get: return PALETTE.WARM.PANEL_FILL if warm else PALETTE.PANEL_FILL


static func make(tier: int, selected := false, padding := Vector4(8, 8, 8, 8)) -> CombatHudFrame:
	var result := CombatHudFrame.new()
	result.detail = tier
	result.warm = selected
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_content_margin(side, padding[side])
	return result


func _draw(canvas: RID, area: Rect2) -> void:
	var r := Rect2(area.position.round(), area.size.round())
	var edge := PALETTE.WARM.BORDER if warm else PALETTE.BORDER
	var light := PALETTE.WARM.METAL if warm else PALETTE.METAL
	var dim := PALETTE.WARM.LINE_IDLE if warm else PALETTE.LINE_IDLE
	var cut := 4 if detail == 1 else 6
	_cut_fill(canvas, r, cut, PALETTE.SHADOW)
	_cut_fill(canvas, r.grow(-1), cut - 1, edge)
	_cut_fill(canvas, r.grow(-3), maxi(1, cut - 2), bg_color)
	# Broken bevel leaves dark bottom/right edges, like the approved iron panels.
	_block(canvas, Rect2(r.position + Vector2(cut + 2, 2), Vector2(r.size.x - cut * 2 - 4, 1)), light)
	_block(canvas, Rect2(r.position + Vector2(2, cut + 2), Vector2(1, r.size.y - cut * 2 - 4)), light)
	var arm := 12 if detail == 1 else 20 if detail == 2 else 34
	for corner in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
		_corner(canvas, r, corner, arm, edge, light, dim)
	if detail >= 2:
		_crest(canvas, Vector2(roundf(r.get_center().x), r.position.y + 4), light, dim, detail == 3)
		_crest(canvas, Vector2(roundf(r.get_center().x), r.end.y - 5), edge, dim, false)
	if detail == 3:
		for y: float in [r.position.y + 9, r.end.y - 10]:
			_block(canvas, Rect2(Vector2(r.position.x + 39, y), Vector2(r.size.x - 78, 1)), dim)
		# Stepped wings around the central seal distinguish the status housing.
		var seal := Vector2(roundf(r.get_center().x), r.position.y + 7)
		for direction: int in [-1, 1]:
			for step in 3:
				_block(canvas, Rect2(seal + Vector2(direction * (18 + step * 6), 2 - step), Vector2(4, 2)), light)
		# Paired etched rails and measured marks, confined to the outer eight pixels.
		for y: float in [r.position.y + 6, r.end.y - 7]:
			for direction: int in [-1, 1]:
				var x := r.get_center().x + direction * 38
				var length := maxf(0, r.size.x * 0.5 - 78)
				_block(canvas, Rect2(Vector2(x if direction > 0 else x - length, y), Vector2(length, 1)), dim)
				for tick in 3:
					_block(canvas, Rect2(Vector2(x + direction * (8 + tick * 7), y - 1), Vector2(2, 3)), edge)
		for x: float in [r.position.x + 4, r.end.x - 5]:
			var center := Vector2(x, roundf(r.get_center().y))
			_block(canvas, Rect2(center - Vector2(2, 8), Vector2(5, 17)), dim)
			_block(canvas, Rect2(center - Vector2(1, 5), Vector2(3, 11)), light)
			_block(canvas, Rect2(center - Vector2(1, 2), Vector2(3, 5)), PALETTE.SHADOW)


func _corner(canvas: RID, r: Rect2, corner: Vector2, arm: int, edge: Color, light: Color, dim: Color) -> void:
	var flip := Vector2(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
	var origin := r.position + r.size * corner
	for strip: Rect2 in [Rect2(4, 3, arm, 3), Rect2(3, 4, 3, arm)]:
		var pos := origin + strip.position * flip
		if flip.x < 0: pos.x -= strip.size.x
		if flip.y < 0: pos.y -= strip.size.y
		_block(canvas, Rect2(pos, strip.size), light)
	var rivet := origin + Vector2(6, 6) * flip
	_block(canvas, Rect2(rivet - Vector2(2, 2), Vector2(4, 4)), PALETTE.SHADOW)
	_block(canvas, Rect2(rivet - Vector2.ONE, Vector2(2, 2)), edge)
	if detail >= 2:
		for offset in [Vector2(arm - 2, 4), Vector2(4, arm - 2)]:
			_block(canvas, Rect2(origin + offset * flip - Vector2.ONE, Vector2(2, 2)), dim)
	if detail == 3:
		for offset in [Vector2(13, 7), Vector2(7, 13)]:
			_block(canvas, Rect2(origin + offset * flip - Vector2.ONE, Vector2(3, 3)), edge)
		for offset in [Vector2(19, 8), Vector2(26, 8), Vector2(8, 19), Vector2(8, 26)]:
			_block(canvas, Rect2(origin + offset * flip - Vector2.ONE, Vector2(3, 3)), dim)


func _crest(canvas: RID, center: Vector2, light: Color, dim: Color, engraved: bool) -> void:
	_block(canvas, Rect2(center - Vector2(17, 1), Vector2(35, 3)), dim)
	for dx in [-11, 11]:
		_block(canvas, Rect2(center + Vector2(dx - 1, -1), Vector2(3, 3)), light)
	for y in range(-3, 4):
		var half := 3 - absi(y)
		_block(canvas, Rect2(center + Vector2(-half, y), Vector2(half * 2 + 1, 1)), light)
	_block(canvas, Rect2(center - Vector2.ONE, Vector2(3, 3)), PALETTE.SHADOW)
	if engraved:
		for dx in [-24, 24]:
			_block(canvas, Rect2(center + Vector2(dx, -2), Vector2(2, 5)), light)


func _cut_fill(canvas: RID, r: Rect2, cut: int, color: Color) -> void:
	_block(canvas, Rect2(r.position + Vector2(cut, 0), Vector2(r.size.x - cut * 2, r.size.y)), color)
	_block(canvas, Rect2(r.position + Vector2(0, cut), Vector2(r.size.x, r.size.y - cut * 2)), color)
	for step in range(1, cut):
		_block(canvas, Rect2(r.position + Vector2(cut - step, step), Vector2(r.size.x - (cut - step) * 2, 1)), color)
		_block(canvas, Rect2(r.position + Vector2(cut - step, r.size.y - step - 1), Vector2(r.size.x - (cut - step) * 2, 1)), color)


func _block(canvas: RID, rect: Rect2, color: Color) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		RenderingServer.canvas_item_add_rect(canvas, rect, color)
