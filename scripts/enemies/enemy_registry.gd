extends Node

var _registered_enemies: Array[Node] = []


func register_enemy(enemy: Node) -> void:
	if enemy == null or _registered_enemies.has(enemy):
		return
	_registered_enemies.append(enemy)


func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	_registered_enemies.erase(enemy)


func get_registered_enemies() -> Array[Node]:
	# Return the live backing array so hot-path queries do not allocate.
	return _registered_enemies
