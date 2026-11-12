extends Node2D
class_name FireSeed

const FIRE_VISUAL = preload("res://scripts/effects/pixel_fire_visual.gd")
const FIRE_PATCH_SCRIPT = preload("res://scripts/effects/fire_patch.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const VISUAL_BUDGET = preload("res://scripts/effects/effect_visual_budget.gd")

const MAX_VISUAL_SEEDS_PER_IMPACT: int = 4
## Flyaway sparks are the most numerous effect in a fire build. Parking spent
## seeds keeps their flame visual and batch slot alive, so a dense wave reuses
## nodes instead of building a new flame for every spark.
const POOL_META := &"_fire_seed_pool"
const POOL_LIMIT: int = 96

var _velocity: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _lifetime: float = 0.22
var _context: RefCounted = null
var _parent_root: Node = null
var _land_position: Vector2 = Vector2.ZERO
var _field_strength: float = 1.0
var _parked: bool = false


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null:
		return
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "fire", {
		"damage": maxf(damage_event.get_elemental_base_damage() * 0.35, 1.0),
		"original_damage": damage_event.get_elemental_base_damage(),
		"burn_duration": 3.0,
		"tick_interval": 0.25,
		"patch_duration": 3.0,
		"seed_count": 3.0,
	}, attachment_item_id)
	var seed_count := maxi(2, int(roundi(context.get_resolved_parameter("seed_count", 3.0) + context.get_resolved_parameter("projectile_count", 1.0))))
	context.set_meta("combat_audio_impact", AudioManager.current_combat_audio())
	# Dense fire keeps one seed instead of four. Fuel (`field_strength`) carries the
	# full burn damage into the patch, and nearby patches merge, so only the
	# quantity of flyaway sparks changes -- never the damage.
	var tier := VISUAL_BUDGET.claim_visual(parent, "fire_seed", hit_position)
	var visual_cap: int = [MAX_VISUAL_SEEDS_PER_IMPACT, 2, 1, 1][tier]
	var visual_seed_count := mini(seed_count, visual_cap)
	var field_strength := float(seed_count) / float(visual_seed_count)
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	for index in visual_seed_count:
		var seed := _acquire(parent)
		seed.global_position = hit_position
		seed._parent_root = parent
		seed._context = context
		seed._field_strength = field_strength
		seed._land_position = hit_position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(8.0, 34.0)
		var launch_direction := safe_direction.rotated(randf_range(-PI * 0.8, PI * 0.8))
		seed._velocity = launch_direction * randf_range(30.0, 92.0) + Vector2(0.0, -randf_range(80.0, 180.0))
		seed._lifetime = randf_range(0.34, 0.56)
		seed._elapsed = 0.0


static func _acquire(parent: Node) -> FireSeed:
	var pool: Array = parent.get_meta(POOL_META, [])
	var seed: FireSeed = null
	while seed == null and not pool.is_empty():
		var candidate = pool.pop_back()
		if is_instance_valid(candidate) and (candidate as FireSeed)._parked:
			seed = candidate as FireSeed
	if seed == null:
		seed = FireSeed.new()
		parent.add_child(seed)
	seed._parked = false
	seed.visible = true
	seed.set_process(true)
	return seed


func _ready() -> void:
	var visual := FIRE_VISUAL.new()
	add_child(visual)
	visual.setup_single(Vector2(14, 22), 2)


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	_velocity = _velocity.move_toward(Vector2.ZERO, 220.0 * delta)
	_velocity.y += 180.0 * delta
	global_position += _velocity * delta
	if _elapsed >= _lifetime:
		FIRE_PATCH_SCRIPT.spawn(_parent_root, _land_position, _context, _field_strength)
		_park()


## Returns the node to its parent's idle list instead of freeing it. The flame
## visual and its batch registration survive, so the next spark is free.
func _park() -> void:
	if _parked:
		return
	_velocity = Vector2.ZERO
	_elapsed = 0.0
	_context = null
	_parent_root = null
	_parked = true
	visible = false
	set_process(false)
	var parent := get_parent()
	if parent == null:
		queue_free()
		return
	var pool: Array = parent.get_meta(POOL_META, [])
	if pool.size() >= POOL_LIMIT:
		queue_free()
		return
	pool.append(self)
	parent.set_meta(POOL_META, pool)
