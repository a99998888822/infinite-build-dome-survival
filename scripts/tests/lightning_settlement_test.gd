extends Node2D

const BEFORE = preload("res://scripts/tests/fixtures/lightning_settlement_original_resolver.gd")
const AFTER = preload("res://scripts/effects/element_reaction_resolver.gd")
const STATE_FIELDS = ["current_hp", "alive", "status_visual_revision", "_stunned_remaining",
	"_burning_remaining", "_burn_tick_timer", "_burn_damage_per_tick", "_burn_damage_remainder",
	"_burn_source_id", "_burn_sources", "_holy_flame", "_dark_flame", "_wet_remaining",
	"_wet_slow_multiplier", "_frozen_remaining", "_light_freeze_reacted", "_light_remaining",
	"_slowed_remaining", "_slow_multiplier", "_blinded_remaining", "_super_armor_remaining",
	"_super_armor_cooldown", "_super_armor_clock", "_super_armor_control_times"]
var checks := 0
var failures := 0

class CallbackEnemy extends EnemyController:
	var on_stun: Callable
	var calls := 0
	func apply_lightning_stun(duration: float = 0.65, control_power: float = -1.0) -> void:
		calls += 1
		super.apply_lightning_stun(duration, control_power)
		if on_stun.is_valid(): on_stun.call()

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func prepare(enemy: EnemyController, state: String) -> void:
	if state.contains("wet"): enemy.apply_wet(5, 0.8, 0)
	if state.contains("light"): enemy.apply_light(5)
	if state.contains("frozen"): enemy.apply_freeze(1, {}, 0)
	if state.contains("burn"):
		enemy.apply_burning(3, 7, "source_a", state.contains("holy"), state.contains("dark"))
		enemy.apply_burning(2, 5, "source_b", state.contains("holy"), state.contains("dark"))
	if state == "dead":
		enemy.alive = false
		enemy.current_hp = 0

func state_of(enemy: EnemyController) -> Dictionary:
	var state: Dictionary = {}
	for field in STATE_FIELDS:
		var value: Variant = enemy.get(field)
		state[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	state.mask = enemy.get_status_visual_mask()
	state.stun_visual = [is_instance_valid(enemy._lightning_visual)]
	if is_instance_valid(enemy._lightning_visual):
		state.stun_visual.append(enemy._lightning_visual.visible)
		state.stun_visual.append(enemy._lightning_visual.get("_remaining"))
	if enemy is CallbackEnemy: state.callback_calls = enemy.calls
	return state

# Each oracle/candidate contact runs on a fresh real actor and audio scope.
# No frames elapse between steps; explicit armor clock advances are identical.
func exercise(old: bool, generic: bool, actor: String, status: String, detonate: float,
		duration: float, power: float, callback: String = "") -> Dictionary:
	seed(20261021)
	var host := Node2D.new()
	add_child(host)
	var enemy: EnemyController
	if actor == "callback": enemy = CallbackEnemy.new()
	else: enemy = load("res://scenes/enemy/" + actor + ".tscn").instantiate()
	host.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.current_hp = 10000
	if enemy.sprite != null: enemy.sprite.show()
	prepare(enemy, status)
	var data := {"parent": host, "hit_position": Vector2.ZERO, "source_id": "electric_probe",
		"stun_duration": duration, "control_power": power, "detonate_burning": detonate}
	if generic: data.damage_event = DamageEvent.create({"damage": 10, "original_damage": 10})
	if enemy is CallbackEnemy:
		enemy.on_stun = func():
			if callback == "payload": data.detonate_burning = 1.0
			if callback == "holy": enemy.apply_burning(3, 7, "callback", true, false)
			if callback == "dark": enemy.apply_burning(3, 7, "callback", false, true)
			if callback == "wet": enemy.apply_wet(5, 0.8, 0)
			if callback == "clear": enemy.clear_burning()
			if callback == "dead": enemy.alive = false
	if callback == "unused_payload": data.detonate_burning = Vector2.ZERO
	var impact: RefCounted = AudioManager.begin_combat_audio()
	var rows: Array = []
	for step in 8:
		# Rewetting/reburning and dense refreshes must inspect current state.
		if step == 3: prepare(enemy, status)
		if step in [2, 4, 6]: enemy._tick_super_armor(0.31)
		var outcome: Variant
		if old or generic:
			var result: Dictionary = BEFORE.apply_element(enemy, "electric", data) if old else AFTER.apply_element(enemy, "electric", data)
			outcome = result if generic else (int(result.burning_detonated) | (int(result.extra_trigger) << 1))
		else:
			outcome = AFTER.apply_electric_contact(enemy, host, Vector2.ZERO, duration, power, detonate)
		rows.append({"result": outcome, "state": state_of(enemy)})
		check(AudioManager.current_combat_audio() == impact, "contact retains enclosing audio scope")
	var result := {"rows": rows, "requests": impact.requests.duplicate(true),
		"suppressed": impact.suppressed_cues.duplicate(true), "reactions": impact.reactions.duplicate(true),
		"next_random": randf()}
	AudioManager.end_combat_audio()
	check(AudioManager.current_combat_audio() == null, "audio scope balances")
	if enemy is CallbackEnemy: enemy.on_stun = Callable()
	host.free()
	return result

func run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for generic in [false, true]:
		for actor in ["mutated_grub", "elite_rusher", "underworld_wolf"]:
			for status in ["plain", "wet", "burn", "wet_burn", "holy_burn", "dark_burn", "frozen", "light_frozen", "dead"]:
				for detonate in [-1.0, 0.0, 1.0]:
					for pair in [[-1.0, -1.0], [0.5, 0.0], [5.0, 100.0]]:
						var a := exercise(true, generic, actor, status, detonate, pair[0], pair[1])
						var b := exercise(false, generic, actor, status, detonate, pair[0], pair[1])
						check(a == b, "oracle equivalence %s %s %s %s %s" % [generic, actor, status, detonate, pair])
		for callback in ["payload", "holy", "dark", "wet", "clear", "dead", "unused_payload"]:
			if not generic and callback in ["payload", "unused_payload"]: continue
			var status := "plain" if callback == "unused_payload" else "burn"
			var a := exercise(true, generic, "callback", status, 0.0, 0.5, 0.0, callback)
			var b := exercise(false, generic, "callback", status, 0.0, 0.5, 0.0, callback)
			check(a == b, "callback equivalence %s %s" % [generic, callback])
	check(AFTER.apply_electric_contact(null, self, Vector2.ZERO, 0.5, 0, 1) == 0, "null target")
	AudioManager.stop_combat_sfx()
	await get_tree().process_frame
	CampProgression.end_transient_session()
	print("LIGHTNING_SETTLEMENT checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
