extends Node
class_name ActiveCombatController
## UI receives events first. Aim references the instance, never a stale slot index.
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var selected_weapon: WeaponInstance
var current_weapon: WeaponInstance
var current_slot := 0
var cursor_icon: CursorWeaponIcon
var _cursor_layer: CanvasLayer
var _pointer_position := Vector2.ZERO
var _marker_pointer_position := Vector2.ZERO
var _has_pointer_position := false
var indicator: WeaponAttackIndicator
var marker: MoveDestinationMarker
var enabled := true
var right_held := false

func initialize(context: BattleRoot) -> void:
	battle = context
	player = battle.player
	loadout = battle.loadout
	player.active_controls = true
	loadout.set_active_combat_enabled(true)
	indicator = WeaponAttackIndicator.new()
	marker = MoveDestinationMarker.new()
	player.get_parent().add_child(indicator)
	player.get_parent().add_child(marker)
	indicator.hide()
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.layer = 40
	add_child(_cursor_layer)
	cursor_icon = CursorWeaponIcon.new()
	cursor_icon.name = "CurrentWeaponCursor"
	_cursor_layer.add_child(cursor_icon)
	CombatSettings.settings_changed.connect(_settings_changed)
	loadout.loadout_changed.connect(_on_loadout_changed)
	player.died.connect(clear_input)
	_settings_changed()

func _exit_tree() -> void:
	if is_instance_valid(indicator):
		indicator.queue_free()
	if is_instance_valid(marker):
		marker.queue_free()

func _settings_changed() -> void:
	var movement_changed := player.keyboard_movement != CombatSettings.keyboard_movement
	player.keyboard_movement = CombatSettings.keyboard_movement
	if movement_changed: clear_input()
	else: cancel_aim()
	loadout.active_casting.mobility_planner.reset_intent()
	_sync_current_weapon()

func mouse_weapon_controls() -> bool:
	return CombatSettings.keyboard_movement

func _sync_current_weapon() -> void:
	var count := mini(10, loadout.weapon_instances.size())
	if count == 0:
		current_weapon = null
		current_slot = 0
		return
	var index := loadout.weapon_instances.find(current_weapon)
	if index >= 0 and index < count and not CombatSettings.is_weapon_automatic(current_weapon):
		current_slot = index
		return
	for offset in count:
		var slot := posmod(current_slot + offset, count)
		if not CombatSettings.is_weapon_automatic(loadout.weapon_instances[slot]):
			current_slot = slot
			current_weapon = loadout.weapon_instances[slot]
			return
	current_weapon = null

func _on_loadout_changed() -> void:
	clear_input()
	_sync_current_weapon()

func cycle_weapon(direction: int) -> void:
	if not mouse_weapon_controls() or not can_control(): return
	_sync_current_weapon()
	var count := mini(10, loadout.weapon_instances.size())
	if count == 0: return
	var aiming := selected_weapon != null
	if current_weapon == null: return
	for offset in range(1, count + 1):
		var slot := posmod(current_slot + direction * offset, count)
		if not CombatSettings.is_weapon_automatic(loadout.weapon_instances[slot]):
			current_slot = slot
			current_weapon = loadout.weapon_instances[slot]
			break
	if aiming:
		selected_weapon = current_weapon
		_update_indicator()
	_update_cursor_icon()

func can_control() -> bool:
	return enabled and is_instance_valid(player) and player.alive and battle._main_flow_coordinator != null and battle._main_flow_coordinator.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))

func pointer_world() -> Vector2:
	# The world SubViewport and the UI may have different render sizes.
	var window := get_viewport()
	var world := player.get_viewport()
	var pointer := _pointer_position if _has_pointer_position else window.get_mouse_position()
	var point := pointer * world.get_visible_rect().size / window.get_visible_rect().size.max(Vector2.ONE)
	return world.get_canvas_transform().affine_inverse() * point

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion or event is InputEventMouseButton) and get_viewport().get_visible_rect().has_point(event.position):
		_pointer_position = event.position
		_has_pointer_position = true
	# Releases must reach us even when the pointer has moved onto a HUD control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		right_held = false

func _unhandled_input(event: InputEvent) -> void:
	if not can_control():
		return
	if event is InputEventKey and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_S and not player.keyboard_movement:
			if event.pressed:
				stop_movement()
			get_viewport().set_input_as_handled()
			return
		if player.accept_move_key(event):
			get_viewport().set_input_as_handled()
		if not event.pressed:
			return
		if code >= KEY_1 and code <= KEY_9:
			select_slot(code - KEY_1)
			get_viewport().set_input_as_handled()
		elif code == KEY_0:
			select_slot(9)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if mouse_weapon_controls() and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if not _pointer_over_ui():
				cycle_weapon(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and mouse_weapon_controls():
			_mouse_weapon_click()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_aim()
			right_held = true
			if not player.keyboard_movement:
				player.request_move(pointer_world())
				marker.show_destination(player.move_destination)
				_marker_pointer_position = _pointer_position
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and selected_weapon != null:
			if loadout.cast_weapon(selected_weapon, pointer_world()):
				cancel_aim()
			get_viewport().set_input_as_handled()

func _mouse_weapon_click() -> void:
	_sync_current_weapon()
	if selected_weapon != null:
		if loadout.cast_weapon(selected_weapon, pointer_world()): cancel_aim()
	elif current_weapon == null:
		return
	elif CombatSettings.quick_cast or current_weapon.is_return_ready():
		if loadout.cast_weapon(current_weapon, pointer_world()): cancel_aim()
	else:
		selected_weapon = current_weapon
		_update_indicator()
	_update_cursor_icon()

func select_slot(index: int) -> void:
	if not can_control() or index < 0 or index >= mini(10, loadout.weapon_instances.size()):
		return
	var weapon := loadout.weapon_instances[index]
	if CombatSettings.is_weapon_automatic(weapon) and not weapon.is_mobility_weapon(): return
	cancel_aim()
	if weapon.is_return_ready():
		loadout.cast_weapon(weapon, pointer_world())
		return
	if not CombatSettings.is_weapon_automatic(weapon):
		current_slot = index
		current_weapon = weapon
	if CombatSettings.quick_cast:
		loadout.cast_weapon(weapon, pointer_world())
	else:
		selected_weapon = weapon
		_update_indicator()
	_update_cursor_icon()

func cancel_aim() -> bool:
	var had_aim := selected_weapon != null
	selected_weapon = null
	if loadout != null: loadout.active_casting.manual_aiming = false
	if is_instance_valid(indicator):
		indicator.hide()
	return had_aim

func clear_input() -> void:
	cancel_aim()
	stop_movement()
	if is_instance_valid(cursor_icon): cursor_icon.hide()

func stop_movement() -> void:
	# A stop order overrides held right-click movement without cancelling a cast.
	right_held = false
	if loadout != null: loadout.active_casting.mobility_planner.reset_intent()
	if is_instance_valid(player):
		player._clear_move_input()
	if is_instance_valid(marker):
		marker.clear_destination()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_pointer_position = false
		clear_input()

func _process(_delta: float) -> void:
	_update_cursor_icon()
	if not can_control():
		return
	if right_held and not player.keyboard_movement:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == null or hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			player.request_move(pointer_world())
			# Camera follow changes world coordinates even with a stationary mouse.
			# Replay an expired cue only for new pointer intent, not camera motion.
			if not marker.active and _marker_pointer_position.distance_squared_to(_pointer_position) > 4.0:
				marker.show_destination(player.move_destination)
				_marker_pointer_position = _pointer_position
			marker.global_position = player.move_destination
	if not player.has_move_destination:
		marker.clear_destination()
	_update_indicator()

func _update_cursor_icon() -> void:
	if not is_instance_valid(cursor_icon): return
	if not mouse_weapon_controls() or not can_control() or not _has_pointer_position or _pointer_over_ui():
		cursor_icon.hide()
		return
	_sync_current_weapon()
	var shown_weapon := selected_weapon if selected_weapon != null else current_weapon
	if shown_weapon == null:
		cursor_icon.hide()
		return
	cursor_icon.update_weapon(shown_weapon, selected_weapon != null, loadout.active_casting.can_cast(shown_weapon))
	cursor_icon.follow_pointer(_pointer_position, get_viewport().get_visible_rect().size)
	cursor_icon.show()

func _pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _update_indicator() -> void:
	loadout.active_casting.manual_aiming = selected_weapon != null
	if selected_weapon == null:
		return
	if not loadout.weapon_instances.has(selected_weapon):
		cancel_aim()
		return
	indicator.global_position = player.global_position
	var offset := pointer_world() - player.global_position
	if selected_weapon.is_copper_lamp():
		var target := loadout.active_casting._auto_target(selected_weapon)
		if target == null:
			indicator.hide()
			return
		offset = target.global_position - selected_weapon.get_attack_origin()
	indicator.configure(selected_weapon, offset, loadout.active_casting.can_cast(selected_weapon))
	indicator.show()
