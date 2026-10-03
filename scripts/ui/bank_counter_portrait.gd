extends Control
class_name BankCounterPortrait

const GOBLIN: Texture2D = preload("res://assets/ui/finance/goblin_banker_states.png")
const DESK: Texture2D = preload("res://assets/ui/finance/bank_counter_desk_picxel.png")
const ACTOR_SCALE := 0.60
const HAND_CONTACT := Vector2(64, 119)
const DESK_CONTACT_Y := 24.0
const DESK_BASE_Y := 56.0
var expression: int = 0
var _reaction_left := 0.0
var _elapsed := 0.0
var _action := ""
var _audio: AudioStreamPlayer
var background_counter := false


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
	if background_counter:
		_draw_on_background()
		return
	var unit := minf(2.0, size.x / 128.0)
	var actor_unit := unit * ACTOR_SCALE
	# Fit from the hat to the actual feet, excluding the PNG's transparent padding.
	var content_height := (DESK_BASE_Y - DESK_CONTACT_Y) * unit + HAND_CONTACT.y * actor_unit
	var fit := minf(1.0, maxf(0, size.y - 2.0) / maxf(1.0, content_height))
	unit *= fit
	actor_unit *= fit
	var origin := Vector2((size.x - 128.0 * unit) * 0.5, size.y - DESK_BASE_Y * unit)
	var actor_size := Vector2(128, 128) * actor_unit
	var actor_pos := Vector2(size.x * 0.5, origin.y + DESK_CONTACT_Y * unit) - HAND_CONTACT * actor_unit
	var breathing := Vector2(0, roundf(sin(_elapsed * 1.5) * 0.6 * minf(1.0, actor_unit)))
	# The complete bust leans over the counter. Draw it once, so sleeves, palms
	# and fingers share the same transform and cannot be cut by tabletop props.
	draw_texture_rect(DESK, Rect2(origin.round(), Vector2(128, 64) * unit), false)
	draw_texture_rect_region(GOBLIN, Rect2((actor_pos + breathing).round(), actor_size.round()), Rect2(expression * 128, 0, 128, 128))
	if _reaction_left > 0.3:
		var t := clampf((1.4 - _reaction_left) / 1.1, 0, 1)
		for index in 4:
			var progress := clampf(t * 1.4 - index * 0.1, 0, 1)
			var target := progress if _action == "deposit" else 1.0 - progress
			var point := origin + Vector2(lerpf(5, 99, target), 18 - sin(progress * PI) * 20) * unit
			draw_rect(Rect2(point.round(), Vector2(3, 2) * unit), FinanceUIStyle.GOLD)


func _draw_on_background() -> void:
	var unit := minf(size.x, size.y) / 128.0
	var extent := Vector2(128, 128) * unit
	var origin := (size - extent) * 0.5
	var breathing := Vector2(0, roundf(sin(_elapsed * 1.5) * 0.6))
	draw_texture_rect_region(GOBLIN, Rect2(origin + breathing, extent), Rect2(expression * 128, 0, 128, 128))
	if _reaction_left > 0.3:
		var t := clampf((1.4 - _reaction_left) / 1.1, 0, 1)
		for index in 4:
			var progress := clampf(t * 1.4 - index * 0.1, 0, 1)
			var target := progress if _action == "deposit" else 1.0 - progress
			var point := origin + Vector2(lerpf(24, 103, target), 120 - sin(progress * PI) * 16) * unit
			draw_rect(Rect2(point.round(), Vector2(3, 2) * unit), FinanceUIStyle.GOLD)
