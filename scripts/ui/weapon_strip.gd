extends Control
class_name WeaponStrip

const WEAPON_SLOT_BUTTON_SCRIPT = preload("res://scripts/ui/weapon_slot_button.gd")
const ATTACHMENT_ROW_HEIGHT: float = 24.0

var _loadout: WeaponLoadout = null
var _weapon_buttons: Array[Button] = []
var _attachment_editing_enabled: bool = false
var _hovered_weapon_button: WeaponSlotButton = null
var _tooltip_attachment_rows: Array[Dictionary] = []
var _tooltip_weapon_id: String = ""

@onready var weapon_list: HBoxContainer = get_node_or_null("StripPanel/StripMargin/StripBody/WeaponScroll/WeaponList")
@onready var load_label: Label = get_node_or_null("StripPanel/StripMargin/StripBody/LoadLabel")
@onready var weapon_tooltip: PanelContainer = get_node_or_null("WeaponTooltip")
@onready var weapon_tooltip_label: RichTextLabel = get_node_or_null("WeaponTooltip/TooltipMargin/TooltipLabel")


func _ready() -> void:
	if weapon_tooltip != null:
		weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _on_weapon_attachment_changed(weapon_id: String, _item_instance_id: String) -> void:
	var should_restore_tooltip := weapon_tooltip != null and weapon_tooltip.visible and _tooltip_weapon_id == weapon_id
	var preserved_tooltip_position := weapon_tooltip.global_position if should_restore_tooltip else Vector2.ZERO
	_refresh_weapon_strip()
	if should_restore_tooltip:
		call_deferred("_restore_weapon_tooltip", weapon_id, preserved_tooltip_position)


func _restore_weapon_tooltip(weapon_id: String, preserved_position: Vector2) -> void:
	if _loadout == null:
		return
	var weapon := _loadout.get_weapon_instance(weapon_id)
	if weapon == null:
		return
	for button in _weapon_buttons:
		var weapon_button := button as WeaponSlotButton
		if weapon_button != null and weapon_button.weapon != null and weapon_button.weapon.weapon_id == weapon_id:
			_show_weapon_tooltip(weapon, weapon_button, preserved_position, true)
			return


func _process(_delta: float) -> void:
	if weapon_tooltip == null or not weapon_tooltip.visible:
		return
	var mouse_position := get_global_mouse_position()
	var over_weapon := _hovered_weapon_button != null and is_instance_valid(_hovered_weapon_button) and _hovered_weapon_button.get_global_rect().has_point(mouse_position)
	var over_tooltip := weapon_tooltip.get_global_rect().has_point(mouse_position)
	if not over_weapon and not over_tooltip:
		_hide_weapon_tooltip()


func _show_weapon_tooltip(weapon: WeaponInstance, anchor_button: Button, preserved_position: Vector2 = Vector2.ZERO, keep_position: bool = false) -> void:
	if weapon_tooltip == null or weapon_tooltip_label == null or weapon == null:
		return
	_hide_weapon_tooltip()
	_hovered_weapon_button = anchor_button as WeaponSlotButton
	_tooltip_weapon_id = weapon.weapon_id
	weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var attached_items := weapon.get_attached_item_instances()
	var can_detach_attachment := _attachment_editing_enabled and not attached_items.is_empty()
	weapon_tooltip_label.text = weapon.build_full_stats_text()
	weapon_tooltip.visible = true
	weapon_tooltip.reset_size()
	if can_detach_attachment:
		for slot_index in range(attached_items.size()):
			var item_instance_id := str(attached_items[slot_index].get("item_instance_id", ""))
			if not item_instance_id.is_empty():
				_tooltip_attachment_rows.append({
					"item_instance_id": item_instance_id,
					"slot_index": slot_index,
					"slot_count": weapon.get_attachment_slot_count(),
				})
		_update_tooltip_attachment_rows()
		call_deferred("_update_tooltip_attachment_rows")
	if keep_position:
		weapon_tooltip.global_position = preserved_position
		return
	var viewport_rect := get_viewport_rect()
	var target := Vector2.ZERO
	if anchor_button != null:
		target = anchor_button.global_position + Vector2(0, anchor_button.size.y - 2)
	if target.x + weapon_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - weapon_tooltip.size.x - 8, 0)
	if target.y + weapon_tooltip.size.y > viewport_rect.size.y and anchor_button != null:
		target.y = maxf(anchor_button.global_position.y - weapon_tooltip.size.y + 2, 0)
	weapon_tooltip.global_position = target


func _update_tooltip_attachment_rows() -> void:
	if weapon_tooltip_label == null:
		return
	for attachment_row in _tooltip_attachment_rows:
		var slot_index := int(attachment_row.get("slot_index", 0))
		var slot_count := int(attachment_row.get("slot_count", 1))
		var content_height := minf(weapon_tooltip_label.size.y, float(weapon_tooltip_label.get_content_height()))
		attachment_row["rect"] = Rect2(
			Vector2(0.0, maxf(content_height - ATTACHMENT_ROW_HEIGHT * float(slot_count - slot_index), 0.0)),
			Vector2(maxf(weapon_tooltip_label.size.x, 1.0), ATTACHMENT_ROW_HEIGHT)
		)


func _input(event: InputEvent) -> void:
	if weapon_tooltip == null or not weapon_tooltip.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	if not weapon_tooltip.get_global_rect().has_point(mouse_event.position):
		return
	print("[WeaponStrip] tooltip right-click: editable=%s rows=%d" % [_attachment_editing_enabled, _tooltip_attachment_rows.size()])
	if not _attachment_editing_enabled or weapon_tooltip_label == null:
		return
	var local_mouse_position := mouse_event.position - weapon_tooltip_label.global_position
	for attachment_row in _tooltip_attachment_rows:
		var row_rect: Rect2 = attachment_row.get("rect", Rect2())
		if row_rect.has_point(local_mouse_position):
			_detach_tooltip_attachment(_tooltip_weapon_id, str(attachment_row.get("item_instance_id", "")))
			return


func _detach_tooltip_attachment(weapon_id: String, item_instance_id: String) -> void:
	print("[WeaponStrip] detach request: weapon=%s item=%s editable=%s has_loadout=%s" % [weapon_id, item_instance_id, _attachment_editing_enabled, _loadout != null])
	if not _attachment_editing_enabled or _loadout == null:
		print("[WeaponStrip] detach rejected before loadout call.")
		return
	var detached := _loadout.detach_item_from_weapon(weapon_id, item_instance_id)
	if detached.is_empty():
		print("[WeaponStrip] detach failed: loadout returned no item.")
		return
	print("[WeaponStrip] detach succeeded: item=%s" % str(detached.get("item_instance_id", "")))
	get_viewport().set_input_as_handled()


func _hide_weapon_tooltip() -> void:
	_tooltip_attachment_rows.clear()
	_tooltip_weapon_id = ""
	if weapon_tooltip != null:
		weapon_tooltip.visible = false
		weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hovered_weapon_button = null
