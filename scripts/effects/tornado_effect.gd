extends Node2D
class_name TornadoEffect

const VISUAL = preload("res://scripts/effects/tornado_visual.gd")
const PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const REACTIONS = preload("res://scripts/effects/element_reaction_resolver.gd")
const FOOTPRINT = preload("res://scripts/effects/spell_footprint.gd")

class Layer extends Node2D:
	var effect: Node2D
	var front := false
	func _draw() -> void:
		VISUAL.draw_layer(self, effect.element, front, effect.age, Vector2.ZERO, effect.area_scale, VISUAL.opacity_at(effect.age))

var element := "air"
var age := 0.0
var area_scale := 1.0
var direction := Vector2.RIGHT
var speed := 48.0
var radius := 42.0
var duration := 3.0
var interval := 0.5
var multiplier := 0.25
var _tick := 0.0
var _event: DamageEvent
var _layers: Array[Node2D] = []

static func spawn(parent: Node, point: Vector2, heading: Vector2, weapon: WeaponInstance, event: DamageEvent, item_id := "") -> TornadoEffect:
	if parent == null or weapon == null or event == null: return null
	var effect := TornadoEffect.new()
	var context := PARAMETERS.build_weapon_context(weapon, "tornado", {
		"duration": 3.0, "speed": 48.0, "radius": 42.0,
		"tick_interval": 0.5, "damage_multiplier": 0.25}, item_id)
	effect.area_scale = maxf(0.1, context.get_resolved_parameter("damage_area_size_multiplier", 1.0))
	effect.radius = maxf(1.0, context.get_resolved_parameter("radius", 42.0)) * effect.area_scale
	effect.speed = maxf(0.0, context.get_resolved_parameter("speed", 48.0))
	effect.duration = clampf(context.get_resolved_parameter("duration", 3.0), 0.1, VISUAL.LIFETIME)
	effect.interval = maxf(0.1, context.get_resolved_parameter("tick_interval", 0.5))
	effect.multiplier = maxf(0.0, context.get_resolved_parameter("damage_multiplier", 0.25))
	effect.direction = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	effect._event = event.duplicate_event()
	parent.add_child(effect)
	effect.global_position = point
	AudioManager.play_enchantment_sfx("wind")
	return effect

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("tornado_effects")
	for front in [false, true]:
		var layer := Layer.new()
		layer.effect = self
		layer.front = front
		CombatRenderWorld.set_world_layer(layer, CombatRenderWorld.ATTACK_Z if front else CombatRenderWorld.BACK_Z)
		add_child(layer)
		_layers.append(layer)

func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	if age >= duration: return
	var step := minf(delta, duration - age)
	global_position += direction * speed * step
	_absorb_field()
	age += step
	# Six contacts at 0, 0.5, ... 2.5; expiry never adds a seventh tick.
	while _tick < age and _tick < duration - 0.00001:
		_damage_enemies()
		_tick += interval
	for layer in _layers: layer.queue_redraw()
	if age >= duration: queue_free()

func _absorb_field() -> void:
	# The first live field encountered fixes the form for the remaining lifetime.
	if element != "air": return
	for group in ["fire_patches", "ice_fields"]:
		for field in get_tree().get_nodes_in_group(group):
			if field.get_parent() != get_parent() or field.is_queued_for_deletion(): continue
			if group == "fire_patches" and field._remaining <= 0.0: continue
			if group == "ice_fields" and field._elapsed >= field._lifetime: continue
			var axes: Vector2 = field.get_terminal_footprint_axes()
			if FOOTPRINT.contains(axes, global_position - field.global_position):
				element = "fire" if group == "fire_patches" else "ice"
				return

func _damage_enemies() -> void:
	# Snapshot membership: reactions may kill or spawn enemies during this tick.
	var targets := EnemyRegistry.get_registered_enemies().duplicate()
	AudioManager.begin_combat_audio()
	for node in targets:
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		if enemy.get_world_2d() != get_world_2d(): continue
		if not FOOTPRINT.contains(FOOTPRINT.axes(radius), enemy.global_position - global_position): continue
		if element != "air":
			REACTIONS.apply_element(enemy, element, {
				"parent": get_parent(), "hit_position": enemy.global_position,
				"source_id": _event.source_weapon_id, "damage_event": _event,
				"original_damage": _event.get_elemental_base_damage(),
				"control_power": _event.control_power})
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.take_attack_damage(_event.get_elemental_damage(multiplier), _event, false, direction)
	AudioManager.end_combat_audio()
