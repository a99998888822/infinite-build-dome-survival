extends Node
class_name TargetingService

@export var enemy_group_name: String = "enemies"


func find_nearest_enemy(origin: Vector2) -> Node2D:
	# 敌人模块完成前允许返回空，武器逻辑必须能安全跳过攻击。
	var nearest_enemy: Node2D = null
	var nearest_distance_sq := INF
	for node in get_tree().get_nodes_in_group(enemy_group_name):
		var enemy := node as Node2D
		if enemy == null or not enemy.is_inside_tree():
			continue
		var distance_sq := origin.distance_squared_to(enemy.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_enemy = enemy
	return nearest_enemy


func find_enemies_in_radius(origin: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq := radius * radius
	for node in get_tree().get_nodes_in_group(enemy_group_name):
		var enemy := node as Node2D
		if enemy != null and enemy.is_inside_tree() and origin.distance_squared_to(enemy.global_position) <= radius_sq:
			result.append(enemy)
	return result
