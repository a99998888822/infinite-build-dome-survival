extends RefCounted
class_name StatPreviewBuilder

const OFFER_RELIC: String = "relic"


static func build_offer_stat_preview(offer: Dictionary, player: PlayerController) -> Dictionary:
	var result := {}
	if player == null:
		return result
	if str(offer.get("offer_type", "")) != OFFER_RELIC:
		return result
	var preview_stack := _duplicate_player_stack(player)
	var effects: Array = offer.get("effects", [])
	var offer_source_id := str(offer.get("target_id", offer.get("offer_id", "relic_preview")))
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_data: Dictionary = effect
		var stat_id := str(effect_data.get("stat", ""))
		if stat_id.is_empty() or not StatDefinitions.has_stat(stat_id):
			continue
		var modifier_data := _build_preview_modifier(effect_data, offer_source_id)
		var modifier := Modifier.from_dictionary(modifier_data)
		if modifier == null or not modifier.validate().is_empty():
			continue
		preview_stack.add_modifier(modifier)
		result[stat_id] = preview_stack.get_stat(stat_id)
	return result


static func _duplicate_player_stack(player: PlayerController) -> ModifierStack:
	var preview_stack := ModifierStack.new()
	preview_stack.base_stats = player.modifier_stack.base_stats.duplicate(true)
	for modifier in player.modifier_stack.modifiers:
		if modifier != null:
			preview_stack.modifiers.append(modifier.duplicate_modifier())
	return preview_stack


static func _build_preview_modifier(effect_data: Dictionary, source_id: String) -> Dictionary:
	var effect_id := str(effect_data.get("id", ""))
	if effect_id.is_empty():
		effect_id = "relic_preview_%s_%s" % [source_id, str(effect_data.get("stat", ""))]
	return {
		"id": effect_id,
		"source_type": str(effect_data.get("source_type", OFFER_RELIC)),
		"source_id": str(effect_data.get("source_id", source_id)),
		"target_scope": str(effect_data.get("target_scope", "player")),
		"stat": str(effect_data.get("stat", "")),
		"operation": str(effect_data.get("operation", Modifier.OPERATION_ADD_FLAT)),
		"value": float(effect_data.get("value", 0.0)),
		"duration": float(effect_data.get("duration", Modifier.PERMANENT_DURATION)),
		"stack_rule": str(effect_data.get("stack_rule", Modifier.STACK_RULE_STACK_ADD)),
		"priority": int(effect_data.get("priority", Modifier.DEFAULT_PRIORITY)),
		"tags": effect_data.get("tags", []),
		"metadata": effect_data.get("metadata", {}).duplicate(true),
	}
