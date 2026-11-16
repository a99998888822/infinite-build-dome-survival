extends RefCounted
## Approved R04 artwork. Playback only; spell collision/damage remain separate.
const FRAME_SIZE := Vector2(192, 184)
const PIVOT := Vector2(96, 158)
const COLUMNS := 8
const FRAME_COUNT := 60
const FPS := 30.0
const LOOP_DURATION := 2.0
const LIFETIME := 3.0
const FLIGHT_SPEED := 48.0
const TEXTURES := {
	"air_back": preload("res://assets/effects/tornado/tornado_air_back.png"),
	"air_front": preload("res://assets/effects/tornado/tornado_air_front.png"),
	"fire_back": preload("res://assets/effects/tornado/tornado_fire_back.png"),
	"fire_front": preload("res://assets/effects/tornado/tornado_fire_front.png"),
	"frost_back": preload("res://assets/effects/tornado/tornado_frost_back.png"),
	"frost_front": preload("res://assets/effects/tornado/tornado_frost_front.png"),
}


static func frame_at(age: float) -> int:
	return int(maxf(age, 0.0) * FPS) % FRAME_COUNT


static func opacity_at(age: float) -> float:
	if age < 0.0 or age >= LIFETIME:
		return 0.0
	return clampf(age / 0.10, 0.0, 1.0) * clampf((LIFETIME - age) / 0.27, 0.0, 1.0)


static func draw_layer(canvas: CanvasItem, element: String, front: bool, age: float, pivot := Vector2.ZERO, size := 1.0, opacity := 1.0) -> void:
	# "ice" is the internal status ID; the authored form is frost.
	var form := "frost" if element == "ice" else element
	var key := form + ("_front" if front else "_back")
	assert(TEXTURES.has(key), "Unknown tornado form: " + element)
	if opacity <= 0.0:
		return
	var frame := frame_at(age)
	var source := Rect2(Vector2(frame % COLUMNS, frame / COLUMNS) * FRAME_SIZE, FRAME_SIZE)
	canvas.draw_texture_rect_region(TEXTURES[key], Rect2((pivot - PIVOT * size).round(), FRAME_SIZE * size), source, Color(1, 1, 1, opacity))
