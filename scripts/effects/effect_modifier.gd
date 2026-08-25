extends RefCounted

const OP_ADD_FLAT: String = "add_flat"
const OP_ADD_PERCENT: String = "add_percent"
const OP_MULTIPLY: String = "multiply"
const OP_OVERRIDE: String = "override"


static func normalize(data: Dictionary) -> Dictionary:
	return {
		"effect_id": str(data.get("effect_id", "*")),
		"channel": str(data.get("channel", "")),
		"operation": str(data.get("operation", OP_ADD_FLAT)),
		"value": data.get("value", 0.0),
		"source_id": str(data.get("source_id", "")),
		"metadata": data.get("metadata", {}).duplicate(true),
	}


static func applies_to(modifier: Dictionary, effect_id: String, channel: String) -> bool:
	var modifier_effect_id := str(modifier.get("effect_id", "*"))
	var modifier_channel := str(modifier.get("channel", ""))
	return (modifier_effect_id == "*" or modifier_effect_id == effect_id) and modifier_channel == channel
