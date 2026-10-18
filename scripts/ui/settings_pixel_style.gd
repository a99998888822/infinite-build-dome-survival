extends RefCounted
## Settings-only skin using the accepted talent HUD textures.

const FRAME = preload("res://assets/ui/talents/hud_border_background.png")
const BUTTON = preload("res://assets/ui/talents/hud_background.png")
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const TEXT := Color("d1c5ac")
const GOLD := Color("d9b978")
const MUTED := Color("86808a")


static func skin(framed := false, tint := Color.WHITE, padding := Vector2(12, 6)) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = FRAME if framed else BUTTON
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 6 if framed else 4)
		box.set_content_margin(side, padding.x if side in [SIDE_LEFT, SIDE_RIGHT] else padding.y)
	return box


static func flat(background: Color, border: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.anti_aliasing = false
	box.set_content_margin_all(0)
	return box


static func apply_button(button: BaseButton, framed := false, selected := false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", GOLD if selected else TEXT)
	button.add_theme_color_override("font_hover_color", Color("f0d49b"))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_hover_pressed_color", Color("f0d49b"))
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", skin(framed, Color(1.35, 1.18, 0.85) if selected else Color(1.0, 0.95, 0.88)))
	button.add_theme_stylebox_override("hover", skin(framed, Color(1.45, 1.3, 1.0)))
	button.add_theme_stylebox_override("pressed", skin(framed, Color(1.35, 1.18, 0.85)))
	button.add_theme_stylebox_override("hover_pressed", skin(framed, Color(1.5, 1.32, 1.0)))
	button.add_theme_stylebox_override("disabled", skin(framed, Color(0.62, 0.60, 0.65)))
	var focus := flat(Color.TRANSPARENT, GOLD)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)


static func apply_slider(slider: HSlider) -> void:
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var track := flat(Color("100f14"), Color("4b3d4b"))
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	for state in ["grabber_area", "grabber_area_highlight"]:
		var fill := flat(Color("967448"), Color("c3a371"))
		fill.content_margin_top = 4
		fill.content_margin_bottom = 4
		slider.add_theme_stylebox_override(state, fill)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		var bitmap := Image.create(14, 22, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color("08080c"))
		bitmap.fill_rect(Rect2i(1, 1, 12, 20), Color("92714d") if state != "grabber_disabled" else MUTED)
		bitmap.fill_rect(Rect2i(3, 3, 8, 16), Color("352b39"))
		bitmap.fill_rect(Rect2i(5, 6, 4, 10), Color("f0d49b") if state == "grabber_highlight" else GOLD)
		slider.add_theme_icon_override(state, ImageTexture.create_from_image(bitmap))


static func apply_scrollbar(scrollbar: VScrollBar) -> void:
	var track := flat(Color("100f14"), Color("302833"))
	track.content_margin_left = 5
	track.content_margin_right = 5
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := flat(Color("685442"), GOLD if state != "grabber" else Color("92714d"))
		grip.set_content_margin_all(5)
		scrollbar.add_theme_stylebox_override(state, grip)


static func apply_popup(popup: PopupMenu) -> void:
	popup.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", GOLD)
	popup.add_theme_stylebox_override("panel", skin(true, Color.WHITE, Vector2(12, 10)))
	popup.add_theme_stylebox_override("hover", skin(false, Color(1.45, 1.3, 1.0)))
	popup.add_theme_constant_override("v_separation", 10)
	for selected in [false, true]:
		var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		bitmap.fill_rect(Rect2i(2, 2, 12, 12), GOLD if selected else MUTED)
		bitmap.fill_rect(Rect2i(4, 4, 8, 8), Color("100f14"))
		if selected: bitmap.fill_rect(Rect2i(6, 6, 4, 4), GOLD)
		popup.add_theme_icon_override("radio_checked" if selected else "radio_unchecked", ImageTexture.create_from_image(bitmap))
