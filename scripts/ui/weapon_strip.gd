extends Control
class_name WeaponStrip

signal minimum_height_changed

const WEAPON_SLOT_BUTTON_SCRIPT = preload("res://scripts/ui/weapon_slot_button.gd")
const CAST_MODE_ICON_SCRIPT = preload("res://scripts/ui/weapon_cast_mode_icon.gd")
const WEAPON_DRAG_TYPE := "esc_weapon_reorder"

@export var slot_size: int = 44
@export var icon_size: int = 34
@export var load_font_size: int = 16
@export var icon_slot_theme: Theme
@export var cast_mode_icon_size: float = WeaponCastModeIcon.ICON_SIZE

class ReorderButton extends Button:
	var direction := 1
	func _draw() -> void:
		var center := (size * 0.5).round()
		var color := Color("666b56") if disabled else Color("dec48a")
		var shadow := Color("10180f")
		if has_theme_color("reorder_color"):
			color = get_theme_color("reorder_hover_color" if is_hovered() else "reorder_color")
			shadow = get_theme_color("reorder_shadow")
		var points := PackedVector2Array([
			center + Vector2(direction * 3, 0),
			center + Vector2(-direction * 3, -4),
			center + Vector2(-direction * 3, 4)])
		# A dark one-pixel edge keeps the small corner mark readable over art.
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), shadow, 2.0)
		draw_colored_polygon(points, color)

var _loadout: WeaponLoadout = null
var _weapon_buttons: Array[Button] = []
var _cast_mode_buttons: Array[WeaponCastModeIcon] = []
var _cast_mode_layer: Control
var _automation_editing_enabled := false
var _reordering_enabled := false
var _selected_weapon_id := ""
var _reorder_buttons: Array[Dictionary] = []
var _drag_scroll_remainder := 0.0
var _attachment_editing_enabled: bool = false
var _hovered_weapon_button: WeaponSlotButton = null
var _tooltip_attachment_rows: Array[Dictionary] = []
var _tooltip_weapon_id: String = ""
var _attachment_tooltip: Panel
var _attachment_tooltip_label: Label
var _hovered_attachment_id := ""
var _tooltip_mouse_position := Vector2.ZERO

@onready var weapon_list: HBoxContainer = get_node_or_null("StripPanel/StripMargin/StripBody/WeaponScroll/WeaponList")
@onready var load_label: Label = get_node_or_null("StripPanel/StripMargin/StripBody/LoadLabel")
@onready var weapon_tooltip: PanelContainer = get_node_or_null("WeaponTooltip")
@onready var weapon_tooltip_label: RichTextLabel = get_node_or_null("WeaponTooltip/TooltipMargin/TooltipLabel")


func _ready() -> void:
	L10n.locale_changed.connect(_refresh_weapon_strip)
	if load_label != null:
		load_label.add_theme_font_size_override("font_size", load_font_size)
	_cast_mode_layer = Control.new()
	_cast_mode_layer.name = "CastModesBelowFrame"
	_cast_mode_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_mode_layer.clip_contents = true
	add_child(_cast_mode_layer)
	resized.connect(_layout_cast_mode_icons, CONNECT_DEFERRED)
	if weapon_list != null:
		weapon_list.minimum_size_changed.connect(func(): minimum_height_changed.emit())
		weapon_list.sort_children.connect(_layout_cast_mode_icons, CONNECT_DEFERRED)
		var scroll := weapon_list.get_parent() as ScrollContainer
		scroll.resized.connect(_layout_cast_mode_icons, CONNECT_DEFERRED)
		scroll.get_h_scroll_bar().value_changed.connect(func(_value: float): _layout_cast_mode_icons.call_deferred())
	if weapon_tooltip != null:
		weapon_tooltip.reparent(GameTooltipLayer.for_owner(self), false)
		weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_tooltip.add_theme_stylebox_override("panel", FinanceUIStyle.box("17231c", "98956a", 0))
	if weapon_tooltip_label != null:
		GameTooltipLayer.apply_pixel_text(weapon_tooltip_label)
		weapon_tooltip_label.add_theme_constant_override("line_separation", 4)
	_build_attachment_tooltip()


func set_loadout(loadout: WeaponLoadout, allow_attachment_editing: bool = false, allow_automation_editing: bool = false, allow_reordering: bool = false) -> void:
	if _loadout != null and _loadout.loadout_changed.is_connected(_on_loadout_changed):
		_loadout.loadout_changed.disconnect(_on_loadout_changed)
	if _loadout != null and _loadout.weapon_attachment_changed.is_connected(_on_weapon_attachment_changed):
		_loadout.weapon_attachment_changed.disconnect(_on_weapon_attachment_changed)
	_loadout = loadout
	_attachment_editing_enabled = allow_attachment_editing
	_automation_editing_enabled = allow_automation_editing
	_reordering_enabled = allow_reordering or allow_automation_editing
	if _loadout != null and not _loadout.weapon_attachment_changed.is_connected(_on_weapon_attachment_changed):
		_loadout.weapon_attachment_changed.connect(_on_weapon_attachment_changed)
	if _loadout != null:
		_loadout.loadout_changed.connect(_on_loadout_changed)
	_refresh_load_label()
	_refresh_weapon_strip()


func _on_loadout_changed() -> void:
	_refresh_load_label()
	_refresh_weapon_strip()


func _make_reorder_button(weapon_id: String, direction: int) -> ReorderButton:
	var arrow := ReorderButton.new()
	arrow.direction = direction
	arrow.name = "MoveLeft" if direction < 0 else "MoveRight"
	arrow.custom_minimum_size = Vector2(14, 14)
	arrow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if direction < 0 else Control.PRESET_BOTTOM_RIGHT)
	arrow.offset_top = -14
	arrow.offset_bottom = 0
	arrow.offset_left = 0 if direction < 0 else -14
	arrow.offset_right = 14 if direction < 0 else 0
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arrow.tooltip_text = "向左移动一位" if direction < 0 else "向右移动一位"
	if icon_slot_theme != null:
		arrow.theme = icon_slot_theme
	arrow.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	for state in ["hover", "pressed"]:
		var feedback := arrow.get_theme_stylebox("reorder_hover") if icon_slot_theme != null else FinanceUIStyle.box("394336", "8c7b4c", 0)
		arrow.add_theme_stylebox_override(state, feedback)
	arrow.pressed.connect(_move_weapon.bind(weapon_id, direction))
	arrow.mouse_entered.connect(_hide_weapon_tooltip)
	return arrow


func _select_weapon(weapon_id: String) -> void:
	_selected_weapon_id = weapon_id


func _move_weapon(weapon_id: String, direction: int) -> void:
	if not _reordering_enabled or _loadout == null: return
	_hide_weapon_tooltip()
	_selected_weapon_id = weapon_id
	if _loadout.move_weapon(weapon_id, direction):
		_reveal_selected_weapon.call_deferred()


func _get_weapon_drag_data(_at_position: Vector2, button: WeaponSlotButton) -> Variant:
	if not _reordering_enabled or _loadout == null or _weapon_buttons.size() < 2:
		return null
	if button.weapon == null or not _loadout.has_weapon(button.weapon.weapon_id):
		return null
	_hide_weapon_tooltip()
	_select_weapon(button.weapon.weapon_id)
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = Vector2(32, 32)
	art.position = -art.size * 0.5
	var icon_path := str(button.weapon.weapon_data.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		art.texture = ItemIconArt.texture_for(load(icon_path) as Texture2D, 32.0)
	preview.add_child(art)
	button.set_drag_preview(preview)
	return {"type": WEAPON_DRAG_TYPE, "loadout": _loadout, "weapon_id": button.weapon.weapon_id}


func _is_weapon_drag_data(data: Variant) -> bool:
	return _reordering_enabled and _loadout != null and data is Dictionary \
		and data.get("type") == WEAPON_DRAG_TYPE and data.get("loadout") == _loadout \
		and _loadout.has_weapon(str(data.get("weapon_id", "")))


func _can_drop_weapon(_at_position: Vector2, data: Variant, button: WeaponSlotButton) -> bool:
	return is_visible_in_tree() and _is_weapon_drag_data(data) and button.weapon != null \
		and button.weapon.weapon_id != str(data.get("weapon_id", "")) \
		and _loadout.weapon_instances.has(button.weapon)


func _drop_weapon(at_position: Vector2, data: Variant, button: WeaponSlotButton) -> void:
	if not _can_drop_weapon(at_position, data, button): return
	_selected_weapon_id = str(data.weapon_id)
	_hide_weapon_tooltip()
	if _loadout.move_weapon_to_index(_selected_weapon_id, _loadout.weapon_instances.find(button.weapon)):
		_reveal_selected_weapon.call_deferred()


func _scroll_during_weapon_drag(delta: float) -> void:
	if not is_visible_in_tree() or not get_viewport().gui_is_dragging() \
		or not _is_weapon_drag_data(get_viewport().gui_get_drag_data()):
		_drag_scroll_remainder = 0.0
		return
	var scroll := weapon_list.get_parent() as ScrollContainer
	var rect := scroll.get_global_rect()
	var direction := 0
	if rect.has_point(_tooltip_mouse_position):
		if _tooltip_mouse_position.x < rect.position.x + 20: direction = -1
		elif _tooltip_mouse_position.x > rect.end.x - 20: direction = 1
	if direction == 0:
		_drag_scroll_remainder = 0.0
		return
	_drag_scroll_remainder += direction * 220.0 * delta
	var pixels := int(_drag_scroll_remainder)
	_drag_scroll_remainder -= pixels
	scroll.scroll_horizontal += pixels


func _reveal_selected_weapon() -> void:
	# Rebuilt nested containers need their final positions before scrolling.
	await get_tree().process_frame
	if weapon_list == null: return
	for button in _weapon_buttons:
		if (button as WeaponSlotButton).weapon.weapon_id == _selected_weapon_id:
			var scroll := weapon_list.get_parent() as ScrollContainer
			scroll.ensure_control_visible(button.get_parent() as Control)
			# ensure_control_visible also adds a vertical scroll margin.
			# This is a single horizontal row; retain its original baseline.
			scroll.scroll_vertical = 0
	_layout_cast_mode_icons()


func _refresh_load_label() -> void:
	if load_label == null:
		return
	if _loadout == null:
		load_label.text = "ui.weapon.load_empty"
		return
	load_label.text = L10n.text("ui.weapon.load") % [_loadout.get_total_load_cost(), _loadout.get_load_capacity()]


func _refresh_weapon_strip() -> void:
	_hide_weapon_tooltip()
	if weapon_list != null:
		for child in weapon_list.get_children():
			weapon_list.remove_child(child)
			child.queue_free()
	_weapon_buttons.clear()
	_reorder_buttons.clear()
	for mode in _cast_mode_buttons:
		_cast_mode_layer.remove_child(mode)
		mode.queue_free()
	_cast_mode_buttons.clear()
	if weapon_list == null or _loadout == null:
		return
	if not _loadout.has_weapon(_selected_weapon_id):
		_selected_weapon_id = "" if _loadout.weapon_instances.is_empty() else _loadout.weapon_instances[0].weapon_id
	var weapons := _loadout.get_weapon_instances()
	for index in weapons.size():
		var weapon := weapons[index]
		var button := WEAPON_SLOT_BUTTON_SCRIPT.new() as WeaponSlotButton
		if button == null:
			continue
		button.configure(weapon, _attachment_editing_enabled)
		button.custom_minimum_size = Vector2.ONE * slot_size
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.flat = true
		if icon_slot_theme != null:
			button.theme = icon_slot_theme
			button.flat = false
		button.text = ""
		button.tooltip_text = ""
		var icon_path := str(weapon.weapon_data.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var texture := load(icon_path)
			if texture is Texture2D:
				button.icon = texture
				button.expand_icon = true
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.add_theme_constant_override("icon_max_width", icon_size)
				ItemIconArt.bind_button(button, texture, 32.0)
		if _attachment_editing_enabled and not button.item_drop_requested.is_connected(_on_item_drop_requested):
			button.item_drop_requested.connect(_on_item_drop_requested)
		if _reordering_enabled:
			button.set_drag_forwarding(_get_weapon_drag_data.bind(button), _can_drop_weapon.bind(button), _drop_weapon.bind(button))
			var group := MarginContainer.new()
			group.name = "Weapon_" + weapon.weapon_id
			group.custom_minimum_size = Vector2.ONE * slot_size
			group.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			group.mouse_filter = Control.MOUSE_FILTER_IGNORE
			weapon_list.add_child(group)
			group.add_child(button)
			button.resized.connect(_layout_cast_mode_icons, CONNECT_DEFERRED)
			var arrows := {"left": null, "right": null}
			if index > 0:
				arrows.left = _make_reorder_button(weapon.weapon_id, -1)
				button.add_child(arrows.left)
			if index < weapons.size() - 1:
				arrows.right = _make_reorder_button(weapon.weapon_id, 1)
				button.add_child(arrows.right)
			_reorder_buttons.append(arrows)
			if icon_slot_theme == null:
				button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			button.pressed.connect(_select_weapon.bind(weapon.weapon_id))
		else:
			weapon_list.add_child(button)
		if _automation_editing_enabled:
			var mode := CAST_MODE_ICON_SCRIPT.new() as WeaponCastModeIcon
			mode.icon_extent = cast_mode_icon_size
			mode.theme = icon_slot_theme
			var panel_style: StyleBox = get_node("StripPanel").get_theme_stylebox("panel")
			var frame_color: Color = panel_style.bg_color if panel_style is StyleBoxFlat else Color("05080a")
			mode.configure(weapon, true, frame_color)
			_cast_mode_layer.add_child(mode)
			mode.mouse_entered.connect(_hide_weapon_tooltip)
			_cast_mode_buttons.append(mode)
		button.mouse_entered.connect(_show_weapon_tooltip.bind(weapon, button))
		_weapon_buttons.append(button)
	_layout_cast_mode_icons.call_deferred()


func get_required_height() -> float:
	# Panel borders (4) + vertical margins (8), including the complete icon row.
	return weapon_list.get_combined_minimum_size().y + 12.0 if weapon_list != null else 62.0


func _layout_cast_mode_icons() -> void:
	if _cast_mode_layer == null or weapon_list == null: return
	_cast_mode_layer.visible = _automation_editing_enabled and not _cast_mode_buttons.is_empty()
	var scroll := weapon_list.get_parent() as ScrollContainer
	var panel := get_node("StripPanel") as Control
	# Center the glyph on the bottom border without changing the original frame.
	# Clip only horizontally to the visible weapon row, and follow its scrolling.
	_cast_mode_layer.position = Vector2(scroll.global_position.x - global_position.x, panel.position.y + panel.size.y - 1 - cast_mode_icon_size * 0.5)
	_cast_mode_layer.size = Vector2(scroll.size.x, cast_mode_icon_size)
	for i in _cast_mode_buttons.size():
		var mode := _cast_mode_buttons[i]
		mode.size = Vector2(maxf(28, cast_mode_icon_size + 8), cast_mode_icon_size)
		mode.position = Vector2(roundf(_weapon_buttons[i].get_global_rect().get_center().x - _cast_mode_layer.global_position.x - mode.size.x * 0.5), 0)


func _on_item_drop_requested(weapon_id: String, item_instance_id: String) -> void:
	if not _attachment_editing_enabled or _loadout == null:
		return
	if _loadout.request_manual_attachment(weapon_id, item_instance_id):
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


func _process(delta: float) -> void:
	_scroll_during_weapon_drag(delta)
	if weapon_tooltip == null or not weapon_tooltip.visible:
		return
	var mouse_position := _tooltip_mouse_position
	var over_weapon := _hovered_weapon_button != null and is_instance_valid(_hovered_weapon_button) and _hovered_weapon_button.get_global_rect().has_point(mouse_position)
	var over_tooltip := weapon_tooltip.get_global_rect().has_point(mouse_position)
	if not over_weapon and not over_tooltip:
		_hide_weapon_tooltip()
		return
	_update_attachment_tooltip(mouse_position)


func _show_weapon_tooltip(weapon: WeaponInstance, anchor_button: Button, preserved_position: Vector2 = Vector2.ZERO, keep_position: bool = false) -> void:
	if get_viewport().gui_is_dragging(): return
	if weapon_tooltip == null or weapon_tooltip_label == null or weapon == null:
		return
	_hide_weapon_tooltip()
	_hovered_weapon_button = anchor_button as WeaponSlotButton
	_tooltip_weapon_id = weapon.weapon_id
	weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var attached_items := weapon.get_attached_item_instances()
	weapon_tooltip_label.text = weapon.build_full_stats_text()
	weapon_tooltip.visible = true
	weapon_tooltip.reset_size()
	if not attached_items.is_empty():
		for slot_index in range(attached_items.size()):
			var item_instance_id := str(attached_items[slot_index].get("item_instance_id", ""))
			if not item_instance_id.is_empty():
				_tooltip_attachment_rows.append({
					"item_instance_id": item_instance_id,
					"slot_index": slot_index,
					"item": attached_items[slot_index],
				})
		_update_tooltip_attachment_rows()
		call_deferred("_update_tooltip_attachment_rows")
	if keep_position:
		weapon_tooltip.global_position = preserved_position.round()
		return
	var viewport_rect := get_viewport_rect()
	var target := Vector2.ZERO
	if anchor_button != null:
		# The tooltip lives on an unscaled canvas layer; use the displayed bounds.
		var anchor_rect := anchor_button.get_global_rect()
		target = Vector2(anchor_rect.position.x, anchor_rect.end.y - 2)
		if _automation_editing_enabled and not _attachment_editing_enabled:
			# Reward details start below the cast controls so every button stays usable.
			target.y = maxf(target.y, _cast_mode_layer.get_global_rect().end.y + 2)
		elif _automation_editing_enabled:
			# Keep the mode button clear, and keep an unbroken path into item details.
			target = Vector2(anchor_rect.end.x - 2, anchor_rect.position.y)
			if target.x + weapon_tooltip.size.x > viewport_rect.size.x:
				target.x = maxf(0, anchor_button.global_position.x - weapon_tooltip.size.x + 2)
	if target.x + weapon_tooltip.size.x > viewport_rect.size.x:
		target.x = maxf(viewport_rect.size.x - weapon_tooltip.size.x - 8, 0)
	if target.y + weapon_tooltip.size.y > viewport_rect.size.y and anchor_button != null:
		target.y = maxf(anchor_button.global_position.y - weapon_tooltip.size.y + 2, 0)
	weapon_tooltip.global_position = target.round()


func _update_tooltip_attachment_rows() -> void:
	if weapon_tooltip_label == null:
		return
	var face := weapon_tooltip_label.get_theme_font("normal_font")
	var font_size := weapon_tooltip_label.get_theme_font_size("normal_font_size")
	var header_width := face.get_string_size(L10n.text("ui.common.enchantments") + WeaponInstance.ATTACHMENT_ICON_GAP, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap_width := face.get_string_size(WeaponInstance.ATTACHMENT_ICON_GAP, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var row_y := weapon_tooltip_label.get_paragraph_offset(weapon_tooltip_label.get_paragraph_count() - 1)
	for attachment_row in _tooltip_attachment_rows:
		var slot_index := int(attachment_row.get("slot_index", 0))
		attachment_row["rect"] = Rect2(
			Vector2(header_width + slot_index * (WeaponInstance.ATTACHMENT_ICON_SIZE + gap_width), row_y),
			Vector2.ONE * WeaponInstance.ATTACHMENT_ICON_SIZE
		)


func _build_attachment_tooltip() -> void:
	_attachment_tooltip = Panel.new()
	_attachment_tooltip.name = "AttachmentTooltip"
	_attachment_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attachment_tooltip.z_index = 4096
	_attachment_tooltip.add_theme_stylebox_override("panel", FinanceUIStyle.box("17231c", "98956a", 0))
	_attachment_tooltip_label = Label.new()
	_attachment_tooltip_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_attachment_tooltip_label.position = Vector2(10, 8)
	_attachment_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attachment_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attachment_tooltip_label.add_theme_color_override("font_color", Color("ffffff"))
	if weapon_tooltip_label != null:
		_attachment_tooltip_label.add_theme_font_override("font", weapon_tooltip_label.get_theme_font("normal_font"))
		_attachment_tooltip_label.add_theme_font_size_override("font_size", weapon_tooltip_label.get_theme_font_size("normal_font_size"))
	_attachment_tooltip.add_child(_attachment_tooltip_label)
	GameTooltipLayer.for_owner(self).add_child(_attachment_tooltip)
	_attachment_tooltip.hide()


func _update_attachment_tooltip(mouse_position: Vector2) -> void:
	if weapon_tooltip_label == null:
		return
	var local_mouse := mouse_position - weapon_tooltip_label.global_position
	for row in _tooltip_attachment_rows:
		var rect: Rect2 = row.get("rect", Rect2())
		if rect.has_point(local_mouse):
			var item_id := str(row.get("item_instance_id", ""))
			if _hovered_attachment_id != item_id or not _attachment_tooltip.visible:
				_hovered_attachment_id = item_id
				_show_attachment_tooltip(row.get("item", {}), rect)
			return
	_hide_attachment_tooltip()


func _show_attachment_tooltip(item: Dictionary, icon_rect: Rect2) -> void:
	var base := DataRegistry.get_record("augmentations", str(item.get("base_item_id", "")))
	var title := L10n.source(str(item.get("display_name", base.get("display_name", L10n.text("ui.common.enchantments")))))
	var description := L10n.source(str(item.get("description", base.get("description", ""))))
	var text := title + ("\n" + description if not description.is_empty() else "")
	var viewport_size := get_viewport_rect().size
	var width := minf(280.0, viewport_size.x - 40.0)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, _attachment_tooltip_label.get_theme_font("font"), _attachment_tooltip_label.get_theme_font_size("font_size"))
	var height := paragraph.get_size().y + maxf(0, paragraph.get_line_count() - 1) * _attachment_tooltip_label.get_theme_constant("line_spacing")
	_attachment_tooltip_label.text = text
	_attachment_tooltip_label.size = Vector2(width, height)
	_attachment_tooltip.size = Vector2(width + 20, height + 16)
	var weapon_rect := weapon_tooltip.get_global_rect()
	var point := Vector2(weapon_rect.end.x + 8, weapon_tooltip_label.global_position.y + icon_rect.position.y)
	if point.x + _attachment_tooltip.size.x > viewport_size.x - 8:
		point.x = weapon_rect.position.x - _attachment_tooltip.size.x - 8
		if point.x < 8:
			point.x = weapon_rect.position.x
			point.y = weapon_rect.end.y + 8
			if point.y + _attachment_tooltip.size.y > viewport_size.y - 8:
				point.y = weapon_tooltip_label.global_position.y + icon_rect.position.y - _attachment_tooltip.size.y - 8
	point.x = clampf(point.x, 8, maxf(8, viewport_size.x - _attachment_tooltip.size.x - 8))
	point.y = clampf(point.y, 8, maxf(8, viewport_size.y - _attachment_tooltip.size.y - 8))
	_attachment_tooltip.position = point.round()
	_attachment_tooltip.show()


func _hide_attachment_tooltip() -> void:
	_hovered_attachment_id = ""
	if _attachment_tooltip != null:
		_attachment_tooltip.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		# Use the same viewport coordinates as the rendered tooltip layer.
		_tooltip_mouse_position = event.position
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
	var detached := _loadout.request_manual_detachment(weapon_id, item_instance_id)
	if detached.is_empty():
		print("[WeaponStrip] detach failed: loadout returned no item.")
		return
	print("[WeaponStrip] detach succeeded: item=%s" % str(detached.get("item_instance_id", "")))
	get_viewport().set_input_as_handled()


func _hide_weapon_tooltip() -> void:
	_hide_attachment_tooltip()
	_tooltip_attachment_rows.clear()
	_tooltip_weapon_id = ""
	if weapon_tooltip != null:
		weapon_tooltip.visible = false
		weapon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hovered_weapon_button = null
