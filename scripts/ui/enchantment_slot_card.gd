extends ItemInventoryCard
class_name EnchantmentSlotCard

signal slot_drop_requested(slot_index: int, item_id: String)
var slot_index := 0
var _number: Label
var _state: Label
var _art: TextureRect
var _empty_mark: Label
var _caption: Label


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(136, 82)
	focus_mode = Control.FOCUS_ALL
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 8
	body.offset_right = -8
	body.offset_top = 5
	body.offset_bottom = -5
	body.add_theme_constant_override("separation", 2)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(header)
	_number = Label.new()
	_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FinanceUIStyle.label(_number, 12, FinanceUIStyle.GOLD)
	header.add_child(_number)
	_state = Label.new()
	FinanceUIStyle.label(_state, 11, FinanceUIStyle.MUTED)
	header.add_child(_state)
	var image_area := Control.new()
	image_area.custom_minimum_size.y = 34
	image_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(image_area)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_area.add_child(_art)
	_empty_mark = Label.new()
	_empty_mark.text = "+"
	_empty_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	FinanceUIStyle.label(_empty_mark, 26, FinanceUIStyle.MUTED)
	image_area.add_child(_empty_mark)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(_caption, 12)
	body.add_child(_caption)
	for label in [_number, _state, _empty_mark, _caption]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure_slot(index: int, item: Dictionary) -> void:
	slot_index = index
	item_instance = item.duplicate(true)
	drag_enabled = not item.is_empty()
	_number.text = "槽位 %02d" % (index + 1)
	_state.text = "已装备" if drag_enabled else "空槽"
	_art.texture = FinanceUIStyle.item_icon(str(item.get("icon", "")), "augmentations", str(item.get("base_item_id", "")))
	_empty_mark.visible = not drag_enabled
	_caption.text = str(item.get("display_name", "点击 / 拖入附魔"))
	tooltip_text = "" if drag_enabled else "选中背包附魔后点击，或拖入。新附魔接在已有附魔后。"
	set_selected(false)


func set_selected(selected: bool) -> void:
	FinanceUIStyle.button(self, selected)
	var normal := FinanceUIStyle.box("3a4933" if selected else ("1a241e" if drag_enabled else "20231d"), "d8ba74" if selected else ("89946a" if drag_enabled else "665f48"), 0)
	normal.set_border_width_all(2)
	add_theme_stylebox_override("normal", normal)
	var hover := FinanceUIStyle.box("3c4c35", "dbbd79", 0)
	hover.set_border_width_all(2)
	add_theme_stylebox_override("hover", hover)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("type", "")) == "augmentation_item"


func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(Vector2.ZERO, data):
		slot_drop_requested.emit(slot_index, str(data.get("item_instance_id", "")))
