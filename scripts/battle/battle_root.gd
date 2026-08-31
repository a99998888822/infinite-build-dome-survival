extends Node
class_name BattleRoot

@onready var player: PlayerController = get_node_or_null("Player")
@onready var loadout: WeaponLoadout = get_node_or_null("Loadout")
@onready var wave_manager: WaveManager = get_node_or_null("WaveManager")
@onready var hud: CanvasLayer = get_node_or_null("HUD")
@onready var esc_overlay: EscOverlay = get_node_or_null("EscLayer/EscOverlay")
@onready var mobile_joystick: MobileJoystick = get_node_or_null("MobileControls/MobileJoystick")

var _main_flow_coordinator: MainFlowCoordinator = null
var _low_resolution_world_parent: Node2D = null
var _low_resolution_world_nodes: Array[Node] = []


func _ready() -> void:
	_attach_world_nodes_to_low_resolution_viewport()
	_bind_mobile_joystick()
	_bind_to_flow()


func _attach_world_nodes_to_low_resolution_viewport() -> void:
	var game_root := _find_game_root()
	if game_root == null:
		return
	_low_resolution_world_parent = game_root.get_world_viewport_root()
	if _low_resolution_world_parent == null:
		return
	for node in [get_node_or_null("ParticleLightField"), get_node_or_null("ParticleWorld"), get_node_or_null("DestructibleTestArea"), player, loadout, wave_manager]:
		if node == null or node.get_parent() == _low_resolution_world_parent:
			continue
		_low_resolution_world_nodes.append(node)
		node.reparent(_low_resolution_world_parent, false)


func restore_world_nodes() -> void:
	for node in _low_resolution_world_nodes:
		if is_instance_valid(node) and node.get_parent() != self:
			node.reparent(self, false)
	_low_resolution_world_nodes.clear()
	_low_resolution_world_parent = null


func _process(delta: float) -> void:
	if _main_flow_coordinator == null or loadout == null:
		return
	if _main_flow_coordinator.get_current_state() != MainFlowCoordinator.STATE_WAVE_COMBAT:
		return
	loadout.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("android"):
		return
	if _main_flow_coordinator == null:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE:
		return
	var state := _main_flow_coordinator.get_current_state()
	if state == MainFlowCoordinator.STATE_WAVE_COMBAT or state == MainFlowCoordinator.STATE_BATTLE_PREPARE:
		_main_flow_coordinator.request_esc_overlay()
	elif state == MainFlowCoordinator.STATE_ESC_OVERLAY:
		_main_flow_coordinator.close_esc_overlay()


func _bind_to_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		return
	_main_flow_coordinator = coordinator
	coordinator.bind_battle_context(player, loadout, wave_manager)
	if hud != null and hud.has_method("bind_context"):
		hud.bind_context(coordinator, player, wave_manager)
	if not coordinator.state_changed.is_connected(_on_flow_state_changed):
		coordinator.state_changed.connect(_on_flow_state_changed)
	if esc_overlay != null and not esc_overlay.back_pressed.is_connected(_on_esc_back_pressed):
		esc_overlay.back_pressed.connect(_on_esc_back_pressed)
	_apply_esc_overlay_visibility(coordinator.get_current_state())
	_apply_mobile_controls(coordinator.get_current_state())


func _on_flow_state_changed(_previous_state: String, current_state: String) -> void:
	_apply_esc_overlay_visibility(current_state)
	_apply_mobile_controls(current_state)


func _bind_mobile_joystick() -> void:
	if mobile_joystick == null:
		return
	if not mobile_joystick.direction_changed.is_connected(_on_mobile_joystick_direction_changed):
		mobile_joystick.direction_changed.connect(_on_mobile_joystick_direction_changed)
	mobile_joystick.set_touch_blocker_root(hud)
	mobile_joystick.set_mobile_input_enabled(false)


func _apply_mobile_controls(state: String) -> void:
	var should_enable := OS.has_feature("mobile") and state == MainFlowCoordinator.STATE_WAVE_COMBAT
	if mobile_joystick != null:
		mobile_joystick.set_mobile_input_enabled(should_enable)
	if not should_enable and player != null:
		player.set_mobile_move_direction(Vector2.ZERO)


func _on_mobile_joystick_direction_changed(direction: Vector2) -> void:
	if player == null:
		return
	var can_move := _main_flow_coordinator != null and _main_flow_coordinator.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT
	player.set_mobile_move_direction(direction if can_move else Vector2.ZERO)


func _apply_esc_overlay_visibility(state: String) -> void:
	if esc_overlay == null:
		return
	var should_show := state == MainFlowCoordinator.STATE_ESC_OVERLAY
	if should_show and _main_flow_coordinator != null and esc_overlay.has_method("configure"):
		esc_overlay.configure(_main_flow_coordinator.get_bound_player(), _main_flow_coordinator.get_bound_loadout())
	if should_show:
		esc_overlay.show_overlay()
	else:
		esc_overlay.hide_overlay()


func _on_esc_back_pressed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.close_esc_overlay()


func _find_game_root() -> GameRoot:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return current as GameRoot
		current = current.get_parent()
	return null


func _find_main_flow_coordinator() -> MainFlowCoordinator:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return (current as GameRoot).get_main_flow_coordinator()
		current = current.get_parent()
	return null
