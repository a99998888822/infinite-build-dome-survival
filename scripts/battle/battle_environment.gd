extends CanvasLayer
class_name BattleEnvironment

@onready var floor: ColorRect = get_node_or_null("Floor")
@onready var crt_overlay: ColorRect = get_node_or_null("../BattleAmbience/CrtOverlay")


func _process(_delta: float) -> void:
	var player := get_node_or_null("../Player") as Node2D
	if player != null and floor != null and floor.material is ShaderMaterial:
		(floor.material as ShaderMaterial).set_shader_parameter("world_offset", player.global_position)
	if crt_overlay != null and crt_overlay.material is ShaderMaterial:
		(crt_overlay.material as ShaderMaterial).set_shader_parameter("time_seconds", Time.get_ticks_msec() / 1000.0)
