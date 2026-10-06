extends RefCounted
class_name WeaponInstance

const DAMAGE_KIND_RANGED: String = "ranged"
const DAMAGE_KIND_MELEE: String = "melee"
const DAMAGE_KIND_ELEMENT: String = "element"
const RARITY_COLORS: Dictionary = {
	"common": Color(0.43, 0.72, 0.48, 1.0),
	"uncommon": Color(0.34, 0.82, 0.78, 1.0),
	"rare": Color(0.34, 0.55, 0.95, 1.0),
	"epic": Color(0.72, 0.42, 0.94, 1.0),
	"mythic": Color(1.0, 0.54, 0.25, 1.0),
	"legendary": Color(1.0, 0.82, 0.28, 1.0),
}
const MIN_ATTACK_INTERVAL_SECONDS: float = 0.05
const ATTACHMENT_ICON_SIZE := 24
const ATTACHMENT_ICON_GAP := " "
const EMPTY_ATTACHMENT_ICON := "res://assets/ui/finance/empty_enchantment_slot.svg"
const DAMAGE_SOURCE_COLORS := {
	"melee_damage": "#EE7777",
	"ranged_damage": "#7FD88F",
	"element_damage": "#78B7FF",
	"principal": "#F5D76E",
}
const EFFECT_PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ATTACHMENT_BONUS_KEYS := ["all_damage_percent", "element_damage_percent", "projectile_count", "damage_area_size", "crit_chance", "crit_damage", "attack_speed"]

var weapon_id: String = ""
static var _next_instance_id: int = 1
var instance_id: String = ""
var trade_base_basis: int = -1
var trade_upgrade_basis: Dictionary = {}
# Reserved for earned, instance-bound titles; combat title scoring is a later feature.
var battle_title: Dictionary = {}
var weapon_data: Dictionary = {}
# Enabled by the production loadout; legacy fixtures may opt out explicitly.
var use_active_range_rules := false
var owner_player: PlayerController = null
var principal_getter: Callable = Callable()
var level: int = 1
var runtime_stats: Dictionary = {}
var effect_ids: Array[String] = []
var effect_modifiers: Array[Dictionary] = []
var _base_effect_ids: Array[String] = []
var _base_effect_modifiers: Array[Dictionary] = []
var _attached_item_instances: Array[Dictionary] = []
var _attachment_bonuses: Dictionary = {}
var attack_interval_ms: int = 0
var active_cooldown_ms: int = -1
var attack_timer: float = 0.0
var volley_index: int = 0
var attack_context: Dictionary = {}
var source_instance_id := ""
var _cast_stats: Dictionary = {}
var _cast_player_stats: Dictionary = {}
var _cast_principal := -1.0
# A replay has its own immutable world origin; the real player never moves.
var fixed_attack_origin: Variant = null
var is_bounce_attack := false
var grenade_blast_radius: float = 0.0
var _attack_hit_sfx_played: bool = false
var _projectile_hit_sfx_played: Dictionary = {}
var _last_attack_feedback_frame: int = -1
var _last_projectile_feedback_frame: int = -1
var _last_attack_visual_frame: int = -1
var _last_projectile_visual_frame: int = -1


func initialize(target_weapon_id: String, player: PlayerController) -> bool:
	var data := DataRegistry.get_record("weapons", target_weapon_id)
	if data.is_empty():
		push_error("[WeaponInstance] missing weapon config: %s" % target_weapon_id)
		return false

	weapon_id = target_weapon_id
	instance_id = "weapon_%d" % _next_instance_id
	_next_instance_id += 1
	trade_base_basis = -1
	trade_upgrade_basis.clear()
	battle_title.clear()
	weapon_data = data
	owner_player = player
	level = 1
	runtime_stats = data.get("base_stats", {}).duplicate(true)
	_base_effect_ids.clear()
	var raw_effect_ids: Variant = data.get("effects", [])
	if raw_effect_ids is Array:
		for effect_id in raw_effect_ids:
			_base_effect_ids.append(str(effect_id))
	_base_effect_modifiers.clear()
	var raw_effect_modifiers: Variant = data.get("effect_modifiers", [])
	if raw_effect_modifiers is Array:
		for modifier in raw_effect_modifiers:
			if modifier is Dictionary:
				_base_effect_modifiers.append(modifier.duplicate(true))
	_attached_item_instances.clear()
	_reset_effect_runtime()
	attack_interval_ms = int(data.get("attack_interval_ms", 1000))
	active_cooldown_ms = int(data.get("active_cooldown_ms", attack_interval_ms))
	attack_timer = 0.0
	volley_index = 0
	grenade_blast_radius = float(data.get("grenade_blast_radius", 0.0))
	reset_hit_sfx_state()
	return true


func tick(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)


func begin_attack() -> void:
	attack_context = {"bounce_used": false}
	reset_hit_sfx_state()


func make_cast_copy() -> WeaponInstance:
	# Freeze a cast's geometry, attachment sequence and values while the loadout
	# can still change in a paused reward screen. Each cast owns its proc budget.
	var copy := WeaponInstance.new()
	copy.initialize(weapon_id, owner_player)
	copy.source_instance_id = instance_id
	copy.weapon_data = weapon_data.duplicate(true)
	copy.use_active_range_rules = use_active_range_rules
	copy.principal_getter = principal_getter
	copy.level = level
	copy.runtime_stats = runtime_stats.duplicate(true)
	copy.attack_interval_ms = attack_interval_ms
	copy.active_cooldown_ms = active_cooldown_ms
	copy.grenade_blast_radius = grenade_blast_radius
	copy.volley_index = volley_index
	copy._base_effect_ids = _base_effect_ids.duplicate()
	copy._base_effect_modifiers = _base_effect_modifiers.duplicate(true)
	copy._attached_item_instances = _attached_item_instances.duplicate(true)
	copy._rebuild_attachment_effects()
	for stat in StatDefinitions.get_all_stat_ids():
		copy._cast_stats[stat] = get_stat(stat)
		copy._cast_player_stats[stat] = owner_player.get_stat(stat)
	copy._cast_principal = get_current_principal()
	copy.begin_attack()
	return copy


func get_attack_origin() -> Vector2:
	return fixed_attack_origin if fixed_attack_origin is Vector2 else owner_player.global_position


func make_bounce_copy(point: Vector2) -> WeaponInstance:
	var copy := WeaponInstance.new()
	copy.weapon_id = weapon_id
	copy.instance_id = instance_id + "_bounce"
	copy.weapon_data = weapon_data.duplicate(true)
	copy.use_active_range_rules = use_active_range_rules
	copy.owner_player = owner_player
	copy.principal_getter = principal_getter
	copy.level = level
	copy.runtime_stats = runtime_stats.duplicate(true)
	copy.attack_interval_ms = attack_interval_ms
	copy.active_cooldown_ms = active_cooldown_ms
	copy.grenade_blast_radius = grenade_blast_radius
	copy.volley_index = volley_index
	copy.fixed_attack_origin = point
	copy.is_bounce_attack = true
	copy.source_instance_id = source_instance_id
	copy._cast_stats = _cast_stats.duplicate()
	copy._cast_player_stats = _cast_player_stats.duplicate()
	copy._cast_principal = _cast_principal
	copy._base_effect_ids = _base_effect_ids.duplicate()
	copy._base_effect_ids.erase("bounce")
	copy._base_effect_modifiers = _base_effect_modifiers.duplicate(true)
	for item in _attached_item_instances:
		if not "bounce" in item.get("effect_ids", []):
			copy._attached_item_instances.append(item.duplicate(true))
	copy._rebuild_attachment_effects()
	copy.begin_attack()
	return copy


func can_attack() -> bool:
	return attack_timer <= 0.0


func get_active_cooldown_seconds() -> float:
	var base := float(active_cooldown_ms if active_cooldown_ms >= 0 else weapon_data.get("active_cooldown_ms", attack_interval_ms)) / 1000.0
	return maxf(0.15, base * get_actual_attack_interval_seconds() / maxf(float(weapon_data.get("attack_interval_ms", attack_interval_ms)) / 1000.0, 0.001))


func reset_attack_timer() -> void:
	attack_timer = get_actual_attack_interval_seconds()
	reset_hit_sfx_state()


func reset_hit_sfx_state() -> void:
	_attack_hit_sfx_played = false
	_projectile_hit_sfx_played.clear()
	_last_attack_feedback_frame = -1
	_last_projectile_feedback_frame = -1
	_last_attack_visual_frame = -1
	_last_projectile_visual_frame = -1


func get_hit_sfx_path() -> String:
	return str(weapon_data.get("hit_sfx", ""))


func play_attack_hit_sfx() -> bool:
	var frame := Engine.get_physics_frames()
	if _attack_hit_sfx_played:
		return false
	_attack_hit_sfx_played = true
	_last_attack_feedback_frame = frame
	AudioManager.play_weapon_hit_sfx(weapon_id, 30)
	return true


func has_played_attack_hit_sfx() -> bool:
	return _attack_hit_sfx_played


func play_projectile_hit_sfx(projectile_id: String) -> bool:
	var key := projectile_id.strip_edges()
	var frame := Engine.get_physics_frames()
	if key.is_empty() or _projectile_hit_sfx_played.has(key) or _last_projectile_feedback_frame == frame:
		return false
	_projectile_hit_sfx_played[key] = true
	_last_projectile_feedback_frame = frame
	AudioManager.play_weapon_hit_sfx(weapon_id, 15)
	return true


func register_hit_feedback_frame(is_projectile: bool) -> bool:
	var frame := Engine.get_physics_frames()
	if is_projectile:
		if _last_projectile_visual_frame == frame:
			return false
		_last_projectile_visual_frame = frame
		return true
	if _last_attack_visual_frame == frame:
		return false
	_last_attack_visual_frame = frame
	return true


func has_played_projectile_hit_sfx(projectile_id: String) -> bool:
	return _projectile_hit_sfx_played.has(projectile_id.strip_edges())


func upgrade() -> bool:
	var max_level := int(weapon_data.get("max_level", 1))
	if level >= max_level:
		return false
	level += 1
	_apply_level_upgrades(level)
	return true


func get_stat(stat_id: String) -> float:
	if _cast_stats.has(stat_id):
		return float(_cast_stats[stat_id])
	var default_value := StatDefinitions.get_default_value(stat_id)
	var weapon_value := float(runtime_stats.get(stat_id, default_value))
	var player_value := owner_player.get_stat(stat_id) if owner_player != null else default_value
	return StatDefinitions.clamp_stat_value(stat_id, weapon_value + player_value - default_value + get_attachment_bonus(stat_id))


func get_attachment_bonus(key: String) -> float:
	return float(_attachment_bonuses.get(key, 0.0))


func get_attachment_damage_multiplier(elemental: bool = false) -> float:
	var multiplier := 1.0 + get_attachment_bonus("all_damage_percent") / 100.0
	if elemental:
		multiplier *= 1.0 + get_attachment_bonus("element_damage_percent") / 100.0
	return multiplier


func get_weapon_stat(stat_id: String) -> float:
	return float(runtime_stats.get(stat_id, StatDefinitions.get_default_value(stat_id)))


func get_effect_ids() -> Array[String]:
	return effect_ids.duplicate()


func has_effect(effect_id: String) -> bool:
	return effect_ids.has(effect_id.strip_edges())


func get_enchantment_sequence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _base_effect_ids:
		result.append({"effect_id": id, "item_instance_id": "__base_effect__"})
	for item in _attached_item_instances:
		for id in item.get("effect_ids", []):
			result.append({"effect_id": str(id), "item_instance_id": str(item.get("item_instance_id", ""))})
	return result


func get_split_continuation(item_id: String) -> int:
	var sequence := get_enchantment_sequence()
	for index in sequence.size():
		if sequence[index].effect_id == "split" and sequence[index].item_instance_id == item_id:
			return index + 1
	return 0


func get_effect_instances(effect_id: String) -> Array[Dictionary]:
	var normalized_id := effect_id.strip_edges()
	var result: Array[Dictionary] = []
	if normalized_id.is_empty():
		return result
	if _base_effect_ids.has(normalized_id):
		result.append({"item_instance_id": "__base_effect__"})
	for item_instance in _attached_item_instances:
		var raw_effect_ids: Variant = item_instance.get("effect_ids", [])
		if raw_effect_ids is Array and raw_effect_ids.has(normalized_id):
			result.append(item_instance.duplicate(true))
	return result


func add_effect_by_id(effect_id: String) -> bool:
	var normalized_id := effect_id.strip_edges()
	if normalized_id.is_empty() or effect_ids.has(normalized_id):
		return false
	effect_ids.append(normalized_id)
	return true


func get_attachment_slot_count() -> int:
	return get_attachment_slots_for_rarity(get_visual_rarity())


static func get_attachment_slots_for_rarity(rarity: String) -> int:
	return 2 if rarity in ["rare", "epic", "mythic", "legendary"] else 1


func has_attachment_slot() -> bool:
	return get_attachment_slot_count() > 0


func has_available_attachment_slot() -> bool:
	return _attached_item_instances.size() < get_attachment_slot_count()


func get_attached_item_instance() -> Dictionary:
	return _attached_item_instances[0].duplicate(true) if not _attached_item_instances.is_empty() else {}


func get_attached_item_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _attached_item_instances:
		result.append(item.duplicate(true))
	return result


func attach_item_instance(item_instance: Dictionary) -> bool:
	if not has_available_attachment_slot() or item_instance.is_empty() or not get_attachment_incompatibility(item_instance).is_empty():
		return false
	var item_instance_id := str(item_instance.get("item_instance_id", ""))
	if item_instance_id.is_empty():
		return false
	for attached_item in _attached_item_instances:
		if str(attached_item.get("item_instance_id", "")) == item_instance_id:
			return false
	_attached_item_instances.append(item_instance.duplicate(true))
	_rebuild_attachment_effects()
	return true


func replace_attachment_instance(target_index: int, item_instance: Dictionary) -> Dictionary:
	if target_index < 0 or target_index >= _attached_item_instances.size() or item_instance.is_empty():
		return {}
	var item_id := str(item_instance.get("item_instance_id", ""))
	if item_id.is_empty() or not get_attachment_incompatibility(item_instance).is_empty():
		return {}
	for attached in _attached_item_instances:
		if str(attached.get("item_instance_id", "")) == item_id:
			return {}
	var replaced := _attached_item_instances[target_index].duplicate(true)
	_attached_item_instances[target_index] = item_instance.duplicate(true)
	_rebuild_attachment_effects()
	return replaced


func get_attachment_incompatibility(item: Dictionary) -> String:
	for effect_id in item.get("effect_ids", []):
		if effect_id in weapon_data.get("unsupported_effects", []):
			return "此武器暂不支持%s附魔" % ("穿透" if effect_id == "pierce" else str(effect_id))
	return ""


func detach_item_instance(item_instance_id: String = "") -> Dictionary:
	if _attached_item_instances.is_empty():
		return {}
	var target_index := _attached_item_instances.size() - 1
	if not item_instance_id.is_empty():
		for index in range(_attached_item_instances.size()):
			if str(_attached_item_instances[index].get("item_instance_id", "")) == item_instance_id:
				target_index = index
				break
		if str(_attached_item_instances[target_index].get("item_instance_id", "")) != item_instance_id:
			return {}
	var detached := _attached_item_instances[target_index].duplicate(true)
	_attached_item_instances.remove_at(target_index)
	_rebuild_attachment_effects()
	return detached


func move_attachment_instance(item_instance_id: String, target_index: int) -> bool:
	if target_index < 0 or target_index >= _attached_item_instances.size():
		return false
	for index in _attached_item_instances.size():
		if str(_attached_item_instances[index].get("item_instance_id", "")) == item_instance_id:
			if index != target_index:
				var item := _attached_item_instances[index]
				_attached_item_instances.remove_at(index)
				_attached_item_instances.insert(target_index, item)
				_rebuild_attachment_effects()
			return true
	return false


func add_augmentation(augmentation_id: String) -> bool:
	if not has_attachment_slot():
		return false
	var augmentation := DataRegistry.get_record("augmentations", augmentation_id)
	if augmentation.is_empty():
		return false
	var legacy_item := {
		"item_instance_id": "legacy_%s" % augmentation_id,
		"base_item_id": augmentation_id,
		"display_name": str(augmentation.get("display_name", augmentation_id)),
		"effect_ids": augmentation.get("effect_ids", []).duplicate(),
		"modifiers": augmentation.get("modifiers", []).duplicate(true),
		"weapon_bonuses": augmentation.get("weapon_bonuses", {}).duplicate(true),
	}
	return attach_item_instance(legacy_item)


func _reset_effect_runtime() -> void:
	effect_ids = _base_effect_ids.duplicate()
	effect_modifiers = _base_effect_modifiers.duplicate(true)
	_attachment_bonuses.clear()


func _rebuild_attachment_effects() -> void:
	_reset_effect_runtime()
	for item_instance in _attached_item_instances:
		var item_instance_id := str(item_instance.get("item_instance_id", ""))
		# Keep attachment bonuses outside player stats and permanent level stats.
		# Rebuilding makes transfer/removal reversible and bounce copies independent.
		var bonuses: Dictionary = item_instance.get("weapon_bonuses", {})
		for key in bonuses:
			if key in ATTACHMENT_BONUS_KEYS:
				_attachment_bonuses[key] = get_attachment_bonus(key) + float(bonuses[key])
		for effect_id in item_instance.get("effect_ids", []):
			add_effect_by_id(str(effect_id))
		for modifier in item_instance.get("modifiers", []):
			if modifier is Dictionary:
				var modifier_data: Dictionary = modifier.duplicate(true)
				modifier_data["source_id"] = item_instance_id
				add_effect_modifier(modifier_data)


func add_effect_modifier(modifier_data: Dictionary) -> void:
	if str(modifier_data.get("channel", "")).is_empty():
		return
	effect_modifiers.append(modifier_data.duplicate(true))


func remove_effect_modifiers_by_source(source_id: String) -> void:
	for index in range(effect_modifiers.size() - 1, -1, -1):
		if str(effect_modifiers[index].get("source_id", "")) == source_id:
			effect_modifiers.remove_at(index)


func get_effect_modifiers(effect_id: String = "", source_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier in effect_modifiers:
		var modifier_effect_id := str(modifier.get("effect_id", "*"))
		var modifier_source_id := str(modifier.get("source_id", ""))
		if not effect_id.is_empty() and modifier_effect_id != "*" and modifier_effect_id != effect_id:
			continue
		if not source_id.is_empty() and modifier_source_id != source_id and modifier_source_id != "":
			# Another copy's local modifiers must not amplify this copy. Global
			# relic/base modifiers and explicit cross-effect modifiers still apply.
			var belongs_to_other_copy := false
			for item in _attached_item_instances:
				if str(item.get("item_instance_id", "")) == modifier_source_id and effect_id in item.get("effect_ids", []):
					belongs_to_other_copy = true
					break
			if belongs_to_other_copy:
				continue
		result.append(modifier.duplicate(true))
	return result


func get_next_upgrade_rarity() -> String:
	var next_level := level + 1
	var upgrade_entry: Dictionary = weapon_data.get("level_upgrades", {}).get(str(next_level), {})
	return str(upgrade_entry.get("rarity", ""))


func get_load_cost() -> int:
	return int(weapon_data.get("load_cost", 0))


func get_hit_radius() -> float:
	var base_radius := float(weapon_data.get("hit_radius", 0))
	if use_active_range_rules:
		if is_mutant_tentacle():
			return StatDefinitions.calculate_damage_area_radius(base_radius, get_stat("damage_area_size"))
		return maxf(base_radius, 4.0) if str(weapon_data.get("projectile_behavior", "")) == "plasma" else base_radius
	if is_nightwatch_spear() or is_camp_dagger() or is_copper_lamp() or is_mutant_tentacle() or is_earth_hammer():
		return StatDefinitions.calculate_damage_area_radius(base_radius, get_stat("damage_area_size"))
	if str(weapon_data.get("projectile_behavior", "")) == "plasma":
		# One radius owns the plasma core, contact query, collider and item details.
		return maxf(StatDefinitions.calculate_damage_area_radius(base_radius, get_stat("damage_area_size")), 4.0)
	return StatDefinitions.calculate_damage_area_radius(StatDefinitions.calculate_attack_radius(base_radius, get_stat("area_size")), get_stat("damage_area_size"))


func get_base_attack_range() -> float:
	var base_range := float(weapon_data.get("attack_range", weapon_data.get("hit_radius", 0)))
	if is_earth_hammer():
		base_range = float(weapon_data.ground_first_offset) + (get_ground_node_count() - 1) * float(weapon_data.ground_node_spacing)
	return base_range


func get_attack_range() -> float:
	var bonus := get_stat("area_size")
	if use_active_range_rules and has_combat_tag("扇形") and has_combat_tag("范围"):
		bonus += get_stat("damage_area_size")
	return StatDefinitions.calculate_attack_radius(get_base_attack_range(), bonus)


func get_combat_tags() -> Array[String]:
	var result: Array[String] = []
	for tag in weapon_data.get("combat_tags", []):
		result.append(str(tag))
	return result


func has_combat_tag(tag: String) -> bool:
	return tag in weapon_data.get("combat_tags", [])


func get_projectile_visual_scale() -> float:
	if use_active_range_rules and has_combat_tag("投射物"):
		return StatDefinitions.calculate_damage_area_multiplier(get_stat("damage_area_size"))
	return 1.0


func get_dagger_outer_radius() -> float:
	if use_active_range_rules:
		return get_attack_range()
	return 36.0 * get_attack_range() / 40.0 + get_hit_radius()


func get_dagger_body_scale() -> Vector2:
	var body_reach := get_attack_range()
	if use_active_range_rules:
		body_reach = StatDefinitions.calculate_attack_radius(get_base_attack_range(), get_stat("area_size"))
	return Vector2(body_reach / 40.0, get_hit_radius() / 4.0)


func get_projectile_speed() -> float:
	return float(weapon_data.get("projectile_speed", 0))


func is_grenade() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "grenade"


func is_ritual_tome() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "ritual_domain"


func is_coin_purse() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "coin"


func is_meteor_flail() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "meteor_flail"


func is_nightwatch_spear() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "nightwatch_spear"


func is_camp_dagger() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "camp_dagger"


func is_copper_lamp() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "copper_lamp"


func is_mutant_tentacle() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "mutant_tentacle"


func is_earth_hammer() -> bool:
	return str(weapon_data.get("projectile_behavior", "")) == "earth_hammer"


func get_ground_node_count() -> int:
	return clampi(int(weapon_data.get("ground_node_count", 5)), 1, 8)


func get_damage_stat_id() -> String:
	match get_attack_kind():
		DAMAGE_KIND_MELEE: return "melee_damage"
		DAMAGE_KIND_ELEMENT: return "element_damage"
	return "ranged_damage"


func get_domain_axes() -> Vector2:
	return Vector2(get_attack_range(), StatDefinitions.calculate_attack_radius(float(weapon_data.get("domain_minor_axis", 145)), get_stat("area_size")))


func get_principal_damage_bonus() -> float:
	return float(weapon_data.get("principal_damage_coefficient", 0.0)) * sqrt(get_current_principal())


func get_current_principal() -> float:
	if _cast_principal >= 0:
		return _cast_principal
	# The finance stat is a starting talent, not the live bank balance.
	return maxf(0.0, float(principal_getter.call())) if principal_getter.is_valid() else 0.0


func get_base_attack_damage() -> float:
	return _get_damage_component_base(get_damage_stat_id()) + get_principal_damage_bonus()


func get_split_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in get_effect_instances("split"):
		var context := EFFECT_PARAMETERS.build_weapon_context(self, "split", {
			"child_count": 2.0, "spread_angle": 36.0, "damage_multiplier": 0.45,
		}, str(item.get("item_instance_id", "")))
		result.append({"child_count": clampi(roundi(context.get_resolved_parameter("child_count", 2.0)), 1, 8),
			"enchantment_start": get_split_continuation(str(item.get("item_instance_id", ""))),
			"spread_angle": maxf(context.get_resolved_parameter("spread_angle", 36.0), 0.0),
			"damage_multiplier": maxf(context.get_resolved_parameter("damage_multiplier", 0.45), 0.0)})
	return result


func get_pierce_hit_limit() -> int:
	var extra := 0
	for item in get_effect_instances("pierce"):
		var context := EFFECT_PARAMETERS.build_weapon_context(self, "pierce", {"extra_target_hits": 0.0}, str(item.get("item_instance_id", "")))
		extra += clampi(roundi(context.get_resolved_parameter("extra_target_hits", 0.0)), 0, 32)
	return 1 + mini(extra, 32)


func get_grenade_blast_radius() -> float:
	return maxf(1.0, StatDefinitions.calculate_damage_area_radius(grenade_blast_radius, get_stat("damage_area_size")))


func get_grenade_split_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if not is_grenade():
		return profiles
	for item in get_effect_instances("split"):
		var context := EFFECT_PARAMETERS.build_weapon_context(self, "split", {
			"child_count": 2.0, "spread_angle": 36.0, "damage_multiplier": 0.45,
		}, str(item.get("item_instance_id", "")))
		profiles.append({
			"enchantment_start": get_split_continuation(str(item.get("item_instance_id", ""))),
			"child_count": clampi(roundi(context.get_resolved_parameter("child_count", 2.0)), 1, 8),
			"spread_angle": maxf(context.get_resolved_parameter("spread_angle", 36.0), 0.0),
			"damage_multiplier": maxf(context.get_resolved_parameter("damage_multiplier", 0.45), 0.0),
			"radius_multiplier": maxf(float(weapon_data.get("grenade_split_radius_multiplier", 0.5)), 0.01),
			"flight_seconds": maxf(float(weapon_data.get("grenade_split_flight_seconds", 0.32)), 0.01),
			"arc_height": maxf(float(weapon_data.get("grenade_split_arc_height", 32)), 0.0),
		})
	return profiles


func get_spread_angle() -> float:
	return float(weapon_data.get("spread_angle", 0))



func get_actual_attack_interval_seconds() -> float:
	var base_interval := maxf(float(attack_interval_ms) / 1000.0, MIN_ATTACK_INTERVAL_SECONDS)
	return maxf(StatDefinitions.calculate_attack_interval(base_interval, get_stat("attack_speed")), MIN_ATTACK_INTERVAL_SECONDS)


func calculate_damage_events(force_critical: bool = false) -> Array[DamageEvent]:
	var events: Array[DamageEvent] = []
	if get_attack_kind() in [DAMAGE_KIND_RANGED, DAMAGE_KIND_ELEMENT, DAMAGE_KIND_MELEE]:
		events.append(_build_damage_event(get_attack_kind(), force_critical))
	return events


func get_projectile_angles() -> Array[float]:
	var projectile_count: int = maxi(1, int(get_stat("projectile_count")))
	var spread_angle := get_spread_angle()
	var angles: Array[float] = []
	if weapon_data.has("projectile_spacing_degrees"):
		var gap := float(weapon_data.projectile_spacing_degrees)
		for index in projectile_count:
			angles.append((index - (projectile_count - 1) * 0.5) * gap)
		return angles
	if projectile_count == 1:
		angles.append(0.0)
		return angles
	var start_angle := -spread_angle / 2.0
	var step := spread_angle / float(projectile_count - 1)
	for index in range(projectile_count):
		angles.append(start_angle + step * float(index))
	return angles


func _apply_level_upgrades(target_level: int) -> void:
	var upgrades: Dictionary = weapon_data.get("level_upgrades", {})
	var upgrade_entry: Dictionary = upgrades.get(str(target_level), {})
	var upgrade_list: Array = upgrade_entry.get("effects", [])
	for upgrade in upgrade_list:
		if not (upgrade is Dictionary):
			continue
		var value := int(upgrade.get("value", 0))
		if upgrade.has("stat"):
			var stat_id := str(upgrade["stat"])
			runtime_stats[stat_id] = StatDefinitions.clamp_stat_value(stat_id, get_weapon_stat(stat_id) + value)
		elif str(upgrade.get("field", "")) == "attack_interval_ms":
			attack_interval_ms = maxi(1, attack_interval_ms + value)
		elif str(upgrade.get("field", "")) == "active_cooldown_ms":
			active_cooldown_ms = maxi(150, active_cooldown_ms + value)
		elif str(upgrade.get("field", "")) == "grenade_blast_radius":
			grenade_blast_radius = maxf(1.0, grenade_blast_radius + value)


func _build_damage_event(damage_kind: String, force_critical: bool, roll_critical: bool = true) -> DamageEvent:
	var base_damage := get_base_attack_damage()
	var damage := base_damage * (1.0 + get_stat("damage_percent") / 100.0)
	var critical := force_critical or (roll_critical and randf() * 100.0 < get_stat("crit_chance"))
	if critical:
		damage *= get_stat("crit_damage") / 100.0
	return DamageEvent.create({
		"source_player": owner_player,
		"source_weapon_id": weapon_id,
		"attack_context": attack_context,
		"damage": maxi(1, int(roundi(damage * get_attachment_damage_multiplier(damage_kind == DAMAGE_KIND_ELEMENT)))),
		"original_damage": maxi(1, int(roundi(damage))),
		# Keep the pre-attachment base; boost the full elemental base once, including
		# the flat element bonus. Children/reactions inherit this captured multiplier.
		"elemental_damage_scale": get_attachment_damage_multiplier(true),
		"damage_area_scale": StatDefinitions.calculate_damage_area_multiplier(get_stat("damage_area_size")),
		# Elemental native attacks already include this bonus; attachments must not add it twice.
		"element_damage_bonus": 0 if damage_kind == DAMAGE_KIND_ELEMENT else maxi(0, int(roundi(get_stat("element_damage")))),
		"damage_kind": damage_kind,
		"is_critical": critical,
		"tags": _get_tags(),
		"hit_position": owner_player.global_position if owner_player != null else Vector2.ZERO,
	})


func _get_damage_component_base(stat_id: String) -> float:
	var coefficient := float(weapon_data.get("player_damage_coefficient", 1.0))
	if is_equal_approx(coefficient, 1.0):
		return get_stat(stat_id)
	var player_bonus := owner_player.get_stat(stat_id) if is_instance_valid(owner_player) else 0.0
	if _cast_player_stats.has(stat_id):
		player_bonus = float(_cast_player_stats[stat_id])
	return maxf(0.0, get_weapon_stat(stat_id) + player_bonus * coefficient)


func get_attack_kind() -> String:
	return str(weapon_data.get("attack_kind", DAMAGE_KIND_RANGED))


func get_visual_rarity() -> String:
	var base_rarity := str(weapon_data.get("rarity", "common"))
	var level_entry: Dictionary = weapon_data.get("level_upgrades", {}).get(str(level), {})
	var level_rarity := str(level_entry.get("rarity", ""))
	return level_rarity if not level_rarity.is_empty() else base_rarity


func get_rarity_color() -> Color:
	return RARITY_COLORS.get(get_visual_rarity(), RARITY_COLORS["common"])


func _get_tags() -> Array[String]:
	var result: Array[String] = []
	for tag in weapon_data.get("tags", []):
		result.append(str(tag))
	return result

func build_full_stats_text() -> String:
	var lines: Array[String] = []
	var display_name := str(weapon_data.get("display_name", weapon_id))
	var max_level := int(weapon_data.get("max_level", 1))
	lines.append("%s  Lv.%d/%d" % [display_name, level, max_level])
	lines.append("[color=#F5D76E]伤害：[/color]" + _format_damage_source(get_damage_stat_id()))
	if get_stat("damage_area_size") != 0:
		lines.append("[color=#F5D76E]伤害范围[/color] %+.0f（每点增加0.5%%）" % get_stat("damage_area_size"))
	var interval := get_active_cooldown_seconds()
	lines.append("[color=#F5D76E]动作后冷却[/color] [color=#FFFFFF]%.2fs[/color]" % interval)
	lines.append("[color=#F5D76E]暴击率[/color] [color=#FFFFFF]%d%%[/color]  [color=#F5D76E]暴击伤害[/color] [color=#FFFFFF]%d%%[/color]" % [int(get_stat("crit_chance")), int(get_stat("crit_damage"))])
	var count_label := "投射物"
	if is_nightwatch_spear(): count_label = "每轮刺击"
	elif is_meteor_flail(): count_label = "每轮挥击"
	elif is_ritual_tome(): count_label = "每次点名"
	elif is_copper_lamp(): count_label = "喷射时长倍率"
	elif is_earth_hammer(): count_label = "地裂方向"
	if not is_camp_dagger() and not is_mutant_tentacle():
		lines.append("[color=#F5D76E]%s[/color] [color=#FFFFFF]%d[/color]" % [count_label, maxi(1, int(get_stat("projectile_count"))) + (2 if is_ritual_tome() else 0)])
	if weapon_data.has("projectile_spacing_degrees"):
		lines.append("[color=#F5D76E]相邻夹角[/color] [color=#FFFFFF]%s°[/color]" % _format_damage_number(float(weapon_data.projectile_spacing_degrees)))
	if is_earth_hammer():
		lines.append("[color=#F5D76E]每路节点[/color] [color=#FFFFFF]%d[/color]" % get_ground_node_count())
	if is_grenade():
		lines.append("[color=#F5D76E]攻击距离[/color] %d  [color=#F5D76E]爆炸半径[/color] %s" % [int(get_attack_range()), _format_damage_number(get_grenade_blast_radius())])
		lines.append("抛射榴弹，%.2f秒后在落点爆炸。" % float(weapon_data.get("grenade_flight_seconds", 0.45)))
	elif is_meteor_flail():
		lines.append("[color=#F5D76E]锤头伤害半径[/color] %s" % _format_damage_number(get_hit_radius()))
		lines.append("前方130°完整连续挥击，额外投射物增加挥击次数。")
	elif is_copper_lamp():
		lines.append("[color=#F5D76E]喷射距离[/color] %d · %s°窄扇面" % [roundi(get_attack_range()), _format_damage_number(get_lamp_cone_degrees())])
		lines.append("按数字键喷射%.2fs，每%.2fs灼烧。" % [get_lamp_spray_seconds(), float(weapon_data.lamp_tick_ms) / 1000])
		lines.append("每个额外投射物增加%.2fs喷射时间。" % (float(weapon_data.lamp_spray_ms) / 1000.0))
		lines.append("随移动方向转向，静止沿用最后方向。")
		lines.append("附魔每%.2fs最多触发一次，元素基数%d%%。" % [float(weapon_data.lamp_proc_ms) / 1000, int(weapon_data.lamp_proc_percent)])
	elif is_mutant_tentacle():
		lines.append("卷曲展开后瞬间拍地。")
	elif is_earth_hammer():
		lines.append("[color=#F5D76E]末节点距离[/color] %d · 每%.2fs向外推进" % [roundi(get_attack_range()), float(weapon_data.ground_node_interval_ms) / 1000])
		lines.append("[color=#F5D76E]节点伤害半径[/color] %s" % _format_damage_number(get_hit_radius()))
		lines.append("空地节点触发附魔；闪电链无目标不释放；短侧枝承接分裂后的附魔；穿透无效。")
	elif is_camp_dagger():
		lines.append("正反手交替斩击，分裂追加弱化追斩。")
	elif is_nightwatch_spear():
		lines.append("[color=#F5D76E]刺击距离[/color] %d  [color=#F5D76E]刺击宽度[/color] %d" % [roundi(get_attack_range()), roundi(get_hit_radius() * 2.0)])
		lines.append("锁定方向，贯穿前方敌人；地形阻挡。")
	elif is_ritual_tome():
		var axes := get_domain_axes()
		lines.append("[color=#F5D76E]领域半径[/color] %d × %d" % [roundi(axes.x), roundi(axes.y)])
		lines.append("按数字键放置法阵；每0.35s点名一次，可重复命中。无敌人时等待，点名完毕后冷却。")
	else:
		lines.append("[color=#F5D76E]攻击范围[/color] [color=#FFFFFF]%d[/color]" % int(get_attack_range()))
	if is_coin_purse():
		lines.append("向瞄准方向扇形散射金币，相邻夹角10°。")
	elif str(weapon_data.get("projectile_behavior", "")) == "plasma":
		lines.append("接触时每%.2f秒灼击，每球最多5次。" % float(weapon_data.get("plasma_tick_interval", 0.1)))
	for profile in (get_grenade_split_profiles() if is_grenade() else get_split_profiles()):
		lines.append("[color=#F5D76E]分裂[/color] %d个 · 伤害%d%%" % [int(profile.child_count), roundi(float(profile.damage_multiplier) * 100)])
	if has_effect("bounce"):
		lines.append("[color=#F5D76E]弹跳[/color] 首次命中立即追加%d次攻击" % get_effect_instances("bounce").size())
	lines.append("[color=#F5D76E]负载[/color] [color=#FFFFFF]%d[/color]" % get_load_cost())
	if has_attachment_slot():
		lines.append(_build_attachment_icons_text())
	return "\n".join(lines)


func get_lamp_cone_degrees() -> float:
	if use_active_range_rules:
		return float(weapon_data.get("lamp_cone_degrees", 60))
	return minf(float(weapon_data.get("lamp_cone_degrees", 30)) * get_hit_radius() / maxf(float(weapon_data.get("hit_radius", 1)), 0.01), 162.0)


func get_lamp_spray_seconds() -> float:
	return maxf(0.001, float(weapon_data.get("lamp_spray_ms", 1800)) / 1000.0) * maxi(1, int(get_stat("projectile_count")))


func _build_attachment_icons_text() -> String:
	var icons: Array[String] = []
	var attachments := get_attached_item_instances()
	for slot_index in get_attachment_slot_count():
		var icon_path := EMPTY_ATTACHMENT_ICON
		if slot_index < attachments.size():
			var attachment := attachments[slot_index]
			var base := DataRegistry.get_record("augmentations", str(attachment.get("base_item_id", "")))
			icon_path = str(attachment.get("icon", ""))
			if icon_path.is_empty():
				icon_path = str(base.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icons.append("[img=%dx%d]%s[/img]" % [ATTACHMENT_ICON_SIZE, ATTACHMENT_ICON_SIZE, icon_path])
		else:
			icons.append("[color=#A9A184]?[/color]")
	return "[color=#F5D76E]附魔[/color]" + ATTACHMENT_ICON_GAP + ATTACHMENT_ICON_GAP.join(icons)


func _format_damage_source(stat_id: String) -> String:
	var fixed_damage := get_weapon_stat(stat_id)
	# Reuse combat's resolved contribution, including coefficients and clamping.
	var player_bonus := _get_damage_component_base(stat_id) - fixed_damage
	var text := "（[color=#FFFFFF]%s[/color]%s" % [_format_damage_number(fixed_damage), _format_damage_bonus(player_bonus, stat_id)]
	if is_coin_purse():
		text += _format_damage_bonus(get_principal_damage_bonus(), "principal")
	return text + "）"


func _format_damage_bonus(value: float, source: String) -> String:
	var sign_text := "+" if value >= 0.0 else "-"
	return "[color=%s]%s%s[/color]" % [DAMAGE_SOURCE_COLORS.get(source, "#FFFFFF"), sign_text, _format_damage_number(absf(value))]


func _format_damage_number(value: float) -> String:
	return String.num(value, 2).trim_suffix(".0")
