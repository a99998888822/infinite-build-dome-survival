extends Node2D
class_name CombatRenderWorld

## Shared visual host for one battle viewport. Simulation owners keep their
## existing nodes; rendering distinguishes ground, actor-local and foreground art.

# Grass stays behind actors. Legacy authored offsets are retained for ground art;
# new callers select a semantic final Z or join the actor-local sorting group.
const GROUND_Z := -256
const GROUND_DECALS_Z := -240
const GRASS_Z := -192
const EFFECT_BASE_Z := -128
const SHADOW_Z := -32
const TELEGRAPH_Z := -8
const BACK_Z := -4
const ATTACK_Z := 8
const BEAM_Z := 12
const STEAM_Z := 16
const IMPACT_Z := 24
const REACTION_Z := 28
const INFO_Z := 64


static func set_world_layer(item: CanvasItem, final_z: int) -> void:
	item.z_as_relative = false
	item.z_index = final_z


static func set_actor_local(item: CanvasItem) -> void:
	item.z_as_relative = true
	item.z_index = 0


static func set_effect_layer(item: CanvasItem, authored_layer: int) -> void:
	set_world_layer(item, EFFECT_BASE_Z + authored_layer)


func _ready() -> void:
	if not is_in_group("combat_render_world"):
		add_to_group("combat_render_world")
