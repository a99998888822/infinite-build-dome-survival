extends Control
class_name WeaponStrip

var _loadout: WeaponLoadout = null
var _weapon_buttons: Array[Button] = []

@onready var weapon_list: HBoxContainer = get_node_or_null("StripPanel/StripMargin/StripBody/WeaponScroll/WeaponList")
@onready var load_label: Label = get_node_or_null("StripPanel/StripMargin/StripBody/LoadLabel")
@onready var weapon_tooltip: PanelContainer = get_node_or_null("WeaponTooltip")
@onready var weapon_tooltip_label: RichTextLabel = get_node_or_null("WeaponTooltip/TooltipMargin/TooltipLabel")


func set_loadout(loadout: WeaponLoadout) -> void:
	_loadout = loadout
	_refresh_load_label()
	_refresh_weapon_strip()


func _refresh_load_label() -> void:
	if load_label == null:
		return
	if _loadout == null:
		load_label.text = "负载0/0"
		return
	load_label.text = "负载%d/%d" % [_loadout.get_total_load_cost(), _loadout.get_load_capacity()]


func _refresh_weapon_strip() -> void:
	for button in _weapon_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_weapon_buttons.clear()
	if weapon_list == null or _loadout == null:
		return
	for weapon in _loadout.get_weapon_instances():
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(44, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon_path := str(weapon.weapon_data.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var texture := load(icon_path)
			if texture is Texture2D:
				button.icon = texture
				button.expand_icon = true
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_list.add_child(button)
		button.mouse_entered.connect(_show_weapon_tooltip.bind(weapon, button))
		button.mouse_exited.connect(_hide_weapon_tooltip)
		_weapon_buttons.append(button)


func _show_weapon_tooltip(weapon: WeaponInstance, anchor_button: Button) -> void:
	if weapon_tooltip == null or weapon_tooltip_label == null:
		return
	var tooltip_text := weapon.build_full_stats_text()
	weapon_tooltip_label.text = tooltip_text
	weapon_tooltip.visible = true
	weapon_tooltip.reset_size()
	var viewport_rect := get_viewport_rect()
	var target := Vector2.ZERO
	if anchor_button != null:
		target = anchor_button.global_position + Vector2(0, anchor_button.size.y + 6)
	if target.x + weapon_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - weapon_tooltip.size.x - 8, 0)
	if target.y + weapon_tooltip.size.y > viewport_rect.size.y:
		target.y = maxf(anchor_button.global_position.y - weapon_tooltip.size.y - 6, 0)
	weapon_tooltip.global_position = target


func _hide_weapon_tooltip() -> void:
	if weapon_tooltip != null:
		weapon_tooltip.visible = false
