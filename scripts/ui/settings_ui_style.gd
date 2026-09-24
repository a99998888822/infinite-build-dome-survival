extends RefCounted
class_name SettingsUIStyle

const TEXT := Color("#d9d0af")
const GOLD := Color("#ffe18a")

static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111b16")
	style.border_color = Color("#d3a637")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 12
	return style

static func credit() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#28382f")
	style.border_color = Color("#536b59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style

static func button(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

static func apply_button(control: Button) -> void:
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_hover_color", GOLD)
	control.add_theme_color_override("font_pressed_color", GOLD)
	control.add_theme_stylebox_override("normal", button(Color("#111b16"), Color("#59441f")))
	control.add_theme_stylebox_override("hover", button(Color("#2b3020"), GOLD))
	control.add_theme_stylebox_override("pressed", button(Color("#473616"), Color("#d3a637")))
