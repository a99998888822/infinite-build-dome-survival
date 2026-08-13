extends Node
class_name BattleRoot

@onready var player: PlayerController = get_node_or_null("Player")
@onready var loadout: WeaponLoadout = get_node_or_null("Loadout")
@onready var wave_manager: WaveManager = get_node_or_null("WaveManager")
@onready var hud: CanvasLayer = get_node_or_null("HUD")


func _ready() -> void:
	_bind_to_flow()


func _bind_to_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		return
	coordinator.bind_battle_context(player, loadout, wave_manager)
	if hud != null and hud.has_method("bind_context"):
		hud.bind_context(coordinator, player, wave_manager)


func _find_main_flow_coordinator() -> MainFlowCoordinator:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return (current as GameRoot).get_main_flow_coordinator()
		current = current.get_parent()
	return null
