extends Node
## Review fixture only: real battle ground, actor, source clips and candidate PNGs.
const BASE := "res://artifacts/previews/pixel_effects_r01_20261010/"
const CROP := Rect2i(420, 200, 440, 320)
var failures: Array[String] = []
var captured := 0
var game: GameRoot
var battle: BattleRoot
var graphical := false

func _ready() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await get_tree().create_timer(120).timeout
	push_error("PIXEL_REVIEW_TIMEOUT")
	get_tree().quit(99)

func frames(n: int = 2) -> void:
	for i in n: await get_tree().process_frame

func capture(path: String) -> void:
	if not graphical: return
	await frames()
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image().get_region(CROP)
	if img.save_png(BASE.path_join(path)) != OK: failures.append(path)
	captured += 1

func run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection(): get_tree().quit(3); return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.active_controller.indicator.hide()
	battle.active_controller.cursor_icon.hide()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(15)
	battle.combat_guide.hide()
	await capture("renders/background.png")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	for key: String in manifest.effects:
		var definition: Dictionary = manifest.effects[key]
		for variant in ["baseline", "candidate"]:
			var weapon := WeaponInstance.new()
			weapon.initialize("weapon_meteor_flail" if key == "flail_trail" else "weapon_star_tome" if key.begins_with("star") else "weapon_dash_blade", battle.player)
			weapon.use_active_range_rules = true
			var stage: Node2D
			var sprite: Sprite2D
			if key == "flail_trail":
				var flail: MeteorFlail = load(BASE + "candidate_flail.gd").new() if variant == "candidate" else MeteorFlail.new()
				battle.player.get_parent().add_child(flail)
				flail.initialize(weapon, Vector2.RIGHT)
				flail.set_physics_process(false)
				stage = flail
			elif key == "wind_blade":
				if variant == "baseline":
					var wind := WindBladeEffect.new()
					battle.player.get_parent().add_child(wind)
					wind.set_process(false)
					stage = wind
				else:
					sprite = Sprite2D.new()
					sprite.texture = ImageTexture.create_from_image(Image.load_from_file(BASE + str(definition.candidate)))
					sprite.hframes = int(definition.frames)
					battle.player.get_parent().add_child(sprite)
					stage = sprite
				stage.global_position = battle.player.global_position + Vector2(48,0)
				stage.z_index = 40
			else:
				var scale_xy := Vector2(1.1, 1.1 * AttackFootprint.ELLIPSE_RATIO) if key == "dash_circle" else Vector2.ONE
				var point := battle.player.global_position + (Vector2(100,0) if key == "star_anchor" else Vector2.ZERO)
				var effect := MobilityAtlasEffect.spawn(battle.player.get_parent(), weapon, key, point, 0, scale_xy)
				effect.set_physics_process(false)
				sprite = effect
				stage = effect
				if variant == "candidate":
					sprite.texture = ImageTexture.create_from_image(Image.load_from_file(BASE + str(definition.candidate)))
					if sprite.texture.get_width() != int(definition.cell[0]) * int(definition.frames): failures.append(key + " width")
			stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			for i in int(definition.frames):
				var at_time := (i + 0.5) / float(definition.fps)
				if stage is MeteorFlail:
					var flail := stage as MeteorFlail
					flail.age = at_time
					var trail: Array = []
					for j in range(1, 5):
						var before := at_time - j / 60.0
						if before >= MeteorFlail.WINDUP and before <= MeteorFlail.WINDUP + MeteorFlail.SWEEP:
							trail.append({"point":flail.head_position(flail.swings[0],before),"time":before})
					flail.swings[0].trail = trail
					flail.queue_redraw()
				elif stage is WindBladeEffect:
					(stage as WindBladeEffect)._elapsed = at_time
					stage.queue_redraw()
				else: sprite.frame = i
				await capture("godot_frames/%s_%s_%02d.png" % [key,variant,i])
			stage.queue_free()
			await frames(2)
		print("PIXEL_REVIEW_CLIP ", key, " frames=", definition.frames)
	# Existing copper lamp is the reference, captured from its production shader.
	var flame: Node2D = load("res://scripts/effects/copper_lamp_flame.gd").new()
	battle.player.get_parent().add_child(flame)
	flame.global_position = battle.player.global_position
	flame.z_index = 40
	for i in 18:
		flame.configure(Vector2.RIGHT, 120, 60, i / 18.0, false)
		await capture("godot_frames/lamp_reference_%02d.png" % i)
	flame.queue_free()
	FileAccess.open(BASE + ("gpu_capture.json" if graphical else "headless.json"), FileAccess.WRITE).store_string(JSON.stringify({"captured":captured,"failures":failures,"fixture":"controlled frame sampling; no combat timing or balance changes"},"\t"))
	print("PIXEL_REVIEW_DONE captured=",captured," failures=",failures.size())
	game.queue_free()
	await frames(5)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await frames(20)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
