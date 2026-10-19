extends StyleBoxFlat
class_name PixelTooltipStyle
## One-pixel iron outline, square corners and a quiet solid reading surface.

const PALETTE = preload("res://scripts/ui/hud_palette.gd")


func _init() -> void:
	bg_color = PALETTE.BACKDROP
	border_color = PALETTE.METAL
	set_border_width_all(1)
	set_corner_radius_all(0)
	anti_aliasing = false
	content_margin_left = 10
	content_margin_top = 8
	content_margin_right = 10
	content_margin_bottom = 8


static func preserving(source: StyleBox) -> PixelTooltipStyle:
	var result := PixelTooltipStyle.new()
	if source != null:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			result.set_content_margin(side, source.get_content_margin(side))
	return result
