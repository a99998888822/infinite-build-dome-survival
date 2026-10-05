extends Node
## Controlled encounters in the production battle; no replacement effect assets.
const TARGET = preload("res://scripts/tests/water_review_target.gd")
const R = preload("res://scripts/effects/element_reaction_resolver.gd")
const SIZE := Vector2i(1152, 648)
const SECONDS := 4.8
const CAPTURE_FPS := 20.0
var output := ""
var cases_path := ""
var only := ""
var no_capture := false
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var weapon: WeaponInstance
var enemies: Array[EnemyController] = []
var host: Node2D
var center := Vector2.ZERO
var caption: Label
var counter: Label
var failures := 0
var summary: Array = []
var observations: Dictionary
var observed_ids: Dictionary
var phase := ""
var current_time := 0.0

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--cases="): cases_path = arg.trim_prefix("--cases=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--no-capture": no_capture = true
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func _run() -> void:
	if output.is_empty() or cases_path.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	for entry: Dictionary in cases:
		if not only.is_empty() and str(entry.id) != only: continue
		var directory := output.path_join(entry.id)
		DirAccess.make_dir_recursive_absolute(directory)
		await _setup(entry)
		var measurement := await _exercise(entry, "", false)
		await _cleanup()
		var capture := {}
		if not no_capture and DisplayServer.get_name() != "headless":
			await _setup(entry)
			capture = await _exercise(entry, directory, true)
			await _cleanup()
		var row := {"id": entry.id, "measurement": measurement, "capture": capture}
		FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(row, "\t"))
		summary.append(row)
		print("INTERACTION_CASE ", entry.id, " fps=", measurement.fps, " cues=", measurement.cues, " failures=", failures)
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "\t"))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("INTERACTION_REVIEW_COMPLETE cases=", summary.size(), " failures=", failures)
	get_tree().quit(1 if failures else 0)

func _setup(entry: Dictionary) -> void:
	seed(4102026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = SIZE
	get_tree().root.content_scale_size = SIZE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection(): push_error("Cannot enter production battle"); get_tree().quit(3); return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 9999
	weapon = battle.loadout.get_weapon_instance("weapon_void_blade")
	weapon._attached_item_instances.clear()
	weapon._rebuild_attachment_effects()
	player.camera_2d.offset = Vector2(90, -8)
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	host = Node2D.new()
	player.get_parent().add_child(host)
	center = player.global_position + Vector2(125, 15)
	enemies.clear()
	for offset in [Vector2.ZERO, Vector2(90, 0), Vector2(0, 88), Vector2(-60, 65), Vector2(150, -30), Vector2(-60, -42)]:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(TARGET)
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 10000
		enemy.global_position = center + offset
		enemies.append(enemy)
	var layer := CanvasLayer.new()
	layer.layer = 80
	game.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(12, 96)
	backdrop.size = Vector2(760, 74)
	backdrop.color = Color(0.02, 0.03, 0.025, 0.82)
	layer.add_child(backdrop)
	caption = Label.new()
	caption.position = Vector2(22, 98)
	caption.add_theme_font_size_override("font_size", 20)
	caption.text = str(entry.title)
	layer.add_child(caption)
	counter = Label.new()
	counter.position = Vector2(22, 131)
	counter.add_theme_font_size_override("font_size", 16)
	layer.add_child(counter)
	var perf: Label = battle.hud._performance_line
	perf.add_theme_font_size_override("font_size", 16)
	perf.add_theme_color_override("font_color", Color.WHITE)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await get_tree().create_timer(1.0).timeout

func _cast(action: Dictionary) -> void:
	var ids: Array = action.spells
	weapon._attached_item_instances.clear()
	for id in ids:
		var item: Dictionary = DataRegistry.get_record("augmentations", "scroll_" + str(id)).duplicate(true)
		item["item_instance_id"] = "interaction_review_" + str(id)
		weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()
	var target: EnemyController = enemies[int(action.get("target", 0))]
	var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": weapon.weapon_id, "source_player": player})
	var fields := {}
	if ids.has("wind"):
		for group in ["fire_patches", "ice_fields"]:
			for field in get_tree().get_nodes_in_group(group): fields[field] = field._radius
	CombatEffectWorld.trigger_weapon_impact(host, weapon, event, target.global_position, Vector2.RIGHT, target)
	for field in fields:
		if field._radius > fields[field]:
			observations["wind_expanded_fire" if field is FirePatch else "wind_expanded_ice"] = true
	phase = str(action.label)

func _exercise(entry: Dictionary, directory: String, capture: bool) -> Dictionary:
	observations = {"cues": {}, "statuses": {}, "kinds": {}, "cue_events": {}, "cue_timeline": [], "particles_peak": 0, "cues_peak": 0, "tongues_peak": 0, "fire_radius_max": 0.0, "ice_radius_max": 0.0, "fire_radius_first": 0.0, "ice_radius_first": 0.0, "palettes": {}, "field_palettes": {}, "damage_labels": {}, "cancel_cleared": false, "conduct_followed": false}
	observed_ids = {}
	observations["conduct_patterns"] = {}
	observations["conduct_duration"] = 0.0
	observations["conduct_max_age"] = 0.0
	var samples: Array = []
	var times: Array[float] = []
	var frame_stamps: Array[float] = []
	var image_file: FileAccess
	if capture: image_file = FileAccess.open(directory.path_join("frames.rgb"), FileAccess.WRITE)
	var start := Time.get_ticks_usec()
	var previous := start
	var next_capture := 0.0
	var next_sample := 0.0
	var action_index := 0
	phase = "准备触发"
	while Time.get_ticks_usec() - start < int(SECONDS * 1e6):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - start) / 1e6
		current_time = elapsed
		times.append(float(now - previous) / 1000.0)
		previous = now
		while action_index < entry.actions.size() and elapsed >= float(entry.actions[action_index].time):
			_cast(entry.actions[action_index])
			action_index += 1
		_observe()
		if elapsed >= next_sample:
			battle.hud._performance_line.refresh()
			var sample: Dictionary = battle.hud._performance_line.sample.duplicate()
			sample.time = elapsed
			samples.append(sample)
			next_sample = elapsed + 0.1
			counter.text = "%s  |  提示 %d · 网格特效 %d · 火舌 %d" % [phase, get_tree().get_nodes_in_group("element_reaction_cues").size(), get_tree().get_nodes_in_group("pixel_combat_effects").size(), _tongues()]
		if capture and elapsed >= next_capture:
			await RenderingServer.frame_post_draw
			var image := get_tree().root.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			image_file.store_buffer(image.get_data())
			frame_stamps.append(float(Time.get_ticks_usec() - start) / 1e6)
			next_capture = elapsed + 1.0 / CAPTURE_FPS
	if capture: image_file.close()
	var duration := float(Time.get_ticks_usec() - start) / 1e6
	var damage := 0
	for enemy in enemies: damage += 10000 - enemy.current_hp
	var passed: bool = damage > 0 and action_index == entry.actions.size()
	for cue in entry.get("expect_cues", []): passed = passed and observations.cues.has(cue)
	for cue in entry.get("forbid_cues", []): passed = passed and not observations.cues.has(cue)
	if entry.has("expect_palette"):
		passed = passed and observations.palettes.has(str(int(entry.expect_palette))) and observations.field_palettes.has(str(int(entry.expect_palette)))
	if entry.id == "cancel": passed = passed and observations.statuses.has("light") and observations.cancel_cleared
	if entry.id in ["water_chain", "water_spark"]:
		passed = passed and observations.conduct_followed and is_equal_approx(observations.conduct_duration, 1.1) and observations.conduct_max_age >= 1.0
		if DisplayServer.get_name() != "headless": passed = passed and observations.conduct_patterns.size() >= 5
	if entry.id in ["fire_chain", "fire_spark"]: passed = passed and observations.particles_peak >= 96
	for label in observations.damage_labels: passed = passed and str(label).is_valid_int()
	for status in entry.get("expect_statuses", []): passed = passed and observations.statuses.has(status)
	for kind in entry.get("expect_kinds", []): passed = passed and observations.kinds.has(kind)
	if entry.id == "wind_steam":
		passed = passed and observations.cue_timeline.any(func(cue): return cue.kind == "steam" and cue.time >= 1.7)
	if entry.get("expand", "") == "fire": passed = passed and observations.get("wind_expanded_fire", false)
	if entry.get("expand", "") == "ice": passed = passed and observations.get("wind_expanded_ice", false)
	if not passed: failures += 1; push_error("Missing expected production reaction: " + str(entry.id))
	times.sort()
	var result := observations.duplicate(true)
	result.merge({"fps": times.size() / duration, "p95_ms": times[int(times.size() * 0.95)], "duration": duration, "damage": damage, "samples": samples, "frames": frame_stamps.size(), "frame_times": frame_stamps, "size": [SIZE.x, SIZE.y], "passed": passed})
	return result

func _tongues() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("pixel_fire_visuals"): count += node.tongue_count
	return count

func _observe() -> void:
	var particles := 0
	for source in get_tree().get_nodes_in_group("combat_particle_counters"):
		if not source.is_queued_for_deletion(): particles += source.get_active_particle_count()
	observations.particles_peak = maxi(observations.particles_peak, particles)
	var cues := get_tree().get_nodes_in_group("element_reaction_cues")
	observations.cues_peak = maxi(observations.cues_peak, cues.size())
	observations.tongues_peak = maxi(observations.tongues_peak, _tongues())
	for cue in cues:
		observations.cues[cue.kind] = true
		if not observed_ids.has(cue.get_instance_id()):
			observed_ids[cue.get_instance_id()] = true
			observations.cue_events[cue.kind] = int(observations.cue_events.get(cue.kind, 0)) + 1
			observations.cue_timeline.append({"kind": cue.kind, "time": current_time})
	for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
		observations.kinds[effect.get_meta("pixel_effect_kind", "unknown")] = true
	for flame in get_tree().get_nodes_in_group("pixel_fire_visuals"):
		observations.palettes[str(flame.palette)] = true
		if flame.get_parent() is FirePatch: observations.field_palettes[str(flame.palette)] = true
	for node in host.get_children():
		if node is Label: observations.damage_labels[node.text] = true
	if current_time > 1.55 and observations.statuses.has("light") and not enemies[0].has_status("light") and not enemies[0].has_status("dark"):
		observations.cancel_cleared = true
	for cue in cues:
		if cue.kind == "conduct" and cue.options.has("follow"):
			observations.conduct_duration = maxf(observations.conduct_duration, cue.duration)
			observations.conduct_max_age = maxf(observations.conduct_max_age, cue.elapsed)
			if not cue._conduct_cells.is_empty(): observations.conduct_patterns[str(hash(cue._conduct_cells))] = true
			var followed: Node2D = cue.options.follow.get_ref()
			if is_instance_valid(followed) and cue.global_position.distance_to(followed.global_position) < 8.0:
				observations.conduct_followed = true
	for enemy in enemies:
		for status in ["wet", "burning", "slowed", "frozen", "stunned", "light", "dark", "holy_flame", "dark_flame"]:
			if enemy.has_status(status): observations.statuses[status] = true
	for field in get_tree().get_nodes_in_group("fire_patches"):
		if observations.fire_radius_first == 0.0: observations.fire_radius_first = field._radius
		observations.fire_radius_max = maxf(observations.fire_radius_max, field._radius)
	for field in get_tree().get_nodes_in_group("ice_fields"):
		if observations.ice_radius_first == 0.0: observations.ice_radius_first = field._radius
		observations.ice_radius_max = maxf(observations.ice_radius_max, field._radius)

func _cleanup() -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	enemies.clear()
	weapon = null
	game.queue_free()
	await frames(12)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
