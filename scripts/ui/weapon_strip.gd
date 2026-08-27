extends Control
class_name WeaponStrip

const WEAPON_SLOT_BUTTON_SCRIPT = preload("res://scripts/ui/weapon_slot_button.gd")

var _loadout: WeaponLoadout = null
var _weapon_buttons: Array[Button] = []
var _attachment_editing_enabled: bool = false
var _hovered_weapon_button: WeaponSlotButton = null
var _tooltip_attachment_button: Button = null

@onready var weapon_list: HBoxContainer = get_node_or_null("StripPanel/StripMargin/StripBody/WeaponScroll/WeaponList")
@onready var load_label: Label = get_node_or_null("StripPanel/StripMargin/StripBody/LoadLabel")
@onready var weapon_tooltip: PanelContainer = get_node_or_null("WeaponTooltip")
@onready var weapon_tooltip_label: RichTextLabel = get_node_or_null("WeaponTooltip/TooltipMargin/TooltipLabel")


func set_loadout(loadout: WeaponLoadout, allow_attachment_editing: bool = false) -> void:
	if _loadout != null and _loadout.weapon_attachment_changed.is_connected(_on_weapon_attachment_changed):
		_loadout.weapon_attachment_changed.disconnect(_on_weapon_attachment_changed)
	_loadout = loadout
	_attachment_editing_enabled = allow_attachment_editing
	if _loadout != null and not _loadout.weapon_attachment_changed.is_connected(_on_weapon_attachment_changed):
		_loadout.weapon_attachment_changed.connect(_on_weapon_attachment_changed)
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
	_hide_weapon_tooltip()
	for button in _weapon_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_weapon_buttons.clear()
	if weapon_list == null or _loadout == null:
		return
	for weapon in _loadout.get_weapon_instances():
		var button := WEAPON_SLOT_BUTTON_SCRIPT.new() as WeaponSlotButton
		if button == null:
			continue
		button.configure(weapon, _attachment_editing_enabled)
		button.custom_minimum_size = Vector2(44.0, 44.0)
		button.flat = true
		button.text = ""
		button.tooltip_text = ""
		var icon_path := str(weapon.weapon_data.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var texture := load(icon_path)
			if texture is Texture2D:
				button.icon = texture
				button.expand_icon = true
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.add_theme_constant_override("icon_max_width", 34)
		if _attachment_editing_enabled and not button.item_drop_requested.is_connected(_on_item_drop_requested):
			button.item_drop_requested.connect(_on_item_drop_requested)
		weapon_list.add_child(button)
		button.mouse_entered.connect(_show_weapon_tooltip.bind(weapon, button))
		_weapon_buttons.append(button)


func _on_item_drop_requested(weapon_id: String, item_instance_id: String) -> void:
	if not _attachment_editing_enabled or _loadout == null:
		return
	if _loadout.attach_item_to_weapon(weapon_id, item_instance_id):
		_refresh_weapon_strip()


func _on_weapon_attachment_changed(_weapon_id: String, _item_instance_id: String) -> void:
	_refresh_weapon_strip()


func _process(_delta: float) -> void:
	if weapon_tooltip == null or not weapon_tooltip.visible:
		return
	var mouse_position := get_global_mouse_position()
	var over_weapon := _hovered_weapon_button != null and is_instance_valid(_hovered_weapon_button) and _hovered_weapon_button.get_global_rect().has_point(mouse_position)
	var over_tooltip := weapon_tooltip.get_global_rect().has_point(mouse_position)
	if not over_weapon and not over_tooltip:
		_hide_weapon_tooltip()


func _show_weapon_tooltip(weapon: WeaponInstance, anchor_button: Button) -> void:
	if weapon_tooltip == null or weapon_tooltip_label == null or weapon == null:
		return
	_hide_weapon_tooltip()
	_hovered_weapon_button = anchor_button as WeaponSlotButton
	weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_PASS
	weapon_tooltip_label.mouse_filter = Control.MOUSE_FILTER_PASS
	weapon_tooltip_label.text = weapon.build_full_stats_text()
	weapon_tooltip.visible = true
	weapon_tooltip.reset_size()
	if _attachment_editing_enabled and not weapon.get_attached_item_instance().is_empty():
		_create_tooltip_attachment_button(weapon.weapon_id)
	var viewport_rect := get_viewport_rect()
	var target := Vector2.ZERO
	if anchor_button != null:
		target = anchor_button.global_position + Vector2(0, anchor_button.size.y + 6)
	if target.x + weapon_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - weapon_tooltip.size.x - 8, 0)
	if target.y + weapon_tooltip.size.y > viewport_rect.size.y and anchor_button != null:
		target.y = maxf(anchor_button.global_position.y - weapon_tooltip.size.y - 6, 0)
	weapon_tooltip.global_position = target


func _create_tooltip_attachment_button(weapon_id: String) -> void:
	_tooltip_attachment_button = Button.new()
	_tooltip_attachment_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_tooltip_attachment_button.focus_mode = Control.FOCUS_NONE
	_tooltip_attachment_button.tooltip_text = "右键卸下此附魔"
	_tooltip_attachment_button.gui_input.connect(_on_tooltip_attachment_gui_input.bind(weapon_id, _tooltip_attachment_button))
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_tooltip_attachment_button.add_theme_stylebox_override(state, empty_style)
	weapon_tooltip_label.add_child(_tooltip_attachment_button)
	_tooltip_attachment_button.position = Vector2(0.0, maxf(weapon_tooltip_label.size.y - 30.0, 0.0))
	_tooltip_attachment_button.size = Vector2(maxf(weapon_tooltip_label.size.x, 280.0), 30.0)
	call_deferred("_position_tooltip_attachment_button")


func _position_tooltip_attachment_button() -> void:
	if _tooltip_attachment_button == null or not is_instance_valid(_tooltip_attachment_button):
		return
	if weapon_tooltip_label == null:
		return
	_tooltip_attachment_button.position = Vector2(0.0, maxf(weapon_tooltip_label.size.y - 30.0, 0.0))
	_tooltip_attachment_button.size = Vector2(maxf(weapon_tooltip_label.size.x, 280.0), 30.0)


func _on_tooltip_attachment_gui_input(event: InputEvent, weapon_id: String, _button: Button) -> void:
	if not _attachment_editing_enabled or _loadout == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var detached := _loadout.detach_item_from_weapon(weapon_id)
		if detached.is_empty():
			return
		_hide_weapon_tooltip()
		get_viewport().set_input_as_handled()


func _hide_weapon_tooltip() -> void:
	if _tooltip_attachment_button != null and is_instance_valid(_tooltip_attachment_button):
		_tooltip_attachment_button.free()
	_tooltip_attachment_button = null
	if weapon_tooltip != null:
		weapon_tooltip.visible = false
		weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hovered_weapon_button = null
