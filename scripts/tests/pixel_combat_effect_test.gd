extends Node2D

# Run this scene headlessly. Optional -- --snapshot-path=<path> exports the
# gameplay state for comparison against an earlier revision.

var checks := 0
var failures := 0
var enemies: Array[EnemyController] = []
var result_log: Array = []
var weapon: WeaponInstance
var event: DamageEvent
var host: Node2D

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS ", label)

func frames() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func setup(positions: Array, parameters: Dictionary = {}) -> void:
	if is_instance_valid(host):
		host.queue_free()
		await frames()
	host = Node2D.new()
	add_child(host)
	enemies.clear()
	for position in positions:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		host.add_child(enemy)
		enemy.position = position
		enemy.current_hp = 10000
		enemy.set_physics_process(false)
		enemies.append(enemy)
	weapon = WeaponInstance.new()
	weapon.weapon_id = "pixel_test"
	weapon.weapon_data = {"hit_radius": 14.0, "tags": []}
	weapon.runtime_stats = {"area_size": 0.0, "damage_area_size": 0.0}
	weapon._attached_item_instances = [{"effect_parameters": parameters}]
	event = DamageEvent.create({"damage": 100, "original_damage": 100, "source_weapon_id": "pixel_test"})
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()

func spawn_effect(kind: String) -> Node2D:
	var effect_id := "water" if kind == "water_wave" else ("wind" if kind == "wind_blade" else kind)
	weapon._attached_item_instances[0]["effect_ids"] = [effect_id]
	var script: Script = load("res://scripts/effects/" + kind + "_effect.gd")
	if kind == "wind_blade":
		script.spawn(host, Vector2.ZERO, Vector2.RIGHT, 480.0, 0.46, weapon, event, enemies[0].get_instance_id())
	else:
		script.spawn(host, Vector2.ZERO, weapon, event)
	var effect: Node2D
	for child in host.get_children():
		if child.get_script() == script:
			effect = child as Node2D
	effect.set_process(false)
	return effect

func snapshot(label: String) -> void:
	var states: Array = []
	for enemy in enemies:
		states.append({"hp": enemy.current_hp, "position": [enemy.position.x, enemy.position.y], "wet": enemy.has_status("wet"), "light": enemy.has_status("light"), "dark": enemy.has_status("dark"), "knockback": enemy.get("_knockback_timer")})
	result_log.append({"label": label, "enemies": states})

func _run() -> void:
	await setup([Vector2.ZERO, Vector2(80, 0), Vector2(165, 0)], {"radius": 132.0})
	var water := spawn_effect("water_wave")
	await frames()
	check(enemies[0].current_hp == 9945 and enemies[1].current_hp == 9945 and enemies[2].current_hp == 10000, "water immediate radius and damage")
	check(enemies[1].has_status("wet"), "water applies wet")
	water.call("_process", 0.3)
	check(enemies[1].current_hp == 9945, "water does not damage again on expansion")
	snapshot("water")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	water.call("_process", 1.0)
	check(is_equal_approx(water.get("_elapsed"), 0.3), "paused water clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	water.call("_process", 0.23)
	check(water.is_queued_for_deletion(), "water lifetime")
	await setup([Vector2(125, 0), Vector2(180, 0)], {"radius": 132.0})
	weapon.runtime_stats["damage_area_size"] = 50.0
	spawn_effect("water_wave")
	await frames()
	check(enemies[0].current_hp == 9945 and enemies[1].current_hp == 10000, "water area modifier still applies")
	snapshot("water_area")
	await setup([Vector2(80, 0), Vector2(150, 0)])
	var hole := spawn_effect("black_hole")
	await frames()
	check(enemies[0].current_hp == 9935 and enemies[1].current_hp == 10000, "black hole radius and damage")
	hole.call("_process", 0.1)
	check(is_equal_approx(enemies[0].position.x, 65.0), "black hole pull speed")
	check(enemies[0].has_status("dark"), "black hole applies dark")
	snapshot("black_hole")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	hole.call("_process", 0.1)
	check(is_equal_approx(enemies[0].position.x, 65.0), "paused black hole does not pull")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	hole.call("_process", 0.76)
	check(hole.is_queued_for_deletion(), "black hole lifetime")
	await setup([Vector2(40, 0), Vector2(110, 0)])
	var sword := spawn_effect("light_sword")
	await frames()
	sword.call("_process", 0.49)
	check(enemies[0].current_hp == 10000 and not sword.get("_strike_started"), "sword anticipation")
	sword.call("_process", 0.02)
	check(enemies[0].current_hp == 10000 and sword.get("_strike_started"), "sword fall starts at delay")
	sword.call("_process", 0.22)
	check(enemies[0].current_hp == 9910 and enemies[1].current_hp == 10000, "sword impact damage and radius")
	check(enemies[0].has_status("light"), "sword applies light")
	sword.call("_process", 0.2)
	check(enemies[0].current_hp == 9910, "sword dissolving does not damage twice")
	snapshot("light_sword")
	sword.call("_process", 0.55)
	check(sword.is_queued_for_deletion(), "sword lifetime")
	await setup([Vector2.ZERO, Vector2(48, 0), Vector2(96, 0), Vector2(48, 40)])
	var wind := spawn_effect("wind_blade")
	wind.call("_process", 0.1)
	check(is_equal_approx(wind.position.x, 48.0), "wind speed")
	check(enemies[0].current_hp == 10000 and enemies[1].current_hp == 9930 and enemies[3].current_hp == 10000, "wind path radius and ignored original target")
	check(is_equal_approx(enemies[1].get("_knockback_timer"), 0.34), "wind knockback duration")
	wind.call("_process", 0.1)
	check(enemies[2].current_hp == 9930, "wind hits later path target")
	wind.position = Vector2(48, 0)
	wind.call("_process", 0.0)
	check(enemies[1].current_hp == 9930, "wind cannot rehit same target")
	snapshot("wind")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	wind.call("_process", 0.3)
	check(is_equal_approx(wind.position.x, 48.0), "paused wind does not move")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	wind.call("_process", 0.27)
	check(wind.is_queued_for_deletion(), "wind lifetime")
	await setup([Vector2.ZERO], {"radius": 132.0})
	var last: Node2D
	for i in range(12): last = spawn_effect("water_wave")
	await frames()
	check(enemies[0].current_hp == 9340, "dense effects retain all twelve damage events")
	if last.get_script().get_script_property_list().any(func(property): return property.name == "_visual_detail"):
		check(last.get("_visual_detail") == 0 and last.visible, "dense effects reduce decoration while retaining core")
	snapshot("dense_water")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--snapshot-path="):
			var file := FileAccess.open(argument.trim_prefix("--snapshot-path="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(result_log, "  "))
				file.close()
	host.queue_free()
	await frames()
	print("EFFECT_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
