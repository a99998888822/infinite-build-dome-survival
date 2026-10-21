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
	check(icon.texture == relic and relic.get_size() == Vector2(36, 36), "inventory uses the approved native 36px source")
	check(icon.size == Vector2(36, 36), "shop relic layout is exactly 36px")
	check(FinanceUIStyle.is_native_relic_icon(icon.texture), "native relic identity is preserved")
	check(not ItemIconArt.supports(relic), "relic bypasses the legacy clarity catalog")
	var reused := icon.texture
	await frames(20)
	check(icon.get_node_or_null(ItemIconArt.BINDING_NAME) == null and icon.texture == reused, "native relic needs no variant binding or polling")
	check(ItemIconArt.texture_for(relic, 40) == reused, "direct texture requests also bypass the old relic atlas")
	window.size = Vector2i(2560, 1440)
	await frames()
	check(icon.texture == relic, "window resizing retains the same approved source")
	window.size = Vector2i(1152, 648)
	await frames()
	check(icon.texture == reused, "returning to a resolution reuses its texture")
	FinanceUIStyle.set_item_icon(icon, relic)
	await frames()
	check(icon.size == Vector2(72, 72), "detail tier displays source at 2x")
	FinanceUIStyle.set_item_icon(icon, relic, FinanceUIStyle.RELIC_LIST_ICON_SCALE)
	await frames()
	check(icon.size == Vector2(36, 36), "pooled detail icon shrinks back to native 1x")
	FinanceUIStyle.set_item_icon(icon, weapon, FinanceUIStyle.RELIC_LIST_ICON_SCALE)
	await frames()
	check(icon.size == Vector2(36, 36) and icon.texture == weapon, "pooled weapon shares the native 36px list contract")
	check(ItemIconArt.source_path(icon.texture) == weapon.resource_path, "pooled control replaces the old relic")
	FinanceUIStyle.set_item_icon(icon, relic, FinanceUIStyle.RELIC_LIST_ICON_SCALE)
	await frames()
	check(icon.texture == relic and icon.size == Vector2(36, 36) and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pooled weapon binding restores native nearest relic")
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
	button.add_theme_constant_override("icon_max_width", 36)
	add_child(button)
	ItemIconArt.bind_button(button, weapon)
	await frames()
	check(button.icon == weapon and weapon.get_size() == Vector2(36, 36), "weapon button uses the native 36px source")
	check(button.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "upper weapon button explicitly uses nearest")
	var return_icon := load("res://assets/ui/icons/weapons/weapon_star_tome_return.png") as Texture2D
	ItemIconArt.bind_button(button, return_icon)
	await frames()
	check(ItemIconArt.source_path(button.icon) == return_icon.resource_path, "return-ready icon retains its distinct identity")
	var crop := AtlasTexture.new()
	crop.atlas = weapon
	crop.region = Rect2(weapon.get_image().get_used_rect())
	var selected := ItemIconArt.texture_for(crop, 40)
	check(selected == weapon, "legacy cropped requests restore the complete native canvas")
	var integrity := true
	for path: String in ItemIconArt.CATALOG.ITEMS:
		var source := load(path) as Texture2D
		if ItemIconArt.is_relic(source):
			integrity = integrity and ItemIconArt.texture_for(source, 80) == source
			continue
		for pixels: int in ItemIconArt.CATALOG.ITEMS[path].variants:
			var result := ItemIconArt.texture_for(source, pixels)
			integrity = integrity and result == source and result.get_size() == Vector2(36, 36)
	check(integrity, "every legacy weapon variant request resolves to the new native source")
	for record: Dictionary in DataRegistry.get_table("relics"):
		var source := load(str(record.icon)) as Texture2D
		check(source.get_size() == Vector2(36, 36) and FinanceUIStyle.is_native_relic_icon(source), "every configured relic uses the approved 36px contract: " + str(record.id))
	var reward := load("res://scenes/ui/rewards/reward_option.tscn").instantiate() as RewardOption
	add_child(reward)
	reward.set_layout_width(160)
	reward.set_available_size(160, 200)
	var relic_offer := DataRegistry.get_record("relics", "relic_piggy_bank").duplicate(true)
	relic_offer.merge({"offer_type": "relic", "target_id": "relic_piggy_bank"}, true)
	reward.configure(relic_offer)
	await frames()
	check(reward.icon_texture.texture == relic and reward.icon_texture.size == Vector2(72, 72), "small reward card displays 36px source at 2x")
	reward.animate_in()
	check(reward.scale == Vector2.ONE, "relic entrance never shrinks source pixels")
	reward._set_card_hovered(true)
	await get_tree().create_timer(0.35).timeout
	check(reward.scale == Vector2.ONE, "relic hover retains exact 2x scale")
	window.size = Vector2i(2560, 1440)
	await frames()
	reward.set_available_size(160, 200)
	await frames()
	check(reward.icon_texture.texture == relic, "reward keeps the approved source at high resolution")
	check(reward.icon_texture.size == Vector2(72, 72) and reward.custom_minimum_size == Vector2(160, 200), "72px detail art fits the small reward layout")
	var weapon_offer := DataRegistry.get_record("weapons", "weapon_camp_dagger").duplicate(true)
	weapon_offer.merge({"offer_type": "new_weapon", "target_id": "weapon_camp_dagger"}, true)
	reward.configure(weapon_offer)
	await frames()
	check(ItemIconArt.source_path(reward.icon_texture.texture) == weapon.resource_path, "real reward card reuses its icon for a weapon")
	check(reward.icon_texture.size == Vector2(72, 72), "small weapon rewards retain exact 2x display")
	reward.animate_in()
	check(reward.scale == Vector2.ONE, "weapon entrance retains integer scale")
	reward._set_card_hovered(true)
	await get_tree().create_timer(0.35).timeout
	check(reward.scale == Vector2.ONE and reward._icon_float_tween == null, "weapon hover and idle never resample the icon")
	reward.configure(relic_offer)
	window.size = Vector2i(1152, 648)
	await frames()
	check(reward.icon_texture.texture == relic and reward.icon_texture.size == Vector2(72, 72), "reused reward card restores its native relic at 2x")
	reward.queue_free()
	await frames()
	print("ITEM_ICON_ART_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
