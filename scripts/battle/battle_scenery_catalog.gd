extends RefCounted
class_name BattleSceneryCatalog
## Cropped views into approved art, with physical size independent of canvas.
const CONFIG_PATH := "res://data_config/battle_scenery.json"
static var _config: Dictionary = {}
static var _textures: Dictionary = {}


static func get_config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config = parsed
		else:
			push_error("Invalid battle scenery catalog")
	return _config


static func get_variant(group: String, variation: int) -> String:
	var choices: Array = get_config().groups[group]
	return str(choices[posmod(variation, choices.size())])


static func get_ground_variant(slot: int, variation: int) -> String:
	var slots: Array = get_config().ground_slots
	return get_variant(str(slots[slot]), variation)


static func get_texture(asset_id: String) -> AtlasTexture:
	if not _textures.has(asset_id):
		var definition: Dictionary = get_config().assets[asset_id]
		var bounds: Array = definition.content_rect
		var texture := AtlasTexture.new()
		texture.atlas = load(str(definition.texture)) as Texture2D
		texture.region = Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
		texture.filter_clip = true
		_textures[asset_id] = texture
	return _textures[asset_id] as AtlasTexture


static func get_base_scale(asset_id: String) -> float:
	var size := get_texture(asset_id).get_size()
	return float(get_config().assets[asset_id].world_extent) / maxf(size.x,size.y)


static func get_depth_scale(screen_fraction: float, horizon_fraction: float) -> float:
	var depth := clampf((screen_fraction-horizon_fraction) / maxf(1.0-horizon_fraction,0.01),0.0,1.0)
	return lerpf(0.60,1.0,smoothstep(0.0,1.0,depth))
