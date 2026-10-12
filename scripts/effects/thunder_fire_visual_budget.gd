extends Node
## Local, pause-aware admission before particle creation. Never owns damage.
const META := &"thunder_fire_visual_budget"
const WINDOW_SECONDS := 0.1
const REGION_RADIUS := 96.0
const SPARK_CELL_SIZE := 24.0
const FULL_LIMIT := 4
const REDUCED_LIMIT := 12
const SPARK_PATCH_LIMIT := 8
enum Tier { FULL, REDUCED, SPARK, SUPPRESSED }

var _clock := 0.0
var _cells: Dictionary = {}
var tier_counts: Array[int] = [0, 0, 0, 0]

static func for_parent(parent: Node) -> Node:
	var budget = parent.get_meta(META) if parent.has_meta(META) else null
	if not is_instance_valid(budget):
		budget = new()
		parent.add_child(budget)
		parent.set_meta(META, budget)
	return budget

func _ready() -> void:
	add_to_group("thunder_fire_visual_budgets")
	GameGlobal.runtime_state_reset.connect(reset)
	set_process(false)

func _exit_tree() -> void:
	if get_parent() != null and get_parent().has_meta(META) and get_parent().get_meta(META) == self:
		get_parent().remove_meta(META)

func reset() -> void:
	_cells.clear()
	_clock = 0.0
	tier_counts = [0, 0, 0, 0]
	set_process(false)

func _process(delta: float) -> void:
	if get_tree().paused or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	_clock += maxf(delta, 0.0)
	var cutoff := _clock - WINDOW_SECONDS
	for cell in _cells.keys():
		var regions: Array = _cells[cell]
		for index in range(regions.size() - 1, -1, -1):
			if float(regions[index].last_seen) <= cutoff:
				regions.remove_at(index)
		if regions.is_empty(): _cells.erase(cell)
	if _cells.is_empty(): set_process(false)

func claim(point: Vector2) -> int:
	set_process(true)
	var cell := Vector2i(floori(point.x / REGION_RADIUS), floori(point.y / REGION_RADIUS))
	var region: Dictionary = {}
	var nearest := REGION_RADIUS * REGION_RADIUS
	# Neighbor lookup prevents a grid boundary from duplicating the full budget.
	# Fixed anchors prevent a chain of nearby hits joining distant screen areas.
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			for candidate: Dictionary in _cells.get(Vector2i(x, y), []):
				var distance := point.distance_squared_to(candidate.position)
				if distance <= nearest:
					region = candidate
					nearest = distance
	if region.is_empty():
		region = {"position": point, "last_seen": _clock, "times": [], "spark_patches": {}}
		if not _cells.has(cell): _cells[cell] = []
		_cells[cell].append(region)
	region.last_seen = _clock
	var times: Array = region.times
	var cutoff := _clock - WINDOW_SECONDS
	while not times.is_empty() and float(times[0]) <= cutoff: times.pop_front()
	times.append(_clock)
	# Only the most recent 13 contacts are needed to decide the density tier.
	if times.size() > REDUCED_LIMIT + 1: times.pop_front()
	var tier := Tier.FULL
	if times.size() > REDUCED_LIMIT:
		var patches: Dictionary = region.spark_patches
		for key in patches.keys():
			if float(patches[key]) <= cutoff: patches.erase(key)
		var patch := Vector2i(floori(point.x / SPARK_CELL_SIZE), floori(point.y / SPARK_CELL_SIZE))
		if patches.has(patch) or patches.size() >= SPARK_PATCH_LIMIT:
			tier = Tier.SUPPRESSED
		else:
			patches[patch] = _clock
			tier = Tier.SPARK
	elif times.size() > FULL_LIMIT:
		tier = Tier.REDUCED
	tier_counts[tier] += 1
	return tier
