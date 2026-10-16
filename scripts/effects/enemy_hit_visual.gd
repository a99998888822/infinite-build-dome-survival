extends Node
## Presentation offset is independent of animation pose, jump height and collision.
const WHITE_SHADER = preload("res://assets/shaders/enemy_hit_white.gdshader")
const SHAKE_SECONDS := 0.18
const SHAKE_PIXELS := 14.0
const WHITE_HOLD_SECONDS := 0.07
const WHITE_FADE_SECONDS := 0.05
const DIRECTIONS := [Vector2(1, -0.35), Vector2(-1, 0.55), Vector2(0.65, 1), Vector2(-0.8, -0.7)]

var sprite: Sprite2D
var elapsed := SHAKE_SECONDS
var applied_offset := Vector2.ZERO
var white_material: ShaderMaterial
var original_material: Material
var flash_white := false
var _pulse_frame := -1


func _ready() -> void:
	sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D
	process_priority = 5 # After animation, before the armor outline copies sprite.offset.
	set_process(false)


func pulse(allow_white: bool) -> void:
	if not is_instance_valid(sprite): return
	elapsed = 0.0
	_pulse_frame = Engine.get_process_frames()
	flash_white = allow_white
	if flash_white:
		if white_material == null:
			white_material = ShaderMaterial.new()
			white_material.shader = WHITE_SHADER
		if sprite.material != white_material:
			original_material = sprite.material
		sprite.material = white_material
	set_process(true)
	_sync()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	# The current frame's delta predates contact; always draw the full white pose once.
	if Engine.get_process_frames() == _pulse_frame: return
	elapsed = minf(elapsed + delta, SHAKE_SECONDS)
	_sync()
	if elapsed >= SHAKE_SECONDS: reset()


func _sync() -> void:
	if not is_instance_valid(sprite): return
	sprite.offset -= applied_offset
	var strength := pow(1.0 - clampf(elapsed / SHAKE_SECONDS, 0.0, 1.0), 1.5)
	var direction: Vector2 = DIRECTIONS[int(elapsed * 60.0) % DIRECTIONS.size()]
	var world_offset := (direction * SHAKE_PIXELS * strength).round()
	# Basis only: never cache/restore the animation's position or scale.
	applied_offset = sprite.global_transform.affine_inverse().basis_xform(world_offset)
	sprite.offset += applied_offset
	if flash_white and sprite.material == white_material:
		var amount := 1.0 - clampf((elapsed - WHITE_HOLD_SECONDS) / WHITE_FADE_SECONDS, 0.0, 1.0)
		white_material.set_shader_parameter("white_amount", amount)
		if amount <= 0.0: sprite.material = original_material


func reset() -> void:
	if is_instance_valid(sprite):
		sprite.offset -= applied_offset
		if sprite.material == white_material and white_material != null:
			sprite.material = original_material
	applied_offset = Vector2.ZERO
	elapsed = SHAKE_SECONDS
	set_process(false)


func _exit_tree() -> void:
	reset()
