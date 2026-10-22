extends Node2D
class_name ElectricSparkEffect

const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/effects/lightning_particle_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const WARNING_SPRITE = preload("res://scripts/effects/electric_spark_warning_sprite.gd")
const FOOTPRINT = preload("res://scripts/effects/spell_footprint.gd")
const GROUND_AREA = preload("res://scripts/effects/spell_ground_area.gd")

const ACTIVATION_DELAY_SECONDS: float = 0.5
const RING_FADE_SECONDS: float = 0.28
const DEFAULT_RADIUS: float = 20.0
const DAMAGE_RADIUS_MULTIPLIER: float = 1.5
const DEFAULT_STRIKE_HEIGHT: float = 182.0
const PARTICLE_ROWS: int = 3
const PARTICLES_PER_ROW: int = 8
const BODY_RADIUS: Vector2 = Vector2(23.0, 14.0)
const PARTICLE_SIZE: Vector2 = Vector2(3.0, 2.0)

var _warning_sprite: MultiMeshInstance2D = null
var _ground_area: Node2D

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _hit_position: Vector2 = Vector2.ZERO
var _attachment_item_id: String = ""
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _ring_radius: float = DEFAULT_RADIUS
var _elapsed: float = 0.0
var _struck: bool = false
var _strike_landed: bool = false
var _ring_fade_start_elapsed: float = 0.0
var _visual_count: int = 24


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := ElectricSparkEffect.new()
	var tier := preload("res://scripts/effects/effect_visual_budget.gd").claim_visual(parent, "lightning_warning", hit_position)
	effect._visual_count = [24, 12, 4, 0][tier]
	parent.add_child(effect)
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._hit_position = hit_position
	effect._attachment_item_id = attachment_item_id
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "electric_spark", {
		"radius": DEFAULT_RADIUS,
		"strike_height": DEFAULT_STRIKE_HEIGHT,
	}, attachment_item_id)
	effect._radius = maxf(
		effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS)
			* effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0),
		18.0,
	) * DAMAGE_RADIUS_MULTIPLIER
	effect._ring_radius = effect._radius
	effect.global_position = hit_position
	effect.call_deferred("_arm")


func _arm() -> void:
	if _context == null:
		queue_free()
		return
	AudioManager.play_combat_sfx("spark_charge")
	_sync_warning()


func _ready() -> void:
	_ground_area = GROUND_AREA.new()
	add_child(_ground_area)
	if _visual_count > 0:
		_warning_sprite = WARNING_SPRITE.new()
		add_child(_warning_sprite)
		_warning_sprite.set_density(_visual_count)
	add_to_group("combat_particle_counters")
	CombatRenderWorld.set_effect_layer(self, 81)
	_sync_warning()


func get_active_particle_count() -> int:
	return _visual_count


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	if not _struck and _elapsed >= ACTIVATION_DELAY_SECONDS:
		_struck = true
		_trigger_strike()
	if _strike_landed and _elapsed >= _ring_fade_start_elapsed + RING_FADE_SECONDS:
		queue_free()
		return
	_sync_warning()


func _trigger_strike() -> void:
	if _context == null or _weapon == null or _damage_event == null:
		_on_ground_strike_landed()
		return
	var strike_height := maxf(_context.get_resolved_parameter("strike_height", DEFAULT_STRIKE_HEIGHT), 96.0)
	var strike_effect := LIGHTNING_EFFECT_SCRIPT.spawn_ground_strike(
		get_parent(),
		_hit_position,
		_weapon,
		_damage_event,
		_attachment_item_id,
		strike_height,
		_radius,
	)
	if strike_effect == null:
		_on_ground_strike_landed()
		return
	strike_effect.ground_strike_landed.connect(_on_ground_strike_landed, CONNECT_ONE_SHOT)


func _on_ground_strike_landed() -> void:
	if _strike_landed:
		return
	_strike_landed = true
	_ring_fade_start_elapsed = _elapsed


func _sync_warning() -> void:
	var fade := 1.0
	if _strike_landed:
		fade = 1.0 - clampf((_elapsed - _ring_fade_start_elapsed) / RING_FADE_SECONDS, 0.0, 1.0)
	if _ground_area != null:
		_ground_area.setup(get_terminal_footprint_axes(), Color(0.8,0.56,0.06,0.12), Color(1.0,0.86,0.24,0.7), 1.0, fade)
	if _warning_sprite != null:
		_warning_sprite.sync(_elapsed, _radius, fade)

func get_terminal_footprint_axes() -> Vector2:
	return FOOTPRINT.axes(_radius)
