extends RefCounted
## Reward panels share the approved iron HUD art and bronze interaction states.

const PALETTE = preload("res://scripts/ui/hud_palette.gd")
const WEAPON_SLOT = preload("res://assets/ui/hud/neutral_iron/weapon_slot_thin.png")
const WEAPON_SLOT_HOVER = preload("res://assets/ui/hud/smoke_bronze/weapon_slot_thin.png")


static func skin(framed := true, warm := false, padding := Vector4(12, 14, 12, 12)) -> NativeHudTextureStyle:
	var box := NativeHudTextureStyle.new()
	box.texture = (PALETTE.WARM_FRAME if warm else PALETTE.FRAME) if framed else (PALETTE.WARM.BUTTON_SELECTED if warm else PALETTE.BUTTON)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 6 if framed else 4)
		box.set_native_margin(side, 8 if framed else 5)
		box.set_content_margin(side, padding[side])
	return box


static func inset(warm := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PALETTE.WARM.PANEL_FILL if warm else PALETTE.BACKDROP
	box.border_color = PALETTE.WARM.BORDER if warm else PALETTE.LINE_IDLE
	box.set_border_width_all(2)
	box.set_content_margin_all(2)
	box.anti_aliasing = false
	return box


static func weapon_slot_theme() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _weapon_slot_skin(false))
	for state in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "Button", _weapon_slot_skin(true))
	var disabled := _weapon_slot_skin(false)
	disabled.modulate_color = Color(0.65, 0.65, 0.65)
	theme.set_stylebox("disabled", "Button", disabled)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	theme.set_color("reorder_color", "Button", Color("dec48a"))
	theme.set_color("reorder_hover_color", "Button", Color("dec48a"))
	theme.set_color("reorder_shadow", "Button", PALETTE.SHADOW)
	theme.set_color("cast_mode_backdrop", "Button", PALETTE.PANEL_FILL)
	var feedback := inset(true)
	feedback.set_content_margin_all(0)
	feedback.set_border_width_all(1)
	theme.set_stylebox("reorder_hover", "Button", feedback)
	theme.set_stylebox("cast_mode_hover", "Button", feedback)
	return theme


static func _weapon_slot_skin(warm: bool) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = WEAPON_SLOT_HOVER if warm else WEAPON_SLOT
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 3)
		box.set_content_margin(side, 8)
	return box


static func apply_button(button: Button, padding := Vector4(10, 0, 10, 0), warm := false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.begin_bulk_theme_override()
	button.add_theme_stylebox_override("normal", skin(false, warm, padding))
	for state in ["hover", "pressed", "hover_pressed"]:
		var box := skin(false, true, padding)
		if state == "pressed": box.modulate_color = Color(0.9, 0.9, 0.9)
		button.add_theme_stylebox_override(state, box)
	var disabled := skin(false, false, padding)
	disabled.modulate_color = Color(0.65, 0.65, 0.65)
	button.add_theme_stylebox_override("disabled", disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = PALETTE.WARM_ACTIVE
	focus.set_border_width_all(1)
	focus.anti_aliasing = false
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", PALETTE.WARM_TEXT if warm else PALETTE.TEXT)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, PALETTE.WARM_ACTIVE)
	button.add_theme_color_override("font_disabled_color", PALETTE.MUTED)
	button.end_bulk_theme_override()
