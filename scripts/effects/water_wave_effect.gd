extends Node2D
class_name WaterWaveEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

const DEFAULT_RADIUS: float = 33.0
const DEFAULT_DURATION: float = 0.52
const DEFAULT_DAMAGE_MULTIPLIER: float = 0.55

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _elapsed: float = 0.0
var _damage_applied: bool = false
var _phase: float = 0.0
var _visual_detail: int = 2
var _splash_layer: Node2D


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
	)
	effect._duration = maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.12)
	effect._phase = randf_range(0.0, TAU)
	# Water is an immediate contact effect, before ice in the impact dispatcher.
	effect._apply_wave()


func _ready() -> void:
	z_index = -8
	_splash_layer = PIXEL.layer(self, 80, _draw_splashes)
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	queue_redraw()
	_splash_layer.queue_redraw()
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


func _draw() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var radius := maxf(_radius * smoothstep(0.0, 1.0, progress), 2.0)
	var fade := 1.0 - smoothstep(0.56, 1.0, progress)
	var clock := floorf(_elapsed * 18.0) / 18.0
	# The damage is immediate: briefly mark its full footprint from the first frame.
	if progress < 0.22 and _visual_detail > 0:
		for index in range(12):
			var start := float(index) * TAU / 12.0 + _phase
			PIXEL.arc(self, _radius, start, start + 0.12, Color(0.17, 0.37, 0.46, (1.0 - progress / 0.22) * 0.34))
	var count := 18 if _visual_detail == 2 else (12 if _visual_detail == 1 else 8)
	for index in range(count):
		var start := float(index) * TAU / float(count) + _phase * 0.08
		var arc_length := TAU / float(count) * (0.48 + float(index % 3) * 0.07)
		var ripple := sin(start * 7.0 + _phase + clock * 4.0) * radius * 0.024
		var crest := radius + ripple
		PIXEL.arc(self, maxf(crest - 3.0, 2.0), start, start + arc_length, Color(0.10, 0.29, 0.40, fade * 0.72), 4)
		PIXEL.arc(self, crest, start, start + arc_length, Color(0.25, 0.61, 0.73, fade * 0.82), 2)
		if index % 2 == 0 and _visual_detail > 0:
			PIXEL.arc(self, crest + 1.0, start + 0.04, start + arc_length * 0.5, Color(0.65, 0.85, 0.86, fade * 0.85), 2)
			if radius > 12.0:
				var foam := Vector2.from_angle(start + arc_length * 0.5) * (crest - 2.0)
				PIXEL.block(self, foam, Vector2(4, 2), Color(0.52, 0.79, 0.83, fade * 0.8))
		if _visual_detail == 2 and radius > 24.0 and index % 3 == 0:
			PIXEL.arc(self, radius * 0.77, start + 0.14, start + 0.26, Color(0.14, 0.39, 0.48, fade * 0.55), 2)


func _draw_splashes() -> void:
	if _visual_detail == 0:
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var count := 9 if _visual_detail == 2 else 4
	for index in range(count):
		var start := float(index % 3) * 0.07
		var age := (progress - start) / 0.76
		if age < 0.0 or age >= 1.0:
			continue
		var angle := float(index) * 2.399 + _phase
		var distance := _radius * (0.12 + age * (0.62 + float(index % 2) * 0.14))
		var point := Vector2.from_angle(angle) * distance
		point.y -= sin(age * PI) * (9.0 + float(index % 3) * 4.0)
		var fade := 1.0 - smoothstep(0.5, 1.0, age)
		PIXEL.block(_splash_layer, point, Vector2(2, 4 if age < 0.5 else 2), Color(0.4, 0.72, 0.8, fade * 0.9))
