extends "res://scripts/tests/reaction_style_audit.gd"
## Production reaction visuals, triggered exclusively by real bow projectiles.
const BLOCKS = preload("res://scripts/effects/reaction_block_visual.gd")
var cast_records: Array = []
var hit_records: Array = []
var preview_seen: Dictionary = {}
var recording_start := 0
var did_wind := false
var player_animation_samples: Array = []
var _last_player_pose := ""

func _process(delta: float) -> void:
	# The audit pauses the wave clock, so advance the normal casting cooldown here.
	if is_instance_valid(battle) and is_instance_valid(battle.loadout):
		battle.loadout.active_casting.tick(delta)

func _run() -> void:
	var original_enabled := BLOCKS.enabled
	var original_thunder_fire := BLOCKS.thunder_fire_enabled
	if OS.get_cmdline_user_args().has("--baseline"):
		BLOCKS.enabled = false
		BLOCKS.thunder_fire_enabled = false
	await super._run()
	BLOCKS.enabled = original_enabled
	BLOCKS.thunder_fire_enabled = original_thunder_fire

func _setup(entry: Dictionary) -> void:
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	await super._setup(entry)
	# Keep the normal animation clock alive; an idle input is enough to stand still.
	player._clear_move_input()
	player.set_physics_process(true)
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
	player_animation_samples.clear()
	_last_player_pose = ""

func _cast(action: Dictionary) -> void:
	weapon._attached_item_instances.clear()
	for id in action.spells:
		var item: Dictionary = DataRegistry.get_record("augmentations","scroll_"+str(id)).duplicate(true)
		if item.is_empty():
			failures += 1
			push_error("REACTION_REVIEW_UNKNOWN_ATTACHMENT "+str(id))
			return
		item.item_instance_id = "reaction_preview_"+str(id)
		weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()
	var target: EnemyController = enemies[int(action.get("target",0))]
	var aim := target.global_position
	if action.get("body_aim",false):
		var collider := target.get_node("CollisionShape2D") as CollisionShape2D
		aim = collider.global_transform*collider.shape.get_rect().get_center()
	var success := battle.loadout.active_casting.cast(weapon,aim)
	cast_records.append({"time":current_time,"spells":action.spells,"success":success})
	if not success:
		failures += 1
		push_error("REACTION_REVIEW_CAST_FAILED "+str(action.spells))
	if action.spells.has("wind"): did_wind = true
	phase = str(action.label)

func _observe() -> void:
	super._observe()
	var animator := player.action_animator
	var pose := "%s:%d" % [animator.current_clip,animator.current_frame]
	if pose != _last_player_pose:
		player_animation_samples.append({"time":current_time,"clip":animator.current_clip,"frame":animator.current_frame})
		_last_player_pose = pose
	if did_wind:
		if observations.fire_radius_max > observations.fire_radius_first:
			observations.wind_expanded_fire = true
		if observations.ice_radius_max > observations.ice_radius_first:
			observations.wind_expanded_ice = true
	for node in get_tree().get_nodes_in_group("pixel_combat_effects"):
		if node.has_meta("reaction_block_visual"):
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
	row.preview_enabled = BLOCKS.enabled
	row.production_defaults = not OS.get_cmdline_user_args().has("--baseline")
	row.thunder_fire_enabled = BLOCKS.thunder_fire_enabled
	row.player_animation = player_animation_samples.duplicate(true)
	var attack_frames: Dictionary = {}
	for sample in player_animation_samples:
		if sample.clip == "attack": attack_frames[sample.frame] = true
	row.player_animation_completed = attack_frames.size() >= 3 and player.action_animator.action.is_empty()
	if not row.player_animation_completed:
		if row.passed: failures += 1
		row.passed = false
		push_error("REACTION_REVIEW_PLAYER_ANIMATION_STALLED")
	if hit_records.is_empty() or cast_records.any(func(c):return not c.success):
		if row.passed: failures += 1
		row.passed = false
	return row
