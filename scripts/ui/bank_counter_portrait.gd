extends Control
class_name BankCounterPortrait

const GOBLIN: Texture2D = preload("res://assets/ui/finance/goblin_banker_states.png")
const DESK: Texture2D = preload("res://assets/ui/finance/bank_counter_desk.png")
const ACTOR_SCALE := 0.7
var expression: int = 0
var _reaction_left := 0.0
var _elapsed := 0.0
var _action := ""
var _audio: AudioStreamPlayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX"
	_audio.volume_db = -8
	add_child(_audio)


func react(action: String, amount: int, source_balance: int) -> void:
	var large := amount >= maxi(50, ceili(float(source_balance) * 0.25))
	expression = (4 if large else 3) if action == "deposit" else (2 if large else 1)
	_action = action
	_reaction_left = 1.4
	var path := "res://assets/audio/sfx/ui/bank_%s.wav" % action
	if ResourceLoader.exists(path):
		_audio.stream = load(path) as AudioStream
		_audio.play()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += delta
	_reaction_left = maxf(0, _reaction_left - delta)
	if _reaction_left <= 0: expression = 0
	queue_redraw()


func _draw() -> void:
	var unit := minf(2.0, size.x / 128.0)
	var origin := Vector2((size.x - 128.0 * unit) * 0.5, size.y - 59.0 * unit)
	# Character size is independent of the counter's responsive enlargement.
	var actor_unit := minf(1.0, unit) * ACTOR_SCALE
	var actor_size := Vector2(128, 112) * actor_unit
	var actor_pos := Vector2(size.x * 0.5 - actor_size.x * 0.5, origin.y + 17.0 * unit - 96.0 * actor_unit)
	actor_pos.y += roundf(sin(_elapsed * 1.5) * 0.6)
	draw_rect(Rect2(origin + Vector2(12, 56) * unit, Vector2(106, 3) * unit), Color("1b251d"))
	draw_texture_rect_region(GOBLIN, Rect2(actor_pos.round(), actor_size.round()), Rect2(expression * 128, 0, 128, 112))
	draw_texture_rect(DESK, Rect2(origin.round(), Vector2(128, 58) * unit), false)
	if _reaction_left > 0.3:
		var t := clampf((1.4 - _reaction_left) / 1.1, 0, 1)
		for index in 4:
			var progress := clampf(t * 1.4 - index * 0.1, 0, 1)
			var target := progress if _action == "deposit" else 1.0 - progress
			var point := origin + Vector2(lerpf(5, 99, target), 18 - sin(progress * PI) * 20) * unit
			draw_rect(Rect2(point.round(), Vector2(3, 2) * unit), FinanceUIStyle.GOLD)
