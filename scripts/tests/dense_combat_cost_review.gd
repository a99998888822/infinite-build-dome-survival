extends Node
## Real 1920x1080 battle, diagnostic-only ablations, no readback during timing.
const COST = preload("res://scripts/tests/fixtures/dense_cost_counters.gd")
const GRUB = preload("res://scripts/tests/fixtures/dense_profiled_grub.gd")
const BAT = preload("res://scripts/tests/fixtures/dense_profiled_bat.gd")
const DRIVER = preload("res://scripts/tests/fixtures/dense_backdrop_driver.gd")
const NODE_DRIVER = preload("res://scripts/tests/fixtures/dense_node_driver.gd")
const PHYSICS_DRIVER = preload("res://scripts/tests/fixtures/dense_physics_driver.gd")
const WEAPONS := ["void_blade", "plasma_cannon", "iron_grenade_cannon", "kunyu_ritual_tome", "rentier_purse", "copper_lamp", "mutant_tentacle", "earth_hammer", "camp_dagger", "nightwatch_spear", "meteor_flail", "dash_blade", "hand_cannon", "star_tome"]
const SPELLS := {
	"baseline": [], "fire": [["fire"]], "water": [["water"]], "ice": [["ice"]],
	"lightning": [["lightning"]], "electric_spark": [["electric_spark"]],
	"wind": [["wind"]], "light_sword": [["light_sword"]],
	"black_hole": [["black_hole"]], "explosion": [["explosion"]],
	"fire_chain": [["fire"], ["lightning"]], "fire_spark": [["fire"], ["electric_spark"]],
	"reflection": [["water"], ["ice"], ["light_sword"]],
	"holy": [["fire"], ["light_sword"]], "dark": [["fire"], ["black_hole"]],
	"freeze": [["water"], ["ice"]], "steam": [["fire"], ["water"]]
}
var suite := "subsystems"
var only := ""
var output := "user://dense_combat_cost_metrics.json"
var repeats := 1
var quick := false
var game: GameRoot
var battle: BattleRoot
var backdrop: CavernSunlightBackdrop
var host: Node2D
var enemies: Array[EnemyController] = []
var weapon: WeaponInstance
var rows: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var casts: Array[Dictionary] = []
var feedback: Array[Dictionary] = []
var telemetry: Array[Dictionary] = []
var measuring := false
var started := 0
var previous := 0
var failures: Array[String] = []
var active_entry: Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		if arg.begins_with("--repeats="): repeats = int(arg.trim_prefix("--repeats="))
		if arg == "--quick": quick = true
	RenderingServer.frame_post_draw.connect(sample_frame)
	CombatHitFeedback.feedback_started.connect(on_feedback)
	run.call_deferred()

func frames(count := 1) -> void:
	for i in count: await get_tree().process_frame

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless": sample_frame()

func on_feedback(tier: int, count: int) -> void:
	if measuring: feedback.append({"time": float(Time.get_ticks_usec() - started) / 1e6, "tier": tier, "count": count})

func sample_frame() -> void:
	if not measuring: return
	var now := Time.get_ticks_usec()
	samples.append({"time": float(now - started) / 1e6, "frame_ms": float(now - previous) / 1000.0,
		"enemy_ms": COST.enemy_usec / 1000.0, "damage_ms": COST.damage_usec / 1000.0,
		"backdrop_ms": COST.backdrop_usec / 1000.0, "hits": COST.hits,
		"particle_ms": COST.particle_usec / 1000.0, "scheduler_ms": COST.scheduler_usec / 1000.0, "feedback_ms": COST.feedback_usec / 1000.0,
		"weapon_ms": COST.weapon_usec / 1000.0, "weapon_draw_ms": COST.weapon_draw_usec / 1000.0,
		"reflection_ms": COST.reflection_usec / 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"numbers": EnemyController.active_damage_numbers, "tasks": EffectScheduler._order.size(),
		"paused": get_tree().paused})
	previous = now
	COST.reset()

func case_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if suite == "subsystems":
		for count in [0, 48, 96, 192]: result.append({"id": "enemies_%d" % count, "count": count})
		for variant in ["no_grass", "no_backdrop_cpu", "no_enemy_physics", "no_enemy_visuals", "move", "move_no_grass"]:
			result.append({"id": variant, "count": 96, "variant": variant})
	elif suite == "weapons":
		for id in WEAPONS: result.append({"id": id, "count": 96, "weapon": "weapon_" + id})
	elif suite == "enchantments":
		for id in SPELLS: result.append({"id": id, "count": 96, "stages": SPELLS[id], "fixed": true})
	elif suite == "builds":
		for id in ["plasma_cannon", "copper_lamp", "kunyu_ritual_tome", "iron_grenade_cannon"]:
			result.append({"id": id + "_fire_chain", "count": 96, "weapon": "weapon_" + id, "attach": ["fire", "lightning"]})
		result.append({"id": "plasma_split_chain", "count": 96, "weapon": "weapon_plasma_cannon", "attach": ["split", "lightning"]})
		result.append({"id": "bow_multishot_bounce", "count": 96, "weapon": "weapon_void_blade", "attach": ["multishot", "bounce"]})
		result.append({"id": "lamp_split_fire_chain", "count": 96, "weapon": "weapon_copper_lamp", "attach": ["split", "fire", "lightning"]})
		result.append({"id": "plasma_fire_spark", "count": 96, "weapon": "weapon_plasma_cannon", "attach": ["fire", "electric_spark"]})
		result.append({"id": "plasma_reflection", "count": 96, "weapon": "weapon_plasma_cannon", "attach": ["water", "ice", "light_sword"]})
	elif suite == "ablations":
		for variant in ["normal", "no_numbers", "no_hit_visual", "no_feedback", "no_thunder_visuals", "no_grass", "no_backdrop_cpu"]:
			result.append({"id": variant, "count": 96, "stages": SPELLS.fire_spark, "fixed": true, "variant": variant})
	elif suite == "ritual":
		for variant in ["normal", "no_domain_drawing", "no_enemy_physics", "no_grass"]:
			result.append({"id": variant, "count": 96, "weapon": "weapon_kunyu_ritual_tome", "variant": variant})
	elif suite == "reflection":
		for variant in ["normal", "no_reflection_visuals"]:
			result.append({"id": variant, "count": 96, "weapon": "weapon_plasma_cannon", "attach": ["water", "ice", "light_sword"], "variant": variant})
	return result

func run() -> void:
	CampProgression.begin_transient_session()
	profile_node(EffectScheduler, "scheduler")
	profile_node(CombatHitFeedback, "feedback")
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("keyboard_movement", true, false)
	for id in WEAPONS: CombatSettings.set_weapon_auto_cast("weapon_" + id, false, false)
	for repeat in repeats:
		var entries := case_list()
		if repeat % 2 == 1: entries.reverse()
		for entry in entries:
			if not only.is_empty() and not str(entry.id) in only.split(","): continue
			await exercise(entry, repeat)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("DENSE_COST_COMPLETE rows=", rows.size(), " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func profile_node(node: Node, category: String) -> void:
	if node.has_meta("dense_profiled"): return
	node.set_meta("dense_profiled", true)
	var driver := NODE_DRIVER.new()
	driver.category = category
	driver.process_priority = node.process_priority
	node.set_process(false)
	node.add_child(driver)

func profile_runtime() -> void:
	if suite == "reflection":
		for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
			if effect is LightReflectionEffect:
				profile_node(effect, "reflection")
				if str(active_entry.get("variant", "")) == "no_reflection_visuals": effect.hide()
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if node.has_meta("dense_physics_profiled") or not node.has_method("_physics_process"): continue
		node.set_meta("dense_physics_profiled", true)
		var driver := PHYSICS_DRIVER.new()
		driver.process_physics_priority = node.process_physics_priority
		node.set_physics_process(false)
		node.add_child(driver)
		if node is RitualDomain:
			if str(active_entry.get("variant", "")) == "no_domain_drawing": node.domain_layer.hide()
			else:
				node.domain_layer.draw.disconnect(node._draw_domain)
				node.domain_layer.draw.connect(profile_domain_draw.bind(node))

func profile_domain_draw(domain: RitualDomain) -> void:
	var before := Time.get_ticks_usec()
	domain._draw_domain()
	COST.weapon_draw_usec += Time.get_ticks_usec() - before

func setup(entry: Dictionary) -> void:
	seed(19102026)
	COST.no_numbers = str(entry.get("variant", "")) == "no_numbers"
	COST.no_hit_visual = str(entry.get("variant", "")) == "no_hit_visual"
	GameGlobal.set_runtime_flag("thunder_fire_visual_mode", "off" if str(entry.get("variant", "")) == "no_thunder_visuals" else "adaptive")
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_window().unfocusable = true
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu._on_start_battle_pressed()
	await frames(4)
	menu._on_character_confirm_pressed()
	await menu.dungeon_loading.finished
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player._invincibility_timer = 99999.0
	# Crowd contact can displace a player even with no input. Lock stationary
	# subsystem/element controls so they see identical terrain; weapon/move
	# cases retain the real player physics and any camera streaming it causes.
	if not entry.has("weapon") and not str(entry.get("variant", "")).begins_with("move"):
		battle.player.set_physics_process(false)
	host = battle.loadout._get_visual_root() as Node2D
	backdrop = host.get_node("Backdrop") as CavernSunlightBackdrop
	backdrop.set_process(false)
	var driver := DRIVER.new()
	backdrop.add_child(driver)
	driver.set_process(str(entry.get("variant", "")) != "no_backdrop_cpu")
	backdrop.profile_enabled = true
	for old in battle.loadout.get_weapon_instances(): battle.loadout.remove_weapon(old.weapon_id)
	var id := str(entry.get("weapon", "weapon_void_blade"))
	if not battle.loadout.equip_weapon(id): failures.append("equip failed: " + id)
	weapon = battle.loadout.get_weapon_instance(id)
	while weapon.get_attachment_slot_count() < entry.get("attach", []).size():
		if not weapon.upgrade(): failures.append("cannot unlock attachment slots: " + id); break
	attach(entry.get("attach", []))
	enemies.clear()
	for i in int(entry.count):
		var bat := i % 10 >= 7 and not bool(entry.get("fixed", false))
		var enemy := load("res://scenes/enemy/echo_bat.tscn" if bat else "res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(entry.get("enemy_script", BAT if bat else GRUB))
		host.add_child(enemy)
		enemy.initialize("enemy_echo_bat" if bat else "enemy_mutated_grub", battle.player)
		if bool(entry.get("fixed", false)):
			enemy.global_position = battle.player.global_position + Vector2(130 + (i % 12 - 5.5) * 20, 40 + (i / 12 - 3.5) * 20)
			enemy.add_runtime_modifier({"id": "diagnostic_stationary", "source_type": "test", "source_id": "dense_cost", "target_scope": "enemy", "stat": "move_speed", "operation": "multiply", "value": 0.0, "duration": -1.0, "stack_rule": "unique"})
		else:
			var angle := float(i % 32) / 32.0 * TAU
			enemy.global_position = battle.player.global_position + Vector2.from_angle(angle) * (80.0 + float(i / 32) * 65.0)
		enemy.current_hp = 1000000
		enemy.visible = str(entry.get("variant", "")) != "no_enemy_visuals"
		enemies.append(enemy)
	CombatHitFeedback.active = str(entry.get("variant", "")) != "no_feedback"
	await get_tree().create_timer(1.0, true).timeout
	if str(entry.get("variant", "")) == "no_enemy_physics":
		for enemy in enemies: enemy.set_physics_process(false)
	if str(entry.get("variant", "")).contains("no_grass"): hide_grass()
	backdrop.update_profile.clear()
	COST.reset()

func attach(ids: Array) -> void:
	weapon._attached_item_instances.clear()
	weapon._rebuild_attachment_effects()
	for id in ids:
		var item := DataRegistry.get_record("augmentations", "scroll_" + str(id)).duplicate(true)
		if item.is_empty(): failures.append("unknown spell: " + str(id)); continue
		item.item_instance_id = "dense_cost_" + str(id)
		if not weapon.attach_item_instance(item): failures.append("cannot attach: " + str(id))

func hide_grass() -> void:
	for group: Dictionary in backdrop.grass_cells.values():
		for band: Dictionary in group.bands:
			band.back.hide()
			band.front.hide()

func move_input(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = pressed
	Input.parse_input_event(event)

func exercise(entry: Dictionary, repeat: int) -> void:
	active_entry = entry
	await setup(entry)
	var seconds := 12.0 if entry.has("weapon") else 8.0
	if quick: seconds = 2.0
	samples.clear()
	casts.clear()
	feedback.clear()
	telemetry.clear()
	started = Time.get_ticks_usec()
	previous = started
	measuring = true
	if str(entry.get("variant", "")).begins_with("move"): move_input(true)
	var next_impact := 0.0
	var sequence_index := 0
	var next_telemetry := 0.0
	var previous_cells := backdrop.cell_rect
	while Time.get_ticks_usec() - started < int(seconds * 1e6):
		await frames()
		var elapsed := float(Time.get_ticks_usec() - started) / 1e6
		if elapsed >= next_telemetry:
			next_telemetry = elapsed + 0.25
			var particles := 0
			for world in get_tree().get_nodes_in_group("particle_worlds"):
				particles += world.get_active_particle_count()
				profile_node(world, "particle")
			var kinds := {}
			for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
				var kind := str(effect.get_meta("pixel_effect_kind", "unknown"))
				kinds[kind] = int(kinds.get(kind, 0)) + 1
			telemetry.append({"time": elapsed, "particles": particles, "effects": kinds, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
		if get_tree().paused: continue
		if entry.has("weapon") and battle.loadout.active_casting.can_cast(weapon) and not weapon.is_return_ready():
			var target := battle.loadout.active_casting._auto_target(weapon)
			if target != null or weapon.is_mobility_weapon():
				var point := weapon.get_auto_target_position(target) if target != null else battle.player.global_position + Vector2(150, 0)
				var before := Time.get_ticks_usec()
				var fired := battle.loadout.cast_weapon(weapon, point)
				if fired: casts.append({"time": elapsed, "cpu_ms": float(Time.get_ticks_usec() - before) / 1000.0})
		if entry.has("stages") and not entry.stages.is_empty() and elapsed >= next_impact:
			var stages: Array = entry.stages
			var stage := sequence_index % stages.size()
			attach(stages[stage])
			var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": weapon.weapon_id, "source_player": battle.player})
			var target := enemies[54]
			var before := Time.get_ticks_usec()
			CombatEffectWorld.trigger_weapon_impact(host, weapon, event, target.global_position, Vector2.RIGHT, target)
			casts.append({"time": elapsed, "cpu_ms": float(Time.get_ticks_usec() - before) / 1000.0})
			sequence_index += 1
			next_impact += 0.1 if stage + 1 < stages.size() else 0.5 - 0.1 * (stages.size() - 1)
		if str(entry.get("variant", "")) == "move_no_grass" and backdrop.cell_rect != previous_cells:
			hide_grass()
			previous_cells = backdrop.cell_rect
		if str(entry.get("variant", "")) == "no_particles":
			for world in get_tree().get_nodes_in_group("particle_worlds"): world.hide()
		profile_runtime()
	measuring = false
	move_input(false)
	var warm := 3.0 if not entry.has("weapon") else 2.0
	if quick: warm = 0.0
	var warm_samples: Array[Dictionary] = []
	var cold_samples: Array[Dictionary] = []
	var hit_count := 0
	for sample in samples:
		hit_count += int(sample.hits)
		if float(sample.time) >= warm: warm_samples.append(sample)
		else: cold_samples.append(sample)
	var row := {"id": entry.id, "repeat": repeat, "config": entry, "warmup_seconds": warm,
		"weapon_level": weapon.level, "attachment_slots": weapon.get_attachment_slot_count(),
		"steady": summarize(warm_samples), "first_window": summarize(cold_samples),
		"casts": casts.duplicate(true), "hits": hit_count, "feedback": feedback.duplicate(true), "telemetry": telemetry.duplicate(true),
		"grass": grass_stats(), "lit_objects": backdrop.lit_objects.size(),
		"player_end": [battle.player.global_position.x, battle.player.global_position.y],
		"native_world_size": [game._world_viewport.size.x, game._world_viewport.size.y],
		"headless": DisplayServer.get_name() == "headless", "samples": samples.duplicate(true),
		"terrain_updates": backdrop.update_profile.duplicate(true)}
	if entry.has("weapon") and (casts.is_empty() or hit_count == 0): failures.append(str(entry.id) + " did not cast/hit")
	rows.append(row)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"suite": suite, "rows": rows, "failures": failures,
		"renderer": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info()}, "\t"))
	print("DENSE_COST ", entry.id, " repeat=", repeat, " steady=", JSON.stringify(row.steady), " first=", JSON.stringify(row.first_window), " casts=", casts.size(), " hits=", hit_count)
	await cleanup()

func grass_stats() -> Dictionary:
	var stats := {"cells": backdrop.cells.size(), "grass_loaded": 0, "grass_batch_nodes": 0}
	for group: Dictionary in backdrop.grass_cells.values():
		stats.grass_loaded += group.blades.size()
		stats.grass_batch_nodes += group.bands.size() * 2
	return stats

func summarize(values: Array[Dictionary]) -> Dictionary:
	if values.is_empty(): return {}
	var result := {"frames": values.size(), "over_33": 0, "over_50": 0, "over_100": 0, "paused_frames": 0}
	for key in ["frame_ms", "enemy_ms", "damage_ms", "backdrop_ms", "particle_ms", "scheduler_ms", "feedback_ms", "weapon_ms", "weapon_draw_ms", "reflection_ms", "process_ms", "physics_ms", "draw_calls", "numbers", "tasks"]:
		var numbers: Array[float] = []
		var total := 0.0
		for row in values:
			var value := float(row[key])
			numbers.append(value)
			total += value
		numbers.sort()
		result[key] = {"mean": total / numbers.size(), "p50": numbers[numbers.size() / 2], "p95": numbers[int(numbers.size() * 0.95)], "p99": numbers[int(numbers.size() * 0.99)], "max": numbers.back()}
	for row in values:
		if row.frame_ms > 33.33: result.over_33 += 1
		if row.frame_ms > 50.0: result.over_50 += 1
		if row.frame_ms > 100.0: result.over_100 += 1
		if row.paused: result.paused_frames += 1
	return result

func cleanup() -> void:
	CombatHitFeedback.clear()
	COST.no_numbers = false
	COST.no_hit_visual = false
	GameGlobal.set_runtime_flag("thunder_fire_visual_mode", "adaptive")
	game.get_main_flow_coordinator().enter_start_page()
	await frames(8)
	game.queue_free()
	await frames(4)
	enemies.clear()
