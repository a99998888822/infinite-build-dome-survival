extends RefCounted
class_name PlayerActionAnimator
## Visual-only actions. Movement and collision remain on PlayerController.
const PIXEL_MINIFY = preload("res://shaders/player/pixel_minify.gdshader")

var enabled := false
var current_clip := "idle"
var current_frame := 0
var action := ""
var facing_direction := Vector2.ZERO
var _elapsed := 0.0
var _move_time := 0.0
var _hold_time := 0.0
var _moving := false
var _sprite: Sprite2D
var _clips: Dictionary = {}
var _sustains: Array[Dictionary] = []
var _minify_material: ShaderMaterial


func configure(sprite: Sprite2D, visuals: Dictionary) -> void:
	_sprite = sprite
	enabled = false
	_clips.clear()
	reset()
	if sprite == null:
		return
	if sprite.material == _minify_material:
		sprite.material = null
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	var path := str(visuals.get("action_animations", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	for key: String in parsed.get("clips", {}):
		var clip: Dictionary = parsed.clips[key].duplicate(true)
		var texture_path := str(clip.get("texture", ""))
		if not ResourceLoader.exists(texture_path):
			push_error("[PlayerActionAnimator] missing texture: " + texture_path)
			return
		clip.texture = load(texture_path) as Texture2D
		_clips[key] = clip
	enabled = _clips.has_all(["idle", "move", "attack", "move_attack", "sustain", "move_sustain", "jump_forward", "jump_backward"])
	if not enabled:
		return
	if bool(visuals.get("preserve_pixel_outline", false)):
		if _minify_material == null:
			_minify_material = ShaderMaterial.new()
			_minify_material.shader = PIXEL_MINIFY
		sprite.material = _minify_material
	sprite.scale = Vector2.ONE * float(visuals.get("action_scale_percent", 50)) / 100.0
	var offset: Array = visuals.get("action_offset", [0.0, -4.0])
	sprite.position = Vector2(float(offset[0]), float(offset[1]))
	_show("idle", 0)


func get_frame_layouts() -> Array[Dictionary]:
	var layouts: Array[Dictionary] = []
	for clip: Dictionary in _clips.values():
		layouts.append({"texture": clip.texture, "grid": Vector2i(int(clip.get("frames", 1)), 1)})
	return layouts


func reset() -> void:
	action = ""
	facing_direction = Vector2.ZERO
	_elapsed = 0.0
	_move_time = 0.0
	_hold_time = 0.0
	_sustains.clear()
	if enabled and is_instance_valid(_sprite):
		_show("idle", 0)


func play(next: String, direction: Vector2 = Vector2.ZERO) -> void:
	if not enabled or not _clips.has(next):
		return
	# Every new request replaces the prior action, including the same action.
	action = next
	facing_direction = direction
	_elapsed = 0.0
	_show(next, 0)


func start_sustain(source: Node = null, seconds: float = 0.0, direction: Vector2 = Vector2.ZERO) -> void:
	if not enabled:
		return
	_sustains.append({"source": weakref(source) if is_instance_valid(source) else null,
		"remaining": seconds, "timed": seconds > 0.0, "direction": direction})
	action = "sustain_enter"
	facing_direction = direction
	_elapsed = 0.0
	_hold_time = 0.0
	_show("sustain", 0)


func tick(delta: float, moving: bool) -> void:
	if not enabled or not is_instance_valid(_sprite):
		return
	_moving = moving
	_move_time = _move_time + delta if moving else 0.0
	_hold_time += delta
	_elapsed += delta
	for index in range(_sustains.size() - 1, -1, -1):
		var state := _sustains[index]
		state.remaining = float(state.remaining) - delta
		var live: Variant = state.source.get_ref() if state.source is WeakRef else null
		var active := false
		if bool(state.timed):
			active = float(state.remaining) > 0.0
		elif is_instance_valid(live) and not live.is_queued_for_deletion() and not live.cancelled:
			if live is CopperLamp:
				active = live.burst_active
			elif live.has_method("is_attacking"):
				active = live.is_attacking()
		if not active:
			_sustains.remove_at(index)
	if action in ["sustain_enter", "sustain_hold"] and _sustains.is_empty():
		action = "sustain_exit"
		_elapsed = 0.0
	if action in ["sustain_enter", "sustain_hold"]:
		_update_sustain_facing()
	if action == "sustain_enter":
		if _elapsed < 4.0 / _fps("sustain"):
			_show("sustain", mini(3, int(_elapsed * _fps("sustain"))))
			return
		action = "sustain_hold"
	if action == "sustain_hold":
		if moving:
			_show("move_sustain", int(_move_time * _fps("move_sustain")) % _count("move_sustain"))
		else:
			_show("sustain", 4 + int(_hold_time * 3.0) % 2)
		return
	if action == "sustain_exit":
		if _elapsed < 2.0 / _fps("sustain"):
			_show("sustain", 6 + mini(1, int(_elapsed * _fps("sustain"))))
			return
		action = ""
	elif not action.is_empty():
		var frame := _frame_at_time(action, _elapsed)
		if frame < _count(action):
			_show(action, frame)
			return
		action = ""
	if not _sustains.is_empty():
		# Resume the hold, not the interrupted windup or an expired action.
		action = "sustain_hold"
		_update_sustain_facing()
		if moving:
			_show("move_sustain", int(_move_time * _fps("move_sustain")) % _count("move_sustain"))
		else:
			_show("sustain", 4 + int(_hold_time * 3.0) % 2)
	elif moving:
		facing_direction = Vector2.ZERO
		_show("move", int(_move_time * _fps("move")) % _count("move"))
	else:
		facing_direction = Vector2.ZERO
		_show("idle", 0)


func _update_sustain_facing() -> void:
	# The latest live sustain owns the pose, including after an interrupt ends.
	var state: Dictionary = _sustains.back()
	var direction: Vector2 = state.direction
	var live: Variant = state.source.get_ref() if state.source is WeakRef else null
	if is_instance_valid(live) and live is CopperLamp:
		direction = live.heading
	if not is_zero_approx(direction.x):
		facing_direction = direction


func _fps(clip: String) -> float:
	return maxf(0.1, float(_clips[clip].get("fps", 10.0)))


func _count(clip: String) -> int:
	return maxi(1, int(_clips[clip].get("frames", 1)))


func _frame_at_time(clip: String, seconds: float) -> int:
	var durations: Array = _clips[clip].get("frame_durations", [])
	if durations.size() == _count(clip):
		var end := 0.0
		for index in durations.size():
			end += maxf(0.001, float(durations[index]))
			if seconds < end - 0.000001:
				return index
		return _count(clip)
	return int(seconds * _fps(clip))


func _show(clip: String, frame: int) -> void:
	if current_clip != clip or _sprite.texture != _clips[clip].texture:
		_sprite.frame = 0
		_sprite.hframes = 1
		_sprite.vframes = 1
		_sprite.texture = _clips[clip].texture
		_sprite.hframes = _count(clip)
	current_clip = clip
	current_frame = clampi(frame, 0, _count(clip) - 1)
	_sprite.frame = current_frame
