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
	if not is_equal_approx(ui_scale, 1.0) and get_tree() != null and get_tree().root != null:
		# WindowSettings re-applies this whenever the display settings change; the
		# profile sets it first so the very first frame is already readable.
		get_tree().root.content_scale_factor = ui_scale


func is_mobile() -> bool:
	## Presentation and input model. Also true under `--mobile-ui` on desktop.
	return _forced or OS.has_feature("mobile")


func is_device() -> bool:
	## Real handheld hardware only. Window and display locks use this so a forced
	## desktop run keeps its normal resolution settings.
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
