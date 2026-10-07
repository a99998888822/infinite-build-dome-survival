extends Node2D
class_name IceFieldEffect
const BAKED = preload("res://scripts/effects/baked_pixel_frames.gd")

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const FROST = preload("res://scripts/effects/frost_pattern.gd")
const DEFAULT_RADIUS := 51.2

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _elapsed: float = 0.0
var _radius: float = DEFAULT_RADIUS
var _lifetime: float = 1.8
var _maximum_radius: float = DEFAULT_RADIUS * 2.0
var _hit_targets: Dictionary = {}
var _scan_timer: float = 0.0
var _ground_shape := ConvexPolygonShape2D.new()
var _shape_radius := -1.0
var _visual_detail := 2
var _visual_frame := -1
var _query := PhysicsShapeQueryParameters2D.new()
var _excluded_bodies: Array[RID] = []

static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := IceFieldEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	PIXEL.register(effect, "ice")
	effect._visual_detail = 2
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "ice", {
		"damage": maxf(damage_event.get_elemental_base_damage() * 0.25, 1.0),
		"radius": DEFAULT_RADIUS,
		"duration": 3.0,
		"slow_multiplier": 0.6,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 12.8)
	effect._lifetime = maxf(effect._context.get_resolved_parameter("duration", 3.0), 0.2)
	effect._maximum_radius = effect._radius * 2.0
	AudioManager.begin_combat_audio()
	AudioManager.play_enchantment_sfx("ice")
	PARTICLE_WORLD_SCRIPT.emit_profile(parent, "ice_burst", hit_position, Vector2.ZERO, 0.6, Color(0.62, 0.80, 0.93, 0.55), {"count_multiplier": 0.3, "size_multiplier": 0.52})
	effect._damage_enemies()
	AudioManager.end_combat_audio()


func _ready() -> void:
	z_index = -6
	_query.shape = _ground_shape
	_query.collision_mask = 2
	_query.collide_with_bodies = true
	if not is_in_group("ice_fields"):
		add_to_group("ice_fields")


func expand_from_wind(radius_multiplier: float = 1.35) -> void:
	if _elapsed >= _lifetime or is_queued_for_deletion():
		return
	var previous := _radius
	_radius = maxf(_radius, minf(_maximum_radius, _radius * maxf(radius_multiplier, 1.0)))
	if _radius > previous:
		ELEMENT_REACTION_RESOLVER_SCRIPT.emit_feedback(get_parent(), "ice_expand", global_position, {"from_radius": previous, "radius": _radius})
		_damage_enemies()
	queue_redraw()

func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	_scan_timer -= delta
	if _scan_timer <= 0.0 and _elapsed < _lifetime:
		_scan_timer = 0.12
		_damage_enemies()
	# Crystal growth/fade needs 12 visual updates per second, independent of damage scans.
	var visual_frame := int(_elapsed * 12.0)
	if visual_frame != _visual_frame:
		_visual_frame = visual_frame
		queue_redraw()
	if _elapsed >= _lifetime:
		queue_free()

func _damage_enemies() -> void:
	AudioManager.begin_combat_audio()
	# Query the same projected ellipse that is painted on the tilted ground.
	# A cached convex outline avoids unsupported non-uniform circle scaling.
	if not is_equal_approx(_shape_radius, _radius):
		var outline := PackedVector2Array()
		for index in 48:
			outline.append(Vector2.from_angle(index * TAU / 48.0) * Vector2(1.0, FROST.GROUND_FLATTEN) * _radius)
		_ground_shape.points = outline
		_shape_radius = _radius
	_query.transform = Transform2D(0.0, global_position)
	var results := get_world_2d().direct_space_state.intersect_shape(_query, maxi(64, EnemyRegistry.get_registered_enemies().size()))
	var previous_excluded_count := _excluded_bodies.size()
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or _hit_targets.has(enemy.get_instance_id()):
			continue
		_hit_targets[enemy.get_instance_id()] = true
		# This field never hits the same body twice. Exclude it before the next
		# narrow-phase query, while retaining scans for newcomers and wind growth.
		_excluded_bodies.append(enemy.get_rid())
		ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "ice", {
			"parent": get_parent(),
			"hit_position": enemy.global_position,
			"source_id": _damage_event.source_weapon_id,
			"slow_duration": _context.get_resolved_parameter("duration", 3.0),
			"slow_multiplier": _context.get_resolved_parameter("slow_multiplier", 0.6),
			"freeze_duration": _context.get_resolved_parameter("freeze_duration", 1.0),
			"original_damage": _damage_event.get_elemental_base_damage(),
			"damage_event": _damage_event,
		})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
	if _excluded_bodies.size() != previous_excluded_count:
		_query.exclude = _excluded_bodies
	AudioManager.end_combat_audio()

func _draw() -> void:
	var fade := 1.0 - smoothstep(0.64, 1.0, clampf(_elapsed / _lifetime, 0.0, 1.0))
	BAKED.draw(self, "ice_d2", mini(36, int(_elapsed * 60.0)), Vector2.ONE * (_radius / DEFAULT_RADIUS), Color(1,1,1,fade))

