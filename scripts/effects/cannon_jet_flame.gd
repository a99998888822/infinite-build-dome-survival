extends "res://scripts/effects/copper_lamp_flame.gd"
## Shares the lamp's cached flow noise, with a short forward-moving jet shader.
const JET_SHADER = preload("res://shaders/effects/cannon_jet_flame.gdshader")
const LIFETIME := 0.28
var weapon: WeaponInstance
var heading := Vector2.RIGHT
var age := 0.0
var cancelled := false


static func spawn(parent: Node, source: WeaponInstance, point: Vector2, direction: Vector2) -> Node2D:
	var effect := new()
	effect.weapon = source
	effect.heading = direction
	effect.flame_material.shader = JET_SHADER
	effect.flame_material.set_shader_parameter("flow_noise", flow_texture)
	parent.add_child(effect)
	effect.global_position = point
	CombatRenderWorld.set_world_layer(effect, CombatRenderWorld.IMPACT_Z)
	effect.add_to_group("weapon_runtime_effects")
	effect._sync_jet()
	return effect


func _sync_jet() -> void:
	configure(heading, weapon.get_attack_range() * 1.25, 56.0, age, false)
	flame_material.set_shader_parameter("opacity", 1.0)


func _physics_process(delta: float) -> void:
	if cancelled: return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	age += delta
	if age >= LIFETIME:
		cancel()
		return
	_sync_jet()


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()
