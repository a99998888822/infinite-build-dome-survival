extends Node2D
class_name BlackHoleEffect
const BAKED = preload("res://scripts/effects/selected_spell_visual.gd")

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

const DEFAULT_RADIUS: float = 90.0
const DEFAULT_DURATION: float = 0.85
const DEFAULT_PULL_SPEED: float = 150.0
const DEFAULT_DARK_DURATION: float = 2.0
const SPHERE_FRACTION := 0.35
const DAMAGE_TO_SPHERE_RATIO := 3.0
const VISUAL_SPHERE_SCALE := 0.8

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _visual_reach := DEFAULT_RADIUS
var _sphere_radius := DEFAULT_RADIUS * SPHERE_FRACTION
var _duration: float = DEFAULT_DURATION
var _pull_speed: float = DEFAULT_PULL_SPEED
var _dark_duration: float = DEFAULT_DARK_DURATION
var _elapsed: float = 0.0
var _targets: Array[EnemyController] = []
var _visual_detail: int = 2
var _audio_impact: RefCounted = null
var _vortex_back: Node2D
var _vortex_front: Node2D
var _sorted_visual: Node2D
var _body_visual: Node2D
var _visual_frame := -1


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := BlackHoleEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._visual_detail = PIXEL.register(effect, "black_hole")
	effect._weapon = weapon
	effect._audio_impact = AudioManager.current_combat_audio()
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "black_hole", {
		"damage_multiplier": 0.45,
		"radius": DEFAULT_RADIUS,
		"duration": DEFAULT_DURATION,
		"pull_speed": DEFAULT_PULL_SPEED,
		"dark_duration": DEFAULT_DARK_DURATION,
	}, attachment_item_id)
	effect._visual_reach = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 24.0)
	effect._sphere_radius = effect._visual_reach * SPHERE_FRACTION
	effect._radius = effect._sphere_radius * DAMAGE_TO_SPHERE_RATIO
	effect._duration = StatDefinitions.calculate_control_duration(maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.1), effect._context.get_resolved_parameter("control_power", 0.0))
	effect._pull_speed = maxf(effect._context.get_resolved_parameter("pull_speed", DEFAULT_PULL_SPEED), 1.0)
	effect._dark_duration = maxf(effect._context.get_resolved_parameter("dark_duration", DEFAULT_DARK_DURATION), 0.1)
	effect.call_deferred("_arm")


func _ready() -> void:
	_sorted_visual = preload("res://scripts/effects/combat_sorted_visual.gd").attach(self)
	_vortex_back = Node2D.new()
	_body_visual = Node2D.new()
	_body_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vortex_front = Node2D.new()
	for surface in [_vortex_back, _body_visual, _vortex_front]:
		_sorted_visual.add_child(surface)
	_body_visual.draw.connect(_draw_body)
	queue_redraw()


func _arm() -> void:
	AudioManager.begin_combat_audio(_audio_impact)
	AudioManager.play_enchantment_sfx("black_hole")
	_collect_targets()
	FirePatch.tint_nearby_fields(get_tree(), global_position, _radius, 2, ELEMENT_REACTION_RESOLVER_SCRIPT.DARK_FLAME_DURATION)
	AudioManager.end_combat_audio()
	_audio_impact = null


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	for enemy in _targets:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if delta > 0.0 and _pull_speed > 0.0 and not enemy.is_movement_locked() and not enemy.global_position.is_equal_approx(global_position) and enemy.can_receive_control():
			enemy.global_position = enemy.global_position.move_toward(global_position, _pull_speed * delta * enemy.get_control_multiplier())
	if _elapsed >= _duration:
		queue_free()
		return
	var frame := int(_elapsed*18.0)
	if frame != _visual_frame:
		_visual_frame = frame
		_body_visual.queue_redraw()


func _collect_targets() -> void:
	if _context == null or _damage_event == null:
		return
	var damage := _damage_event.get_elemental_damage(_context.get_resolved_parameter("damage_multiplier", 0.45))
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var handled: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or handled.has(enemy.get_instance_id()):
			continue
		handled[enemy.get_instance_id()] = true
		_targets.append(enemy)
		var had_light := enemy.has_status("light")
		if had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
				"damage_event": _damage_event,
			})
		enemy.take_attack_damage(damage, _damage_event, false, global_position.direction_to(enemy.global_position))
		if not had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
				"damage_event": _damage_event,
			})


func _draw_body() -> void:
	var t := BAKED.hole_time(_elapsed,_duration)
	if t<0.0:
		BAKED.draw(_body_visual,"hole_steady",fposmod(_elapsed-0.56,2.0),Vector2.ONE*(_visual_reach/DEFAULT_RADIUS))
	else:
		BAKED.draw(_body_visual,"hole_r03",t,Vector2.ONE*(_visual_reach/DEFAULT_RADIUS))
