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


func _ready() -> void:
	L10n.locale_changed.connect(refresh)
	add_theme_constant_override("separation", 4)
	# Separate the card edges, scroll track and sale heading instead of letting
	# the default scrollbar touch both rows. Keep the remaining form compact.
	var weapon_section := MarginContainer.new()
	weapon_section.add_theme_constant_override("margin_bottom", 14)
	add_child(weapon_section)
	_weapon_scroll = TouchScrollContainer.new()
	_weapon_scroll.follow_focus = true
	FinanceUIStyle.bank_horizontal_scroll(_weapon_scroll)
	weapon_section.add_child(_weapon_scroll)
	var weapon_padding := MarginContainer.new()
	weapon_padding.add_theme_constant_override("margin_left", 4)
	weapon_padding.add_theme_constant_override("margin_right", 4)
	weapon_padding.add_theme_constant_override("margin_top", 4)
	weapon_padding.add_theme_constant_override("margin_bottom", 18)
	_weapon_scroll.add_child(weapon_padding)
	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 8)
	weapon_padding.add_child(_weapon_row)
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
	FinanceUIStyle.label(_weapon_name, 14)
	heading.add_child(_weapon_name)
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
	FinanceUIStyle.label(_title, 12, FinanceUIStyle.MUTED)
	add_child(_title)
	_inventory_scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.bank_scroll(_inventory_scroll)
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
	FinanceUIStyle.label(_selection, 12, FinanceUIStyle.MUTED)
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
		button.custom_minimum_size = Vector2(180, 46)
		button.icon = FinanceUIStyle.item_icon(str(weapon.weapon_data.get("icon", "")), "weapons", weapon.weapon_id)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 36)
		button.focus_mode = Control.FOCUS_ALL
		FinanceUIStyle.bank_button(button, weapon.weapon_id == selected_weapon_id)
		button.pressed.connect(_select_weapon.bind(weapon.weapon_id))
		button.item_drop_requested.connect(_drop_item)
		button.mouse_entered.connect(func(): tooltip_requested.emit(weapon.build_full_stats_text()))
		button.mouse_exited.connect(func(): tooltip_hidden.emit())
	var current := loadout.get_weapon_instance(selected_weapon_id)
	_weapon_icon.texture = FinanceUIStyle.item_icon(str(current.weapon_data.get("icon", "")), "weapons", current.weapon_id) if current != null else null
	_weapon_name.text = "%s · Lv.%d" % [L10n.source(str(current.weapon_data.get("display_name", ""))), current.level] if current != null else "尚无武器"
	_weapon_name.tooltip_text = ""
	_sell_weapon.disabled = weapons.size() <= 1
	_sell_weapon.tooltip_text = "ui.enchantment.keep_one_weapon" if _sell_weapon.disabled else "ui.enchantment.sale_returns_enchantments"
	_clear(_slots)
	if current != null:
		var attached := current.get_attached_item_instances()
		for index in current.get_attachment_slot_count():
			if index > 0:
				var arrow := Label.new()
				arrow.text = "→"
				FinanceUIStyle.label(arrow, 12, FinanceUIStyle.GOLD)
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
		_inventory.columns = 1
		var empty := Label.new()
		empty.name = "EmptyEnchantmentLabel"
		empty.text = "ui.enchantment.inventory.empty"
		empty.autowrap_mode = TextServer.AUTOWRAP_OFF
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		FinanceUIStyle.label(empty, 12, Color("8b9089"))
		_inventory.add_child(empty)
	_update_selection()


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
	var usable := maxf(1, _inventory_scroll.size.x - _inventory_scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	var gap := _inventory.get_theme_constant("h_separation")
	_inventory.columns = clampi(floori((usable + gap) / (EnchantmentInventoryCard.CARD_SIZE.x + gap)), 1, 4)
	if _inventory.get_child_count() == 1 and _inventory.get_child(0) is Label:
		_inventory.columns = 1


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
