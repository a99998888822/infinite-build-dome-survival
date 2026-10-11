extends Node
## Resolution switching, pooled controls and resource identity regressions.

var failures := 0
var checks := 0
@onready var window := get_tree().root


func _ready() -> void:
	_run.call_deferred()


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)


func _run() -> void:
	window.size = Vector2i(1152, 648)
	window.content_scale_size = Vector2i(1152, 648)
	var relic := load("res://assets/ui/icons/relics/relic_piggy_bank.png") as Texture2D
	var weapon := load("res://assets/ui/icons/weapons/weapon_camp_dagger.png") as Texture2D
	var frame := Control.new()
	frame.size = Vector2(44, 44)
	add_child(frame)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(icon)
	FinanceUIStyle.set_item_icon(icon, relic, FinanceUIStyle.RELIC_LIST_ICON_SCALE)
	await frames()
	check(icon.texture.get_meta(ItemIconArt.SIZE_META, 0) == 40, "inventory selects the actual 40px variant")
	check(icon.size == Vector2(40, 40), "relic layout footprint remains 40px")
	check(FinanceUIStyle.is_native_relic_icon(icon.texture), "atlas resource retains native relic identity")
	check(ItemIconArt.source_path(icon.texture) == relic.resource_path, "atlas maps to the original source path")
	var binding := icon.get_node(ItemIconArt.BINDING_NAME) as ItemIconArt.IconBinding
	var refreshes := binding.refresh_count
	var reused := icon.texture
	await frames(20)
	check(binding.refresh_count == refreshes and icon.texture == reused, "static icons do not poll or rebuild per frame")
	check(ItemIconArt.texture_for(relic, 40) == reused, "controls share cached atlas regions")
	window.size = Vector2i(2560, 1440)
	await frames()
	check(icon.texture.get_meta(ItemIconArt.SIZE_META, 0) == 89, "resize picks 89px art instead of enlarging 40px art")
	window.size = Vector2i(1152, 648)
	await frames()
	check(icon.texture == reused, "returning to a resolution reuses its texture")
	FinanceUIStyle.set_item_icon(icon, weapon, FinanceUIStyle.RELIC_LIST_ICON_SCALE)
	await frames()
	check(not icon.has_meta("scaled_relic_icon") and icon.custom_minimum_size == Vector2.ZERO, "pooled weapon restores its original layout")
	check(ItemIconArt.source_path(icon.texture) == weapon.resource_path, "pooled control replaces the old relic")
	FinanceUIStyle.set_item_icon(icon, null)
	await frames()
	check(icon.texture == null, "clearing a pooled icon removes its bound source")
	var unhandled := GradientTexture2D.new()
	ItemIconArt.bind_texture(icon, unhandled)
	await frames()
	check(icon.texture == unhandled, "unrelated UI art is not replaced")
	var button := Button.new()
	button.expand_icon = true
	button.size = Vector2(44, 44)
	button.add_theme_constant_override("icon_max_width", 34)
	add_child(button)
	ItemIconArt.bind_button(button, weapon)
	await frames()
	check(button.icon.get_meta(ItemIconArt.SIZE_META, 0) == 34, "upper weapon button selects 34px art")
	check(button.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "upper weapon button explicitly uses nearest")
	var return_icon := load("res://assets/ui/icons/weapons/weapon_star_tome_return.png") as Texture2D
	ItemIconArt.bind_button(button, return_icon)
	await frames()
	check(ItemIconArt.source_path(button.icon) == return_icon.resource_path, "return-ready icon retains its distinct identity")
	var crop := AtlasTexture.new()
	crop.atlas = weapon
	crop.region = Rect2(weapon.get_image().get_used_rect())
	var selected := ItemIconArt.texture_for(crop, 40) as AtlasTexture
	check(selected != null and selected.region.size.x < 64 and selected.region.size.y < 64, "cropped character-select icons preserve their cropped footprint")
	var integrity := true
	for path: String in ItemIconArt.CATALOG.ITEMS:
		var source := load(path) as Texture2D
		for pixels: int in ItemIconArt.CATALOG.ITEMS[path].variants:
			var result := ItemIconArt.texture_for(source, pixels)
			integrity = integrity and result is AtlasTexture and result.get_size() == Vector2(pixels, pixels)
			integrity = integrity and result.atlas != null and result.atlas.resource_path.begins_with("res://assets/ui/icons/clarity/")
	check(integrity, "all installed atlas regions resolve at their declared dimensions")
	var reward := load("res://scenes/ui/rewards/reward_option.tscn").instantiate() as RewardOption
	add_child(reward)
	reward.set_layout_width(160)
	reward.set_available_size(160, 200)
	var relic_offer := DataRegistry.get_record("relics", "relic_piggy_bank").duplicate(true)
	relic_offer.merge({"offer_type": "relic", "target_id": "relic_piggy_bank"}, true)
	reward.configure(relic_offer)
	await frames()
	check(reward.icon_texture.texture.get_meta(ItemIconArt.SIZE_META, 0) == 48, "real reward card uses 48px art")
	window.size = Vector2i(2560, 1440)
	await frames()
	reward.set_available_size(160, 200)
	await frames()
	check(reward.icon_texture.texture.get_meta(ItemIconArt.SIZE_META, 0) == 107, "real reward card changes art at high resolution")
	check(reward.icon_texture.size == Vector2(48, 48) and reward.custom_minimum_size == Vector2(160, 200), "atlas dimensions do not expand reward card layout")
	var weapon_offer := DataRegistry.get_record("weapons", "weapon_camp_dagger").duplicate(true)
	weapon_offer.merge({"offer_type": "new_weapon", "target_id": "weapon_camp_dagger"}, true)
	reward.configure(weapon_offer)
	await frames()
	check(ItemIconArt.source_path(reward.icon_texture.texture) == weapon.resource_path, "real reward card reuses its icon for a weapon")
	reward.configure(relic_offer)
	window.size = Vector2i(1152, 648)
	await frames()
	check(reward.icon_texture.texture.get_meta(ItemIconArt.SIZE_META, 0) == 48, "reused reward card restores its relic and original size")
	reward.queue_free()
	await frames()
	print("ITEM_ICON_ART_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
