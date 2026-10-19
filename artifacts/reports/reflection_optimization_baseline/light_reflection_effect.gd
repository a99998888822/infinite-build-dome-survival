extends Node2D
class_name LightReflectionEffect
const BAKED = preload("res://scripts/effects/baked_pixel_frames.gd")
const BLOCKS = preload("res://scripts/effects/reaction_block_visual.gd")

const DEFAULT_RADIUS: float = 220.0
const DEFAULT_DURATION: float = 0.58
const DEFAULT_DAMAGE_MULTIPLIER: float = 3.5
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const RASTER = preload("res://scripts/effects/reflection_pixel_batch.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")

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
var _candidate_revision: int = -1
var _candidate_hit_count: int = 0
var _candidate_indices := PackedInt32Array()
var _visual_tier := 0


static func spawn(parent: Node, origin: Vector2, direction: Vector2, damage_event: DamageEvent, radius: float = DEFAULT_RADIUS, damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER) -> void:
	if parent == null or damage_event == null:
		return
	var effect := LightReflectionEffect.new()
	parent.add_child(effect)
	effect.global_position = origin
	effect._orientation = direction.angle() if not direction.is_zero_approx() else 0.0
	effect._visual_detail = PIXEL.register(effect, "reflection")
	effect._visual_tier = preload("res://scripts/effects/effect_visual_budget.gd").claim_visual(parent, "reflection", origin)
	effect.z_index = 81
	effect._damage_event = damage_event
	effect._radius = maxf(radius, 48.0)
	effect._damage_multiplier = maxf(damage_multiplier, 1.0)
	AudioManager.play_reaction_sfx("reflection")
	effect.queue_redraw()


func _ready() -> void:
	_rects.setup(self)


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	_damage_sweep()
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func _damage_sweep() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var sweep_angle := lerpf(_sweep_start, _sweep_end, progress)
	var radius_squared := _radius * _radius
	var registry := EnemyRegistry.get_registered_enemies()
	var candidates := EnemyRegistry.candidates_in_radius(global_position, _radius)
	if candidates.size() * 2 > registry.size():
		_damage_sweep_dense()
		return
	_candidate_revision = -1
	var scan_origin := global_position
	var version := EnemyRegistry.spatial_revision
	for index in candidates:
		if _hit_targets.has(registry[index].get_instance_id()): continue
		var previous_hits := _hit_targets.size()
		_sweep_target(registry[index] as EnemyController, sweep_angle, radius_squared)
		if _hit_targets.size() != previous_hits and (EnemyRegistry.sync_spatial_revision() != version or global_position != scan_origin):
			var cursor := index + 1
			while cursor < registry.size():
				_sweep_target(registry[cursor] as EnemyController, sweep_angle, radius_squared)
				cursor += 1
			return


func _damage_sweep_dense() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var sweep_angle := lerpf(_sweep_start, _sweep_end, progress)
	var radius_squared := _radius * _radius
	var radius_with_slack := radius_squared + maxf(0.01, radius_squared * 0.000001)
	var registry := EnemyRegistry.get_registered_enemies()
	if _candidate_revision != EnemyRegistry.revision or _hit_targets.size() < _candidate_hit_count:
		_candidate_revision = EnemyRegistry.revision
		_candidate_indices.clear()
		for index in registry.size():
			var node := registry[index]
			if is_instance_valid(node) and not _hit_targets.has(node.get_instance_id()):
				_candidate_indices.append(index)
	# Compact in registry order, dropping only targets already hit by THIS beam.
	# Out-of-range and currently dead targets stay eligible for future scans.
	var remaining := 0
	for cursor in _candidate_indices.size():
		var index := _candidate_indices[cursor]
		var enemy := registry[index] as EnemyController
		if enemy == null: continue
		_candidate_indices[remaining] = index
		remaining += 1
		if not enemy.is_alive(): continue
		# Inline the common unhit path: no repeated dictionary lookup or helper
		# dispatch per target. Keep the original boundary/angle calculations.
		if global_position.distance_squared_to(enemy.global_position) > radius_with_slack: continue
		if global_position.distance_to(enemy.global_position) > _radius: continue
		var offset := global_position.direction_to(enemy.global_position)
		var angle := atan2(offset.y, offset.x) - _orientation
		while angle > PI: angle -= TAU
		while angle < -PI: angle += TAU
		if angle < _sweep_start or angle > sweep_angle: continue
		remaining -= 1
		_hit_targets[enemy.get_instance_id()] = true
		var damage := _damage_event.get_elemental_damage(_damage_multiplier)
		enemy.take_attack_damage(damage, _damage_event, false, offset)
		if _candidate_revision != EnemyRegistry.revision:
			# A damage callback may add/remove an enemy. Continue the live array at
			# the same index as the original iterator, including same-scan spawns.
			_candidate_revision = -1
			index += 1
			while index < registry.size():
				_sweep_target(registry[index] as EnemyController, sweep_angle, radius_squared)
				index += 1
			_candidate_hit_count = _hit_targets.size()
			return
	_candidate_indices.resize(remaining)
	_candidate_hit_count = _hit_targets.size()


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
