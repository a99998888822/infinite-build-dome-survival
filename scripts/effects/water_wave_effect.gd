extends Node2D
class_name WaterWaveEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
# Shared resources load with the effect script, before the first combat hit.
const ATLAS_RADIUS: float = 45.696
const ATLAS_TILE := 112
const ATLAS_COLUMNS := 8
const ATLAS_FRAMES := 52
const ATLASES: Array[Texture2D] = [
	preload("res://assets/sprites/effects/water_wave/water_d0_p0.png"),
	preload("res://assets/sprites/effects/water_wave/water_d0_p1.png"),
	preload("res://assets/sprites/effects/water_wave/water_d0_p2.png"),
	preload("res://assets/sprites/effects/water_wave/water_d0_p3.png"),
	preload("res://assets/sprites/effects/water_wave/water_d1_p0.png"),
	preload("res://assets/sprites/effects/water_wave/water_d1_p1.png"),
	preload("res://assets/sprites/effects/water_wave/water_d1_p2.png"),
	preload("res://assets/sprites/effects/water_wave/water_d1_p3.png"),
	preload("res://assets/sprites/effects/water_wave/water_d2_p0.png"),
	preload("res://assets/sprites/effects/water_wave/water_d2_p1.png"),
	preload("res://assets/sprites/effects/water_wave/water_d2_p2.png"),
	preload("res://assets/sprites/effects/water_wave/water_d2_p3.png"),
]

const DEFAULT_RADIUS: float = 33.0
const DEFAULT_DURATION: float = 0.85
const DEFAULT_DAMAGE_MULTIPLIER: float = 0.45
const SIZE_MULTIPLIER: float = 0.7
# Approved PNG footprint: 0.8 times the prior 0.85 scale, for art and collision.
const RADIUS_SCALE: float = 0.68

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _elapsed: float = 0.0
var _damage_applied: bool = false
var _visual_detail: int = 2
var _atlas_index := 0
var _atlas_frame := -1


static func spawn(
	parent: Node,
	hit_position: Vector2,
	weapon: WeaponInstance,
	damage_event: DamageEvent,
	attachment_item_id: String = ""
) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := WaterWaveEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._visual_detail = PIXEL.register(effect, "water")
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "water", {
		"radius": DEFAULT_RADIUS,
		"duration": DEFAULT_DURATION,
		"damage_multiplier": DEFAULT_DAMAGE_MULTIPLIER,
		"wet_duration": 5.0,
		"wet_slow_multiplier": 0.8,
	}, attachment_item_id)
	effect._radius = maxf(
		effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS)
			* effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0),
		32.0,
	) * SIZE_MULTIPLIER * RADIUS_SCALE
	effect._duration = maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.12)
	# Preserve the reviewed four phases and one random sample per spawned wave.
	var phase := randf_range(0.0, TAU)
	var phase_index := posmod(roundi(phase / TAU * 4.0), 4)
	effect._atlas_index = effect._visual_detail * 4 + phase_index
	# Apply contact synchronously so the following slot observes the wet state.
	effect._apply_wave()


func _ready() -> void:
	z_index = -8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	var frame := _get_atlas_frame()
	if frame != _atlas_frame:
		_atlas_frame = frame
		queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func _apply_wave() -> void:
	if _damage_applied or _context == null or _damage_event == null:
		return
	_damage_applied = true
	AudioManager.begin_combat_audio()
	AudioManager.play_enchantment_sfx("water")
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := get_world_2d().direct_space_state.intersect_shape(query, maxi(64, EnemyRegistry.get_registered_enemies().size()))
	var damage := _damage_event.get_elemental_damage(_context.get_resolved_parameter("damage_multiplier", DEFAULT_DAMAGE_MULTIPLIER))
	var wet_duration: float = _context.get_resolved_parameter("wet_duration", 5.0)
	var wet_slow_multiplier: float = _context.get_resolved_parameter("wet_slow_multiplier", 0.8)
	var handled: Dictionary = {}
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or handled.has(enemy.get_instance_id()):
			continue
		handled[enemy.get_instance_id()] = true
		ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "water", {
			"parent": get_parent(),
			"hit_position": enemy.global_position,
			"source_id": _damage_event.source_weapon_id,
			"damage": _damage_event.damage,
			"original_damage": _damage_event.get_elemental_base_damage(),
			"wet_duration": wet_duration,
			"wet_slow_multiplier": wet_slow_multiplier,
			"damage_event": _damage_event,
		})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
	AudioManager.end_combat_audio()


func _get_atlas_frame() -> int:
	return clampi(int(_elapsed / _duration * (ATLAS_FRAMES - 1) + 0.00001), 0, ATLAS_FRAMES - 1)


func _draw() -> void:
	var frame := _get_atlas_frame()
	var extent := Vector2.ONE * ATLAS_TILE * _radius / ATLAS_RADIUS
	var region := Rect2(Vector2((frame % ATLAS_COLUMNS) * ATLAS_TILE, (frame / ATLAS_COLUMNS) * ATLAS_TILE), Vector2.ONE * ATLAS_TILE)
	draw_texture_rect_region(ATLASES[_atlas_index], Rect2(-extent * 0.5, extent), region)
