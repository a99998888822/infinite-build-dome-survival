extends Area2D
class_name FirePatch

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")

var _context: RefCounted = null
var _remaining: float = 2.0
var _tick_timer: float = 0.0
var _visual_timer: float = 0.0
var _damage_event: DamageEvent = null


static func spawn(parent: Node, patch_position: Vector2, context: RefCounted) -> FirePatch:
	if parent == null:
		return null
	var patch := FirePatch.new()
	parent.add_child(patch)
	patch.global_position = patch_position
	patch._context = context
	patch._remaining = maxf(context.get_resolved_parameter("patch_duration", 2.0), 0.2) if context != null else 2.0
	var radius := 30.0
	if context != null:
		radius *= maxf(context.get_resolved_parameter("area_size_multiplier", 1.0), 0.25)
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle
	patch.add_child(collision_shape)
	patch.collision_layer = 0
	patch.collision_mask = 3
	patch.monitoring = true
	patch.monitorable = false
	return patch


func _ready() -> void:
	z_index = 42
	add_to_group("fire_patches")


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_remaining -= delta
	_tick_timer -= delta
	_visual_timer -= delta
	if _visual_timer <= 0.0:
		var emission_multiplier := _context.get_resolved_parameter("particle_rate", 1.0) if _context != null else 1.0
		_visual_timer = 0.055 / maxf(emission_multiplier, 0.2)
		var intensity := 0.8
		if _context != null:
			intensity = maxf(_context.get_resolved_parameter("intensity_multiplier", 1.0), 0.2)
		var flame_color := _context.get_tinted_color(Color(1.0, 0.55, 0.10, 1.0)) if _context != null else Color.TRANSPARENT
		PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_flame", global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-5.0, 5.0)), Vector2.UP, intensity, flame_color, {
			"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0) if _context != null else 1.0,
			"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0) if _context != null else 1.0,
			"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0) if _context != null else 1.0,
			"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0) if _context != null else 1.0,
			"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0) if _context != null else 1.0,
			"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0) if _context != null else 1.0,
		})
	if _tick_timer <= 0.0:
		var interval := _context.get_resolved_parameter("tick_interval", 0.25) if _context != null else 0.25
		_tick_timer = maxf(interval, 0.08)
		_apply_tick_damage()
	if _remaining <= 0.0:
		queue_free()


func _apply_tick_damage() -> void:
	var damage := 2
	var burn_damage := 1.0
	var burn_duration := 2.0
	if _context != null:
		damage = maxi(1, int(roundi(_context.get_resolved_parameter("damage", 2.0))))
		burn_damage = maxf(_context.get_resolved_parameter("burn_damage", 1.0), 1.0)
		burn_duration = maxf(_context.get_resolved_parameter("burn_duration", 2.0), 0.2)
	for body in get_overlapping_bodies():
		if body is EnemyController:
			var enemy := body as EnemyController
			if enemy.is_alive():
				enemy.apply_burning(burn_duration, burn_damage, "fire_patch")
				enemy.take_damage(damage, "fire_patch", false, Vector2.ZERO)
		elif body is PlayerController:
			var player := body as PlayerController
			player.take_damage(damage, "fire_patch")
