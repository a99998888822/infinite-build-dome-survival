extends RefCounted
class_name FinanceFrameSkin
## Approved clean bank frames. Applied at creation/state changes, never per frame.
const TEXTURES := {
	"panel": preload("res://assets/ui/finance/clean_frames/panel.png"),
	"slim": preload("res://assets/ui/finance/clean_frames/slim.png"),
	"card": preload("res://assets/ui/finance/clean_frames/card.png"),
	"card_uncommon": preload("res://assets/ui/finance/clean_frames/card_uncommon.png"),
	"card_rare": preload("res://assets/ui/finance/clean_frames/card_rare.png"),
	"card_epic": preload("res://assets/ui/finance/clean_frames/card_epic.png"),
	"card_legendary": preload("res://assets/ui/finance/clean_frames/card_legendary.png"),
	"button": preload("res://assets/ui/finance/clean_frames/button.png"),
	"selected": preload("res://assets/ui/finance/clean_frames/selected.png"),
	"input": preload("res://assets/ui/finance/clean_frames/input.png"),
	"slot": preload("res://assets/ui/finance/clean_frames/slot.png"),
	"thumb": preload("res://assets/ui/finance/clean_frames/thumb.png"),
}


static func box(kind: String = "panel", margin: int = 0, shade: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TEXTURES[kind]
	style.modulate_color = shade
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 4)
		style.set_content_margin(side, margin)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


static func with_margins(control: Control, theme_name: String, kind: String, shade: Color = Color.WHITE) -> StyleBoxTexture:
	var style := box(kind, 0, shade)
	var previous := control.get_theme_stylebox(theme_name)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, previous.get_content_margin(side))
	return style


static func button(control: Button, selected: bool = false, slot: bool = false) -> void:
	var kind := "selected" if selected else ("slot" if slot else "button")
	control.add_theme_stylebox_override("normal", with_margins(control, "normal", kind))
	control.add_theme_stylebox_override("hover", with_margins(control, "hover", kind, Color(1.16, 1.14, 1.08)))
	control.add_theme_stylebox_override("pressed", with_margins(control, "pressed", "selected" if control.toggle_mode else kind, Color(0.88, 0.88, 0.85)))
	control.add_theme_stylebox_override("hover_pressed", with_margins(control, "normal", "selected", Color(1.1, 1.08, 1.02)))
	control.add_theme_stylebox_override("disabled", with_margins(control, "disabled", "button", Color(0.76, 0.78, 0.72)))
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func scrollbar(bar: ScrollBar) -> void:
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, with_margins(bar, state, "thumb"))
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func nine_patch(frame: NinePatchRect) -> void:
	frame.texture = TEXTURES.panel
	frame.patch_margin_left = 4
	frame.patch_margin_right = 4
	frame.patch_margin_top = 4
	frame.patch_margin_bottom = 4
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
