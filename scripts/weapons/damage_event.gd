extends RefCounted
class_name DamageEvent

var source_player: PlayerController = null
var source_weapon_id: String = ""
var damage: int = 0
# Base before weapon-local percentage enchantments; their elemental multiplier
# lives in elemental_damage_scale so native and elemental hits never double-dip.
var original_damage: int = 0
var element_damage_bonus: int = 0
# Scale the complete elemental base before the effect's final rounding.
var elemental_damage_scale: float = 1.0
var damage_area_scale: float = 1.0
# Captured by the source weapon; -1 lets legacy/source-less events use the target's player.
var control_power: float = -1.0
var damage_kind: String = ""
var is_critical: bool = false
var tags: Array[String] = []
var hit_position: Vector2 = Vector2.ZERO
# Shared by every native contact/projectile in one attack, including split children.
var attack_context: Dictionary = {}
var enchantment_start: int = 0
var split_child: bool = false


static func create(data: Dictionary) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_player = data.get("source_player", null)
	event.source_weapon_id = str(data.get("source_weapon_id", ""))
	event.damage = int(data.get("damage", 0))
	event.original_damage = int(data.get("original_damage", event.damage))
	event.element_damage_bonus = maxi(0, int(data.get("element_damage_bonus", 0)))
	event.elemental_damage_scale = maxf(float(data.get("elemental_damage_scale", 1.0)), 0.0)
	event.damage_area_scale = maxf(float(data.get("damage_area_scale", 1.0)), 0.01)
	event.control_power = float(data.get("control_power", -1.0))
	event.damage_kind = str(data.get("damage_kind", ""))
	event.is_critical = bool(data.get("is_critical", false))
	event.tags = _to_string_array(data.get("tags", []))
	event.hit_position = data.get("hit_position", Vector2.ZERO)
	event.attack_context = data.get("attack_context", {})
	event.enchantment_start = int(data.get("enchantment_start", 0))
	event.split_child = bool(data.get("split_child", false))
	return event


func to_dictionary() -> Dictionary:
	return {
		"source_player": source_player,
		"source_weapon_id": source_weapon_id,
		"damage": damage,
		"original_damage": original_damage,
		"element_damage_bonus": element_damage_bonus,
		"elemental_damage_scale": elemental_damage_scale,
		"damage_area_scale": damage_area_scale,
		"control_power": control_power,
		"damage_kind": damage_kind,
		"is_critical": is_critical,
		"tags": tags.duplicate(),
		"hit_position": hit_position,
		"attack_context": attack_context,
		"enchantment_start": enchantment_start,
		"split_child": split_child,
	}


func duplicate_event() -> DamageEvent:
	return DamageEvent.create(to_dictionary())


func continue_after_split(profile: Dictionary) -> DamageEvent:
	var child := duplicate_event()
	child.enchantment_start = int(profile.get("enchantment_start", 0))
	child.split_child = true
	return child


func get_elemental_base_damage() -> float:
	return maxf(float(original_damage) + float(element_damage_bonus), 0.0) * elemental_damage_scale


func get_elemental_damage(multiplier: float) -> int:
	return maxi(1, int(roundi(get_elemental_base_damage() * maxf(multiplier, 0.0))))


static func _to_string_array(raw_values: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_values is Array:
		for value in raw_values:
			result.append(str(value))
	return result
