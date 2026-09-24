extends Node
class_name TargetingService

@export var enemy_group_name: String = "enemies"


func find_nearest_enemy(origin: Vector2) -> Node2D:
	# 敌人模块完成前允许返回空，武器逻辑必须能安全跳过攻击。
	return find_nearest_enemy_in_radius(origin, INF)


func find_nearest_enemy_in_radius(origin: Vector2, radius: float) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance_sq := INF
	var radius_sq := radius * radius
	for node in _get_enemy_candidates():
		var enemy := node as Node2D
		if enemy == null or not enemy.is_inside_tree():
			continue
		var distance_sq := origin.distance_squared_to(enemy.global_position)
		if distance_sq > radius_sq:
			continue
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_enemy = enemy
	return nearest_enemy


func find_enemies_in_radius(origin: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq := radius * radius
	for node in _get_enemy_candidates():
		var enemy := node as Node2D
		if enemy != null and enemy.is_inside_tree() and origin.distance_squared_to(enemy.global_position) <= radius_sq:
			result.append(enemy)
	return result


func _get_enemy_candidates() -> Array[Node]:
	if enemy_group_name == "enemies":
		return EnemyRegistry.get_registered_enemies()
	return get_tree().get_nodes_in_group(enemy_group_name)


func find_cluster_targets(origin: Vector2, attack_range: float, blast_radius: float, count: int) -> Array[Vector2]:
	# Build a spatial grid once per volley. Only adjacent cells can affect a
	# cluster score; never perform this search every animation frame.
	var grid: Dictionary = {}
	var candidates: Array[Vector2] = []
	var cell_size := maxf(1.0, blast_radius)
	for node in _get_enemy_candidates():
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or not enemy.is_inside_tree():
			continue
		var point := enemy.global_position
		if origin.distance_squared_to(point) > pow(attack_range + blast_radius, 2):
			continue
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(point)
		if origin.distance_squared_to(point) <= attack_range * attack_range:
			candidates.append(point)
	var ranked: Array[Dictionary] = []
	for point in candidates:
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		var score := 0
		for x in range(-1, 2):
			for y in range(-1, 2):
				for nearby: Vector2 in grid.get(cell + Vector2i(x, y), []):
					if point.distance_squared_to(nearby) <= blast_radius * blast_radius:
						score += 1
		ranked.append({"point": point, "score": score, "distance": origin.distance_squared_to(point)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.distance < b.distance if a.score == b.score else a.score > b.score)
	var targets: Array[Vector2] = []
	if ranked.is_empty():
		return targets
	for index in count:
		var chosen: Vector2 = ranked[0].point
		for candidate in ranked:
			var separate := true
			for previous in targets:
				if previous.distance_squared_to(candidate.point) < 4.0 * blast_radius * blast_radius:
					separate = false
					break
			if separate:
				chosen = candidate.point
				break
		targets.append(chosen)
	return targets
