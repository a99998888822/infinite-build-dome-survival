extends Control
class_name WeaponStrip

const WEAPON_SLOT_BUTTON_SCRIPT = preload("res://scripts/ui/weapon_slot_button.gd")

var _loadout: WeaponLoadout = null
var _weapon_buttons: Array[Button] = []
var _attachment_editing_enabled: bool = false

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
		var icon_path := str(weapon.weapon_data.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var texture := load(icon_path)
			if texture is Texture2D:
				button.icon = texture
				button.expand_icon = true
				button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
				button.icon_max_width = 34
		if _attachment_editing_enabled and not button.item_drop_requested.is_connected(_on_item_drop_requested):
			button.item_drop_requested.connect(_on_item_drop_requested)
		weapon_list.add_child(button)
		button.mouse_entered.connect(_show_weapon_tooltip.bind(weapon, button))
		button.mouse_exited.connect(_hide_weapon_tooltip)
		_weapon_buttons.append(button)


func _on_item_drop_requested(weapon_id: String, item_instance_id: String) -> void:
	if not _attachment_editing_enabled or _loadout == null:
		return
	if _loadout.attach_item_to_weapon(weapon_id, item_instance_id):
		_refresh_weapon_strip()


func _on_weapon_attachment_changed(_weapon_id: String, _item_instance_id: String) -> void:
	_refresh_weapon_strip()


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
