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


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.custom_minimum_size.y = 52
	weapon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(weapon_scroll)
	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 8)
	weapon_scroll.add_child(_weapon_row)
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
	_sell_weapon = _button("出售武器", heading)
	_sell_weapon.pressed.connect(func(): sale_requested.emit("weapon", selected_weapon_id))
	var slot_scroll := ScrollContainer.new()
	slot_scroll.custom_minimum_size.y = 84
	slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(slot_scroll)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	slot_scroll.add_child(_slots)
	_title = Label.new()
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_title, 12, FinanceUIStyle.MUTED)
	add_child(_title)
	_inventory_scroll = preload("res://scripts/ui/touch_scroll_container.gd").new()
	FinanceUIStyle.scroll(_inventory_scroll)
	_inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_scroll.custom_minimum_size.y = 52
	add_child(_inventory_scroll)
	_inventory = GridContainer.new()
	_inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory.add_theme_constant_override("h_separation", 8)
	_inventory.add_theme_constant_override("v_separation", 6)
	_inventory_scroll.add_child(_inventory)
	_selection = Label.new()
	_selection.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_selection, 12, FinanceUIStyle.MUTED)
	add_child(_selection)
	var actions := HBoxContainer.new()
	add_child(actions)
	_apply = _button("装备到当前武器", actions)
	_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply.pressed.connect(_apply_selected)
	_move_left = _button("← 前移", actions)
	_move_left.tooltip_text = "将选中的已装备附魔前移一格"
	_move_left.pressed.connect(_move_selected.bind(-1))
	_move_right = _button("后移 →", actions)
	_move_right.tooltip_text = "将选中的已装备附魔后移一格"
	_move_right.pressed.connect(_move_selected.bind(1))
	_sell_item = _button("出售附魔", actions)
	_sell_item.pressed.connect(func(): sale_requested.emit("enchantment", selected_item_id))
	resized.connect(func(): _inventory.columns = 2 if size.x >= 430 else 1)


func refresh() -> void:
	if flow == null or _weapon_row == null: return
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
		FinanceUIStyle.button(button, weapon.weapon_id == selected_weapon_id)
		button.pressed.connect(_select_weapon.bind(weapon.weapon_id))
		button.item_drop_requested.connect(_drop_item)
	var current := loadout.get_weapon_instance(selected_weapon_id)
	_weapon_icon.texture = FinanceUIStyle.item_icon(str(current.weapon_data.get("icon", "")), "weapons", current.weapon_id) if current != null else null
	_weapon_name.text = "%s · Lv.%d" % [str(current.weapon_data.get("display_name", "")), current.level] if current != null else "尚无武器"
	_sell_weapon.disabled = weapons.size() <= 1
	_sell_weapon.tooltip_text = "至少保留一把武器" if _sell_weapon.disabled else "出售后，附魔自动归还背包"
	_clear(_slots)
	if current != null:
		var attached := current.get_attached_item_instances()
		for index in current.get_attachment_slot_count():
			if index > 0:
				var arrow := Label.new()
				arrow.text = "→"
				FinanceUIStyle.label(arrow, 14, FinanceUIStyle.GOLD)
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
		_title.text = "附魔背包 · 槽位从左至右排列，可拖动或前后移位"
		_title.tooltip_text = "称号：" + str(current.battle_title.get("display_name", "")) if not str(current.battle_title.get("display_name", "")).is_empty() else "选中已装备附魔后，可卸下或调整顺序。"
	_clear(_inventory)
	_inventory.columns = 2 if size.x >= 430 else 1
	for item in player.item_inventory.get_items():
		var card := _item_card(item, _inventory, 160)
		var equipped := str(item.get("equipped_weapon_id", ""))
		var owner := loadout.get_weapon_instance(equipped)
		card.text += "\n" + ("未装备" if owner == null else "已装：" + str(owner.weapon_data.get("display_name", "")))
		card.pressed.connect(_select_item.bind(str(item.get("item_instance_id", ""))))
	if _inventory.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "暂无附魔 · 战斗中拾取后可在此配置"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		FinanceUIStyle.label(empty, 12, FinanceUIStyle.MUTED)
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
	_selection.text = "选中：" + str(item.get("display_name", "")) if not item.is_empty() else "选择一张附魔，可装备、转移或出售"
	_apply.text = "卸下附魔" if same_weapon else ("转移至此武器" if not equipped.is_empty() else "装备至此武器")
	_apply.disabled = item.is_empty() or current == null or (not same_weapon and not current.has_available_attachment_slot())
	_apply.tooltip_text = "当前武器没有空槽，请先卸下附魔" if current != null and not same_weapon and not current.has_available_attachment_slot() else ""
	_sell_item.disabled = item.is_empty() or not equipped.is_empty()
	_sell_item.tooltip_text = "先卸下，再出售" if not equipped.is_empty() else ""
	var selected_index := -1
	var attached := current.get_attached_item_instances() if current != null else []
	for index in attached.size():
		if str(attached[index].get("item_instance_id", "")) == selected_item_id: selected_index = index
	_move_left.disabled = selected_index <= 0
	_move_right.disabled = selected_index < 0 or selected_index >= attached.size() - 1
	if selected_index >= 0: _selection.text += " · 槽位 %02d" % (selected_index + 1)
	for container in [_inventory, _slots]:
		for child in container.get_children():
			if child is EnchantmentSlotCard:
				child.set_selected(not selected_item_id.is_empty() and str(child.item_instance.get("item_instance_id", "")) == selected_item_id)
			elif child is ItemInventoryCard:
				FinanceUIStyle.button(child, str(child.item_instance.get("item_instance_id", "")) == selected_item_id)


func _apply_selected() -> void:
	var item := flow.get_bound_player().item_inventory.find_item(selected_item_id)
	var same_weapon := str(item.get("equipped_weapon_id", "")) == selected_weapon_id
	_operate("detach" if same_weapon else "attach", selected_weapon_id, selected_item_id)


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
		feedback_requested.emit("此槽已有附魔，请先卸下，或将新附魔拖到空槽。", false)
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
		feedback_requested.emit("请先选择背包中的附魔。", false)
		return
	tooltip_hidden.emit()
	var result := flow.submit_enchantment_operation(action, weapon_id, item_id, target_index)
	var success := bool(result.get("success", false))
	var message := "附魔已卸下。其余附魔按顺序前移。" if action == "detach" else ("附魔排列已更新。" if action == "move" else "附魔配置已更新。")
	feedback_requested.emit(message if success else FinanceUIStyle.reason(str(result.get("reason", ""))), success)


func _item_card(item: Dictionary, parent: Control, width: float) -> ItemInventoryCard:
	var card := ItemInventoryCard.new()
	parent.add_child(card)
	card.configure(item, true)
	card.custom_minimum_size = Vector2(width, 42)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_constant_override("icon_max_width", 28)
	card.text = str(item.get("display_name", "附魔"))
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.focus_mode = Control.FOCUS_ALL
	FinanceUIStyle.button(card)
	card.item_tooltip_requested.connect(func(_anchor, content): tooltip_requested.emit(content))
	card.item_tooltip_hidden.connect(func(): tooltip_hidden.emit())
	return card


func _button(caption: String, parent: Control) -> Button:
	var control := Button.new()
	control.text = caption
	control.custom_minimum_size.y = 28
	FinanceUIStyle.button(control)
	parent.add_child(control)
	return control


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
