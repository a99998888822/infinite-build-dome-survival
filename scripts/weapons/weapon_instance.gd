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
const EFFECT_PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")

var weapon_id: String = ""
static var _next_instance_id: int = 1
var instance_id: String = ""
var trade_base_basis: int = -1
var trade_upgrade_basis: Dictionary = {}
# Reserved for earned, instance-bound titles; combat title scoring is a later feature.
var battle_title: Dictionary = {}
var weapon_data: Dictionary = {}
var owner_player: PlayerController = null
var principal_getter: Callable = Callable()
var level: int = 1
var runtime_stats: Dictionary = {}
var effect_ids: Array[String] = []
var effect_modifiers: Array[Dictionary] = []
var _base_effect_ids: Array[String] = []
var _base_effect_modifiers: Array[Dictionary] = []
var _attached_item_instances: Array[Dictionary] = []
var attack_interval_ms: int = 0
var attack_timer: float = 0.0
var volley_index: int = 0
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
	attack_timer = 0.0
	volley_index = 0
	grenade_blast_radius = float(data.get("grenade_blast_radius", 0.0))
	reset_hit_sfx_state()
	return true


func tick(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)


func can_attack() -> bool:
	return attack_timer <= 0.0


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
	var default_value := StatDefinitions.get_default_value(stat_id)
	var weapon_value := float(runtime_stats.get(stat_id, default_value))
	var player_value := owner_player.get_stat(stat_id) if owner_player != null else default_value
	return StatDefinitions.clamp_stat_value(stat_id, weapon_value + player_value - default_value)


func get_weapon_stat(stat_id: String) -> float:
	return float(runtime_stats.get(stat_id, StatDefinitions.get_default_value(stat_id)))


func get_effect_ids() -> Array[String]:
	return effect_ids.duplicate()


func has_effect(effect_id: String) -> bool:
	return effect_ids.has(effect_id.strip_edges())


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
	return maxi(0, int(weapon_data.get("attachment_slots", 0)))


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
	}
	return attach_item_instance(legacy_item)


func _reset_effect_runtime() -> void:
	effect_ids = _base_effect_ids.duplicate()
	effect_modifiers = _base_effect_modifiers.duplicate(true)


func _rebuild_attachment_effects() -> void:
	_reset_effect_runtime()
	for item_instance in _attached_item_instances:
		var item_instance_id := str(item_instance.get("item_instance_id", ""))
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
	if str(weapon_data.get("projectile_behavior", "")) == "plasma":
		# One radius owns the plasma core, contact query, collider and item details.
		return maxf(StatDefinitions.calculate_damage_area_radius(base_radius, get_stat("damage_area_size")), 4.0)
	return StatDefinitions.calculate_attack_radius(base_radius, get_stat("area_size"))


func get_attack_range() -> float:
	var base_range := float(weapon_data.get("attack_range", weapon_data.get("hit_radius", 0)))
	return StatDefinitions.calculate_attack_radius(base_range, get_stat("area_size"))


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
	# The finance stat is a starting talent, not the live bank balance.
	return maxf(0.0, float(principal_getter.call())) if principal_getter.is_valid() else 0.0


func get_base_attack_damage() -> float:
	return _get_damage_component_base(get_damage_stat_id()) + get_principal_damage_bonus()


func get_split_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in get_effect_instances("split"):
		var context := EFFECT_PARAMETERS.build_weapon_context(self, "split", {
			"child_count": 2.0, "spread_angle": 36.0, "damage_multiplier": 0.6,
		}, str(item.get("item_instance_id", "")))
		result.append({"child_count": clampi(roundi(context.get_resolved_parameter("child_count", 2.0)), 1, 8),
			"spread_angle": maxf(context.get_resolved_parameter("spread_angle", 36.0), 0.0),
			"damage_multiplier": maxf(context.get_resolved_parameter("damage_multiplier", 0.6), 0.0)})
	return result


func get_pierce_hit_limit() -> int:
	var extra := 0
	for item in get_effect_instances("pierce"):
		var context := EFFECT_PARAMETERS.build_weapon_context(self, "pierce", {"extra_target_hits": 0.0}, str(item.get("item_instance_id", "")))
		extra += clampi(roundi(context.get_resolved_parameter("extra_target_hits", 0.0)), 0, 32)
	return 1 + mini(extra, 32)


func get_grenade_blast_radius() -> float:
	return maxf(1.0, grenade_blast_radius * (1.0 + get_stat("damage_area_size") / 100.0))


func get_grenade_split_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if not is_grenade():
		return profiles
	for item in get_effect_instances("split"):
		var context := EFFECT_PARAMETERS.build_weapon_context(self, "split", {
			"child_count": 2.0, "spread_angle": 36.0, "damage_multiplier": 0.6,
		}, str(item.get("item_instance_id", "")))
		profiles.append({
			"child_count": clampi(roundi(context.get_resolved_parameter("child_count", 2.0)), 1, 8),
			"spread_angle": maxf(context.get_resolved_parameter("spread_angle", 36.0), 0.0),
			"damage_multiplier": maxf(context.get_resolved_parameter("damage_multiplier", 0.6), 0.0),
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
		elif str(upgrade.get("field", "")) == "grenade_blast_radius":
			grenade_blast_radius = maxf(1.0, grenade_blast_radius + value)


func _build_damage_event(damage_kind: String, force_critical: bool) -> DamageEvent:
	var base_damage := get_base_attack_damage()
	var damage := base_damage * (1.0 + get_stat("damage_percent") / 100.0)
	var critical := force_critical or randf() * 100.0 < get_stat("crit_chance")
	if critical:
		damage *= get_stat("crit_damage") / 100.0
	return DamageEvent.create({
		"source_player": owner_player,
		"source_weapon_id": weapon_id,
		"damage": maxi(1, int(roundi(damage))),
		"original_damage": maxi(1, int(roundi(damage))),
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
	var damage_label := "近战" if get_attack_kind() == DAMAGE_KIND_MELEE else ("元素" if get_attack_kind() == DAMAGE_KIND_ELEMENT else "远程")
	var damage_line := "[color=#F5D76E]%s伤害[/color]%s" % [damage_label, _format_damage_source(get_damage_stat_id())]
	lines.append(damage_line)
	if is_coin_purse():
		var principal := get_current_principal()
		lines.append("[color=#F5D76E]本金增伤[/color] +%s（%s×√%s，不消耗本金）" % [str(snappedf(get_principal_damage_bonus(), 0.1)), str(weapon_data.get("principal_damage_coefficient", 0.3)), str(snappedf(maxf(principal, 0.0), 0.1))])
	if is_coin_purse() or is_ritual_tome():
		lines.append("[color=#F5D76E]非暴击伤害[/color] %d（含通用增伤，护甲减免前）" % maxi(1, roundi(get_base_attack_damage() * (1.0 + get_stat("damage_percent") / 100.0))))
	var interval := get_actual_attack_interval_seconds()
	lines.append("[color=#F5D76E]攻击间隔[/color] [color=#FFFFFF]%.2fs[/color]（每秒约 %.1f 次）" % [interval, 1.0 / interval])
	lines.append("[color=#F5D76E]暴击率[/color] [color=#FFFFFF]%d%%[/color]  [color=#F5D76E]暴击伤害[/color] [color=#FFFFFF]%d%%[/color]" % [int(get_stat("crit_chance")), int(get_stat("crit_damage"))])
	lines.append("[color=#F5D76E]%s[/color] [color=#FFFFFF]%d[/color]" % ["主挥击次数" if is_meteor_flail() else ("每轮点名" if is_ritual_tome() else "投射物"), maxi(1, int(get_stat("projectile_count")))])
	if is_grenade():
		lines.append("[color=#F5D76E]攻击距离[/color] %d  [color=#F5D76E]爆炸半径[/color] %s" % [int(get_attack_range()), str(snappedf(get_grenade_blast_radius(), 0.1))])
		lines.append("[color=#F5D76E]飞行时间[/color] %.2fs · 固定落点" % float(weapon_data.get("grenade_flight_seconds", 0.45)))
		var damage := maxi(1, roundi(_get_damage_component_base("ranged_damage") * (1.0 + get_stat("damage_percent") / 100.0)))
		lines.append("[color=#F5D76E]非暴击伤害[/color] %d（护甲减免前）" % damage)
		lines.append("每个受击目标分别触发命中附魔；支持分裂，不支持穿透。")
		for profile in get_grenade_split_profiles():
			lines.append("[color=#F5D76E]集束分裂[/color] 每个目标 %d 枚 · 伤害 %d%% · 半径 %s · 飞行 %.2fs" % [int(profile.child_count), roundi(float(profile.damage_multiplier) * 100), str(snappedf(get_grenade_blast_radius() * float(profile.radius_multiplier), 0.1)), float(profile.flight_seconds)])
		if has_effect("split"):
			lines.append("子榴弹排除主爆炸已命中目标，仍触发其他附魔；只分裂一代。")
	elif is_meteor_flail():
		var multiplier := float(weapon_data.get("flail_outer_multiplier", 1.5))
		var damage := get_base_attack_damage() * (1.0 + get_stat("damage_percent") / 100.0)
		lines.append("[color=#F5D76E]锤头伸展[/color] %d · 前方140° · 命中半径 %d" % [roundi(get_attack_range()), roundi(get_hit_radius())])
		lines.append("[color=#F5D76E]近圈 / 外圈伤害[/color] %d / %d（非暴击、护甲减免前）" % [maxi(1, roundi(damage)), maxi(1, roundi(roundi(damage) * multiplier))])
		lines.append("伸展至%d%%距离后伤害为%d%%；锁定方向，锤头接触命中，锁链无伤害。" % [roundi(float(weapon_data.get("flail_outer_threshold", 0.8)) * 100), roundi(multiplier * 100)])
		for profile in get_split_profiles():
			lines.append("[color=#F5D76E]分裂追击[/color] 首次主命中追加 %d 次 · 伤害 %d%% · 每轮只追加一代" % [int(profile.child_count), roundi(float(profile.damage_multiplier) * 100)])
		lines.append("每次挥击对同一目标命中一次；各次命中触发元素附魔，不支持穿透。")
	elif is_ritual_tome():
		var axes := get_domain_axes()
		lines.append("[color=#F5D76E]领域半轴[/color] %d × %d（受攻击范围加成）" % [roundi(axes.x), roundi(axes.y)])
		lines.append("随机点名领域内不同目标；分裂不越出领域，不支持穿透。")
	else:
		lines.append("[color=#F5D76E]攻击范围[/color] [color=#FFFFFF]%d[/color]  [color=#F5D76E]命中半径[/color] [color=#FFFFFF]%d[/color]" % [int(get_attack_range()), int(get_hit_radius())])
	if is_coin_purse():
		lines.append("每轮均匀环射，方向逐轮偏转30°；同轮金币与分裂弹不重复命中同一敌人。")
	if is_coin_purse() or is_ritual_tome():
		for profile in get_split_profiles():
			lines.append("[color=#F5D76E]分裂[/color] 每次主命中追加 %d 个 · 伤害 %d%% · 只分裂一代" % [int(profile.child_count), roundi(float(profile.damage_multiplier) * 100)])
	lines.append("[color=#F5D76E]负载[/color] [color=#FFFFFF]%d[/color]" % get_load_cost())
	if has_attachment_slot():
		var attachments := get_attached_item_instances()
		for slot_index in range(get_attachment_slot_count()):
			var attachment_name := "空槽"
			if slot_index < attachments.size():
				var attachment := attachments[slot_index]
				attachment_name = str(attachment.get("display_name", attachment.get("base_item_id", "已装填")))
			lines.append("[color=#F5D76E]附加槽 %d[/color] [color=#FFFFFF]%s[/color]" % [slot_index + 1, attachment_name])
	return "\n".join(lines)


func _format_damage_source(stat_id: String) -> String:
	var fixed_damage := int(roundi(get_weapon_stat(stat_id)))
	var player_bonus := int(roundi((owner_player.get_stat(stat_id) - StatDefinitions.get_default_value(stat_id)) if owner_player != null else 0.0))
	var coefficient := float(weapon_data.get("player_damage_coefficient", 1.0))
	if not is_equal_approx(coefficient, 1.0):
		return " %s（%d + %d×%s）" % [str(snappedf(_get_damage_component_base(stat_id), 0.1)), fixed_damage, player_bonus, str(coefficient)]
	return "([color=#FFFFFF]%d[/color]+[color=#7FD88F]%d[/color])" % [fixed_damage, player_bonus]
