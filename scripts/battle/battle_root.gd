extends Node
class_name BattleRoot

@onready var player: PlayerController = get_node_or_null("Player")
@onready var loadout: WeaponLoadout = get_node_or_null("Loadout")
@onready var wave_manager: WaveManager = get_node_or_null("WaveManager")
@onready var hud: CanvasLayer = get_node_or_null("HUD")
@onready var esc_overlay: EscOverlay = get_node_or_null("EscLayer/EscOverlay")

var _main_flow_coordinator: MainFlowCoordinator = null


func _ready() -> void:
	_bind_to_flow()


func _process(delta: float) -> void:
	if _main_flow_coordinator == null or loadout == null:
		return
	if _main_flow_coordinator.get_current_state() != MainFlowCoordinator.STATE_WAVE_COMBAT:
		return
	loadout.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
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


func _on_flow_state_changed(_previous_state: String, current_state: String) -> void:
	_apply_esc_overlay_visibility(current_state)


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


func _find_main_flow_coordinator() -> MainFlowCoordinator:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return (current as GameRoot).get_main_flow_coordinator()
		current = current.get_parent()
	return null
