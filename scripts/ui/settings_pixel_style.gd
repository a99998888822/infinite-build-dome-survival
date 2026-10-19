extends RefCounted
## Neutral iron controls, with an explicit warm selection for movement cards.

const PALETTE = preload("res://scripts/ui/hud_palette.gd")
const FRAME = PALETTE.FRAME
const BUTTON = PALETTE.BUTTON
const FONT = preload("res://assets/font/native_hud/interface.res")
const POPUP_FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const TEXT := PALETTE.TEXT
const GOLD := PALETTE.ACTIVE
const MUTED := PALETTE.MUTED


static func skin(framed := false, tint := Color.WHITE, padding := Vector2(20, 10), selected := false, warm_selected := false) -> StyleBox:
	var box := NativeHudTextureStyle.new()
	box.texture = (PALETTE.FRAME_SELECTED if framed else PALETTE.BUTTON_SELECTED) if selected else (FRAME if framed else BUTTON)
	if framed and selected and warm_selected:
		box.texture = PALETTE.WARM_FRAME
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 6 if framed else 4)
		box.set_native_margin(side, 10.0 if framed else 6.666667)
		box.set_content_margin(side, padding.x if side in [SIDE_LEFT, SIDE_RIGHT] else padding.y)
	return box


static func flat(background: Color, border: Color, width := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.anti_aliasing = false
	box.set_content_margin_all(0)
	return box


static func apply_button(button: BaseButton, framed := false, selected := false, warm_selection := false) -> void:
	var warm_selected := warm_selection and selected
	var accent: Color = PALETTE.WARM_ACTIVE if warm_selected else GOLD
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", accent if selected else TEXT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_hover_pressed_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", skin(framed, Color.WHITE, Vector2(20, 10), selected, warm_selected))
	button.add_theme_stylebox_override("hover", skin(framed, Color.WHITE, Vector2(20, 10), true, warm_selected))
	button.add_theme_stylebox_override("pressed", skin(framed, Color(0.9, 0.9, 0.9), Vector2(20, 10), true, warm_selected))
	button.add_theme_stylebox_override("hover_pressed", skin(framed, Color.WHITE, Vector2(20, 10), true, warm_selected))
	button.add_theme_stylebox_override("disabled", skin(framed, Color(0.64, 0.64, 0.64)))
	var focus := flat(Color.TRANSPARENT, accent)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)


static func apply_slider(slider: HSlider) -> void:
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var track := flat(PALETTE.SHADOW, PALETTE.LINE_IDLE)
	track.content_margin_top = 6.666667
	track.content_margin_bottom = 6.666667
	slider.add_theme_stylebox_override("slider", track)
	for state in ["grabber_area", "grabber_area_highlight"]:
		var fill := flat(PALETTE.BORDER, PALETTE.ACTIVE if state == "grabber_area_highlight" else PALETTE.METAL)
		fill.content_margin_top = 6.666667
		fill.content_margin_bottom = 6.666667
		slider.add_theme_stylebox_override(state, fill)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		var bitmap := Image.create(14, 22, false, Image.FORMAT_RGBA8)
		bitmap.fill(PALETTE.SHADOW)
		bitmap.fill_rect(Rect2i(1, 1, 12, 20), PALETTE.METAL if state != "grabber_disabled" else MUTED)
		bitmap.fill_rect(Rect2i(3, 3, 8, 16), PALETTE.NODE_FILL)
		bitmap.fill_rect(Rect2i(5, 6, 4, 10), GOLD if state == "grabber_highlight" else PALETTE.METAL)
		bitmap.resize(23, 37, Image.INTERPOLATE_NEAREST)
		slider.add_theme_icon_override(state, ImageTexture.create_from_image(bitmap))


static func apply_scrollbar(scrollbar: VScrollBar) -> void:
	var track := flat(PALETTE.SHADOW, PALETTE.NODE_FILL)
	track.content_margin_left = 8.333333
	track.content_margin_right = 8.333333
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := flat(PALETTE.BORDER, GOLD if state != "grabber" else PALETTE.METAL)
		grip.set_content_margin_all(8.333333)
		scrollbar.add_theme_stylebox_override(state, grip)


static func apply_popup(popup: PopupMenu) -> void:
	popup.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	popup.add_theme_font_override("font", POPUP_FONT)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", GOLD)
	popup.add_theme_stylebox_override("panel", _popup_skin(true, Color.WHITE, Vector2(12, 10)))
	popup.add_theme_stylebox_override("hover", _popup_skin(false, Color.WHITE, Vector2(12, 6), true))
	popup.add_theme_constant_override("v_separation", 10)
	for selected in [false, true]:
		var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		bitmap.fill_rect(Rect2i(2, 2, 12, 12), GOLD if selected else MUTED)
		bitmap.fill_rect(Rect2i(4, 4, 8, 8), PALETTE.SHADOW)
		if selected: bitmap.fill_rect(Rect2i(6, 6, 4, 4), GOLD)
		popup.add_theme_icon_override("radio_checked" if selected else "radio_unchecked", ImageTexture.create_from_image(bitmap))


static func _popup_skin(framed := false, tint := Color.WHITE, padding := Vector2(12, 6), selected := false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = (PALETTE.FRAME_SELECTED if framed else PALETTE.BUTTON_SELECTED) if selected else (FRAME if framed else BUTTON)
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 6 if framed else 4)
		box.set_content_margin(side, padding.x if side in [SIDE_LEFT, SIDE_RIGHT] else padding.y)
	return box
