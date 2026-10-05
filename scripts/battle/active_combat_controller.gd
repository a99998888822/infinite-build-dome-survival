extends Node
class_name ActiveCombatController
## UI receives events first. Aim references the instance, never a stale slot index.
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var selected_weapon: WeaponInstance
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
	CombatSettings.settings_changed.connect(_settings_changed)
	loadout.loadout_changed.connect(clear_input)
	player.died.connect(clear_input)
	_settings_changed()

func _exit_tree() -> void:
	if is_instance_valid(indicator):
		indicator.queue_free()
	if is_instance_valid(marker):
		marker.queue_free()

func _settings_changed() -> void:
	player.keyboard_movement = CombatSettings.keyboard_movement
	clear_input()

func can_control() -> bool:
	return enabled and is_instance_valid(player) and player.alive and battle._main_flow_coordinator != null and battle._main_flow_coordinator.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))

func pointer_world() -> Vector2:
	# The world SubViewport and the UI may have different render sizes.
	var window := get_viewport()
	var world := player.get_viewport()
	var point := window.get_mouse_position() * world.get_visible_rect().size / window.get_visible_rect().size.max(Vector2.ONE)
	return world.get_canvas_transform().affine_inverse() * point

func _input(event: InputEvent) -> void:
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
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_aim()
			right_held = true
			if not player.keyboard_movement:
				player.request_move(pointer_world())
				marker.show_destination(player.move_destination)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and selected_weapon != null:
			if loadout.cast_weapon(selected_weapon, pointer_world()):
				cancel_aim()
			get_viewport().set_input_as_handled()

func select_slot(index: int) -> void:
	if not can_control() or index < 0 or index >= mini(10, loadout.weapon_instances.size()):
		return
	cancel_aim()
	var weapon := loadout.weapon_instances[index]
	if CombatSettings.quick_cast or weapon.is_copper_lamp() or weapon.is_ritual_tome():
		loadout.cast_weapon(weapon, pointer_world())
	else:
		selected_weapon = weapon
		_update_indicator()

func cancel_aim() -> bool:
	var had_aim := selected_weapon != null
	selected_weapon = null
	if is_instance_valid(indicator):
		indicator.hide()
	return had_aim

func clear_input() -> void:
	cancel_aim()
	stop_movement()

func stop_movement() -> void:
	# A stop order overrides held right-click movement without cancelling a cast.
	right_held = false
	if is_instance_valid(player):
		player._clear_move_input()
	if is_instance_valid(marker):
		marker.clear_destination()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_input()

func _process(_delta: float) -> void:
	if not can_control():
		return
	if right_held and not player.keyboard_movement:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == null or hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			player.request_move(pointer_world())
			if not marker.active:
				marker.show_destination(player.move_destination)
			marker.global_position = player.move_destination
	if not player.has_move_destination:
		marker.clear_destination()
	_update_indicator()

func _update_indicator() -> void:
	if selected_weapon == null:
		return
	if not loadout.weapon_instances.has(selected_weapon):
		cancel_aim()
		return
	indicator.global_position = player.global_position
	indicator.configure(selected_weapon, pointer_world() - player.global_position, loadout.active_casting.can_cast(selected_weapon))
	indicator.show()
