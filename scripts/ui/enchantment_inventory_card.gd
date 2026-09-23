extends ItemInventoryCard
class_name EnchantmentInventoryCard

const CARD_SIZE := Vector2(112, 28)
const INSPECT_ICON: Texture2D = preload("res://assets/ui/finance/inspect_enchantment.svg")
var _art: TextureRect
var _caption: Label
var _inspect: TextureRect


func _ready() -> void:
	super._ready()
	var body := HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 4
	body.offset_right = -4
	body.offset_top = 4
	body.offset_bottom = -4
	body.add_theme_constant_override("separation", 3)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(20, 20)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_art)
	_caption = Label.new()
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FinanceUIStyle.label(_caption, 11)
	body.add_child(_caption)
	_inspect = TextureRect.new()
	_inspect.texture = INSPECT_ICON
	_inspect.custom_minimum_size = Vector2(16, 16)
	_inspect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_inspect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inspect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inspect.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect.mouse_default_cursor_shape = Control.CURSOR_HELP
	body.add_child(_inspect)
	_inspect.mouse_entered.connect(func():
		if not item_instance.is_empty(): item_tooltip_requested.emit(self, _build_tooltip())
	)
	_inspect.mouse_exited.connect(func(): item_tooltip_hidden.emit())
	visibility_changed.connect(func():
		if not is_visible_in_tree(): item_tooltip_hidden.emit()
	)


func configure(next_item: Dictionary, allow_drag: bool = true) -> void:
	super.configure(next_item, allow_drag)
	icon = null
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_ALL
	_art.texture = FinanceUIStyle.item_icon(str(item_instance.get("icon", "")), "augmentations", str(item_instance.get("base_item_id", "")))
	_caption.text = str(item_instance.get("display_name", "附魔"))
	FinanceUIStyle.button(self)


func _on_mouse_entered() -> void:
	# Only the magnifying glass opens details; the card remains a selection/drag target.
	pass
