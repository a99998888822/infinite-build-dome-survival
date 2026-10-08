extends Button
class_name WeaponCastModeIcon
## Shared preference indicator. Only inventory instances accept clicks.

const AUTO_ICON := preload("res://assets/ui/icons/cast_auto.svg")
const MANUAL_ICON := preload("res://assets/ui/icons/cast_manual.svg")
const ICON_SIZE := 14.0 # 70% of the original 20px glyph.
var weapon: WeaponInstance
var automatic := false
var editable := false
var _frame_color := Color("05080a")


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", int(ICON_SIZE))
	add_theme_constant_override("h_separation", 0)
	var plain := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", plain)
	add_theme_stylebox_override("focus", plain)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("293c32")
	hover.border_color = Color("91b8a3")
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)
	hover.set_content_margin_all(0)
	for state in ["hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(state, hover)
	# Opaque backing masks the border through the glyph's transparent pixels.
	var backing := ColorRect.new()
	backing.name = "BorderMask"
	backing.color = _frame_color
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.show_behind_parent = true
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	backing.offset_left = -ICON_SIZE * 0.5 - 1
	backing.offset_right = ICON_SIZE * 0.5 + 1
	backing.offset_top = -ICON_SIZE * 0.5
	backing.offset_bottom = ICON_SIZE * 0.5
	pressed.connect(_toggle)
	CombatSettings.settings_changed.connect(sync_policy)
	L10n.locale_changed.connect(sync_policy)
	sync_policy()


func configure(source: WeaponInstance, allow_editing: bool, frame_color: Color = Color("05080a")) -> void:
	weapon = source
	editable = allow_editing
	_frame_color = Color(frame_color, 1.0)
	name = "CastMode_" + weapon.weapon_id
	mouse_filter = Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if editable else Control.CURSOR_ARROW
	sync_policy()


func sync_policy() -> void:
	if weapon == null: return
	automatic = CombatSettings.prefers_auto_cast(weapon.weapon_id, weapon.is_mobility_weapon())
	icon = AUTO_ICON if automatic else MANUAL_ICON
	var tint := Color("91dcb8") if automatic else Color("ddbe79")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		add_theme_color_override("icon_" + state + "_color", tint)
	var state_key := "ui.weapon.cast_mode.auto" if automatic else "ui.weapon.cast_mode.manual"
	tooltip_text = L10n.source(str(weapon.weapon_data.get("display_name", ""))) + " · " + L10n.text(state_key)
	var action_key := "ui.weapon.cast_mode.to_manual" if automatic else "ui.weapon.cast_mode.to_auto"
	tooltip_text += "\n" + L10n.text(action_key if editable else "ui.weapon.cast_mode.edit_hint")
	if weapon.is_mobility_weapon() and automatic:
		tooltip_text += "\n" + L10n.text("ui.weapon.cast_mode.mobility_hint")


func _toggle() -> void:
	if editable and weapon != null:
		CombatSettings.set_weapon_auto_cast(weapon.weapon_id, not automatic)
