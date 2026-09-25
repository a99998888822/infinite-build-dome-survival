extends Node

const TARGET_SCRIPT = preload("res://scripts/tests/water_review_target.gd")
const FRAMES := 180
const PAIRS := {
	"water": "", "fire": "scroll_fire", "ice": "scroll_ice",
	"chain": "scroll_lightning", "thunder": "scroll_electric_spark",
	"wind": "scroll_wind", "light": "scroll_light_sword",
	"dark": "scroll_black_hole", "explosion": "scroll_explosion",
}
var variant := "water"
var capture_dir := ""
var checks := 0
var failures := 0
var player: PlayerController
var weapon: WeaponInstance
var event: DamageEvent
var host: Node2D
var enemies: Array[EnemyController] = []
var positions: Array[Vector2] = []
var statuses: Dictionary = {}
var cues: Dictionary = {}
var water_radius := 0.0
var total_damage := 0
var hits := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)


func _run() -> void:
	if not PAIRS.has(variant):
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	seed(250926)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
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
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if effect.has_method("cancel"): effect.cancel()
	player = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 100
	weapon = battle.loadout.get_weapon_instance("weapon_void_blade")
	weapon._attached_item_instances.clear()
	var attachments := ["scroll_water"]
	if not str(PAIRS[variant]).is_empty(): attachments.append(PAIRS[variant])
	for id in attachments:
		var item: Dictionary = DataRegistry.get_record("augmentations", id).duplicate(true)
		item["item_instance_id"] = "water_review_" + str(id)
		weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()
	weapon.runtime_stats["damage_area_size"] = 0.0
	event = DamageEvent.create({"damage": 10, "original_damage": 10,
		"source_weapon_id": weapon.weapon_id, "source_player": player})
	host = Node2D.new()
	player.get_parent().add_child(host)
	var center := player.global_position + Vector2(80, 35)
	for offset in [Vector2.ZERO, Vector2(62, -42), Vector2(48, 64), Vector2(137, 8)]:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(TARGET_SCRIPT)
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 10000
		enemy.global_position = center + offset
		enemies.append(enemy)
		positions.append(enemy.global_position)
	await frames(8)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var graphical := DisplayServer.get_name() != "headless"
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for index in FRAMES:
		if index in [0, 96]: _reset_encounter()
		if index in [12, 108]:
			CombatEffectWorld.trigger_weapon_impact(host, weapon, event, center, Vector2.RIGHT, enemies[0])
			hits += 1
		_observe()
		if graphical: await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		if graphical and not capture_dir.is_empty():
			var result := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if result != OK:
				get_tree().quit(3)
				return
	for enemy in enemies: total_damage += 10000 - enemy.current_hp
	check(is_equal_approx(water_radius, 92.4), "equipped water uses radius 132 times 0.7")
	check(total_damage > 0, "real enemy damage observed")
	match variant:
		"water": check(statuses.has("wet"), "water applies wet")
		"fire": check(cues.has("steam"), "water and fire produce steam")
		"ice": check(statuses.has("frozen") and cues.has("freeze"), "water and ice freeze")
		"chain", "thunder": check(cues.has("conduct"), "wet electric conduction observed")
		"wind": check(cues.has("wet_spread"), "wind spreads wet along water ribbons")
		"light": check(statuses.has("light"), "light sword lands and applies light")
		"dark": check(statuses.has("dark"), "black hole applies dark")
		"explosion": check(total_damage > 30, "water and explosion apply damage")
	var report := {"variant": variant, "production": true, "attachments": attachments,
		"frames": FRAMES, "fps": 30, "triggered_impacts": hits, "water_radius": water_radius,
		"statuses": statuses.keys(), "reaction_cues": cues.keys(), "total_damage_last_cycle": total_damage,
		"checks": checks, "failures": failures, "encounter": "fixed positions; native status timers and knockback",
		"capture_viewport": [1152, 648], "crop": [416, 129, 480, 360]}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("WATER_COMBINATION_CAPTURE ", variant, " checks=", checks, " failures=", failures)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)


func _reset_encounter() -> void:
	for index in enemies.size():
		var enemy := enemies[index]
		enemy.global_position = positions[index]
		enemy.current_hp = 10000
		enemy.velocity = Vector2.ZERO
		enemy._knockback_timer = 0.0
		enemy.clear_wet()
		enemy.clear_burning()
		enemy.clear_light()
		enemy.clear_blind()
		enemy._slowed_remaining = 0.0
		enemy._frozen_remaining = 0.0
		enemy._stunned_remaining = 0.0


func _observe() -> void:
	for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
		if effect is WaterWaveEffect: water_radius = effect._radius
	for cue in get_tree().get_nodes_in_group("element_reaction_cues"):
		cues[cue.kind] = true
	for enemy in enemies:
		for status in ["wet", "burning", "slowed", "frozen", "stunned", "light", "dark"]:
			if enemy.has_status(status): statuses[status] = true
