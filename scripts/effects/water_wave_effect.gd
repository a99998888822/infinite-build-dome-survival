extends Node2D
class_name WaterWaveEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

const DEFAULT_RADIUS: float = 33.0
const DEFAULT_DURATION: float = 0.52
const DEFAULT_DAMAGE_MULTIPLIER: float = 0.55
const SIZE_MULTIPLIER: float = 0.7

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
	) * SIZE_MULTIPLIER
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
	var fade := 1.0 - smoothstep(0.55, 1.0, progress)
	# Damage is immediate over a circle. Show that full surface from the first
	# frame; only currents inside it grow and curl, never the damage footprint.
	_draw_surface(progress, fade)
	# Broad S-shaped wave fronts travel across the surface. Leave open water
	# between crests so the silhouette reads as flowing water at normal scale.
	var width := clampf(_radius * 0.09, 4.0, 8.0)
	var orientation := _phase * 0.18
	for stream in range(3 if _visual_detail > 0 else 2):
		var ribbon := PackedVector2Array()
		var foam := PackedVector2Array()
		var row := (float(stream) - 1.0) * 0.43
		for index in range(29):
			var u := float(index) / 28.0
			var x := lerpf(-0.78, 0.78, u)
			var bend := sin(u * TAU * 1.12 - progress * 6.5 + stream * 0.85)
			var y := row + (progress - 0.35) * 0.38 + bend * 0.12
			var point := (Vector2(x, y) * _radius).rotated(orientation)
			point = point.limit_length(maxf(_radius - width - 2.0, 0.0))
			ribbon.append(point)
			var lip := point + Vector2(0, -width * 0.45).rotated(orientation)
			foam.append(lip.limit_length(maxf(_radius - 3.0, 0.0)))
		PIXEL.path(self, ribbon, Color(0.035, 0.20, 0.29, fade * 0.78), width + 4.0)
		PIXEL.path(self, ribbon, Color(0.12, 0.49, 0.65, fade * 0.91), width)
		PIXEL.path(self, foam, Color(0.38, 0.77, 0.84, fade * 0.9), 2)
		# Broken foam highlights move along the crest rather than outlining it.
		for index in range(3, foam.size() - 2):
			if posmod(index + stream * 3 - int(progress * 14.0), 11) < 4:
				PIXEL.line(self, foam[index - 1], foam[index], Color(0.77, 0.95, 0.94, fade * 0.92), 2)
		if _visual_detail > 0:
			var head := ribbon[ribbon.size() - 4]
			var curl := PackedVector2Array()
			for index in range(13):
				var u := float(index) / 12.0
				var angle := -PI * 0.1 - u * PI * 1.55
				var curl_point := head + (Vector2(cos(angle), sin(angle)) * _radius * 0.12 * (1.0 - u * 0.72)).rotated(orientation)
				curl.append(curl_point.limit_length(maxf(_radius - 4.0, 0.0)))
			PIXEL.path(self, curl, Color(0.25, 0.65, 0.77, fade * 0.9), 4)
			PIXEL.path(self, curl, Color(0.65, 0.91, 0.92, fade * 0.92), 2)


func _draw_surface(progress: float, fade: float) -> void:
	PIXEL.ellipse(self, Vector2.ONE * _radius, Color(0.09, 0.42, 0.59, 0.22 * fade))
	var edge := PackedVector2Array()
	for index in range(49):
		var angle := float(index) * TAU / 48.0
		var inward_ripple := (0.5 + 0.5 * sin(angle * 6.0 - progress * 8.0 + _phase)) * 0.8
		edge.append(Vector2.from_angle(angle) * maxf(_radius - 2.0 - inward_ripple, 0.0))
	PIXEL.path(self, edge, Color(0.09, 0.38, 0.55, 0.38 * fade), 4)
	PIXEL.path(self, edge, Color(0.34, 0.73, 0.84, 0.50 * fade), 2)
	# Short foamy crests follow the boundary; they do not replace the currents.
	for index in 3:
		var angle := index * TAU / 3.0 - progress * 1.3 + _phase
		PIXEL.arc(self, maxf(_radius - 2.0, 0.0), angle, angle + 0.40, Color(0.69, 0.93, 0.95, 0.78 * fade), 2)


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
		point.y -= sin(age * PI) * (9.0 + float(index % 3) * 4.0) * SIZE_MULTIPLIER
		var fade := 1.0 - smoothstep(0.5, 1.0, age)
		PIXEL.block(_splash_layer, point, Vector2(2, 4 if age < 0.5 else 2), Color(0.4, 0.72, 0.8, fade * 0.9))
