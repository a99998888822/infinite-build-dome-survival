extends Container
class_name NativeHudBox
## Box layout in native canvas units. Fractional margins must survive layout;
## integer rounding at every nested box otherwise accumulates visible drift.

@export var vertical := false
@export var separation := 0.0:
	set(value):
		separation = value
		update_minimum_size()
		queue_sort()
@export var alignment := BoxContainer.ALIGNMENT_BEGIN


func _enter_tree() -> void:
	if not child_entered_tree.is_connected(_watch_child):
		child_entered_tree.connect(_watch_child)
		child_exiting_tree.connect(_unwatch_child)
	for child in get_children(): _watch_child(child)


func _watch_child(child: Node) -> void:
	if not child is Control: return
	if not child.minimum_size_changed.is_connected(_invalidate):
		child.minimum_size_changed.connect(_invalidate)
		child.visibility_changed.connect(_invalidate)
	_invalidate()


func _unwatch_child(child: Node) -> void:
	if child is Control and child.minimum_size_changed.is_connected(_invalidate):
		child.minimum_size_changed.disconnect(_invalidate)
		child.visibility_changed.disconnect(_invalidate)
	_invalidate.call_deferred()


func _invalidate() -> void:
	update_minimum_size()
	queue_sort()


func bind_scroll(scroll: ScrollContainer) -> void:
	# ScrollContainer caches its content extent in its minimum-size pass.
	var refresh := func():
		scroll.update_minimum_size()
		scroll.get_minimum_size()
		scroll.queue_sort()
	resized.connect(refresh)
	minimum_size_changed.connect(refresh)
	refresh.call_deferred()


static func horizontal(gap := 0.0) -> NativeHudBox:
	var box := NativeHudBox.new()
	box.separation = gap
	return box


static func column(gap := 0.0) -> NativeHudBox:
	var box := horizontal(gap)
	box.vertical = true
	return box


func _controls() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children():
		if child is Control and child.visible and not child.is_set_as_top_level(): result.append(child)
	return result


func _get_minimum_size() -> Vector2:
	var axis := 1 if vertical else 0
	var minimum := Vector2.ZERO
	var controls := _controls()
	for child in controls:
		var extent := child.get_combined_minimum_size()
		minimum[axis] += extent[axis]
		minimum[1 - axis] = maxf(minimum[1 - axis], extent[1 - axis])
	minimum[axis] += separation * maxi(0, controls.size() - 1)
	return minimum


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN: return
	var controls := _controls()
	var axis := 1 if vertical else 0
	var extra := maxf(0.0, size[axis] - _get_minimum_size()[axis])
	var stretch := 0.0
	for child in controls:
		var flags := child.size_flags_vertical if vertical else child.size_flags_horizontal
		if flags & Control.SIZE_EXPAND: stretch += child.size_flags_stretch_ratio
	var cursor := 0.0
	if is_zero_approx(stretch):
		if alignment == BoxContainer.ALIGNMENT_CENTER: cursor = extra * 0.5
		elif alignment == BoxContainer.ALIGNMENT_END: cursor = extra
	for child in controls:
		var minimum := child.get_combined_minimum_size()
		var extent := minimum
		var point := Vector2.ZERO
		var along := child.size_flags_vertical if vertical else child.size_flags_horizontal
		var across := child.size_flags_horizontal if vertical else child.size_flags_vertical
		var slot := minimum[axis]
		if along & Control.SIZE_EXPAND and stretch > 0: slot += extra * child.size_flags_stretch_ratio / stretch
		point[axis] = cursor
		if along & Control.SIZE_FILL: extent[axis] = slot
		elif along & Control.SIZE_SHRINK_CENTER: point[axis] += (slot - minimum[axis]) * 0.5
		elif along & Control.SIZE_SHRINK_END: point[axis] += slot - minimum[axis]
		if across & Control.SIZE_FILL: extent[1 - axis] = maxf(minimum[1 - axis], size[1 - axis])
		elif across & Control.SIZE_SHRINK_CENTER: point[1 - axis] = (size[1 - axis] - minimum[1 - axis]) * 0.5
		elif across & Control.SIZE_SHRINK_END: point[1 - axis] = size[1 - axis] - minimum[1 - axis]
		child.position = point
		child.size = extent
		cursor += slot + separation
