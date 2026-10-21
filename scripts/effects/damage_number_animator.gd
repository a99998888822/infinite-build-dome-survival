extends Node
## One idle-tween clock preserves the original post-process animation phase.
## Labels inherit their parent's pause mode, as does this shared clock.
const META := &"_damage_number_animator"
const RISE_SECONDS := 0.62
const HOLD_SECONDS := 0.10
const FADE_SECONDS := 0.28
const LIFETIME := RISE_SECONDS + HOLD_SECONDS + FADE_SECONDS

class Batch:
	var age := 0.0
	var birth_frame := -1
	var has_critical := false
	var labels: Array[CombatDamageNumber] = []

var _batches: Array[Batch] = []
var _finished: Array[CombatDamageNumber] = []
var _flush_pending := false
var _clock: Tween
var _clock_age := 0.0
# Diagnostic view; the animation loop only traverses batches and live properties.
var _active: Array[CombatDamageNumber]:
	get:
		var result: Array[CombatDamageNumber] = []
		for batch in _batches:
			for label in batch.labels:
				if is_instance_valid(label) and label.active: result.append(label)
		return result

static func for_parent(parent: Node) -> Node:
	var animator: Node = parent.get_meta(META) if parent.has_meta(META) else null
	if is_instance_valid(animator): return animator
	animator = new()
	animator.name = "DamageNumberAnimator"
	parent.add_child(animator)
	parent.set_meta(META, animator)
	return animator

func animate(label: CombatDamageNumber, critical: bool) -> void:
	label.active = true
	label.origin = label.global_position
	label.critical = critical
	var frame := Engine.get_process_frames()
	var batch: Batch = _batches.back() if not _batches.is_empty() else null
	if batch == null or batch.birth_frame != frame or batch.age != 0.0:
		batch = Batch.new()
		batch.birth_frame = frame
		_batches.append(batch)
	batch.labels.append(label)
	batch.has_critical = batch.has_critical or critical
	if _clock == null or not _clock.is_valid():
		_clock_age = 0.0
		_clock = create_tween().set_loops()
		_clock.tween_method(_tick_clock, 0.0, 3600.0, 3600.0)

func _tick_clock(value: float) -> void:
	var delta := value - _clock_age if value >= _clock_age else value
	_clock_age = value
	advance(delta)
	if _batches.is_empty() and _clock != null:
		_clock.kill()
		_clock = null

func advance(delta: float) -> void:
	var write := 0
	for batch in _batches:
		var previous := batch.age
		batch.age += delta
		var age := batch.age
		var moving := previous < RISE_SECONDS
		var scaling := previous < 0.14
		var fading := previous < 0.10 or age >= RISE_SECONDS + HOLD_SECONDS
		var rise_offset := Vector2.ZERO
		var critical_offset := Vector2.ZERO
		var normal_scale := Vector2.ONE
		var critical_scale := Vector2.ONE
		if moving:
			var rise_age := minf(age, RISE_SECONDS)
			rise_offset = Vector2(0, -EnemyController.DAMAGE_NUMBER_RISE * rise_age / RISE_SECONDS)
			if batch.has_critical:
				var strength := maxf(1.0 - rise_age / EnemyController.DAMAGE_NUMBER_CRITICAL_SHAKE_SECONDS, 0.0)
				var shake := Vector2(sin(rise_age * TAU * 14.0) * 5.0, sin(rise_age * TAU * 19.0) * 2.0) * strength
				critical_offset = rise_offset + shake.round()
		if scaling:
			var progress := float(Tween.interpolate_value(0.0, 1.0, minf(age, 0.14), 0.14, Tween.TRANS_BACK, Tween.EASE_OUT))
			normal_scale = Vector2.ONE * lerpf(0.84, 1.0, progress)
			critical_scale = Vector2.ONE * lerpf(0.92, 1.0, progress)
		var alpha := maxf(0.0, 1.0 - (age - RISE_SECONDS - HOLD_SECONDS) / FADE_SECONDS) if age >= RISE_SECONDS + HOLD_SECONDS else minf(age / 0.10, 1.0)
		if moving or scaling or fading:
			for label in batch.labels:
				if not is_instance_valid(label) or not label.active: continue
				if moving: label.global_position = label.origin + (critical_offset if label.critical else rise_offset)
				if scaling: label.scale = critical_scale if label.critical else normal_scale
				if fading: label.modulate.a = alpha
		if age >= LIFETIME:
			_finished.append_array(batch.labels)
		else:
			_batches[write] = batch
			write += 1
	_batches.resize(write)
	if not _finished.is_empty() and not _flush_pending:
		_flush_pending = true
		_recycle_finished.call_deferred()

func _recycle_finished() -> void:
	_flush_pending = false
	for label in _finished:
		if is_instance_valid(label): EnemyController._recycle_damage_number(label)
	_finished.clear()

func _exit_tree() -> void:
	if _clock != null: _clock.kill()
	_clock = null
	_batches.clear()
	_finished.clear()
