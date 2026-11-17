extends Node
## One switch for the mobile presentation and input model.
##
## Every mobile branch asks this node instead of OS.has_feature("mobile"), so a
## desktop run can exercise the phone layout with `--mobile-ui`. While the mode
## is off every answer here is the historical desktop one, which keeps this
## branch mergeable with master.

const FORCE_ARG := "--mobile-ui"
const SCALE_ARG_PREFIX := "--mobile-ui-scale="
## The canvas is 1920x1080 and a 20:9 handheld renders it 1:1, so 12px HUD text
## stays 12 physical pixels. This lifts the whole UI into a readable range.
const DEFAULT_UI_SCALE := 1.45
## Clearance above the handheld home-indicator strip, in logical pixels.
const BOTTOM_INSET := 16.0
## Handhelds run the simulation at the rate they can afford instead of paying for
## a full 60 Hz tick set on every rendered frame. Measured on the seven-weapon
## stress scene: 60 Hz/2 steps 39 FPS, 30 Hz/1 step 51 FPS, and the catch-up loop
## that produced the 150-330 ms spikes disappears at both settings.
const MOBILE_PHYSICS_TICKS_PER_SECOND := 30
const MOBILE_MAX_PHYSICS_STEPS := 1

var ui_scale := 1.0

var _forced := false
var _scale_override := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_forced = FORCE_ARG in args
	for arg in args:
		if arg.begins_with(SCALE_ARG_PREFIX):
			_scale_override = float(arg.trim_prefix(SCALE_ARG_PREFIX))
	ui_scale = _scale_override if _scale_override > 0.0 else DEFAULT_UI_SCALE if is_mobile() else 1.0
	apply_simulation_budget()
	if get_tree() != null and get_tree().root != null:
		apply_to_window(get_tree().root)


## Keeps the simulation inside the frame the device can actually render. One
## allowed physics step means a slow frame slows simulated time instead of
## queueing more physics work behind it, which is what turns a 45 ms frame into a
## 300 ms one. Desktop keeps the authored tick rate and gets a two-step catch-up.
func apply_simulation_budget() -> void:
	if is_mobile():
		Engine.physics_ticks_per_second = MOBILE_PHYSICS_TICKS_PER_SECOND
		Engine.max_physics_steps_per_frame = MOBILE_MAX_PHYSICS_STEPS
	else:
		# Desktop keeps the project's authored tick rate; only the catch-up is capped.
		Engine.max_physics_steps_per_frame = 2


func apply_to_window(window: Window) -> void:
	## WindowSettings re-applies this whenever the display settings change; the
	## profile sets it first so the very first frame is already readable.
	if window == null:
		return
	window.content_scale_factor = ui_scale
	# A 20:9 handheld is wider than the 16:9 canvas. Expanding keeps the vertical
	# field of view and lets the extra width show more battlefield instead of
	# letterboxing 240 px on each side. Desktop keeps the authored aspect.
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if is_mobile() else Window.CONTENT_SCALE_ASPECT_KEEP
	# The mobile UI owns the whole display. Capture hosts keep their requested
	# dimensions on a private desktop instead of changing the native window mode.
	if is_mobile() and DisplayServer.get_name() != "headless" and not window.is_embedded() \
			and not "--background-capture" in OS.get_cmdline_user_args():
		window.mode = Window.MODE_FULLSCREEN


func is_mobile() -> bool:
	## Presentation and input model. Also true under `--mobile-ui` on desktop.
	return _forced or OS.has_feature("mobile")


func is_device() -> bool:
	## Real handheld hardware only; presentation locks also apply in preview mode.
	return not _forced and OS.has_feature("mobile")


func is_forced() -> bool:
	## A desktop run pretending to be a phone; useful for screenshot reviews.
	return _forced


func uses_pointer() -> bool:
	## Aim, click-to-move and the weapon cursor all belong to the pointer model.
	return not is_mobile()


func bottom_inset() -> float:
	## Handhelds reserve a home-indicator strip at the bottom edge. The value is
	## in logical pixels and stays adjustable until a device pass measures it.
	return BOTTOM_INSET if is_mobile() else 0.0


func weapon_available(weapon_id: String) -> bool:
	## A phone has one stick and no aim pointer, so steering weapons are never
	## offered there. Copies that already exist are dropped by
	## WeaponLoadout.sanitize_for_platform().
	if not is_mobile() or weapon_id.is_empty():
		return true
	var data := DataRegistry.get_record("weapons", weapon_id)
	if data.is_empty():
		return true
	return str(data.get("projectile_behavior", "")) not in WeaponInstance.MOBILITY_BEHAVIORS
