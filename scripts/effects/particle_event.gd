extends RefCounted

static func create(data: Dictionary) -> Dictionary:
	var raw_tags: Variant = data.get("tags", [])
	var tags: Array[String] = []
	if raw_tags is Array:
		for tag in raw_tags:
			tags.append(str(tag))
	return {
		"profile_id": str(data.get("profile_id", "")),
		"global_position": data.get("global_position", Vector2.ZERO),
		"direction": data.get("direction", Vector2.ZERO),
		"intensity": maxf(float(data.get("intensity", 1.0)), 0.0),
		"color_override": data.get("color_override", Color.TRANSPARENT),
		"source_id": str(data.get("source_id", "")),
		"tags": tags,
	}
