extends RefCounted

static var remove_glow := false
static var remove_spray := false
static var profiling := false
static var hide_warning_diagnostic := false
static var counters: Dictionary = {}
static var costs: Dictionary = {}

static func count(key: String, amount: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + amount

static func cost(key: String, started: int) -> void:
	if profiling:
		var row: Dictionary = costs.get(key, {"calls": 0, "usec": 0, "max_usec": 0})
		var elapsed := Time.get_ticks_usec() - started
		row.calls += 1
		row.usec += elapsed
		row.max_usec = maxi(row.max_usec, elapsed)
		costs[key] = row
