extends Node2D
var failures := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	CampProgression.begin_transient_session()
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_copper_lamp", player)
	weapon.use_active_range_rules = true
	var base := weapon.get_base_attack_range()
	for pair in [[0.0, 0.0, 1.0], [100.0, 0.0, 1.25], [0.0, 100.0, 1.25], [100.0, 100.0, 1.5], [227.0, 230.0, 2.1425], [-90.0, 0.0, 0.55], [-90.0, -90.0, 0.55]]:
		_set_total(weapon, "area_size", pair[0])
		_set_total(weapon, "damage_area_size", pair[1])
		var expected: float = base * pair[2]
		_check(is_equal_approx(weapon.get_attack_range(), expected), "lamp quarter-efficiency range " + str(pair))
		_check(is_equal_approx(AttackFootprint.targeting_dimensions(weapon).x, expected), "targeting uses the same range")
		var cast := weapon.make_cast_copy()
		_check(is_equal_approx(cast.get_attack_range(), expected), "cast snapshot applies efficiency once")
		_check(cast.get_stat("area_size") == pair[0] and cast.get_stat("damage_area_size") == pair[1], "raw scores retained")
		var bounce := cast.make_bounce_copy(Vector2(30, 0))
		_check(is_equal_approx(bounce.get_attack_range(), expected), "bounce does not halve a second time")
	_set_total(weapon, "area_size", 227)
	_set_total(weapon, "damage_area_size", 230)
	var lamp := CopperLamp.new()
	add_child(lamp)
	lamp.initialize(weapon.make_cast_copy())
	lamp.manual_control = true
	lamp.manual_direction = Vector2.RIGHT
	lamp.externally_driven = true
	lamp.burst_active = true
	lamp.set_physics_process(false)
	lamp._physics_process(0.01)
	_check(is_equal_approx(lamp.beams[0].reach, base * 2.1425), "damage beam uses reduced range")
	_check(is_equal_approx(lamp.flame_visuals[0].reach, base * 2.1425), "visible flame uses the same reduced range")
	_check(weapon.get_lamp_cone_degrees() == 60, "cone angle unchanged")
	var dagger := WeaponInstance.new()
	dagger.initialize("weapon_camp_dagger", player)
	dagger.use_active_range_rules = true
	_set_total(dagger, "area_size", 100)
	_set_total(dagger, "damage_area_size", 100)
	_check(is_equal_approx(dagger.get_attack_range(), dagger.get_base_attack_range() * 2.0), "other cone weapons retain existing scaling")
	lamp.queue_free()
	player.queue_free()
	await get_tree().process_frame
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("LAMP_RANGE_SCALING checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _set_total(weapon: WeaponInstance, stat: String, value: float) -> void:
	weapon.runtime_stats[stat] = float(weapon.runtime_stats.get(stat, 0.0)) + value - weapon.get_stat(stat)
