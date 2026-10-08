extends Sprite2D
class_name MobilityAtlasEffect
## Shared imported PNGs. One sprite per effect, no procedural particles or polygons.
const CLIPS := {
	"dash_trail": [preload("res://assets/sprites/weapons/mobility/dash_trail.png"), Vector2(128,64), 8, 24.0, Vector2(118,32)],
	"dash_circle": [preload("res://assets/sprites/weapons/mobility/dash_circle.png"), Vector2(160,160), 10, 48.0, Vector2(80,80)],
	"muzzle": [preload("res://assets/sprites/weapons/mobility/muzzle.png"), Vector2(96,64), 6, 30.0, Vector2(6,32)],
	"pellet_hit": [preload("res://assets/sprites/weapons/mobility/pellet_hit.png"), Vector2(64,64), 6, 24.0, Vector2(32,32)],
	"recoil_dust": [preload("res://assets/sprites/weapons/mobility/recoil_dust.png"), Vector2(128,64), 8, 20.0, Vector2(64,32)],
	"star_depart": [preload("res://assets/sprites/weapons/mobility/star_depart.png"), Vector2(96,128), 8, 24.0, Vector2(48,64)],
	"star_arrive": [preload("res://assets/sprites/weapons/mobility/star_arrive.png"), Vector2(96,128), 8, 24.0, Vector2(48,64)],
	"star_return": [preload("res://assets/sprites/weapons/mobility/star_return.png"), Vector2(96,128), 8, 24.0, Vector2(48,64)],
	"star_shockwave": [preload("res://assets/sprites/weapons/mobility/star_shockwave.png"), Vector2(160,160), 10, 24.0, Vector2(80,80)],
	"star_anchor": [preload("res://assets/sprites/weapons/mobility/star_anchor.png"), Vector2(128,128), 12, 12.0, Vector2(64,64)],
}
var weapon: WeaponInstance
var cancelled := false
var looping := false
var age := 0.0
var clip: Array
var follow: WeakRef

static func spawn(parent: Node, source: WeaponInstance, key: String, point: Vector2, angle: float = 0.0, dimensions: Vector2 = Vector2.ONE, loop: bool = false) -> MobilityAtlasEffect:
	var effect := MobilityAtlasEffect.new()
	effect.weapon = source
	effect.clip = CLIPS[key]
	effect.texture = effect.clip[0]
	effect.hframes = effect.clip[2]
	effect.offset = effect.clip[1] * 0.5 - effect.clip[4]
	effect.looping = loop
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.z_index = -2 if key in ["dash_circle", "star_shockwave", "star_anchor", "recoil_dust"] else 40
	parent.add_child(effect)
	effect.add_to_group("weapon_runtime_effects")
	effect.global_position = point
	effect.rotation = angle
	effect.scale = dimensions
	return effect

func _physics_process(delta: float) -> void:
	if cancelled: return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	age += delta
	var next := int(age * float(clip[3]))
	if not looping and next >= hframes:
		cancel()
		return
	if follow != null and is_instance_valid(follow.get_ref()):
		global_position = follow.get_ref().global_position
	next %= hframes
	if frame != next: frame = next

func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()
