extends Node
## Minimum physical sizes, resource reuse, resize stability and native clipping.

var checks := 0
var failures := 0
@onready var window := get_tree().root


func _ready() -> void: run.call_deferred()


func frames(count := 12) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)


func run() -> void:
	window.content_scale_size = Vector2i(1152, 648)
	window.size = Vector2i(1024, 576)
	var weapon := load("res://assets/ui/icons/weapons/weapon_wood_arrow.png") as Texture2D
	var relic := load("res://assets/ui/icons/relics/relic_piggy_bank.png") as Texture2D
	var row := HBoxContainer.new()
	row.position = Vector2(30, 40)
	add_child(row)
	var detail := TextureRect.new()
	detail.custom_minimum_size = Vector2(26, 26)
	detail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(detail)
	ItemIconArt.bind_texture(detail, weapon, false, 26, null, 26)
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 44)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 34)
	row.add_child(button)
	ItemIconArt.bind_button(button, weapon, 32)
	var first_minimum := Vector2.ZERO
	for dimensions in [Vector2i(1024, 576), Vector2i(640, 360), Vector2i(1152, 648), Vector2i(1366, 768), Vector2i(2560, 1440), Vector2i(1024, 576)]:
		window.size = dimensions
		await frames()
		for control: Control in [detail, button]:
			var texture: Texture2D = control.texture if control is TextureRect else control.icon
			check(texture is ItemIconArt.PIXEL_TEXTURE, "weapon uses its native Control texture drawing")
			var t := ItemIconArt.PIXEL_TEXTURE.screen_transform(control)
			var rect: Rect2 = t * texture.last_local_rect
			check(rect.size.is_equal_approx(texture.physical_size()), "drawn size equals whole source pixels")
			check(rect.position.distance_to(rect.position.round()) < 0.01, "destination is aligned to screen pixels: %s %s %s" % [dimensions, control.get_class(), rect])
			check(maxf(rect.size.x, rect.size.y) >= (26.0 if control == detail else 32.0), "minimum physical size survives window resize")
			var bounds := t * Rect2(Vector2.ZERO, control.size)
			check(bounds.grow(0.01).encloses(rect), "icon fits in the space reserved by the native container")
			check(ItemIconArt.source_path(texture) == weapon.resource_path, "custom drawing retains weapon identity")
		if first_minimum == Vector2.ZERO: first_minimum = detail.custom_minimum_size
	check(detail.custom_minimum_size.is_equal_approx(first_minimum), "returning to original resolution restores minimum without growth")
	var binding := detail.get_node(ItemIconArt.BINDING_NAME) as ItemIconArt.IconBinding
	var refreshes := binding.refresh_count
	var drawn: int = detail.texture.draw_count
	await frames(30)
	check(binding.refresh_count == refreshes and detail.texture.draw_count == drawn, "static icons neither poll nor redraw every frame")
	row.position += Vector2(3.25, 1.5)
	await frames()
	check(detail.texture.draw_count > drawn, "moving an ancestor updates physical alignment")
	var moved: Rect2 = ItemIconArt.PIXEL_TEXTURE.screen_transform(detail) * detail.texture.last_local_rect
	check(moved.position.distance_to(moved.position.round()) < 0.01, "fractional ancestor movement remains aligned")
	ItemIconArt.bind_texture(detail, relic)
	await frames()
	check(not detail.texture is ItemIconArt.PIXEL_TEXTURE and detail.custom_minimum_size == Vector2(26, 26), "switching to relic restores normal layout and texture behavior")
	ItemIconArt.bind_button(button, null)
	await frames()
	check(button.icon == null and button.custom_minimum_size == Vector2(44, 44) and button.get_theme_constant("icon_max_width") == 34, "clearing weapon restores button constraints")
	var valid := true
	for path: String in ItemIconArt.CATALOG.ITEMS:
		if not path.contains("/weapons/"): continue
		var source := load(path) as Texture2D
		var cropped := AtlasTexture.new()
		cropped.atlas = source
		cropped.region = Rect2(source.get_image().get_used_rect())
		for candidate: Texture2D in [source, cropped]:
			for minimum in [26.0, 32.0]:
				for desired in [14.0, 23.0, 31.0, 43.0, 98.0, 260.0]:
					var selected := ItemIconArt.weapon_pixel_art(candidate, desired, minimum)
					var extent: Vector2 = selected.texture.get_size() * selected.multiple
					valid = valid and maxf(extent.x, extent.y) >= minimum and int(selected.multiple) >= 1
	check(valid, "all 15 weapon states including cropped art honor minimum size and integer magnification")
	var card := PreparationOfferCard.new()
	card.size = Vector2(160, 160)
	add_child(card)
	var weapon_offer := {"offer_type": "new_weapon", "target_id": "weapon_void_blade", "icon": weapon.resource_path, "rarity": "common", "shop_cost": 15}
	var relic_offer := {"offer_type": "relic", "target_id": "relic_piggy_bank", "icon": relic.resource_path, "rarity": "common", "shop_cost": 15}
	window.size = Vector2i(640, 360)
	card.configure(weapon_offer, "", 100)
	await frames()
	var weapon_minimum := card._icon_frame.custom_minimum_size
	card.configure(relic_offer, "", 100)
	await frames()
	check(card._icon_frame.custom_minimum_size == Vector2(44, 44) and not card._icon.texture is ItemIconArt.PIXEL_TEXTURE, "pooled shop card restores relic footprint")
	card.configure(weapon_offer, "", 100)
	await frames()
	check(card._icon_frame.custom_minimum_size.is_equal_approx(weapon_minimum), "pooled shop card restores physical weapon footprint without cumulative growth")
	card.queue_free()
	row.queue_free()
	await frames()
	print("WEAPON_PIXEL_LAYOUT_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
