extends RefCounted
## Opt-in aggregate counters; disabled gameplay never reads the clock.
static var enabled := false
static var counters: Dictionary = {}
static var elapsed_usec: Dictionary = {}

static func reset() -> void:
	counters.clear()
	elapsed_usec.clear()

static func count(key: StringName, amount: int = 1) -> void:
	if enabled:
		counters[key] = int(counters.get(key, 0)) + amount

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(key: StringName, started: int) -> void:
	if enabled and started > 0:
		elapsed_usec[key] = int(elapsed_usec.get(key, 0)) + Time.get_ticks_usec() - started

static func snapshot() -> Dictionary:
	return {"counters": counters.duplicate(), "elapsed_usec": elapsed_usec.duplicate()}
