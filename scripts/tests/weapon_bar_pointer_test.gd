extends Node
## Hover follows input events and canvas transforms without polling the OS cursor.

var checks := 0
var failures := 0

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	CampProgression.begin_transient_session()
	var holder := Control.new()
	add_child(holder)
	var bar := ActiveCombatWeaponBar.new()
	holder.add_child(bar)
	var sources: Array[WeaponInstance] = []
	for id in ["weapon_void_blade", "weapon_copper_lamp"]:
		var weapon := WeaponInstance.new()
		weapon.initialize(id, null)
		sources.append(weapon)
	bar.setup(sources)
	await get_tree().process_frame
	var point := bar.cards[0].get_global_transform_with_canvas() * (bar.cards[0].size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	bar.update_slot(0, 1.0, 2.0, false, false)
	bar.update_slot(1, 1.0, 2.0, false, false)
	check(bar.cards[0].get_theme_stylebox("panel") == bar._style(true), "mouse motion highlights its slot")
	check(bar.cards[1].get_theme_stylebox("panel") == bar._style(false), "mouse motion leaves other slots normal")
	holder.position += Vector2(500, 0)
	bar.update_slot(0, 1.0, 2.0, false, false)
	check(bar.cards[0].get_theme_stylebox("panel") == bar._style(false), "stationary pointer respects layout movement")
	holder.scale = Vector2(0.5, 0.5)
	var click := InputEventMouseButton.new()
	click.position = bar.cards[1].get_global_transform_with_canvas() * (bar.cards[1].size * 0.5)
	click.button_index = MOUSE_BUTTON_RIGHT
	get_viewport().push_input(click, true)
	bar.update_slot(1, 1.0, 2.0, false, false)
	check(bar.cards[1].get_theme_stylebox("panel") == bar._style(true), "mouse button position respects scaled canvas")
	bar._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	bar.update_slot(1, 1.0, 2.0, false, false)
	check(bar.cards[1].get_theme_stylebox("panel") == bar._style(false), "focus loss clears hover")
	bar.update_slot(1, 1.0, 2.0, false, true)
	check(bar.cards[1].get_theme_stylebox("panel") == bar._style(true), "selection remains independent of hover")
	bar._input(motion)
	bar._notification(NOTIFICATION_WM_MOUSE_EXIT)
	check(not bar._has_pointer_position, "window exit clears pointer availability")
	get_tree().paused = true
	get_viewport().push_input(click, true)
	get_tree().paused = false
	bar.update_slot(1, 1.0, 2.0, false, false)
	check(bar.cards[1].get_theme_stylebox("panel") == bar._style(true), "pointer updates during hitstop without advancing bar effects")
	bar.setup(sources)
	await get_tree().process_frame
	bar._has_pointer_position = false
	get_viewport().push_input(click, true)
	check(bar._has_pointer_position, "loadout rebuild retains the pointer input relay")
	holder.queue_free()
	await get_tree().process_frame
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("WEAPON_BAR_POINTER checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
