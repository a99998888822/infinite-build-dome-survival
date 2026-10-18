extends Node
## Per-attack local hit chains. Only new targets cross feedback milestones.
## Bound only while a battle exists. Presentation layers keep aim/camera math stable.
signal feedback_started(tier: int, local_count: int)

const LOCAL_RADIUS := 240.0
const CHAIN_GAP_SECONDS := 0.20
const SCREEN_SHADER = preload("res://assets/shaders/combat_screen_shake.gdshader")
const SHAKE_PIXELS := [0.0, 1.0, 2.0, 6.0]
const SHAKE_SECONDS := [0.0, 0.14, 0.22, 0.32]
const HITSTOP_SECONDS := [0.0, 0.05, 0.05, 0.05]
const DIRECTIONS := [Vector2(1, -0.4), Vector2(-0.8, 0.65), Vector2(0.6, -1), Vector2(-1, 0.3)]

var active := false
var tier := 0
var last_local_count := 0
var screen_offset := Vector2.ZERO
var shake_elapsed := 0.0
var hitstop_until_usec := 0
var _owns_pause := false
var _batches: Dictionary = {}
var _chains: Array[Dictionary] = []
var _combat_clock := 0.0
var _layers: Array[CanvasLayer] = []
var _base_offsets: Array[Vector2] = []
var _world_viewport: Viewport
var _saved_update_mode := -1
var _input_receivers: Array[Node] = []
var _presentation: CanvasItem
var _presentation_material: ShaderMaterial
var _original_presentation_material: Material


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000 # Close the previous hit frame before its flash advances.


func bind_battle(world_viewport: Viewport, layers: Array[CanvasLayer], presentation: CanvasItem = null) -> void:
	unbind_battle()
	_world_viewport = world_viewport
	_layers = layers.duplicate()
	for layer in _layers: _base_offsets.append(layer.offset)
	_presentation = presentation
	if is_instance_valid(_presentation):
		_original_presentation_material = _presentation.material
		_presentation_material = ShaderMaterial.new()
		_presentation_material.shader = SCREEN_SHADER
		_presentation.material = _presentation_material
	active = true


func unbind_battle() -> void:
	clear()
	if is_instance_valid(_presentation) and _presentation.material == _presentation_material:
		_presentation.material = _original_presentation_material
	_presentation = null
	_presentation_material = null
	_original_presentation_material = null
	active = false
	_layers.clear()
	_base_offsets.clear()
	_world_viewport = null
	_input_receivers.clear()


func set_input_receivers(receivers: Array[Node]) -> void:
	_input_receivers = receivers.duplicate()


func _input(event: InputEvent) -> void:
	# Paused gameplay does not receive releases. Forward only those state updates,
	# so keys, held mouse movement and touch sticks cannot stick after hitstop.
	if not _owns_pause: return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch): return
	if event.is_pressed(): return
	for receiver in _input_receivers:
		if is_instance_valid(receiver): receiver.call("_input", event)


func record_damage(enemy: Node2D, attack_id: int = 0, hit_position: Variant = null) -> void:
	# Status ticks without an attack identity retain body feedback only.
	if attack_id <= 0: return
	if not active or enemy.get_viewport() != _world_viewport: return
	if get_tree().paused or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	var frame := Engine.get_physics_frames()
	if not _batches.has(frame): _batches[frame] = {"time": _combat_clock, "attacks": {}}
	var attacks: Dictionary = _batches[frame].attacks
	if not attacks.has(attack_id): attacks[attack_id] = {}
	# Snapshot before death/free/movement; a multihit on one enemy still counts once.
	var hits: Dictionary = attacks[attack_id]
	if not hits.has(enemy.get_instance_id()):
		hits[enemy.get_instance_id()] = hit_position if hit_position is Vector2 else enemy.global_position


static func local_hit_count(positions: Array) -> int:
	var highest := 0
	var radius_squared := LOCAL_RADIUS * LOCAL_RADIUS
	# No transitive flood fill: a long chain cannot join distant combat pockets.
	for center: Vector2 in positions:
		var count := 0
		for point: Vector2 in positions:
			if center.distance_squared_to(point) <= radius_squared: count += 1
		highest = maxi(highest, count)
	return highest


static func tier_for_count(count: int) -> int:
	if count >= 12: return 3
	if count >= 6: return 2
	if count >= 3: return 1
	return 0


static func milestone_for_count(count: int) -> int:
	if count >= 12: return (count / 3) * 3
	if count >= 6: return 6
	if count >= 3: return 3
	return 0


func _physics_process(delta: float) -> void:
	if active and not get_tree().paused and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		_combat_clock += delta


func _accumulate(attack_id: int, hits: Dictionary, at: float) -> int:
	var pending := hits.duplicate()
	var touched: Array[Dictionary] = []
	# A group's center stays fixed. Chained neighbors cannot join distant pockets.
	for id in hits:
		var best: Dictionary = {}
		var distance := LOCAL_RADIUS * LOCAL_RADIUS + 0.001
		for chain in _chains:
			if int(chain.attack_id) != attack_id or at - float(chain.last_hit) > CHAIN_GAP_SECONDS + 0.00001: continue
			if chain.hits.has(id):
				pending.erase(id)
				best = {}
				break
			var next: float = chain.center.distance_squared_to(hits[id])
			if next < distance:
				distance = next
				best = chain
		if not pending.has(id) or best.is_empty(): continue
		best.hits[id] = hits[id]
		best.last_hit = at
		if not touched.has(best): touched.append(best)
		pending.erase(id)
	# Seed each new pocket at the densest hit position in this contact batch.
	while not pending.is_empty():
		var center: Vector2 = pending.values()[0]
		var best_count := 0
		for candidate: Vector2 in pending.values():
			var count := 0
			for point: Vector2 in pending.values():
				if candidate.distance_squared_to(point) <= LOCAL_RADIUS * LOCAL_RADIUS: count += 1
			if count > best_count:
				center = candidate
				best_count = count
		var chain := {"attack_id": attack_id, "center": center, "hits": {}, "last_hit": at, "milestone": 0}
		for id in pending.keys():
			if center.distance_squared_to(pending[id]) <= LOCAL_RADIUS * LOCAL_RADIUS:
				chain.hits[id] = pending[id]
				pending.erase(id)
		_chains.append(chain)
		touched.append(chain)
	var request := 0
	for chain in touched:
		var count: int = chain.hits.size()
		last_local_count = count
		var milestone := milestone_for_count(count)
		if milestone > int(chain.milestone):
			chain.milestone = milestone
			request = maxi(request, count)
	return request


func _process(delta: float) -> void:
	if not active: return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		clear()
		return
	if _owns_pause:
		if Time.get_ticks_usec() < hitstop_until_usec: return
		_release_hitstop()
		return # Do not consume the frozen interval from the shake's animation.
	if get_tree().paused: return
	if tier > 0:
		shake_elapsed += delta
		if shake_elapsed >= SHAKE_SECONDS[tier]:
			tier = 0
			_set_screen_offset(Vector2.ZERO)
		else:
			_update_shake()
	var highest := 0
	var frame := Engine.get_physics_frames()
	# Close a physics frame only after it ended, including idle/deferred damage.
	for key in _batches.keys():
		if int(key) >= frame: continue
		var batch: Dictionary = _batches[key]
		for attack_id in batch.attacks:
			highest = maxi(highest, _accumulate(attack_id, batch.attacks[attack_id], float(batch.time)))
		_batches.erase(key)
	for index in range(_chains.size() - 1, -1, -1):
		if _combat_clock - float(_chains[index].last_hit) > CHAIN_GAP_SECONDS + 0.00001:
			_chains.remove_at(index)
	if highest > 0: _play(highest)


func _play(count: int) -> void:
	last_local_count = count
	var requested := tier_for_count(count)
	if requested == 0: return
	# A weaker cluster cannot replace a stronger shake; impulses never add together.
	if requested >= tier:
		tier = requested
		shake_elapsed = 0.0
		_update_shake()
	var seconds: float = HITSTOP_SECONDS[requested]
	if seconds > 0.0 and not get_tree().paused:
		_owns_pause = true
		hitstop_until_usec = Time.get_ticks_usec() + int(seconds * 1000000.0)
		get_tree().paused = true
		if _world_viewport is SubViewport:
			_saved_update_mode = _world_viewport.render_target_update_mode
			# Draw this contact once, then freeze even GPU-only particles/shaders.
			_world_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	feedback_started.emit(requested, count)


func _update_shake() -> void:
	var envelope := pow(1.0 - clampf(shake_elapsed / SHAKE_SECONDS[tier], 0.0, 1.0), 1.5)
	var direction: Vector2 = DIRECTIONS[int(shake_elapsed * 60.0) % DIRECTIONS.size()]
	_set_screen_offset((direction * SHAKE_PIXELS[tier] * envelope).round())


func _set_screen_offset(value: Vector2) -> void:
	screen_offset = value
	var layer_offset := value
	if is_instance_valid(_presentation):
		var viewport := _presentation.get_viewport()
		var ui_size := viewport.get_visible_rect().size.max(Vector2.ONE) if viewport != null else Vector2.ONE
		var size := _world_viewport.get_visible_rect().size.max(Vector2.ONE) if is_instance_valid(_world_viewport) else ui_size
		_presentation_material.set_shader_parameter("shake_uv", value / size)
		layer_offset = value * ui_size / size
	for index in _layers.size():
		if is_instance_valid(_layers[index]): _layers[index].offset = _base_offsets[index] + layer_offset


func _release_hitstop() -> void:
	if _saved_update_mode >= 0 and is_instance_valid(_world_viewport):
		_world_viewport.render_target_update_mode = _saved_update_mode
	_saved_update_mode = -1
	if _owns_pause and is_inside_tree(): get_tree().paused = false
	_owns_pause = false
	hitstop_until_usec = 0


func clear() -> void:
	_release_hitstop()
	_batches.clear()
	_chains.clear()
	_combat_clock = 0.0
	tier = 0
	last_local_count = 0
	shake_elapsed = 0.0
	_set_screen_offset(Vector2.ZERO)


func _exit_tree() -> void:
	unbind_battle()
