extends RefCounted
class_name StatPreviewBuilder

const OFFER_RELIC: String = "relic"


static func build_offer_stat_preview(offer: Dictionary, player: PlayerController) -> Dictionary:
	var result := {}
	if player == null:
		return result
	if str(offer.get("offer_type", "")) != OFFER_RELIC:
		return result
	var effects: Array = offer.get("effects", [])
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_data: Dictionary = effect
		var stat_id := str(effect_data.get("stat", ""))
		if stat_id.is_empty():
			continue
		var modifier_data := effect_data.duplicate(true)
		result[stat_id] = player.get_stat_with_extra_modifier(stat_id, modifier_data)
	return result
