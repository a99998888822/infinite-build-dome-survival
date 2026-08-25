extends Button
class_name WeaponSlotButton

signal item_drop_requested(weapon_id: String, item_instance_id: String)

var weapon: WeaponInstance = null
var attachment_editing_enabled: bool = false


func configure(next_weapon: WeaponInstance, allow_attachment_editing: bool) -> void:
	weapon = next_weapon
	attachment_editing_enabled = allow_attachment_editing
	custom_minimum_size = Vector2(142.0, 50.0)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat = false
	_refresh_text()


func set_attachment_editing_enabled(enabled: bool) -> void:
	attachment_editing_enabled = enabled


func _refresh_text() -> void:
	if weapon == null:
		text = ""
		return
	var weapon_name := str(weapon.weapon_data.get("display_name", weapon.weapon_id))
	var slot_count := weapon.get_attachment_slot_count()
	if slot_count <= 0:
		text = weapon_name
		return
	var attached := weapon.get_attached_item_instance()
	var attachment_name := "空槽"
	if not attached.is_empty():
		attachment_name = str(attached.get("display_name", attached.get("base_item_id", "已装填")))
	text = "%s\n[%s]" % [weapon_name, attachment_name]
	tooltip_text = weapon.build_full_stats_text()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not attachment_editing_enabled or weapon == null:
		return false
	if not (data is Dictionary):
		return false
	if str(data.get("type", "")) != "augmentation_item":
		return false
	return weapon.has_attachment_slot()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data):
		return
	item_drop_requested.emit(weapon.weapon_id, str(data.get("item_instance_id", "")))
