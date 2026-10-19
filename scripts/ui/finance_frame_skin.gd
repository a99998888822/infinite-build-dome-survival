extends RefCounted
class_name FinanceFrameSkin
## Iron bank panels and smoke-bronze interaction states, shared with the HUD.
const HUD = preload("res://scripts/ui/reward_hud_style.gd")
const PALETTE = HUD.PALETTE
const SMALL_BUTTON = preload("res://assets/ui/hud/neutral_iron/button_small.png")
const SMALL_BUTTON_SELECTED = preload("res://assets/ui/hud/smoke_bronze/button_small.png")


static func box(kind: String = "panel", margin: int = 0, shade: Color = Color.WHITE) -> FinanceHudBox:
	var style := FinanceHudBox.new()
	var warm := kind in ["selected", "tab_selected", "card_hover", "small_selected"]
	var small := kind in ["small", "small_selected"]
	var framed := kind in ["panel", "dialog"] or kind.begins_with("card")
	var recessed := kind in ["input", "slot", "slot_selected", "thumb"]
	warm = warm or kind == "slot_selected"
	style.texture = (PALETTE.WARM_FRAME if warm else PALETTE.FRAME) if framed else (PALETTE.WARM.BUTTON_SELECTED if warm else PALETTE.BUTTON)
	if recessed: style.texture = HUD.WEAPON_SLOT_HOVER if warm else HUD.WEAPON_SLOT
	if small: style.texture = SMALL_BUTTON_SELECTED if warm else SMALL_BUTTON
	style.modulate_color = shade
	style.inner_rule = kind == "dialog"
	style.bottom_rail = kind == "tab_selected"
	style.rule_color = PALETTE.WARM_ACTIVE if warm else PALETTE.LINE_IDLE
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 2 if small else (3 if recessed else (6 if framed else 4)))
		style.set_native_margin(side, 2 if small else (4 if recessed else (8 if framed else 5)))
		style.set_content_margin(side, margin)
	return style


static func with_margins(control: Control, theme_name: String, kind: String, shade: Color = Color.WHITE) -> FinanceHudBox:
	var style := box(kind, 0, shade)
	var previous := control.get_theme_stylebox(theme_name)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, previous.get_content_margin(side))
	return style


static func button(control: Button, selected: bool = false, slot: bool = false, small: bool = true) -> void:
	var normal_kind := "slot" if slot else ("small" if small else "button")
	var active_kind := "slot_selected" if slot else ("small_selected" if small else "selected")
	var kind := active_kind if selected else normal_kind
	control.add_theme_stylebox_override("normal", box(kind, 4))
	control.add_theme_stylebox_override("hover", box(active_kind, 4))
	control.add_theme_stylebox_override("pressed", box(active_kind, 4, Color(0.88, 0.88, 0.88)))
	control.add_theme_stylebox_override("hover_pressed", box(active_kind, 4))
	control.add_theme_stylebox_override("disabled", box(normal_kind, 4, Color(0.65, 0.65, 0.65)))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = PALETTE.WARM_ACTIVE
	focus.set_border_width_all(1)
	focus.anti_aliasing = false
	control.add_theme_stylebox_override("focus", focus)
	control.add_theme_color_override("font_color", PALETTE.WARM_TEXT if selected else PALETTE.TEXT)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, PALETTE.WARM_ACTIVE)
	control.add_theme_color_override("font_disabled_color", PALETTE.MUTED)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func scrollbar(bar: ScrollBar) -> void:
	bar.add_theme_stylebox_override("scroll", HUD.inset())
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, box("thumb" if state == "grabber" else "slot_selected", 4))
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func nine_patch(frame: NinePatchRect) -> void:
	frame.texture = PALETTE.FRAME
	frame.patch_margin_left = 6
	frame.patch_margin_right = 6
	frame.patch_margin_top = 6
	frame.patch_margin_bottom = 6
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
