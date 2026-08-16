extends RefCounted
class_name DamageEvent

var source_player: PlayerController = null
var source_weapon_id: String = ""
var damage: int = 0
var damage_kind: String = ""
var is_critical: bool = false
var tags: Array[String] = []
var hit_position: Vector2 = Vector2.ZERO


static func create(data: Dictionary) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_player = data.get("source_player", null)
	event.source_weapon_id = str(data.get("source_weapon_id", ""))
	event.damage = int(data.get("damage", 0))
	event.damage_kind = str(data.get("damage_kind", ""))
	event.is_critical = bool(data.get("is_critical", false))
	event.tags = _to_string_array(data.get("tags", []))
	event.hit_position = data.get("hit_position", Vector2.ZERO)
	return event


func to_dictionary() -> Dictionary:
	return {
		"source_player": source_player,
		"source_weapon_id": source_weapon_id,
		"damage": damage,
		"damage_kind": damage_kind,
		"is_critical": is_critical,
		"tags": tags.duplicate(),
		"hit_position": hit_position,
	}


func duplicate_event() -> DamageEvent:
	return DamageEvent.create(to_dictionary())


static func _to_string_array(raw_values: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_values is Array:
		for value in raw_values:
			result.append(str(value))
	return result
