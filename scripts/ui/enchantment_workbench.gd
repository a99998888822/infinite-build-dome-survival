extends VBoxContainer
class_name EnchantmentWorkbench

signal sale_requested(kind: String, target_id: String)
signal feedback_requested(message: String, success: bool)
signal tooltip_requested(content: String)
signal tooltip_hidden

var flow: MainFlowCoordinator
var selected_weapon_id := ""
var selected_item_id := ""
var _weapon_row: HBoxContainer
var _weapon_name: Label
var _sell_weapon: Button
var _upgrade_weapon: Button
var _principal_upgrade_quote: Dictionary = {}
var _slots: HBoxContainer
var _inventory: GridContainer
var _inventory_scroll: ScrollContainer
var _selection: Label
var _apply: Button
var _sell_item: Button
var _title: Label
var _move_left: Button
var _move_right: Button
var _weapon_icon: TextureRect
var _weapon_scroll: ScrollContainer
var _weapon_scroll_left: Button
var _weapon_scroll_right: Button
var _weapon_scroll_direction := 0
var _weapon_scroll_elapsed := 0.0
var _weapon_scroll_position := 0.0

const WEAPON_SCROLL_STEP := 32.0
const WEAPON_SCROLL_SPEED := 320.0
const WEAPON_SCROLL_DELAY := 0.22


func _ready() -> void:
	L10n.locale_changed.connect(refresh)
	set_process(false)
	add_theme_constant_override("separation", 4)
	var weapon_section := MarginContainer.new()
	weapon_section.add_theme_constant_override("margin_bottom", 6)
	add_child(weapon_section)
	var weapon_view := MarginContainer.new()
	weapon_section.add_child(weapon_view)
	_weapon_scroll = TouchScrollContainer.new()
	_weapon_scroll.follow_focus = true
	FinanceUIStyle.bank_horizontal_scroll(_weapon_scroll)
	_weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	weapon_view.add_child(_weapon_scroll)
	var weapon_padding := MarginContainer.new()
	weapon_padding.add_theme_constant_override("margin_left", 4)
	weapon_padding.add_theme_constant_override("margin_right", 4)
	weapon_padding.add_theme_constant_override("margin_top", 4)
	weapon_padding.add_theme_constant_override("margin_bottom", 4)
	_weapon_scroll.add_child(weapon_padding)
	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 8)
	weapon_padding.add_child(_weapon_row)
	# Overlay the clipped edges without changing the viewport as arrows appear.
	var navigation := Control.new()
	navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_view.add_child(navigation)
	_weapon_scroll_left = _weapon_scroll_button("◀", -1, navigation)
	_weapon_scroll_right = _weapon_scroll_button("▶", 1, navigation)
	_weapon_scroll.get_h_scroll_bar().changed.connect(_sync_weapon_scroll_buttons)
	_weapon_scroll.get_h_scroll_bar().value_changed.connect(func(_value): _sync_weapon_scroll_buttons())
	visibility_changed.connect(_stop_weapon_scroll)
	var heading := HBoxContainer.new()
	add_child(heading)
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(26, 26)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heading.add_child(_weapon_icon)
	_weapon_name = Label.new()
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_weapon_name, 23)
	heading.add_child(_weapon_name)
	_upgrade_weapon = _button("ui.enchantment.principal_upgrade", heading)
	_upgrade_weapon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_upgrade_weapon.pressed.connect(_purchase_principal_upgrade)
	_upgrade_weapon.mouse_entered.connect(_show_principal_upgrade_tooltip)
	_upgrade_weapon.mouse_exited.connect(func(): tooltip_hidden.emit())
	_sell_weapon = _button("ui.enchantment.sell_weapon", heading)
	_sell_weapon.pressed.connect(func(): sale_requested.emit("weapon", selected_weapon_id))
	var slot_scroll := ScrollContainer.new()
	slot_scroll.custom_minimum_size.y = 64
	FinanceUIStyle.bank_horizontal_scroll(slot_scroll)
	add_child(slot_scroll)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 4)
	slot_scroll.add_child(_slots)
	_title = Label.new()
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_title, 20, FinanceUIStyle.MUTED)
	add_child(_title)
	_inventory_scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.bank_scroll(_inventory_scroll)
	# Keep six columns even in small windows; allow access without squeezing art.
	_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	FinanceFrameSkin.scrollbar(_inventory_scroll.get_h_scroll_bar())
	_inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_scroll.custom_minimum_size.y = 52
	add_child(_inventory_scroll)
	_inventory = GridContainer.new()
	_inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory.add_theme_constant_override("h_separation", 4)
	_inventory.add_theme_constant_override("v_separation", 6)
	_inventory_scroll.add_child(_inventory)
	_selection = Label.new()
	_selection.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_selection, 20, FinanceUIStyle.MUTED)
	add_child(_selection)
	var actions := HBoxContainer.new()
	add_child(actions)
	_apply = _button("ui.enchantment.equip_current", actions)
	_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply.pressed.connect(_apply_selected)
	_move_left = _button("ui.enchantment.move_left", actions)
	_move_left.tooltip_text = "ui.enchantment.move_left_tooltip"
	_move_left.pressed.connect(_move_selected.bind(-1))
	_move_right = _button("ui.enchantment.move_right", actions)
	_move_right.tooltip_text = "ui.enchantment.move_right_tooltip"
	_move_right.pressed.connect(_move_selected.bind(1))
	_sell_item = _button("ui.enchantment.sell", actions)
	_sell_item.pressed.connect(_sell_selected_item)
	_inventory_scroll.resized.connect(_layout_inventory)


func refresh() -> void:
	if flow == null or _weapon_row == null: return
	_stop_weapon_scroll()
	tooltip_hidden.emit()
	var loadout := flow.get_bound_loadout()
	var player := flow.get_bound_player()
	if loadout == null or player == null: return
	var weapons := loadout.get_weapon_instances()
	if loadout.get_weapon_instance(selected_weapon_id) == null:
		selected_weapon_id = weapons[0].weapon_id if not weapons.is_empty() else ""
	_clear(_weapon_row)
	for weapon in weapons:
		var button := WeaponSlotButton.new()
		_weapon_row.add_child(button)
		button.configure(weapon, true)
		button.custom_minimum_size = Vector2(120, 46)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.icon = FinanceUIStyle.item_icon(str(weapon.weapon_data.get("icon", "")), "weapons", weapon.weapon_id)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 36)
		button.focus_mode = Control.FOCUS_ALL
		FinanceUIStyle.bank_button(button, weapon.weapon_id == selected_weapon_id)
		button.add_theme_font_size_override("font_size", 10)
		ItemIconArt.bind_button(button, button.icon, 32.0)
		button.pressed.connect(_select_weapon.bind(weapon.weapon_id))
		button.item_drop_requested.connect(_drop_item)
		button.mouse_entered.connect(func(): tooltip_requested.emit(weapon.build_full_stats_text()))
		button.mouse_exited.connect(func(): tooltip_hidden.emit())
	var current := loadout.get_weapon_instance(selected_weapon_id)
	ItemIconArt.bind_texture(_weapon_icon, FinanceUIStyle.item_icon(str(current.weapon_data.get("icon", "")), "weapons", current.weapon_id) if current != null else null, false, 26.0, null, 26.0)
	_weapon_name.text = "%s · Lv.%d" % [L10n.source(str(current.weapon_data.get("display_name", ""))), current.level] if current != null else "尚无武器"
	_weapon_name.tooltip_text = ""
	_sell_weapon.disabled = weapons.size() <= 1
	_sell_weapon.tooltip_text = "ui.enchantment.keep_one_weapon" if _sell_weapon.disabled else "ui.enchantment.sale_returns_enchantments"
	_refresh_principal_upgrade()
	_clear(_slots)
	if current != null:
		var attached := current.get_attached_item_instances()
		for index in current.get_attachment_slot_count():
			if index > 0:
				var arrow := Label.new()
				arrow.text = "→"
				FinanceUIStyle.label(arrow, 20, FinanceUIStyle.GOLD)
				_slots.add_child(arrow)
			var item: Dictionary = attached[index] if index < attached.size() else {}
			var slot := EnchantmentSlotCard.new()
			_slots.add_child(slot)
			slot.configure_slot(index, item)
			slot.slot_drop_requested.connect(_drop_into_slot)
			slot.item_tooltip_requested.connect(func(_anchor, content): tooltip_requested.emit(content))
			slot.item_tooltip_hidden.connect(func(): tooltip_hidden.emit())
			if item.is_empty():
				slot.pressed.connect(func(): _operate("attach", selected_weapon_id, selected_item_id))
			else:
				slot.pressed.connect(_select_item.bind(str(item.get("item_instance_id", ""))))
		_title.text = "ui.enchantment.inventory.title"
		_title.tooltip_text = L10n.text("ui.enchantment.weapon_title_prefix") + L10n.source(str(current.battle_title.get("display_name", ""))) if not L10n.source(str(current.battle_title.get("display_name", ""))).is_empty() else L10n.text("ui.enchantment.selected_equipped_hint")
		_title.tooltip_text += L10n.text("ui.enchantment.split_order_hint")
		_title.tooltip_text += L10n.text("ui.enchantment.replace_hint")
	_clear(_inventory)
	_layout_inventory()
	for item in player.item_inventory.get_items():
		if not str(item.get("equipped_weapon_id", "")).is_empty(): continue
		var card := _item_card(item, _inventory)
		card.pressed.connect(_select_item.bind(str(item.get("item_instance_id", ""))))
	if _inventory.get_child_count() == 0:
		var empty := Label.new()
		empty.name = "EmptyEnchantmentLabel"
		empty.text = "ui.enchantment.inventory.empty"
		empty.autowrap_mode = TextServer.AUTOWRAP_OFF
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		FinanceUIStyle.label(empty, 17, Color("8b9089"))
		_inventory.add_child(empty)
	_update_selection()
	_sync_weapon_scroll_buttons.call_deferred()


func _refresh_principal_upgrade() -> void:
	_principal_upgrade_quote = flow.get_principal_weapon_upgrade_quote(selected_weapon_id)
	_upgrade_weapon.disabled = not bool(_principal_upgrade_quote.get("success", false))
	var reason := str(_principal_upgrade_quote.get("reason", ""))
	if reason == "principal_upgrade_max_level":
		_upgrade_weapon.text = "ui.enchantment.upgrade_max_level"
	elif reason == "principal_upgrade_used":
		_upgrade_weapon.text = "ui.enchantment.upgrade_used"
	else:
		_upgrade_weapon.text = L10n.text("ui.enchantment.principal_upgrade_price") % int(_principal_upgrade_quote.get("price", 0))


func _show_principal_upgrade_tooltip() -> void:
	var description := L10n.source(str(_principal_upgrade_quote.get("description", "")))
	var reason := str(_principal_upgrade_quote.get("reason", ""))
	if not reason.is_empty():
		if not description.is_empty(): description += "\n"
		description += FinanceUIStyle.reason(reason)
	if not description.is_empty(): tooltip_requested.emit(description)


func _purchase_principal_upgrade() -> void:
	tooltip_hidden.emit()
	var result := flow.purchase_principal_weapon_upgrade(selected_weapon_id, str(_principal_upgrade_quote.get("quote_token", "")))
	var success := bool(result.get("success", false))
	feedback_requested.emit(L10n.text("ui.enchantment.principal_upgrade_done") if success else FinanceUIStyle.reason(str(result.get("reason", ""))), success)
	refresh()


func _weapon_scroll_button(caption: String, direction: int, parent: Control) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(24, 46)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	FinanceUIStyle.bank_button(button)
	button.add_theme_font_size_override("font_size", 10)
	parent.add_child(button)
	button.anchor_left = 0.0 if direction < 0 else 1.0
	button.anchor_right = button.anchor_left
	button.anchor_bottom = 1.0
	button.offset_left = 0.0 if direction < 0 else -24.0
	button.offset_right = 24.0 if direction < 0 else 0.0
	button.offset_top = 4.0
	button.offset_bottom = -4.0
	button.hide()
	button.button_down.connect(_start_weapon_scroll.bind(direction))
	button.button_up.connect(_stop_weapon_scroll)
	button.mouse_exited.connect(_stop_weapon_scroll)
	button.mouse_entered.connect(func(): tooltip_hidden.emit())
	return button


func _start_weapon_scroll(direction: int) -> void:
	_weapon_scroll_direction = direction
	_weapon_scroll_elapsed = 0.0
	_weapon_scroll_position = _weapon_scroll.scroll_horizontal
	set_process(true)
	_scroll_weapons(WEAPON_SCROLL_STEP * direction)


func _stop_weapon_scroll() -> void:
	_weapon_scroll_direction = 0
	set_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_weapon_scroll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_weapon_scroll()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_stop_weapon_scroll()
		return
	var previous := _weapon_scroll_elapsed
	_weapon_scroll_elapsed += delta
	var active_delta := maxf(0.0, _weapon_scroll_elapsed - WEAPON_SCROLL_DELAY) - maxf(0.0, previous - WEAPON_SCROLL_DELAY)
	if active_delta > 0:
		_scroll_weapons(WEAPON_SCROLL_SPEED * active_delta * _weapon_scroll_direction)


func _scroll_weapons(distance: float) -> void:
	var bar := _weapon_scroll.get_h_scroll_bar()
	_weapon_scroll_position = clampf(_weapon_scroll_position + distance, 0.0, maxf(0.0, bar.max_value - bar.page))
	_weapon_scroll.scroll_horizontal = roundi(_weapon_scroll_position)
	_sync_weapon_scroll_buttons()


func _sync_weapon_scroll_buttons() -> void:
	if _weapon_scroll_left == null or _weapon_scroll_right == null: return
	var bar := _weapon_scroll.get_h_scroll_bar()
	var limit := maxi(0, roundi(bar.max_value - bar.page))
	_weapon_scroll_left.visible = _weapon_scroll.scroll_horizontal > 0
	_weapon_scroll_right.visible = _weapon_scroll.scroll_horizontal < limit
	if (_weapon_scroll_direction < 0 and not _weapon_scroll_left.visible) or (_weapon_scroll_direction > 0 and not _weapon_scroll_right.visible):
		_stop_weapon_scroll()


func _select_weapon(id: String) -> void:
	selected_weapon_id = id
	refresh()


func _select_item(id: String) -> void:
	selected_item_id = id
	_update_selection()
	tooltip_hidden.emit()


func _update_selection() -> void:
	var item := flow.get_bound_player().item_inventory.find_item(selected_item_id)
	if item.is_empty(): selected_item_id = ""
	var equipped := str(item.get("equipped_weapon_id", ""))
	var current := flow.get_bound_loadout().get_weapon_instance(selected_weapon_id)
	var same_weapon := not equipped.is_empty() and equipped == selected_weapon_id
	_selection.text = L10n.text("ui.enchantment.selected_prefix") + L10n.source(str(item.get("display_name", ""))) if not item.is_empty() else "ui.enchantment.select_hint"
	_apply.text = "ui.enchantment.unequip" if same_weapon else ("ui.enchantment.transfer_here" if not equipped.is_empty() else "ui.enchantment.equip_here")
	_apply.disabled = item.is_empty() or current == null or (not same_weapon and not current.has_available_attachment_slot())
	_apply.tooltip_text = "ui.enchantment.no_empty_slots_hint" if current != null and not same_weapon and not current.has_available_attachment_slot() else ""
	if current != null and not same_weapon:
		var incompatibility := current.get_attachment_incompatibility(item)
		if not incompatibility.is_empty():
			_apply.disabled = true
			_apply.tooltip_text = incompatibility
			_selection.text += " · " + incompatibility
	var sale_quote := flow.get_inventory_sale_quote("enchantment", selected_item_id) if not item.is_empty() and equipped.is_empty() else {}
	_sell_item.text = L10n.text("ui.enchantment.sell_price") % int(sale_quote.get("total", 0)) if bool(sale_quote.get("success", false)) else "ui.enchantment.sell"
	_sell_item.disabled = item.is_empty() or not equipped.is_empty() or not bool(sale_quote.get("success", false))
	_sell_item.tooltip_text = "ui.enchantment.unequip_before_sale" if not equipped.is_empty() else ""
	if bool(sale_quote.get("success", false)):
		_sell_item.tooltip_text = HumanityEconomy.sale_tooltip(sale_quote)
	var selected_index := -1
	var attached := current.get_attached_item_instances() if current != null else []
	for index in attached.size():
		if str(attached[index].get("item_instance_id", "")) == selected_item_id: selected_index = index
	_move_left.disabled = selected_index <= 0
	_move_right.disabled = selected_index < 0 or selected_index >= attached.size() - 1
	for container in [_inventory, _slots]:
		for child in container.get_children():
			if child is EnchantmentSlotCard:
				child.set_selected(not selected_item_id.is_empty() and str(child.item_instance.get("item_instance_id", "")) == selected_item_id)
			elif child is ItemInventoryCard:
				FinanceUIStyle.bank_button(child, str(child.item_instance.get("item_instance_id", "")) == selected_item_id)


func _apply_selected() -> void:
	var item := flow.get_bound_player().item_inventory.find_item(selected_item_id)
	var same_weapon := str(item.get("equipped_weapon_id", "")) == selected_weapon_id
	_operate("detach" if same_weapon else "attach", selected_weapon_id, selected_item_id)


func _sell_selected_item() -> void:
	if flow == null or selected_item_id.is_empty():
		return
	var quote := flow.get_inventory_sale_quote("enchantment", selected_item_id)
	if not bool(quote.get("success", false)):
		feedback_requested.emit(FinanceUIStyle.reason(str(quote.get("reason", ""))), false)
		return
	var result := flow.submit_inventory_sale("enchantment", selected_item_id, str(quote.get("quote_token", "")))
	if bool(result.get("success", false)):
		feedback_requested.emit(L10n.text("ui.enchantment.sale_done") % int(result.get("gold_gained", 0)), true)
	else:
		feedback_requested.emit(FinanceUIStyle.reason(str(result.get("reason", ""))), false)


func _drop_item(weapon_id: String, item_id: String) -> void:
	selected_weapon_id = weapon_id
	selected_item_id = item_id
	_operate("attach", weapon_id, item_id)


func _drop_into_slot(index: int, item_id: String) -> void:
	var item := flow.get_bound_player().item_inventory.find_item(item_id)
	var weapon := flow.get_bound_loadout().get_weapon_instance(selected_weapon_id)
	if weapon == null: return
	selected_item_id = item_id
	var attached := weapon.get_attached_item_instances()
	if str(item.get("equipped_weapon_id", "")) == selected_weapon_id:
		_operate("move", selected_weapon_id, item_id, mini(index, attached.size() - 1))
	elif index < attached.size():
		_operate("replace", selected_weapon_id, item_id, index)
	else:
		_operate("attach", selected_weapon_id, item_id)


func _move_selected(direction: int) -> void:
	var weapon := flow.get_bound_loadout().get_weapon_instance(selected_weapon_id)
	if weapon == null: return
	var attached := weapon.get_attached_item_instances()
	for index in attached.size():
		if str(attached[index].get("item_instance_id", "")) == selected_item_id:
			_operate("move", selected_weapon_id, selected_item_id, index + direction)
			return


func _operate(action: String, weapon_id: String, item_id: String, target_index: int = -1) -> void:
	if item_id.is_empty():
		feedback_requested.emit(L10n.text("ui.enchantment.select_inventory_first"), false)
		return
	tooltip_hidden.emit()
	var result := flow.submit_enchantment_operation(action, weapon_id, item_id, target_index)
	var success := bool(result.get("success", false))
	var message := L10n.text("ui.enchantment.unequip_done") if action == "detach" else ("附魔排列已更新。" if action == "move" else "附魔配置已更新。")
	if action == "replace": message = "附魔已替换，原附魔已归还背包。"
	feedback_requested.emit(message if success else FinanceUIStyle.reason(str(result.get("reason", ""))), success)


func _layout_inventory() -> void:
	_inventory.columns = 6


func _item_card(item: Dictionary, parent: Control) -> ItemInventoryCard:
	var card := EnchantmentInventoryCard.new()
	parent.add_child(card)
	card.configure(item, true)
	card.item_tooltip_requested.connect(func(_anchor, content): tooltip_requested.emit(content))
	card.item_tooltip_hidden.connect(func(): tooltip_hidden.emit())
	return card


func _button(caption: String, parent: Control) -> Button:
	var control := Button.new()
	control.text = caption
	control.custom_minimum_size.y = 28
	FinanceUIStyle.bank_button(control)
	parent.add_child(control)
	return control


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
