extends Sprite2D
## Two baked paths; the owning lightning pulse drives frame and opacity.
## No independent timer: pause, lifetime modifiers and deletion stay in sync.
const ATLAS = preload("res://assets/effects/lightning_ground_arcs/ground_arcs.png")
const PHASE_COUNT := 2
const VARIANT_COUNT := 8
static var _random := RandomNumberGenerator.new()
static var _random_ready := false
var variant_index := 0
var _phase := 0

static func spawn(parent: Node, point: Vector2, base_alpha: float) -> Sprite2D:
	if parent == null or not is_instance_valid(parent):
		return null
	if not _random_ready:
		_random.randomize()
		_random_ready = true
	var effect := new() as Sprite2D
	effect.texture = ATLAS
	effect.hframes = VARIANT_COUNT
	effect.vframes = PHASE_COUNT
	effect.variant_index = _random.randi_range(0, VARIANT_COUNT - 1)
	effect.frame = effect.variant_index
	effect.modulate.a = base_alpha
	# A child for ownership, but use world coordinates and the ground draw layer.
	effect.top_level = true
	effect.z_as_relative = false
	parent.add_child(effect)
	effect.global_position = (point / 2.0).round() * 2.0
	return effect

func _ready() -> void:
	z_index = 16
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("lightning_ground_arc_bursts")

func sync_pulse(echoed: bool, opacity: float) -> void:
	var next_phase := 1 if echoed else 0
	if next_phase != _phase:
		_phase = next_phase
		frame = variant_index + _phase * VARIANT_COUNT
	self_modulate.a = opacity
