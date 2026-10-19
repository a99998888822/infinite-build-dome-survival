extends Node2D
class_name SharedBaselineReflectionEffect
const BAKED = preload("res://scripts/effects/baked_pixel_frames.gd")
const BLOCKS = preload("res://scripts/effects/reaction_block_visual.gd")

const DEFAULT_RADIUS: float = 220.0
const DEFAULT_DURATION: float = 0.58
const DEFAULT_DAMAGE_MULTIPLIER: float = 3.5
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const RASTER = preload("res://scripts/effects/reflection_pixel_batch.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")
const QUERY_CACHE = preload("res://scripts/tests/fixtures/shared_baseline_reflection_query.gd")

var _rects := RASTER.new()

var _damage_event: DamageEvent = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER
var _elapsed: float = 0.0
var _hit_targets: Dictionary = {}
var _sweep_start: float = -PI * 0.5
var _sweep_end: float = PI * 0.5
var _orientation: float = 0.0
var _visual_detail: int = 2
var _visual_tier := 0


static func spawn(parent: Node, origin: Vector2, direction: Vector2, damage_event: DamageEvent, radius: float = DEFAULT_RADIUS, damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER) -> void:
	if parent == null or damage_event == null:
		return
	var effect := SharedBaselineReflectionEffect.new()
	parent.add_child(effect)
	effect.global_position = origin
	effect._orientation = direction.angle() if not direction.is_zero_approx() else 0.0
	effect._visual_tier = preload("res://scripts/effects/effect_visual_budget.gd").claim_visual(parent, "reflection", origin)
	if effect._visual_tier == 3:
		# Suppressed beams still count toward other effects' visual density.
		# Their own detail is never drawn, so no group-wide scan is needed.
		effect.set_meta("pixel_effect_kind", "reflection")
		effect.add_to_group(PIXEL.DETAIL_GROUP)
		effect._visual_detail = 0
	else:
		effect._visual_detail = PIXEL.register(effect, "reflection")
	effect.z_index = 81
	effect._damage_event = damage_event
	effect._radius = maxf(radius, 48.0)
	effect._damage_multiplier = maxf(damage_multiplier, 1.0)
	AudioManager.play_reaction_sfx("reflection")
	if effect._visual_tier != 3: effect.queue_redraw()


func _ready() -> void:
	_rects.setup(self)


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	_damage_sweep()
	if _visual_tier != 3: queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func _damage_sweep() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var sweep_angle := lerpf(_sweep_start, _sweep_end, progress)
	var radius_squared := _radius * _radius
	var origin := global_position
	var radius := _radius
	var orientation := _orientation
	var start_angle := _sweep_start
	var candidates := QUERY_CACHE.candidates(origin, radius, orientation, start_angle, sweep_angle)
	var registry := EnemyRegistry.get_registered_enemies()
	var revision := EnemyRegistry.revision
	var version := EnemyRegistry.spatial_revision
	for cursor in candidates.indices.size():
		var index: int = candidates.indices[cursor]
		var enemy := registry[index] as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		if _hit_targets.has(enemy.get_instance_id()): continue
		_hit_targets[enemy.get_instance_id()] = true
		var damage := _damage_event.get_elemental_damage(_damage_multiplier)
		enemy.take_attack_damage(damage, _damage_event, false, candidates.directions[cursor])
		if revision != EnemyRegistry.revision or version != EnemyRegistry.sync_spatial_revision() or origin != global_position or radius != _radius or orientation != _orientation or start_angle != _sweep_start:
			# Damage callbacks can move/spawn/remove targets or move this beam.
			# Finish in the legacy live registry order instead of a stale snapshot.
			index += 1
			while index < registry.size():
				_sweep_target(registry[index] as EnemyController, sweep_angle, radius_squared)
				index += 1
			return


func _sweep_target(enemy: EnemyController, sweep_angle: float, radius_squared: float) -> bool:
	if not is_instance_valid(enemy):
		return true
	if _hit_targets.has(enemy.get_instance_id()):
		return true
	if not enemy.is_alive():
		return false
	# Keep the original boundary and angle arithmetic, including near-boundary
	# distance_to, so moving targets retain their original first-hit timing.
	var distance_squared := global_position.distance_squared_to(enemy.global_position)
	if distance_squared > radius_squared + maxf(0.01, radius_squared * 0.000001):
		return false
	if global_position.distance_to(enemy.global_position) > _radius:
		return false
	var offset := global_position.direction_to(enemy.global_position)
	var angle := atan2(offset.y, offset.x) - _orientation
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	if angle < _sweep_start or angle > sweep_angle:
		return false
	_hit_targets[enemy.get_instance_id()] = true
	var damage := _damage_event.get_elemental_damage(_damage_multiplier)
	enemy.take_attack_damage(damage, _damage_event, false, offset)
	return true


func _draw() -> void:
	BAKED.ALIGNED.begin(self)
	if _visual_tier == 3: return
	var progress := clampf(_elapsed / _duration, 0, 1)
	var fade := 1.0 - progress * 0.72
	var angle := lerpf(_sweep_start, _sweep_end, progress) + _orientation
	if BLOCKS.enabled:
		BLOCKS.draw_reflection(self,_radius,_elapsed,_duration,angle,_visual_detail)
		return
	var direction := Vector2.from_angle(angle)
	draw_set_transform(Vector2.ZERO, angle)
	BAKED.draw_aligned(self,"reflection_beam",0,Vector2(_radius/220.0,1),Color(1,1,1,fade),Transform2D(angle,Vector2.ZERO))
	if _visual_detail > 0 and _visual_tier == 0: BAKED.draw_aligned(self,"reflection_sides",0,Vector2(_radius/220.0,1),Color(1,1,1,fade),Transform2D(angle,Vector2.ZERO))
	draw_set_transform(Vector2.ZERO)
	if _visual_tier >= 2: return
	_draw_png_shard( Vector2(0,-8), Vector2.UP, 38, 11, fade)
	_draw_png_star( direction * 16, 11, Color(0.93,1,0.92,fade))
	for index in (7 if _visual_detail > 0 and _visual_tier == 0 else 3):
		var trail_angle := lerpf(_sweep_start, angle - _orientation, float(index) / 7.0) + _orientation
		var axis := Vector2.from_angle(trail_angle)
		var point := axis * _radius * (0.24 + fmod(index * 0.137,0.6))
		_draw_png_shard( point, axis, 9,3,(0.7 if index % 2 == 0 else 0.6) * fade)


func _draw_png_shard(center: Vector2, direction: Vector2, length: float, width: float, fade: float) -> void:
	draw_set_transform(center, direction.angle())
	BAKED.draw_aligned(self,"shard",0,Vector2(length/38.0,width/11.0),Color(1,1,1,fade),Transform2D(direction.angle(),center),1.0)
	draw_set_transform(Vector2.ZERO)
func _draw_png_star(center: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(center)
	BAKED.draw_aligned(self,"star",0,Vector2.ONE*radius/11.0,color,Transform2D(0,center),1.0)
	draw_set_transform(Vector2.ZERO)
