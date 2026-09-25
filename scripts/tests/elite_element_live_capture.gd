extends Node

var variant := "water"
var capture_dir := ""
var checks := 0
var failures := 0
var game: GameRoot
var manager: WaveManager
var player: PlayerController
var host: Node2D
var weapon: WeaponInstance
var event: DamageEvent
var target: EnemyController
var boss: EliteRusher
var probe_center := Vector2.ZERO
var probe_radius := 23.1
var probe_label: Label
var probe_results: Array = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			variant = argument.trim_prefix("--variant=")
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	if capture_dir.is_empty() or variant not in ["elite", "water", "steam", "frost", "stats", "water_range"]:
		get_tree().quit(2)
		return
	seed(250925)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	check(flow.confirm_character_selection(), "production battle initialized")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	manager = battle.wave_manager
	manager.set_process(false)
	player = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 100
	player.add_runtime_modifier({"id": "capture_pickup", "source_id": "capture", "source_type": "test", "stat": "pickup_radius", "operation": "override", "value": 0, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		enemy.free()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		runtime.queue_free()
	weapon = battle.loadout.get_weapon_instance("weapon_void_blade")
	event = DamageEvent.create({"damage": 3, "original_damage": 3, "source_weapon_id": weapon.weapon_id, "source_player": player})
	host = Node2D.new()
	player.get_parent().add_child(host)
	var origin := player.global_position
	if variant == "stats":
		var hud := battle.hud as BattleHud
		hud._set_drawer_open(true, false)
		await frames(10)
		DirAccess.make_dir_recursive_absolute(capture_dir)
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("stats_top.png"))
		hud.stats_scroll.scroll_vertical = int(hud.stats_scroll.get_v_scroll_bar().max_value)
		await frames(8)
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("stats_bottom.png"))
		check(hud.stats_drawer.size.x == 320, "original drawer width preserved")
		check(hud._stat_value_labels.size() >= 30, "all attribute rows available")
		get_tree().quit(0 if failures == 0 else 1)
		return
	if variant == "elite":
		boss = manager.spawn_enemy("enemy_elite_rusher", origin + Vector2(175, 20)) as EliteRusher
		boss.current_hp = int(boss.get_stat("max_hp"))
		# Keep the comparison creature out of the dash path.
		target = manager.spawn_enemy("enemy_mutated_grub", origin + Vector2(130, 90))
		target.set_physics_process(false)
		target.current_hp = 10000
	else:
		target = manager.spawn_enemy("enemy_mutated_grub", origin + Vector2(148, 35))
		target.set_physics_process(false)
		target.current_hp = 10000
	if variant == "water_range":
		probe_center = origin + Vector2(95, 35)
		var overlay := Node2D.new()
		overlay.z_index = 90
		host.add_child(overlay)
		overlay.draw.connect(_draw_water_probe.bind(overlay))
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		overlay.set_meta("probe_overlay", true)
		probe_label = Label.new()
		probe_label.position = Vector2(488, 205)
		probe_label.add_theme_font_size_override("font_size", 14)
		battle.hud.add_child(probe_label)
	await frames(8)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var frame_count := 240 if variant == "elite" else 180
	var peak_effect_count := 0
	var loot_seen := false
	for index in frame_count:
		match variant:
			"water_range":
				var cycle := index / 45
				var overlaps := cycle % 2 == 0
				if index % 45 == 0:
					var area_bonus := 0.0 if cycle < 2 else 100.0
					weapon.runtime_stats["damage_area_size"] = area_bonus
					probe_radius = 23.1 * (1.0 + area_bonus / 100.0)
					var body_radius: float = target.get_node("CollisionShape2D").shape.radius
					var direction := Vector2.RIGHT if cycle < 2 else Vector2.DOWN
					target.global_position = probe_center + direction * (probe_radius + body_radius + (-3.0 if overlaps else 3.0))
					target.clear_wet()
					probe_label.text = "青线：伤害范围 · 金线：敌人碰撞体\n范围 +%d%% · %s水面" % [int(area_bonus), "接触" if overlaps else "离开"]
				if index % 45 == 8:
					var hp_before := target.current_hp
					WaterWaveEffect.spawn(host, probe_center, weapon, event)
					var damaged := target.current_hp < hp_before
					check(damaged == overlaps, "water boundary cycle %d expected_hit=%s actual_hit=%s" % [cycle, overlaps, damaged])
					probe_results.append({"radius": probe_radius, "overlaps": overlaps, "damaged": damaged})
					probe_label.text += " → " + ("命中" if damaged else "未命中")
				for child in host.get_children():
					if child.has_meta("probe_overlay"):
						child.queue_redraw()
			"elite":
				if index in [36, 78, 111] and boss.is_alive():
					CombatEffectWorld._apply_wind(host, boss, weapon, event, boss.global_position, Vector2.RIGHT, "")
				if index == 78:
					boss.apply_slow(3, 0.45)
					boss.apply_lightning_stun(0.65)
				if index == 132:
					boss.take_damage(10000, weapon.weapon_id)
				loot_seen = loot_seen or not get_tree().get_nodes_in_group("relic_pickups").is_empty()
			"water":
				if index % 45 == 8:
					WaterWaveEffect.spawn(host, origin + Vector2(122, 35), weapon, event)
			"steam":
				if index % 54 == 0:
					ElementReactionResolver.apply_element(target, "fire", {"source_id": weapon.weapon_id, "original_damage": 3, "burn_tick_damage": 0})
				if index % 54 == 12:
					ElementReactionResolver.apply_element(target, "water", {"source_id": weapon.weapon_id, "original_damage": 3, "damage": 3, "parent": host})
			"frost":
				if index % 104 == 4:
					IceFieldEffect.spawn(host, origin + Vector2(116, 35), weapon, event)
		peak_effect_count = maxi(peak_effect_count, host.get_child_count())
		await RenderingServer.frame_post_draw
		var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
		if error != OK:
			get_tree().quit(3)
			return
	check(loot_seen if variant == "elite" else peak_effect_count > 0, "production effect or actual boss drop observed")
	var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"variant": variant, "production": true, "frames": frame_count, "fps": 30, "checks": checks, "failures": failures, "loot_seen": loot_seen, "boss_scale": EliteRusher.BODY_SCALE, "control_multiplier": EliteRusher.CONTROL_MULTIPLIER, "water_probes": probe_results}, "\t"))
	print("LIVE_CAPTURE ", variant, " frames=", frame_count, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _draw_water_probe(canvas: Node2D) -> void:
	# Capture-only outlines: cyan is the actual query, amber is the enemy collider.
	canvas.draw_arc(probe_center, probe_radius, 0, TAU, 64, Color(0.2, 0.95, 0.95, 0.8), 1)
	if is_instance_valid(target):
		var body_radius: float = target.get_node("CollisionShape2D").shape.radius
		canvas.draw_arc(target.global_position, body_radius, 0, TAU, 32, Color(1.0, 0.7, 0.25, 0.8), 1)
