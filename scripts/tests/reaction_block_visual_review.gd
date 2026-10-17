extends "res://scripts/tests/reaction_style_audit.gd"
## Candidate reaction visuals, triggered exclusively by real bow projectiles.
const BLOCK_PREVIEW = preload("res://scripts/effects/reviews/reaction_block_preview.gd")
var cast_records: Array = []
var hit_records: Array = []
var preview_seen: Dictionary = {}
var recording_start := 0
var did_wind := false

func _process(delta: float) -> void:
	# The audit pauses the wave clock, so advance the normal casting cooldown here.
	if is_instance_valid(battle) and is_instance_valid(battle.loadout):
		battle.loadout.active_casting.tick(delta)

func _run() -> void:
	BLOCK_PREVIEW.enabled = not OS.get_cmdline_user_args().has("--baseline")
	await super._run()
	BLOCK_PREVIEW.enabled = false

func _setup(entry: Dictionary) -> void:
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	await super._setup(entry)
	# Review fixture: shorten only the bow cooldown so ordered elements fit a clip.
	weapon.active_cooldown_ms = 300
	weapon.weapon_data = weapon.weapon_data.duplicate(true)
	weapon.weapon_data.attachment_slots = 2
	for enemy in enemies:
		enemy.damage_received.connect(func(source: String,damage: int):
			hit_records.append({"enemy":enemy.get_instance_id(),"source":source,"damage":damage,"time":float(Time.get_ticks_usec()-recording_start)/1e6}))
	cast_records.clear()
	hit_records.clear()
	preview_seen.clear()
	did_wind = false

func _cast(action: Dictionary) -> void:
	weapon._attached_item_instances.clear()
	for id in action.spells:
		var item: Dictionary = DataRegistry.get_record("augmentations","scroll_"+str(id)).duplicate(true)
		item.item_instance_id = "reaction_preview_"+str(id)
		weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()
	var target: EnemyController = enemies[int(action.get("target",0))]
	var success := battle.loadout.active_casting.cast(weapon,target.global_position)
	cast_records.append({"time":current_time,"spells":action.spells,"success":success})
	if not success:
		failures += 1
		push_error("REACTION_REVIEW_CAST_FAILED "+str(action.spells))
	if action.spells.has("wind"): did_wind = true
	phase = str(action.label)

func _observe() -> void:
	super._observe()
	if did_wind:
		if observations.fire_radius_max > observations.fire_radius_first:
			observations.wind_expanded_fire = true
		if observations.ice_radius_max > observations.ice_radius_first:
			observations.wind_expanded_ice = true
	for node in get_tree().get_nodes_in_group("pixel_combat_effects"):
		if node.has_meta("reaction_block_candidate"):
			preview_seen[str(node.get_meta("pixel_effect_kind","unknown"))] = true
	if not get_tree().get_nodes_in_group("reaction_block_blasts").is_empty():
		preview_seen.thunder_fire = true

func _audit_case(entry: Dictionary,directory: String) -> Dictionary:
	recording_start = Time.get_ticks_usec()
	var row: Dictionary = await super._audit_case(entry,directory)
	row.scripted_production_impacts = false
	row.projectile_collision = true
	row.weapon = weapon.weapon_id
	row.casts = cast_records.duplicate(true)
	row.damage = hit_records.duplicate(true)
	row.preview_seen = preview_seen.duplicate()
	row.preview_enabled = BLOCK_PREVIEW.enabled
	if hit_records.is_empty() or cast_records.any(func(c):return not c.success):
		if row.passed: failures += 1
		row.passed = false
	return row
