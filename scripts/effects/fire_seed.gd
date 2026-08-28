extends Node2D
class_name FireSeed

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const FIRE_PATCH_SCRIPT = preload("res://scripts/effects/fire_patch.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")

const MAX_VISUAL_SEEDS_PER_IMPACT: int = 4
const TRAIL_INTERVAL_SECONDS: float = 0.07

var _velocity: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _lifetime: float = 0.22
var _context: RefCounted = null
var _parent_root: Node = null
var _land_position: Vector2 = Vector2.ZERO
var _field_strength: float = 1.0
var _trail_timer: float = 0.0


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null:
		return
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "fire", {
		"damage": maxf(float(damage_event.damage) * 0.35, 1.0),
		"burn_damage": maxf(float(damage_event.damage) * 0.18, 1.0),
		"burn_duration": 2.4,
		"tick_interval": 0.25,
		"patch_duration": 2.0,
		"seed_count": 3.0,
	}, attachment_item_id)
	var seed_count := maxi(2, int(roundi(context.get_resolved_parameter("seed_count", 3.0) + context.get_resolved_parameter("projectile_count", 1.0))))
	var visual_seed_count := mini(seed_count, MAX_VISUAL_SEEDS_PER_IMPACT)
	var field_strength := float(seed_count) / float(visual_seed_count)
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	for index in visual_seed_count:
		var seed := FireSeed.new()
		parent.add_child(seed)
		seed.global_position = hit_position
		seed._parent_root = parent
		seed._context = context
		seed._field_strength = field_strength
		seed._land_position = hit_position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(8.0, 34.0)
		var launch_direction := safe_direction.rotated(randf_range(-PI * 0.8, PI * 0.8))
		seed._velocity = launch_direction * randf_range(30.0, 92.0) + Vector2(0.0, -randf_range(12.0, 52.0))
		seed._lifetime = randf_range(0.16, 0.30)


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	_velocity = _velocity.move_toward(Vector2.ZERO, 220.0 * delta)
	_velocity.y += 180.0 * delta
	global_position += _velocity * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = TRAIL_INTERVAL_SECONDS
		PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_spark", global_position, _velocity, 0.35, Color.TRANSPARENT, {
			"count_multiplier": 0.75,
			"lifetime_multiplier": 0.75,
		})
	if _elapsed >= _lifetime:
		FIRE_PATCH_SCRIPT.spawn(_parent_root, _land_position, _context, _field_strength)
		queue_free()
