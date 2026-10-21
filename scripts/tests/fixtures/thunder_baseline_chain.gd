extends "res://scripts/effects/lightning_particle_effect.gd"

func _find_farthest_enemy(origin: Vector2) -> EnemyController:
	var farthest: EnemyController = null
	var farthest_distance := -1.0
	var jump_radius_squared := _jump_radius * _jump_radius
	var registry := EnemyRegistry.get_registered_enemies()
	for index in EnemyRegistry.candidates_in_radius(origin, _jump_radius):
		var enemy := registry[index] as EnemyController
		if enemy == null or not enemy.is_alive() or _visited.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance <= jump_radius_squared and distance >= farthest_distance:
			farthest_distance = distance
			farthest = enemy
	return farthest


func _find_random_enemy(origin: Vector2) -> EnemyController:
	var candidates: Array[EnemyController] = []
	var jump_radius_squared := _jump_radius * _jump_radius
	var registry := EnemyRegistry.get_registered_enemies()
	for index in EnemyRegistry.candidates_in_radius(origin, _jump_radius):
		var enemy := registry[index] as EnemyController
		if enemy != null and enemy.is_alive() and not _visited.has(enemy.get_instance_id()) and origin.distance_squared_to(enemy.global_position) <= jump_radius_squared:
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi_range(0, candidates.size() - 1)]


