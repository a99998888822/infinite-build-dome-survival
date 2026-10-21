extends Node
class_name NightEvacuation
## Owns the extraction phase; the existing wave-end transaction stays authoritative.
const CONFIG_PATH := "res://data_config/night_evacuation.json"
const BANK_SIZE := Vector2(609,379)
const BANK_ANCHOR := Vector2(316,258)
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
var manager: WaveManager
var player: PlayerController
var scenery: CavernPopulationBackdrop
var visual: Node2D
var active := false
var extraction_pending := false
var elapsed := 0.0
var bank_anchor := Vector2.ZERO
var ring_center := Vector2.ZERO
var previous_foot := Vector2.ZERO
var spawn_authorized := false
var flank_spawn_authorized := false
var spawn_timers: Array[float] = []
var rng := RandomNumberGenerator.new()
var reward_remainder := 0.0
var spawned_count := 0
var extracted_count := 0
var next_hunter_at := 33.0
var next_flank_at := 12.0

func initialize(source: WaveManager, subject: PlayerController) -> void:
	manager = source
	player = subject
	manager.evacuation = self
	rng.randomize()
	manager.wave_started.connect(_on_wave_started)
	manager.wave_end_absorb_started.connect(_on_wave_finished)
	player.died.connect(reset)
	player.evacuation_safety_check = try_enter_shelter
	process_physics_priority = 1
	visual = preload("res://scripts/battle/night_evacuation_visual.gd").new()
	add_child(visual)
	visual.initialize(self)

func is_active() -> bool:
	return active or extraction_pending

func reset() -> void:
	active = false
	extraction_pending = false
	spawn_authorized = false
	flank_spawn_authorized = false
	elapsed = 0.0
	reward_remainder = 0.0
	spawned_count = 0
	next_hunter_at = 33.0
	next_flank_at = float(config.flank_first_seconds)
	spawn_timers.clear()
	if is_instance_valid(scenery) and scenery is CavernGrasslandBackdrop:
		(scenery as CavernGrasslandBackdrop).reserve_shelter(Rect2())
	if is_instance_valid(player): player.evacuation_sheltered = false
	if is_instance_valid(visual): visual.reset()

func _on_wave_started(_id: String, _duration: int) -> void:
	reset()

func _on_wave_finished(_id: String) -> void:
	active = false
	extraction_pending = false
	spawn_authorized = false
	visual.hide_guidance()

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.evacuation_sheltered = false
		player.evacuation_safety_check = Callable()
	if is_instance_valid(visual): visual.reset()

func foot_position() -> Vector2:
	# Use the scenery's animation-aware foot offset, even while the visual is reparented.
	var offset := scenery.foot_offset if is_instance_valid(scenery) else Vector2(0,40)
	return player.global_position + offset

func ring_axes() -> Vector2:
	return Vector2(float(config.ring_axes[0]),float(config.ring_axes[1]))

func begin() -> void:
	if is_active() or not manager.running or not player.is_alive(): return
	scenery = get_tree().get_first_node_in_group("battle_cavern") as CavernPopulationBackdrop
	bank_anchor = choose_location()
	ring_center = bank_anchor + Vector2(float(config.ring_offset[0]),float(config.ring_offset[1]))
	if scenery is CavernGrasslandBackdrop:
		(scenery as CavernGrasslandBackdrop).reserve_shelter(Rect2(bank_anchor+Vector2(-300,-245),Vector2(600,425)))
	previous_foot = foot_position()
	elapsed = 0.0
	active = true
	manager.cleanup_active = true
	manager.cleanup_time_left = 0.0
	manager.spawn_timers_ms.clear()
	manager._elite_spawn_schedule.clear()
	manager._challenge_elite_schedule.clear()
	for i in (manager.current_wave.get("spawn_groups",[]) as Array).size():
		spawn_timers.append(float(config.grace_seconds)+float(i)*.45)
	visual.begin()

func choose_location() -> Vector2:
	var origin := foot_position()
	var view := player.get_viewport().get_canvas_transform().affine_inverse()*player.get_viewport_rect()
	var best := origin+Vector2(1600,0)
	var best_score := INF
	var phase := rng.randf()*TAU
	# Test authored future landmarks too: offscreen cells may not yet be streamed.
	for step in 5:
		for i in 32:
			var direction := Vector2.RIGHT.rotated(phase+TAU*float(i)/32.0)
			var candidate := origin+direction*(float(config.base_travel_distance)+float(step)*160.0)
			var bounds := Rect2(candidate-BANK_ANCHOR,BANK_SIZE)
			if view.grow(float(config.offscreen_margin)).intersects(bounds): continue
			if not placement_clear(candidate,origin): continue
			var score := origin.distance_to(candidate)
			for enemy in EnemyRegistry.get_registered_enemies():
				if is_instance_valid(enemy) and enemy.is_alive():
					var near := Geometry2D.get_closest_point_to_segment(enemy.global_position,origin,candidate)
					if enemy.global_position.distance_to(near)<230: score += 260.0
			if score<best_score:
				best_score = score
				best = candidate
		if best_score<INF: return best.round()
	# Expand the search rather than accepting an obstructed entrance.
	for i in 128:
		var candidate := origin+Vector2.RIGHT.rotated(phase+TAU*float(i)/128.0)*(2200.0+float(i/32)*250.0)
		if placement_clear(candidate,origin): return candidate.round()
	push_error("No reachable evacuation placement found")
	return best.round()

func placement_clear(candidate: Vector2, origin: Vector2) -> bool:
	var bounds := Rect2(candidate-BANK_ANCHOR,BANK_SIZE).grow(95)
	# Do not create an impassable body around an enemy already in the world.
	for enemy in EnemyRegistry.get_registered_enemies():
		if is_instance_valid(enemy) and enemy.is_alive() and bounds.has_point(enemy.global_position): return false
	if not is_instance_valid(scenery): return true
	var seen: Dictionary = {}
	for point in [candidate,origin.lerp(candidate,.25),origin.lerp(candidate,.5),origin.lerp(candidate,.75)]:
		for entry: Dictionary in scenery._nearby_landmarks(point):
			var location: Vector2 = entry.point
			if seen.has(location): continue
			seen[location] = true
			if bounds.has_point(location): return false
			if location.distance_to(Geometry2D.get_closest_point_to_segment(location,origin,candidate))<110.0: return false
	return true

func contains_foot(point: Vector2) -> bool:
	return ((point-ring_center)/ring_axes()).length_squared()<=1.0

func try_enter_shelter() -> bool:
	if player.evacuation_sheltered: return true
	if not active or not manager.running or not player.is_alive() or bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)): return false
	var foot := foot_position()
	var a := (previous_foot-ring_center)/ring_axes()
	var b := (foot-ring_center)/ring_axes()
	var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b)
	if not contains_foot(foot) and closest.length_squared()>1.0: return false
	player.evacuation_sheltered = true
	player.velocity = Vector2.ZERO
	player.has_move_destination = false
	active = false
	extraction_pending = true
	manager._wave_finish_queued = true
	extracted_count += 1
	complete_extraction.call_deferred()
	return true

func _physics_process(_delta: float) -> void:
	if not active or bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)): return
	try_enter_shelter()
	previous_foot = foot_position()

func complete_extraction() -> void:
	if not extraction_pending or not player.is_alive() or manager.run_statistics.frozen: return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)): return
	manager.finish_current_wave()

func advance(delta: float) -> void:
	if extraction_pending:
		complete_extraction()
		return
	if not active: return
	elapsed += maxf(0.0,delta)
	if try_enter_shelter(): return
	_process_flank_spawn()
	var groups: Array = manager.current_wave.get("spawn_groups",[])
	for i in groups.size():
		spawn_timers[i] -= delta
		if spawn_timers[i]>0.0: continue
		spawn_timers[i] = maxf(.14,manager.calculate_spawn_interval(float(groups[i].spawn_interval_ms))/1000.0/spawn_multiplier())
		var available := maxi(0,int(manager._difficulty.enemy_limit)-manager.get_living_enemy_count())
		# Reserve one slot for announced pursuit; never exceed the population budget.
		if elapsed>=30.0 and elapsed>=next_hunter_at-3.0: available = maxi(0,available-1)
		var count := mini(available,manager._take_enemy_spawn_count(int(groups[i].count_per_spawn)))
		for j in mini(count,12):
			var point := choose_spawn_position()
			if not point.is_finite(): continue
			spawn_authorized = true
			var enemy := manager.spawn_enemy("enemy_mutated_grub",point)
			spawn_authorized = false
			if enemy == null: continue
			spawned_count += 1
			enemy.set_meta("evacuation_enemy",true)
			apply_pressure(enemy)
	if elapsed>=next_hunter_at:
		var hunters := 0
		for enemy in EnemyRegistry.get_registered_enemies():
			if is_instance_valid(enemy) and enemy.is_alive() and bool(enemy.get_meta("evacuation_hunter",false)): hunters += 1
		if hunters<2 and manager.get_living_enemy_count()<int(manager._difficulty.enemy_limit):
			var point := choose_spawn_position()
			if point.is_finite():
				spawn_authorized = true
				var hunter := manager.spawn_enemy("enemy_elite_rusher",point)
				spawn_authorized = false
				if hunter != null:
					hunter.set_meta("evacuation_enemy",true)
					hunter.set_meta("evacuation_hunter",true)
					apply_pressure(hunter)
					spawned_count += 1
			next_hunter_at = elapsed+18.0
	visual.refresh()

func spawn_multiplier() -> float:
	if elapsed<=float(config.grace_seconds): return 1.0
	return lerpf(1.0,3.0,clampf((elapsed-float(config.grace_seconds))/27.0,0,1))

func night_progress() -> float:
	# One continuous fade across the countdown/evacuation boundary.
	if not is_instance_valid(manager) and not is_active() and not (is_instance_valid(visual) and visual.lit): return 0.0
	var seconds := elapsed if is_active() or (is_instance_valid(visual) and visual.lit) else -manager.wave_time_left
	return smoothstep(-float(config.dusk_lead_seconds),float(config.night_seconds),seconds)

func pressure_multiplier(start_seconds: float) -> float:
	var periods := maxf(0.0,elapsed-start_seconds)/float(config.pressure_double_seconds)
	return 1.0+minf(periods,1.0)+maxf(0.0,periods-1.0)*float(config.pressure_late_gain_per_period)

func apply_pressure(enemy: EnemyController) -> void:
	# Capture growth once at birth: living enemies never heal or gain damage.
	var damage := pressure_multiplier(float(config.damage_growth_start))
	var factors := {"max_hp":pressure_multiplier(float(config.health_growth_start)),
		"melee_damage":damage,"ranged_damage":damage,"element_damage":damage}
	var base_speed := enemy.get_chase_speed()
	var speed_progress := smoothstep(0.0,float(config.speed_growth_seconds),elapsed-float(config.speed_growth_start))
	var speed_limit := maxf(0.0,player.get_stat("move_speed"))*float(config.speed_player_ratio)
	var grown_speed := lerpf(minf(base_speed,speed_limit),speed_limit,speed_progress)
	var resolved_speed := enemy.get_stat("move_speed")
	if resolved_speed > 0.0: factors.move_speed = grown_speed/resolved_speed
	enemy.night_speed_player_ratio = float(config.speed_player_ratio)
	for stat: String in factors:
		enemy.modifier_stack.add_modifier_from_dictionary({"id":"evacuation_"+stat,"source_type":"evacuation","source_id":"night",
			"target_scope":"enemy","stat":stat,"operation":"multiply","value":factors[stat],"duration":-1,"stack_rule":"replace_same_source"})
	enemy.current_hp = int(enemy.get_stat("max_hp"))

func reward_multiplier() -> float:
	return maxf(float(config.minimum_reward_multiplier),pow(.5,maxf(0,elapsed-float(config.reward_decay_start))/float(config.reward_decay_period)))

func scale_reward_actions(actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in actions:
		var action := source.duplicate(true)
		if str(action.get("type",""))=="exp_orb":
			var exact := float(action.amount)*reward_multiplier()+reward_remainder
			action.amount = floori(exact)
			reward_remainder = exact-float(action.amount)
			if int(action.amount)<=0: continue
		result.append(action)
	return result

func allows_spawn(point: Vector2) -> bool:
	if not active or not spawn_authorized: return false
	return spawn_position_valid(point,flank_spawn_authorized)

func spawn_position_valid(point: Vector2, flank := false) -> bool:
	if not point.is_finite(): return false
	var origin := foot_position()
	var forward := origin.direction_to(ring_center)
	var offset := point-origin
	if offset.length()<float(config.spawn_min_distance)-1.0: return false
	if point.distance_to(ring_center)<float(config.entrance_spawn_clearance): return false
	if flank:
		var bank_offset := point-ring_center
		if bank_offset.length()<float(config.flank_min_radius) or bank_offset.length()>float(config.flank_max_radius): return false
		if bank_offset.normalized().dot(forward)<cos(deg_to_rad(float(config.flank_half_angle_degrees))): return false
		return not Rect2(bank_anchor-BANK_ANCHOR,BANK_SIZE).grow(48.0).has_point(point)
	if offset.normalized().dot(-forward)<cos(deg_to_rad(float(config.rear_half_angle_degrees))): return false
	if point.distance_to(Geometry2D.get_closest_point_to_segment(point,origin,ring_center))<float(config.route_half_width): return false
	return true

func choose_spawn_position() -> Vector2:
	var origin := foot_position()
	var rear := ring_center.direction_to(origin)
	for attempt in 16:
		var direction := rear.rotated(deg_to_rad(rng.randf_range(-float(config.rear_half_angle_degrees),float(config.rear_half_angle_degrees))))
		var point := origin+direction*rng.randf_range(float(config.spawn_min_distance),float(config.spawn_max_distance))
		if not spawn_position_valid(point): continue
		if manager._get_spawn_clearance_squared(point)<24.0*24.0: continue
		if is_instance_valid(scenery) and not scenery._clear_of_large(point,scenery._nearby_landmarks(point),20): continue
		return point
	return Vector2(INF,INF)

func choose_flank_spawn_position() -> Vector2:
	var forward := foot_position().direction_to(ring_center)
	for attempt in 24:
		var direction := forward.rotated(deg_to_rad(rng.randf_range(-float(config.flank_half_angle_degrees),float(config.flank_half_angle_degrees))))
		var point := ring_center+direction*rng.randf_range(float(config.flank_min_radius),float(config.flank_max_radius))
		if not spawn_position_valid(point,true): continue
		if manager._get_spawn_clearance_squared(point)<WaveManager.SPAWN_SEPARATION_DISTANCE*WaveManager.SPAWN_SEPARATION_DISTANCE: continue
		if is_instance_valid(scenery) and not scenery._clear_of_large(point,scenery._nearby_landmarks(point),32): continue
		return point
	return Vector2(INF,INF)

func _process_flank_spawn() -> void:
	if elapsed<next_flank_at: return
	# Missed opportunities are discarded, never accumulated into a burst.
	next_flank_at = elapsed+rng.randf_range(float(config.flank_interval_min),float(config.flank_interval_max))
	if manager.get_living_enemy_count()>=int(manager._difficulty.enemy_limit): return
	var flankers := 0
	for enemy in EnemyRegistry.get_registered_enemies():
		if is_instance_valid(enemy) and enemy.is_alive() and bool(enemy.get_meta("evacuation_flanker",false)): flankers += 1
	if flankers>=int(config.flank_alive_limit): return
	var point := choose_flank_spawn_position()
	if not point.is_finite(): return
	spawn_authorized = true
	flank_spawn_authorized = true
	var enemy := manager.spawn_enemy("enemy_mutated_grub",point)
	spawn_authorized = false
	flank_spawn_authorized = false
	if enemy == null: return
	enemy.set_meta("evacuation_enemy",true)
	enemy.set_meta("evacuation_flanker",true)
	apply_pressure(enemy)
	spawned_count += 1

func distance_to_shelter() -> int:
	var offset := foot_position()-ring_center
	var scaled_distance := (offset/ring_axes()).length()
	if scaled_distance<=1.0: return 0
	# Distance along the indicated direction to the actual elliptical boundary.
	return ceili(offset.length()*(1.0-1.0/scaled_distance))
