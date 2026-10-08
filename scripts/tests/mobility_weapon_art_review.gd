extends Node
## Controlled art staging, not the implementation of the three weapon mechanics.
const INDICATOR = preload("res://scripts/battle/mobility_weapon_indicator.gd")
const BASE := "res://artifacts/generated/mobility_weapons_20261007/"
const IDS := ["dash_blade", "recoil_gun", "star_tome"]
const TITLES := ["突进短刃", "巨型手持火炮", "移星秘典"]
const DESCRIPTIONS := ["先快后慢短冲 · 终点快速圆斩 · 位移距离与斩击范围独立成长", "前方近距离散弹 · 同时先快后慢滑退 · 后退距离固定", "大椭圆内指定落点闪现 · 震开并留印 · 再次触发返回"]
const PREVIEW_FPS := 50
const PREVIEW_FRAMES := 100
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var indicator: Node2D
var art_root: Node2D
var definitions: Dictionary
var textures: Dictionary = {}
var sprites: Dictionary = {}
var pellets: Array[Sprite2D] = []
var enemies: Array[EnemyController] = []
var icon: TextureRect
var title: Label
var subtitle: Label
var phase: Label
var capture_dir := ""
var frames_dir := ""
var failures := 0
var checks := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--frames-dir="): frames_dir = arg.trim_prefix("--frames-dir=")
	_run.call_deferred()


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)


func frames(count: int = 4) -> void:
	for i in count: await get_tree().process_frame
	await get_tree().create_timer(0.03).timeout


func image_texture(path: String) -> ImageTexture:
	# artifacts/.gdignore keeps candidate assets out of shipping imports.
	# Image loading here proves these exact candidate PNGs, not cached old textures.
	var img := Image.load_from_file(BASE.path_join(path))
	check(img != null and not img.is_empty(), "candidate image " + path)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	if "--indicators-only" in OS.get_cmdline_user_args():
		await frames(6)
		for kind in 3: await export_indicator(kind, false)
		await export_indicator(2, true)
		print("MOBILITY_INDICATOR_EXPORT checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	definitions = JSON.parse_string(FileAccess.get_file_as_string(BASE.path_join("manifest.json")))
	for group in ["icons", "effects"]:
		for key in definitions[group]:
			textures[group + "/" + key] = image_texture(definitions[group][key].path)
	_validate_revision_rules()
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "real battle background loaded")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	battle.hud.set_process(false)
	battle.hud.hide()
	for layer in battle.hud.find_children("*", "CanvasLayer", true, false): layer.hide()
	player = battle.player
	player.set_physics_process(false)
	player.set_process_input(false)
	art_root = Node2D.new()
	player.get_parent().add_child(art_root)
	indicator = INDICATOR.new()
	art_root.add_child(indicator)
	for key in definitions.effects:
		var sprite := Sprite2D.new()
		sprite.texture = textures["effects/" + key]
		sprite.region_enabled = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -2 if key in ["dash_circle", "star_anchor", "star_shockwave", "recoil_dust"] else 40
		art_root.add_child(sprite)
		sprite.hide()
		sprites[key] = sprite
	for i in 5:
		var pellet := Sprite2D.new()
		pellet.texture = textures["effects/pellet"]
		pellet.region_enabled = true
		pellet.region_rect = Rect2(0, 0, 48, 16)
		pellet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pellet.z_index = 40
		art_root.add_child(pellet)
		pellets.append(pellet)
	for i in 4:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", Vector2(200 + i * 20, 0))
		enemy.set_physics_process(false)
		enemies.append(enemy)
	_make_labels()
	await frames()
	for kind in 3:
		_configure(kind)
		_pose(kind, 0)
		await frames()
		check(indicator.visible and indicator.available, "indicator ready " + IDS[kind])
		await capture(IDS[kind] + "_indicator")
		await export_indicator(kind, false)
		_pose(kind, [0.60, 0.42, 0.50][kind])
		await frames()
		await capture(IDS[kind] + "_effect")
		if kind == 2:
			_pose(kind, 1.15)
			await frames()
			await capture("star_tome_return_ready")
			await export_indicator(kind, true)
		if DisplayServer.get_name() != "headless" and not frames_dir.is_empty():
			var folder := frames_dir.path_join(IDS[kind])
			DirAccess.make_dir_recursive_absolute(folder)
			var samples: Array[Dictionary] = []
			for i in PREVIEW_FRAMES:
				_pose(kind, float(i) / PREVIEW_FPS)
				samples.append({"time": float(i) / PREVIEW_FPS, "player": [player.global_position.x, player.global_position.y], "slash_visible": sprites.dash_circle.visible})
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(folder.path_join("%03d.png" % i))
			var trace := FileAccess.open(folder.path_join("motion_samples.json"), FileAccess.WRITE)
			trace.store_string(JSON.stringify(samples, "\t"))
		check(failures == 0, "candidate art sequence " + IDS[kind])
	flow.enter_start_page()
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("MOBILITY_ART_REVIEW checks=%d failures=%d gpu=%s" % [checks, failures, str(DisplayServer.get_name() != "headless")])
	get_tree().quit(1 if failures else 0)


func _make_labels() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 100
	add_child(ui)
	var backing := ColorRect.new()
	backing.color = Color(0.035, 0.055, 0.065, 1.0)
	backing.size = Vector2(1280, 150)
	ui.add_child(backing)
	icon = TextureRect.new()
	icon.position = Vector2(28, 25)
	icon.size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.add_child(icon)
	title = _label(ui, Vector2(148, 23), 30, Color("e2ecdf"))
	subtitle = _label(ui, Vector2(150, 72), 20, Color("b8cecd"))
	phase = _label(ui, Vector2(150, 111), 17, Color("f0ce94"))
	var footer := _label(ui, Vector2(28, 677), 16, Color("b9c7bf"))
	footer.text = "美术动作预演 · 使用当前战斗背景与角色 · 射程和时长仅供预览，尚未接入武器逻辑"


func _label(parent: Node, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("111c20"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label


func _configure(kind: int) -> void:
	title.text = TITLES[kind]
	subtitle.text = DESCRIPTIONS[kind]
	icon.texture = textures["icons/" + IDS[kind]]
	indicator.kind = kind
	indicator.aim_offset = Vector2(140, 0) if kind != 2 else Vector2(170, -20)
	indicator.movement_distance = [140.0, 96.0, 210.0][kind]
	indicator.impact_radius = 64
	indicator.attack_range_bonus = 0
	indicator.damage_area_bonus = 0
	indicator.return_ready = false


func _pose(kind: int, t: float) -> void:
	for sprite in sprites.values(): sprite.hide()
	for pellet in pellets: pellet.hide()
	player.modulate = Color.WHITE
	player.global_position = Vector2.ZERO
	indicator.visible = t < 0.3
	indicator.return_ready = false
	indicator.global_position = Vector2.ZERO
	icon.texture = textures["icons/" + IDS[kind]]
	phase.text = "大椭圆：最大位移距离 · 小圆：伤害范围" if kind != 1 else "前方扇面：散弹范围 · 后方落点：固定后退距离"
	for i in enemies.size():
		enemies[i].global_position = Vector2(185, 0) + Vector2.from_angle(i * TAU / 4) * 43
	match kind:
		0:
			var move := travel_progress((t - 0.3) / 0.22)
			player.global_position = indicator.get_landing_offset() * move
			if t >= 0.3 and t < 0.52:
				fx("dash_trail", t-0.3, player.global_position + Vector2(-35, -4), Vector2.ONE * 0.8)
				phase.text = "短冲减速：10 → 4 → 0 · 到终点停住"
			if t >= 0.52:
				fx("dash_circle", t-0.52, player.global_position, Vector2.ONE * (indicator.get_impact_radius() / 64.0))
				phase.text = "快速圆斩 · 约 0.21 秒 · 以玩家为圆心"
		1:
			var move := travel_progress((t - 0.3) / 0.28)
			player.global_position = indicator.get_landing_offset() * move
			if t >= 0.3:
				phase.text = "前方散弹 · 后撤减速：10 → 4 → 0 · 距离不吃加成"
				fx("muzzle", t-0.3, Vector2(43, -12), Vector2.ONE * 0.7)
				fx("recoil_dust", t-0.3, player.global_position + Vector2(32, 9), Vector2.ONE * 0.85)
				if t < 0.58:
					for i in pellets.size():
						var angle := deg_to_rad((i-2)*13.0)
						pellets[i].show()
						pellets[i].position = Vector2(25, -12) + Vector2.from_angle(angle) * ((t-0.3)*460)
						pellets[i].rotation = angle
						pellets[i].scale = Vector2.ONE * 0.7
		2:
			var landing: Vector2 = indicator.get_landing_offset()
			if t >= 0.3 and t < 1.6: player.global_position = landing
			if t >= 0.3:
				phase.text = "闪现到落点 · 冲击波向外震开 · 起点印记保留"
				fx("star_depart", t-0.3, Vector2(0, -14), Vector2.ONE)
				fx("star_arrive", t-0.3, landing + Vector2(0, -14), Vector2.ONE)
				fx("star_shockwave", t-0.3, landing, Vector2.ONE * (indicator.get_impact_radius() / 64.0))
				if t < 1.6:
					fx("star_anchor", t-0.3, Vector2.ZERO, Vector2.ONE)
					icon.texture = textures["icons/star_tome_return"]
				var push := clampf((t-0.3)/0.2, 0, 1)*38
				for i in enemies.size():
					enemies[i].global_position = landing + Vector2.from_angle(i*TAU/4) * (42+push)
			if t >= 0.85 and t < 1.6:
				phase.text = "返回标记可用 · 再次触发回到起点"
				indicator.show()
				indicator.return_ready = true
				indicator.global_position = landing
				indicator.anchor_offset = -landing
			if t >= 1.6:
				phase.text = "再次触发 · 返回起点"
				fx("star_depart", t-1.6, landing + Vector2(0, -14), Vector2.ONE)
				fx("star_return", t-1.6, Vector2(0, -14), Vector2.ONE)
	indicator.queue_redraw()
	player.camera_2d.global_position = Vector2(20, -32)
	player.camera_2d.offset = Vector2.ZERO
	player.camera_2d.zoom = Vector2.ONE * 1.8
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()


static func travel_progress(time_ratio: float) -> float:
	# Integral of relative velocity 10 -> 4 over the first 80%, then 4 -> 0.
	# The integral is 6, so normalization preserves the exact requested distance.
	var u := clampf(time_ratio, 0.0, 1.0)
	if u <= 0.8:
		return (10.0 * u - 3.75 * u * u) / 6.0
	var tail := u - 0.8
	return (5.6 + 4.0 * tail - 10.0 * tail * tail) / 6.0


func _validate_revision_rules() -> void:
	var probe := INDICATOR.new()
	for kind in [INDICATOR.Kind.DASH_BLADE, INDICATOR.Kind.STAR_TOME]:
		probe.kind = kind
		probe.movement_distance = 140
		probe.aim_offset = Vector2(400, 400)
		probe.attack_range_bonus = 0
		probe.damage_area_bonus = 0
		var axes := probe.get_movement_axes()
		var impact := probe.get_impact_radius()
		check(axes.x > axes.y and is_equal_approx((probe.get_landing_offset() / axes).length(), 1.0), "diagonal destination is clamped to the maximum movement ellipse")
		probe.attack_range_bonus = 100
		var extended := probe.get_movement_axes()
		check(extended.x > axes.x and extended.y > axes.y and is_equal_approx(probe.get_impact_radius(), impact), "attack distance expands displacement ellipse without enlarging damage circle")
		var landing := probe.get_landing_offset()
		probe.damage_area_bonus = 100
		check(probe.get_impact_radius() > impact and probe.get_movement_axes() == extended and probe.get_landing_offset() == landing, "damage area expands impact without changing displacement or its endpoint")
		probe.aim_offset = Vector2(12, 8)
		check(probe.get_landing_offset().is_equal_approx(probe.aim_offset), "nearby pointer remains the selected destination")
	probe.kind = INDICATOR.Kind.RECOIL_GUN
	probe.movement_distance = 96
	probe.aim_offset = Vector2(200, -70)
	for bonus in [-100, 0, 100, 1000]:
		probe.attack_range_bonus = bonus
		probe.damage_area_bonus = bonus
		check(is_equal_approx(probe.get_landing_offset().length(), 96) and probe.get_landing_offset().dot(probe.aim_offset) < 0, "cannon retreat stays fixed and opposite aim at bonus %d" % bonus)
	probe.free()
	var previous_step := INF
	var decelerates := true
	for i in 100:
		var step := travel_progress((i+1)/100.0) - travel_progress(i/100.0)
		decelerates = decelerates and step >= 0 and step <= previous_step + 0.000001
		previous_step = step
	check(decelerates and is_equal_approx(travel_progress(1), 1) and is_equal_approx(travel_progress(2), 1) and travel_progress(-1) == 0, "travel starts fastest, continuously slows, reaches destination without overshoot")
	check(previous_step < 0.001, "last travel step brakes almost to zero before stopping")
	var slash: Dictionary = definitions.effects.dash_circle
	check(is_equal_approx(float(slash.frames) / float(slash.fps), 10.0/48.0), "circular slash now completes in about 0.21 seconds")


func fx(key: String, time: float, at: Vector2, scale_value: Vector2) -> void:
	var record: Dictionary = definitions.effects[key]
	var frame := floori(time * float(record.fps))
	if frame < 0: return
	if record.loop: frame %= int(record.frames)
	elif frame >= int(record.frames): return
	var sprite: Sprite2D = sprites[key]
	sprite.region_rect = Rect2(frame * int(record.frame_size[0]), 0, record.frame_size[0], record.frame_size[1])
	sprite.position = at
	sprite.scale = scale_value
	sprite.show()


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or capture_dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "GPU capture " + name)


func export_indicator(kind: int, returning: bool) -> void:
	if DisplayServer.get_name() == "headless" or capture_dir.is_empty(): return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var exported := INDICATOR.new()
	exported.kind = kind
	exported.position = Vector2(260, 240)
	exported.aim_offset = Vector2(140, 0) if kind != 2 else Vector2(170, -20)
	exported.movement_distance = [140.0, 96.0, 210.0][kind]
	exported.return_ready = returning
	exported.anchor_offset = Vector2(-170, 20)
	viewport.add_child(exported)
	await frames(2)
	await RenderingServer.frame_post_draw
	var suffix := "_return" if returning else ""
	# Transparent canvas capture is premultiplied; portable PNG consumers expect
	# straight alpha. Unpremultiply once here so compositing does not darken lines.
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	for offset in range(0, pixels.size(), 4):
		var alpha := int(pixels[offset + 3])
		if alpha > 0:
			for channel in 3:
				pixels[offset + channel] = mini(255, roundi(float(pixels[offset + channel]) * 255.0 / alpha))
	image = Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)
	check(image.save_png(capture_dir.path_join(IDS[kind] + suffix + "_indicator_alpha.png")) == OK, "transparent indicator " + IDS[kind] + suffix)
	viewport.queue_free()
	await frames(2)
