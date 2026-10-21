extends Node
## Exercise real bar layout, input, texture selection and pulse at both tiers.
const BAR = preload("res://scripts/ui/active_combat_weapon_bar.gd")
const PULSE = preload("res://scripts/ui/weapon_pulse_r02.gd")
var bar: ActiveCombatWeaponBar
var checks := 0
var failures := 0
var output := ""
var clicked := -1
var captured: Array[Dictionary] = []


func _ready() -> void:
	WindowSettings._startup_applied = true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 4) -> void:
	for _i in count: await get_tree().process_frame


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)


func configure(count: int, width: int) -> void:
	var window := get_tree().root
	window.size = Vector2i(width, 1080)
	window.content_scale_size = Vector2i(width, 1080)
	await frames()
	var records := DataRegistry.get_table("weapons")
	var sources: Array[WeaponInstance] = []
	for i in count:
		var source := WeaponInstance.new()
		source.initialize(str(records[i % records.size()].id), null)
		sources.append(source)
	bar.setup(sources)
	await frames()
	bar.apply_layout()


func verify_layout(expected: float) -> void:
	check(bar.icon_size == expected, "tier matches available width")
	check(bar.size.x <= get_viewport().get_visible_rect().size.x * 0.8, "bar stays within reserved width")
	for i in bar.icons.size():
		var icon := bar.icons[i]
		check(icon.size == Vector2.ONE * expected, "icon uses an exact 72 or 36 pixel square")
		check(icon.texture.get_size() == Vector2(36, 36), "texture is always the same 36px grid")
		check(icon.scale == Vector2.ONE, "no inherited icon pulse scale")
		check(icon.global_position == icon.global_position.round(), "integer icon placement")
		check(bar.cards[i].get_global_rect().encloses(icon.get_global_rect()), "card contains complete icon")
		check(icon.get_node_or_null(ItemIconArt.BINDING_NAME) == null, "window resize cannot select another atlas size")
		for j in range(i):
			check(not bar.cards[i].get_rect().intersects(bar.cards[j].get_rect()), "wrapped cards never overlap")


func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	check(screenshot.save_png(output.path_join(name + ".png")) == OK, "save GPU review")
	var icons: Array[Dictionary] = []
	for icon in bar.icons:
		icons.append({"source": ItemIconArt.source_path(icon.texture), "region": icon.texture.region if icon.texture is AtlasTexture else Rect2(), "position": icon.global_position, "size": icon.size})
	captured.append({"name": name, "tier": bar.icon_size, "icons": icons})


func _run() -> void:
	CampProgression.begin_transient_session()
	bar = BAR.new()
	add_child(bar)
	bar.slot_pressed.connect(func(index: int): clicked = index)
	await configure(0, 1920)
	check(bar.icons.is_empty() and bar.size.x == 0, "empty loadout remains empty")
	for pair in [[1, 72], [6, 72], [13, 72], [14, 36], [30, 36]]:
		await configure(pair[0], 1920)
		verify_layout(pair[1])
	await configure(14, 640)
	verify_layout(36)
	check(bar.columns < 14 and bar.cards[-1].position.y > 0, "compact icons wrap instead of shrinking further")
	var index := 10
	CombatSettings.set_weapon_auto_cast(bar.weapons[index].weapon_id, false, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = bar.cards[index].get_rect().get_center()
	bar._gui_input(click)
	check(clicked == index, "wrapped card input routes to the correct weapon")
	check(bar._get_tooltip(bar.cards[index].get_rect().get_center()) == bar.cast_mode_icons[index].tooltip_text, "wrapped tooltip belongs to its own row")
	clicked = -1
	click.position = bar.cast_mode_icons[index].get_rect().get_center()
	bar._gui_input(click)
	check(clicked == -1, "cast-mode badge does not trigger a weapon")
	await configure(6, 1920)
	var initial := bar.icons[0].texture
	for dimensions in [Vector2i(1280, 720), Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		get_tree().root.size = dimensions
		await frames()
		bar.apply_layout()
		check(bar.icons[0].texture == initial and bar.icons[0].size == Vector2(72,72), "window output changes preserve logical art tier and source")
	var native := ImageTexture.create_from_image(Image.create(36,36,false,Image.FORMAT_RGBA8))
	check(BAR.combat_icon(native) == native, "future approved native36 bypasses stale atlas variants")
	var return_source := load("res://assets/ui/icons/weapons/weapon_star_tome_return.png") as Texture2D
	check(BAR.combat_icon(return_source).get_size() == Vector2(36,36) and ItemIconArt.source_path(BAR.combat_icon(return_source)) == return_source.resource_path, "return state retains identity and the 36px source tier")
	for child in bar.cards[0].get_children():
		if child.get_script() == PULSE:
			for time in [0.0, 0.03, 0.06, 0.12, 0.22]:
				child.age = time
				child.paint()
				check(bar.icons[0].scale == Vector2.ONE and bar.icons[0].size == Vector2(72,72), "pulse never introduces fractional art scaling")
			child.age = 1.0
			bar.icons[0].modulate = Color.WHITE
			child.queue_redraw()
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	await capture("01_six_weapons_72")
	await configure(14, 1920)
	await capture("02_fourteen_weapons_36")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(captured, "\t"))
	bar.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("ACTIVE_WEAPON_ICON_LAYOUT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
