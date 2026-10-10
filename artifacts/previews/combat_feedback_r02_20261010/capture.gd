extends Node
## Real runtime/shape contacts. Stationary high-HP targets, fixed 60 Hz simulation.
const BASE := "res://artifacts/previews/combat_feedback_r02_20261010/"
const RESPONSE = preload("res://scripts/effects/combat_feedback_r02.gd")
const WEAPONS := ["weapon_camp_dagger", "weapon_earth_hammer", "weapon_kunyu_ritual_tome", "weapon_copper_lamp"]
const CASES := [
	{"id":"dagger", "weapons":[0], "frames":36, "positions":[Vector2(36,0)]},
	{"id":"hammer", "weapons":[1], "frames":54, "positions":[Vector2(65,0),Vector2(130,4),Vector2(210,-4)]},
	{"id":"tome", "weapons":[2], "frames":48, "positions":[Vector2(65,-30),Vector2(100,28),Vector2(150,-10)]},
	{"id":"lamp", "weapons":[3], "frames":66, "positions":[Vector2(80,0),Vector2(100,24)]},
	{"id":"combo", "weapons":[0], "frames":42, "positions":[Vector2(36,-12),Vector2(36,12)]},
	{"id":"dense", "weapons":[0,1,2,3], "frames":72, "positions":[]}
]
var game: GameRoot
var battle: BattleRoot
var stage: Node2D
var targets: Array[EnemyController] = []
var sources: Array[WeaponInstance] = []
var runtimes: Array[Node2D] = []
var receipts: Array = []
var report: Dictionary = {}
var failures: Array = []
var tick := 0
var captured := 0
var graphical := false


func _ready() -> void:
	run.call_deferred()
	watchdog.call_deferred()


func watchdog() -> void:
	await get_tree().create_timer(230, true, false, true).timeout
	push_error("R02_CAPTURE_TIMEOUT")
	get_tree().quit(99)


func frames(count: int = 2) -> void:
	for i in count: await get_tree().process_frame


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
	battle.hud.set_process(false)
	AudioManager.stop_bgm()
	Engine.time_scale = 0
	for entry in CASES:
		for variant in ["before", "r02"]:
			await run_case(entry, variant)
		var before: Dictionary = report[entry.id + "_before"]
		var after: Dictionary = report[entry.id + "_r02"]
		for key in ["contacts", "health", "knockback", "rng_next"]:
			if before[key] != after[key]: failures.append(entry.id + " gameplay mismatch " + key)
		if before.hits.is_empty(): failures.append(entry.id + " no actual contacts")
	var path := "validation/gpu_capture.json" if graphical else "validation/headless.json"
	FileAccess.open(BASE + path, FileAccess.WRITE).store_string(JSON.stringify({"cases":report,"captured":captured,"failures":failures},"\t"))
	GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
	Engine.time_scale = 1
	game.queue_free()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("R02_CAPTURE_DONE frames=", captured, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func run_case(entry: Dictionary, variant: String) -> void:
	GameGlobal.set_runtime_flag(RESPONSE.SETTINGS.FLAG, variant == "r02")
	stage = Node2D.new()
	battle.player.get_parent().add_child(stage)
	targets.clear()
	sources.clear()
	runtimes.clear()
	receipts.clear()
	var positions: Array = entry.positions.duplicate()
	if entry.id == "dense":
		for row in 4:
			for col in 6: positions.append(Vector2(36 + col * 28, (row - 1.5) * 26))
	for i in positions.size():
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		stage.add_child(enemy)
		enemy.global_position = battle.player.global_position + positions[i]
		enemy.current_hp = 10000
		enemy.set_physics_process(false)
		enemy.damage_received.connect(func(id: String, amount: int): receipts.append([tick, i, id, amount]))
		targets.append(enemy)
	for index in entry.weapons:
		var source := WeaponInstance.new()
		source.initialize(WEAPONS[index], battle.player)
		source.use_active_range_rules = true
		if entry.id == "combo": source.runtime_stats.projectile_count = 3
		sources.append(source)
	var bar: ActiveCombatWeaponBar = battle.hud.combat_bar
	bar.setup(sources)
	bar.show()
	await frames(4)
	seed(61409)
	for source in sources:
		var runtime: Node2D
		if source.is_camp_dagger():
			runtime = CampDagger.new()
			stage.add_child(runtime)
			runtime.initialize(source, Vector2.RIGHT)
			runtime.configure_continuous_combo()
		elif source.is_earth_hammer():
			runtime = EarthHammer.new()
			stage.add_child(runtime)
			runtime.initialize(source, Vector2.RIGHT)
		elif source.is_ritual_tome():
			runtime = RitualDomain.new()
			stage.add_child(runtime)
			runtime.initialize(source, true)
			runtime.target_rng.seed = 4455
		else:
			runtime = CopperLamp.new()
			stage.add_child(runtime)
			runtime.initialize(source)
			runtime.externally_driven = true
			runtime.burst_active = true
			runtime.manual_control = true
			runtime.manual_direction = Vector2.RIGHT
		runtime.set_physics_process(false)
		runtimes.append(runtime)
	for f in int(entry.frames):
		for sub in 2:
			tick = f * 2 + sub
			GameGlobal.set_runtime_flag("battle_runtime_paused", false)
			# Advance existing responses first: new contact is visible in this frame.
			for enemy in targets:
				var response = enemy.get_meta(RESPONSE.META) if enemy.has_meta(RESPONSE.META) else null
				if is_instance_valid(response): response._physics_process(1.0 / 60)
			for tween in get_tree().get_processed_tweens(): tween.custom_step(1.0 / 60)
			for effect in get_tree().get_nodes_in_group("weapon_runtime_effects") + get_tree().get_nodes_in_group("combat_impacts_r02"):
				if is_instance_valid(effect) and not effect.is_queued_for_deletion() and not runtimes.has(effect) and effect.has_method("_physics_process"):
					effect._physics_process(1.0 / 60)
			for card in bar.cards:
				for child in card.get_children():
					if child.get_script() == preload("res://scripts/ui/weapon_pulse_r02.gd") and child.is_physics_processing(): child._physics_process(1.0 / 60)
			for runtime in runtimes:
				if is_instance_valid(runtime) and not runtime.is_queued_for_deletion(): runtime._physics_process(1.0 / 60)
			AudioManager._process(1.0 / 60)
			AudioManager.flush_combat_audio(true)
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		for i in sources.size():
			var executing: bool = is_instance_valid(runtimes[i]) and not runtimes[i].is_queued_for_deletion() and runtimes[i].is_attacking() if not sources[i].is_copper_lamp() else f < 54
			bar.update_slot(i, 0, 1, executing, false)
		if graphical: await capture(entry.id + "_" + variant, f, bar)
		else: await frames(1)
	var health: Array = []
	var knockback: Array = []
	var responses: Array = []
	for enemy in targets:
		health.append(enemy.current_hp)
		knockback.append([enemy._knockback_velocity.x,enemy._knockback_velocity.y,enemy._knockback_timer])
		var response = enemy.get_meta(RESPONSE.META) if enemy.has_meta(RESPONSE.META) else null
		responses.append([response.response_count,response.suppressed_count] if is_instance_valid(response) else [0,0])
	# Broad-phase query order is unspecified for colliders struck in the same tick.
	var contacts := receipts.duplicate(true)
	contacts.sort_custom(func(a: Array, b: Array): return JSON.stringify(a) < JSON.stringify(b))
	report[entry.id + "_" + variant] = {"hits":receipts.duplicate(true),"contacts":contacts,"health":health,"knockback":knockback,"rng_next":randf(),"responses":responses}
	print("R02_CLIP ", entry.id, " ", variant, " actual_hits=", receipts.size())
	stage.queue_free()
	AudioManager.stop_combat_sfx()
	await frames(3)


func capture(id: String, frame: int, bar: ActiveCombatWeaponBar) -> void:
	await frames(1)
	await RenderingServer.frame_post_draw
	var screenshot := get_tree().root.get_texture().get_image()
	var out := Image.create(620,440,false,Image.FORMAT_RGB8)
	out.fill(Color("17221f"))
	screenshot.convert(Image.FORMAT_RGB8)
	out.blit_rect(screenshot,Rect2i(440,190,620,350),Vector2i.ZERO)
	var card_rect := Rect2i(Vector2i(bar.position),Vector2i(bar.size))
	out.blit_rect(screenshot,card_rect,Vector2i(18,356))
	if out.save_png(BASE + "frames/%s_%03d.png" % [id,frame]) != OK: failures.append(id + " save")
	captured += 1
