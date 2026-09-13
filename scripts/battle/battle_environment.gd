extends CanvasLayer
class_name BattleEnvironment

@onready var floor: ColorRect = get_node_or_null("Floor")
@onready var crt_overlay: ColorRect = get_node_or_null("../BattleAmbience/CrtOverlay")


func _process(_delta: float) -> void:
	var player := _find_world_node("Player") as Node2D
	var wave_manager := _find_world_node("WaveManager")
	if floor != null and floor.material is ShaderMaterial:
		var floor_material := floor.material as ShaderMaterial
		if player != null:
			floor_material.set_shader_parameter("world_offset", player.global_position)
		floor_material.set_shader_parameter("time_seconds", Time.get_ticks_msec() / 1000.0)
		var wave_number := 1.0
		if wave_manager != null:
			wave_number = maxf(1.0, float(int(wave_manager.get("current_wave_index")) + 1))
		floor_material.set_shader_parameter("wave_index", wave_number)
		floor_material.set_shader_parameter("danger_level", clampf((wave_number - 1.0) / 8.0, 0.0, 1.0))
	if crt_overlay != null and crt_overlay.material is ShaderMaterial:
		(crt_overlay.material as ShaderMaterial).set_shader_parameter("time_seconds", Time.get_ticks_msec() / 1000.0)


func _find_world_node(node_name: String) -> Node:
	var local_node := get_node_or_null("../%s" % node_name)
	if local_node != null:
		return local_node
	var current: Node = self
	while current != null:
		if current is GameRoot:
			var world_root := (current as GameRoot).get_world_viewport_root()
			if world_root != null:
				var world_node := world_root.get_node_or_null(node_name)
				if world_node != null:
					return world_node
		current = current.get_parent()
	return null
