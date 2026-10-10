extends Node2D
class_name WindBladeEffect
const PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ATLAS = preload("res://assets/sprites/effects/wind_blade.png")
const FRAME_SIZE := Vector2(128, 96)
const FRAME_COUNT := 12

const DEFAULT_SPEED: float = 480.0
const DEFAULT_LIFETIME: float = 0.46
const DEFAULT_RADIUS: float = 28.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = DEFAULT_SPEED
var _lifetime: float = DEFAULT_LIFETIME
var _elapsed: float = 0.0
var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _damage_multiplier := 0.7
var _hit_radius := DEFAULT_RADIUS * 0.5
var _area_scale := 1.0
var _knockback_speed := 450.0
var _knockback_duration := 0.3
var _hit_targets: Dictionary = {}
var _ground_contact := Callable()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func spawn(parent: Node, hit_position: Vector2, direction: Vector2, speed: float = DEFAULT_SPEED, lifetime: float = DEFAULT_LIFETIME, weapon: WeaponInstance = null, damage_event: DamageEvent = null, ignored_target_id: int = 0, ground_contact: Callable = Callable(), attachment_item_id: String = "") -> void:
	if parent == null:
		return
	var effect := WindBladeEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	effect._speed = maxf(speed, 1.0)
	effect._lifetime = maxf(lifetime, 0.1)
	effect._weapon = weapon
	effect._damage_event = damage_event
	if weapon != null:
		var context := PARAMETERS.build_weapon_context(weapon, "wind", {"damage_multiplier": 0.7, "knockback_speed": 450.0, "knockback_duration": 0.3}, attachment_item_id)
		effect._damage_multiplier = context.get_resolved_parameter("damage_multiplier", 0.7)
		effect._area_scale = maxf(0.01, context.get_resolved_parameter("damage_area_size_multiplier", 1))
		effect._hit_radius = maxf(StatDefinitions.calculate_attack_radius(float(weapon.weapon_data.get("hit_radius", 0)), weapon.get_stat("area_size")), DEFAULT_RADIUS * 0.5) * effect._area_scale
		effect._knockback_speed = context.get_resolved_parameter("knockback_speed", 450)
		effect._knockback_duration = context.get_resolved_parameter("knockback_duration", 0.3)
	effect._ground_contact = ground_contact
	if ignored_target_id > 0:
		effect._hit_targets[ignored_target_id] = true
	effect.rotation = effect._direction.angle()
	AudioManager.play_enchantment_sfx("wind")


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	global_position += _direction * _speed * delta
	_damage_path_enemies()
	queue_redraw()
	if _elapsed >= _lifetime:
		queue_free()


func _damage_path_enemies() -> void:
	if _weapon == null or _damage_event == null:
		return
	var radius_squared := _hit_radius * _hit_radius
	var wind_damage := _damage_event.get_elemental_damage(_damage_multiplier)
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or _hit_targets.has(enemy.get_instance_id()):
			continue
		if global_position.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		_hit_targets[enemy.get_instance_id()] = true
		if _ground_contact.is_valid():
			_ground_contact.call(enemy)
			continue
		if enemy.can_be_pushed_by_wind():
			enemy.apply_knockback(_direction, _knockback_speed, _knockback_duration, _weapon.get_stat("control_power"))
		else:
			enemy.show_control_resistance()
		enemy.take_damage(wind_damage, _damage_event.source_weapon_id, false, _direction if enemy.can_be_pushed_by_wind() else Vector2.ZERO)


func _draw() -> void:
	var progress := clampf(_elapsed / _lifetime, 0.0, 1.0)
	var frame := mini(int(progress * FRAME_COUNT), FRAME_COUNT - 1)
	var size := FRAME_SIZE * _area_scale
	# Rotation still belongs to the moving node; only the visual extent scales.
	draw_texture_rect_region(ATLAS, Rect2(-size * 0.5, size), Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE))
