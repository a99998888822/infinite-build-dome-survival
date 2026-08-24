extends RefCounted
class_name ParticleEvent

var profile_id: String = ""
var global_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var intensity: float = 1.0
var color_override: Color = Color.TRANSPARENT
var source_id: String = ""
var tags: Array[String] = []


static func create(data: Dictionary) -> ParticleEvent:
	var event := ParticleEvent.new()
	event.profile_id = str(data.get("profile_id", ""))
	event.global_position = data.get("global_position", Vector2.ZERO)
	event.direction = data.get("direction", Vector2.ZERO)
	event.intensity = maxf(float(data.get("intensity", 1.0)), 0.0)
	event.color_override = data.get("color_override", Color.TRANSPARENT)
	event.source_id = str(data.get("source_id", ""))
	var raw_tags: Variant = data.get("tags", [])
	if raw_tags is Array:
		for tag in raw_tags:
			event.tags.append(str(tag))
	return event
