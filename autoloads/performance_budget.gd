extends Node
## Global frame-time budget. Owns one number: how much decoration and how often
## swept queries may run. Gameplay never branches on it — damage, hits and status
## stay identical at every tier, only decoration, visual admission and query
## cadence change.
##
## Tiers: 2 = full, 1 = reduced, 0 = minimal. The tier is derived from a rolling
## p90 of real frame deltas so a device that cannot hold the target degrades
## before the player feels a stutter, and recovers only when there is headroom.

const TIER_FULL := 2
const TIER_REDUCED := 1
const TIER_MINIMAL := 0
const FORCE_PREFIX := "--budget-tier="
## Rolling window of frame deltas, in frames.
const WINDOW := 30
## Seconds between re-evaluations of the window.
const EVALUATE_INTERVAL := 0.2
## Seconds a tier must hold before it can change again.
const CHANGE_COOLDOWN := 0.8
## p90 thresholds in milliseconds.
const REDUCED_ABOVE_MS := 20.0
const MINIMAL_ABOVE_MS := 30.0
## Upward moves need real headroom, otherwise the tier would flap.
const RECOVER_AT_MS := 17.0
## Ignore stalls from loading, alt-tab and initial shader compilation.
const STALL_MS := 250.0

var _tier := TIER_FULL
var _forced := -1
var _samples: Array[float] = []
var _since_evaluate := 0.0
var _since_change := 0.0
var _last_usec := 0


func _ready() -> void:
	process_priority = -4096
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(FORCE_PREFIX):
			_forced = clampi(int(arg.trim_prefix(FORCE_PREFIX)), TIER_MINIMAL, TIER_FULL)
	if _forced >= 0:
		_tier = _forced
	_last_usec = Time.get_ticks_usec()


## 2 = full, 1 = reduced, 0 = minimal.
func tier() -> int:
	return _tier


func is_reduced() -> bool:
	return _tier <= TIER_REDUCED


## Swept contact queries may skip this many physics ticks while still covering
## the whole travelled distance in one longer sweep, so no hit is lost. Two is the
## largest skip that kept the measured hit counters flat; three drifted them by
## about five percent, so the extra decimation is not offered.
func sweep_period() -> int:
	return 1 if _tier >= TIER_FULL else 2


## Consecutive decorative effects are admitted at a tighter tier as the budget
## drops. Gameplay effects never ask this.
func admission_shift() -> int:
	return TIER_FULL - _tier


func reset() -> void:
	_tier = _forced if _forced >= 0 else TIER_FULL
	_samples.clear()
	_since_evaluate = 0.0
	_since_change = 0.0
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	if _forced >= 0:
		return
	if frame_ms <= 0.0 or frame_ms > STALL_MS:
		return
	_samples.append(frame_ms)
	if _samples.size() > WINDOW:
		_samples.remove_at(0)
	_since_evaluate += frame_ms / 1000.0
	_since_change += frame_ms / 1000.0
	if _since_evaluate < EVALUATE_INTERVAL or _samples.size() < WINDOW:
		return
	_since_evaluate = 0.0
	var ordered := _samples.duplicate()
	ordered.sort()
	var p90: float = ordered[mini(ordered.size() - 1, int(ordered.size() * 0.9))]
	var target := _tier
	if p90 > MINIMAL_ABOVE_MS:
		target = TIER_MINIMAL
	elif p90 > REDUCED_ABOVE_MS:
		target = TIER_REDUCED
	elif p90 <= RECOVER_AT_MS:
		target = TIER_FULL
	if target > _tier and p90 > RECOVER_AT_MS:
		target = _tier
	if target != _tier and _since_change >= CHANGE_COOLDOWN:
		_tier = target
		_since_change = 0.0
