extends Node
const BLOCKS = preload("res://scripts/effects/reaction_block_visual.gd")
const BUDGET = preload("res://scripts/effects/thunder_fire_visual_budget.gd")
class Probe extends ExplosionEffect:
	static var hits := 0
	static var total_damage := 0
	static var terrain := 0
	func _damage_enemies(_radius: float, damage: int, _falloff: float) -> void:
		hits += 1
		total_damage += damage
	func _damage_terrain(_radius: float) -> Array[Dictionary]:
		terrain += 1
		return []

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	check(BLOCKS.enabled,"approved block styles are enabled in normal gameplay")
	check(BLOCKS.thunder_fire_enabled,"approved irregular thunder-fire is enabled in normal gameplay")
	CampProgression.begin_transient_session()
	var weapon := WeaponInstance.new()
	check(weapon.initialize("weapon_void_blade",null),"weapon fixture initializes")
	var event := DamageEvent.create({"damage":20,"original_damage":20,"source_weapon_id":weapon.weapon_id})
	var baseline := 0
	for enabled in [false,true]:
		BLOCKS.enabled = enabled
		BLOCKS.thunder_fire_enabled = enabled
		var host := Node2D.new()
		add_child(host)
		Probe.hits = 0; Probe.total_damage = 0; Probe.terrain = 0
		for index in 24:
			var probe := Probe.new()
			host.add_child(probe)
			probe._weapon = weapon
			probe._damage_event = event
			probe._reaction_id = "thunder_fire"
			probe._radius_override = 72
			probe._detonate()
		check(Probe.hits==24 and Probe.terrain==24,"density reduction preserves every damage and terrain call")
		if enabled: check(Probe.total_damage==baseline,"production effect keeps the original reaction damage")
		else: baseline = Probe.total_damage
		if enabled:
			var bursts := get_tree().get_nodes_in_group("reaction_block_blasts")
			check(bursts.size()==13,"same-point burst admission remains four full, eight reduced, one small")
			check(bursts[-1].radius<=18 and bursts[-1].duration<=0.2,"dense-tier bursts remain small and short")
			var burst: Node = bursts[0]
			var age: float = burst.elapsed
			GameGlobal.set_runtime_flag("battle_runtime_paused",true)
			burst._process(0.1)
			check(burst.elapsed==age,"hit stop and pause freeze production effect animation")
			GameGlobal.set_runtime_flag("battle_runtime_paused",false)
			burst._process(0.6)
			check(burst.is_queued_for_deletion(),"production effect expires with no persistent tail")
		host.queue_free()
		for frame in 3: await get_tree().process_frame
	BLOCKS.enabled = true
	BLOCKS.thunder_fire_enabled = true
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	# Let the audio mixer release its stopped playback before quitting the engine.
	await get_tree().create_timer(0.12).timeout
	CampProgression.end_transient_session()
	print("REACTION_BLOCK_PREVIEW_TEST checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
