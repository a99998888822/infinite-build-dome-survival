extends Node2D
class_name WindBladeEffect
const PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const BLOCK_VFX = preload("res://scripts/effects/enchantment_block_vfx.gd")
const FOOTPRINT = preload("res://scripts/effects/spell_footprint.gd")

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
var _hit_radius := FOOTPRINT.WIND_RADIUS
var _area_scale := 1.0
var _knockback_speed := 450.0
var _knockback_duration := 0.3
var _hit_targets: Dictionary = {}
var _ground_contact := Callable()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	CombatRenderWorld.set_effect_layer(self, 78)


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
		# One reviewed circle for this spell, independent of its source weapon.
		effect._hit_radius = FOOTPRINT.WIND_RADIUS * effect._area_scale
		effect._knockback_speed = context.get_resolved_parameter("knockback_speed", 450)
		effect._knockback_duration = context.get_resolved_parameter("knockback_duration", 0.3)
	effect._ground_contact = ground_contact
	if ignored_target_id > 0:
		effect._hit_targets[ignored_target_id] = true
	# Direction is evaluated inside the fixed pixel grid, not by rotating it.
	effect.rotation = 0.0
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
	var registry := EnemyRegistry.get_registered_enemies()
	var candidates := EnemyRegistry.candidates_in_radius(global_position, _hit_radius)
	var scan_origin := global_position
	var version := EnemyRegistry.spatial_revision
	for index in candidates:
		if not _damage_target(registry[index] as EnemyController, radius_squared, wind_damage): continue
		if EnemyRegistry.sync_spatial_revision() != version or global_position != scan_origin:
			# A callback can teleport/spawn/reparent a later target. Continue the
			# original live-array iterator from the same next index in that case.
			var cursor := index + 1
			while cursor < registry.size():
				_damage_target(registry[cursor] as EnemyController, radius_squared, wind_damage)
				cursor += 1
			return


func _damage_target(enemy: EnemyController, radius_squared: float, wind_damage: int) -> bool:
	if enemy == null or not enemy.is_alive() or _hit_targets.has(enemy.get_instance_id()): return false
	if global_position.distance_squared_to(enemy.global_position) > radius_squared: return false
	_hit_targets[enemy.get_instance_id()] = true
	if _ground_contact.is_valid():
		_ground_contact.call(enemy)
		return true
	if enemy.can_be_pushed_by_wind():
		enemy.apply_knockback(_direction, _knockback_speed, _knockback_duration, _weapon.get_stat("control_power"))
	else:
		enemy.show_control_resistance()
	enemy.take_attack_damage(wind_damage, _damage_event, false, _direction if enemy.can_be_pushed_by_wind() else Vector2.ZERO)
	return true


func _draw() -> void:
	var progress := clampf(_elapsed / _lifetime, 0.0, 1.0)
	BLOCK_VFX.paint(self,5,Rect2(Vector2(-124,-124)*_area_scale,Vector2(248,248)*_area_scale),_area_scale,_elapsed,progress)
	material.set_shader_parameter("direction",_direction)
