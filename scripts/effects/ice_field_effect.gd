extends Node2D
class_name IceFieldEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const FROST = preload("res://scripts/effects/frost_pattern.gd")

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _elapsed: float = 0.0
var _radius: float = 64.0
var _lifetime: float = 1.8
var _maximum_radius: float = 128.0
var _hit_targets: Dictionary = {}
var _scan_timer: float = 0.0

static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := IceFieldEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "ice", {
		"damage": maxf(damage_event.get_elemental_base_damage() * 0.35, 1.0),
		"radius": 64.0,
		"duration": 3.0,
		"slow_multiplier": 0.45,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", 64.0) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 16.0)
	effect._lifetime = maxf(effect._context.get_resolved_parameter("duration", 3.0), 0.2)
	effect._maximum_radius = effect._radius * 2.0
	AudioManager.begin_combat_audio()
	AudioManager.play_enchantment_sfx("ice")
	PARTICLE_WORLD_SCRIPT.emit_profile(parent, "ice_burst", hit_position, Vector2.ZERO, 1.0, Color.TRANSPARENT, {"count_multiplier": 0.4, "size_multiplier": 0.65})
	effect._damage_enemies()
	AudioManager.end_combat_audio()


func _ready() -> void:
	z_index = -6
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
	queue_redraw()
	if _elapsed >= _lifetime:
		queue_free()

func _damage_enemies() -> void:
	AudioManager.begin_combat_audio()
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := get_world_2d().direct_space_state.intersect_shape(query, maxi(64, EnemyRegistry.get_registered_enemies().size()))
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or _hit_targets.has(enemy.get_instance_id()):
			continue
		_hit_targets[enemy.get_instance_id()] = true
		ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "ice", {
			"parent": get_parent(),
			"hit_position": enemy.global_position,
			"source_id": _damage_event.source_weapon_id,
			"slow_duration": _context.get_resolved_parameter("duration", 3.0),
			"slow_multiplier": _context.get_resolved_parameter("slow_multiplier", 0.45),
			"freeze_duration": _context.get_resolved_parameter("freeze_duration", 1.0),
			"original_damage": _damage_event.get_elemental_base_damage(),
			"damage_event": _damage_event,
		})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
	AudioManager.end_combat_audio()

func _draw() -> void:
	var progress := clampf(_elapsed / _lifetime, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.64, 1.0, progress)
	var growth := smoothstep(0.0, 0.42, _elapsed)
	PIXEL.ellipse(self, Vector2.ONE * _radius * growth, Color(0.24, 0.51, 0.63, 0.12 * fade))
	FROST.draw_crystal(self, Vector2.ZERO, _radius * 0.90, growth, fade, PI / 6.0)
	for index in 6:
		var angle := index * TAU / 6.0
		var center := Vector2.from_angle(angle) * _radius * 0.67
		var small_growth := smoothstep(0.12 + (index % 2) * 0.07, 0.60, _elapsed)
		FROST.draw_crystal(self, center, _radius * 0.23, small_growth, fade * 0.82, angle + PI / 6)
		var sparkle := 0.35 + 0.35 * sin(_elapsed * 4.0 + index * 1.7)
		PIXEL.block(self, center + Vector2(3, -3), Vector2(2, 2), Color(0.85, 0.97, 1.0, sparkle * fade * small_growth))
