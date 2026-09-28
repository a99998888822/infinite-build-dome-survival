extends RefCounted
class_name RunStatistics
## Run-owned counters; spending, banking and the bounded journal cannot erase them.

var run_id := ""
var frozen := false
var kills := 0
var combat_gold := 0
var interest := 0
var completed_waves := 0
var monsters: Dictionary = {}
var _enemies: Dictionary = {}
var _interest_events: Dictionary = {}
var _waves: Dictionary = {}
var _advice: Dictionary = {}
var _last_accepted := false


func _init() -> void:
	reset()


func reset() -> void:
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	frozen = false
	kills = 0
	combat_gold = 0
	interest = 0
	completed_waves = 0
	monsters.clear()
	_enemies.clear()
	_interest_events.clear()
	_waves.clear()
	_advice.clear()
	_last_accepted = false


func record_kill(instance_id: int, enemy_id: String) -> bool:
	if frozen or instance_id == 0 or enemy_id.is_empty() or _enemies.has(instance_id): return false
	_enemies[instance_id] = true
	kills += 1
	monsters[enemy_id] = int(monsters.get(enemy_id, 0)) + 1
	return true


func record_combat_gold(amount: int) -> void:
	if not frozen: combat_gold += maxi(0, amount)


func record_interest(result: Dictionary) -> void:
	# settlement_id groups a wave's receipt; event_id identifies each actual payment.
	var event_id := str(result.get("event_id", ""))
	if frozen or event_id.is_empty() or _interest_events.has(event_id) or not bool(result.get("success", false)): return
	_interest_events[event_id] = true
	interest += maxi(0, int(result.get("gain", 0)))


func complete_wave(wave_number: int) -> void:
	if frozen or wave_number <= 0 or _waves.has(wave_number): return
	_waves[wave_number] = true
	completed_waves += 1


func show_advice(kind: String, token: String) -> void:
	var key := kind + ":" + token
	if not frozen and not token.is_empty() and not _advice.has(key): _advice[key] = -1


func decide_advice(kind: String, token: String, accepted: bool) -> void:
	var key := kind + ":" + token
	if frozen or int(_advice.get(key, -2)) != -1: return
	_advice[key] = 1 if accepted else 0
	_last_accepted = accepted


func snapshot() -> Dictionary:
	var accepted := 0
	var refused := 0
	for decision in _advice.values():
		if int(decision) == 1: accepted += 1
		elif int(decision) == 0: refused += 1
	return {"run_id": run_id, "kills": kills, "gold": combat_gold, "waves": completed_waves, "interest": interest,
		"monsters": monsters.duplicate(true), "accepted": accepted, "refused": refused,
		"has_advice": accepted + refused > 0, "followed": accepted > refused or (accepted == refused and _last_accepted)}


func freeze() -> Dictionary:
	frozen = true
	return snapshot()
