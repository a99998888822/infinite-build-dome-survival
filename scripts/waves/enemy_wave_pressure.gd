extends RefCounted
class_name EnemyWavePressure
## Run-owned adaptation. The manager supplies an unpaused combat clock and events.

var rules: Dictionary = {}
var next_bonus: Dictionary = {"normal": 0, "elite": 0}
var wave_bonus: Dictionary = {"normal": 0, "elite": 0}
var last_summary: Dictionary = {}
var elapsed := 0.0
var _wave := 0
var _finished := true
var _engaged: Dictionary = {}
var _counts: Dictionary = {}
var _slow_waves: Dictionary = {"normal": 0, "elite": 0}


static func calculate_erosion(erosion: float) -> Dictionary:
	var config := DataRegistry.get_record("erosion_pressure_rules", "erosion_enemy_stats")
	var value := maxf(0.0, erosion)
	var reference := maxf(1.0, float(config.get("erosion_full_at", 100)))
	var hp := value / reference * float(config.get("max_hp_bonus_percent", 180)) / 100.0
	var damage := value / reference * float(config.get("damage_bonus_percent", 90)) / 100.0
	for step: Dictionary in config.get("growth_steps", []):
		var excess := maxf(0.0, value - float(step.erosion)) / reference / 100.0
		hp += excess * float(step.max_hp_bonus_percent)
		damage += excess * float(step.damage_bonus_percent)
	return {"erosion": value, "max_hp_multiplier": 1.0 + hp, "damage_multiplier": 1.0 + damage,
		"armor_multiplier": 1.0 + value / reference * float(config.get("armor_bonus_percent", 135)) / 100.0}


func reset() -> void:
	rules = DataRegistry.get_record("enemy_adaptation_rules", "kill_speed_hp")
	next_bonus = {"normal": 0, "elite": 0}
	wave_bonus = next_bonus.duplicate()
	_slow_waves = {"normal": 0, "elite": 0}
	last_summary.clear()
	_engaged.clear()
	_counts.clear()
	elapsed = 0.0
	_wave = 0
	_finished = true


func begin_wave(wave: int) -> void:
	if rules.is_empty(): reset()
	_wave = wave
	wave_bonus = next_bonus.duplicate()
	elapsed = 0.0
	_finished = false
	_engaged.clear()
	_counts = {"normal": {"samples": 0, "fast": 0}, "elite": {"samples": 0, "fast": 0}}


func advance(delta: float) -> void:
	if not _finished: elapsed += maxf(0.0, delta)


func record_damage(instance_id: int, enemy_type: String) -> void:
	if _finished or not _counts.has(enemy_type) or _engaged.has(instance_id): return
	_engaged[instance_id] = {"type": enemy_type, "first_hit": elapsed}


func record_kill(instance_id: int) -> void:
	if _finished or not _engaged.has(instance_id): return
	var entry: Dictionary = _engaged[instance_id]
	_engaged.erase(instance_id)
	var count: Dictionary = _counts[entry.type]
	count.samples += 1
	if elapsed - float(entry.first_hit) <= float(rules.fast_kill_ms) / 1000.0 + 0.000001:
		count.fast += 1


func finish_wave(pressure: Dictionary) -> Dictionary:
	if _finished: return last_summary.duplicate(true)
	_finished = true
	# Engaged survivors are slow samples. New encounters with insufficient time
	# and enemies never hit do not bias the denominator; crowd pressure is separate.
	for entry: Dictionary in _engaged.values():
		if elapsed - float(entry.first_hit) > float(rules.fast_kill_ms) / 1000.0 + 0.000001:
			_counts[entry.type].samples += 1
	_engaged.clear()
	var observed := elapsed >= float(rules.minimum_observed_seconds)
	var eligible := _wave + 1 >= int(rules.first_effective_wave) and observed
	var struggling := bool(pressure.get("struggling", false))
	last_summary = {"wave": _wave, "observed_seconds": elapsed, "struggling": struggling, "types": {}}
	for kind: String in ["normal", "elite"]:
		var config: Dictionary = rules[kind]
		var count: Dictionary = _counts[kind]
		var ratio := float(count.fast) / float(count.samples) if int(count.samples) > 0 else 0.0
		var enough := int(count.samples) >= int(config.minimum_samples)
		var reason := "hold"
		if eligible and struggling:
			next_bonus[kind] = maxi(0, int(next_bonus[kind]) - int(config.step_percent))
			_slow_waves[kind] = 0
			reason = "struggling"
		elif eligible and enough and ratio * 100.0 + 0.000001 >= float(rules.fast_ratio_percent):
			next_bonus[kind] = mini(int(config.max_percent), int(next_bonus[kind]) + int(config.step_percent))
			_slow_waves[kind] = 0
			reason = "fast_kills"
		elif eligible and enough and ratio * 100.0 < float(rules.slow_ratio_percent):
			_slow_waves[kind] += 1
			if int(_slow_waves[kind]) >= int(rules.slow_waves_to_relax):
				next_bonus[kind] = maxi(0, int(next_bonus[kind]) - int(config.step_percent))
				_slow_waves[kind] = 0
				reason = "slow_kills"
		else:
			_slow_waves[kind] = 0
		last_summary.types[kind] = {"samples": count.samples, "fast_kills": count.fast, "fast_ratio": ratio,
			"current_bonus_percent": wave_bonus[kind], "next_bonus_percent": next_bonus[kind], "reason": reason}
	return last_summary.duplicate(true)


func build_modifiers(enemy_type: String) -> Array[Dictionary]:
	var bonus := int(wave_bonus.get(enemy_type, 0))
	if bonus <= 0: return []
	return [{"id": "kill_speed_hp", "source_type": "wave", "source_id": "kill_speed_hp",
		"target_scope": "enemy", "stat": "max_hp", "operation": Modifier.OPERATION_MULTIPLY,
		"value": 1.0 + float(bonus) / 100.0, "duration": Modifier.PERMANENT_DURATION,
		"stack_rule": Modifier.STACK_RULE_UNIQUE}]


func snapshot() -> Dictionary:
	return {"wave_bonus_percent": wave_bonus.duplicate(), "next_bonus_percent": next_bonus.duplicate(),
		"last_wave": last_summary.duplicate(true)}
