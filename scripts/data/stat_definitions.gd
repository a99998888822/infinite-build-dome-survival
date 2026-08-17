extends RefCounted
class_name StatDefinitions

const ARMOR_K: float = 100
const MIN_DAMAGE_TAKEN_PERCENT: float = 5
const DEFAULT_HUMANITY: float = 100
const DEFAULT_DIVINITY: float = 0
const HUMANITY_LOW_THRESHOLD: float = 30
const DIVINITY_HIGH_THRESHOLD: float = 70

const CATEGORY_SURVIVAL: String = "生存"
const CATEGORY_MOVEMENT: String = "移动"
const CATEGORY_ATTACK: String = "攻击"
const CATEGORY_CRITICAL: String = "暴击"
const CATEGORY_PROJECTILE: String = "投射物"
const CATEGORY_CONTROL: String = "范围与控制"
const CATEGORY_REWARD: String = "掉落与成长"
const CATEGORY_BUILD: String = "构筑"
const CATEGORY_SUMMON: String = "召唤"
const CATEGORY_WAVE: String = "波次"
const CATEGORY_ELDRITCH: String = "精神/外神"

const STAT_DEFINITIONS: Dictionary = {
	"max_hp": {
		"display_name": "最大生命",
		"category": CATEGORY_SURVIVAL,
		"default": 100,
		"min": 1,
		"max": 99999,
		"is_integer": true,
		"is_percent": false,
		"description": "角色、敌人或召唤物的最大生命值。"
	},
	"hp_regen": {
		"display_name": "每秒回血",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 9999,
		"is_integer": true,
		"is_percent": false,
		"description": "每秒恢复的生命值。"
	},
	"shield": {
		"display_name": "护盾",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 99999,
		"is_integer": true,
		"is_percent": false,
		"description": "优先承受伤害的护盾值。"
	},
	"revive_count": {
		"display_name": "额外复活",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 99,
		"is_integer": true,
		"is_percent": false,
		"description": "本局额外复活次数；复活后消耗 1 次。"
	},
	"on_kill_heal": {
		"display_name": "击杀回血",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 99999,
		"is_integer": true,
		"is_percent": false,
		"description": "每次击杀敌人后恢复的固定生命值。"
	},
	"armor": {
		"display_name": "护甲",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 99999,
		"is_integer": true,
		"is_percent": false,
		"description": "通过曲线函数换算为受到伤害百分比，护甲越高边际收益越低。"
	},
	"damage_taken_percent": {
		"display_name": "受到伤害百分比",
		"category": CATEGORY_SURVIVAL,
		"default": 100,
		"min": MIN_DAMAGE_TAKEN_PERCENT,
		"max": 1000,
		"is_integer": true,
		"is_percent": true,
		"description": "最终承受伤害百分比，整数100表示承受100%伤害，89表示承受89%伤害。"
	},
	"move_speed": {
		"display_name": "移动速度",
		"category": CATEGORY_MOVEMENT,
		"default": 180,
		"min": 0,
		"max": 3000,
		"is_integer": true,
		"is_percent": false,
		"description": "实体移动速度。"
	},
	"melee_damage": {
		"display_name": "近战伤害",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": 0,
		"max": 999999,
		"is_integer": true,
		"is_percent": false,
		"description": "近战伤害固定数值加成。"
	},
	"ranged_damage": {
		"display_name": "远程伤害",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": 0,
		"max": 999999,
		"is_integer": true,
		"is_percent": false,
		"description": "远程伤害固定数值加成。"
	},
	"summon_damage": {
		"display_name": "眷族伤害",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": 0,
		"max": 999999,
		"is_integer": true,
		"is_percent": false,
		"description": "召唤物或眷族实体伤害固定数值加成。"
	},
	"damage_percent": {
		"display_name": "伤害加成",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": -95,
		"max": 10000,
		"is_integer": true,
		"is_percent": true,
		"description": "通用伤害百分比加成，影响近战、远程、眷族等伤害。"
	},
	"attack_speed": {
		"display_name": "攻击速度",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": -90,
		"max": 10000,
		"is_integer": true,
		"is_percent": true,
		"description": "整数百分比攻速；实际攻击间隔 = 武器固定速率 / (1 + attack_speed / 100)。"
	},
	"crit_chance": {
		"display_name": "暴击率",
		"category": CATEGORY_CRITICAL,
		"default": 0,
		"min": 0,
		"max": 100,
		"is_integer": true,
		"is_percent": true,
		"description": "攻击造成暴击的概率。"
	},
	"crit_damage": {
		"display_name": "暴击伤害",
		"category": CATEGORY_CRITICAL,
		"default": 150,
		"min": 100,
		"max": 2000,
		"is_integer": true,
		"is_percent": true,
		"description": "暴击时的伤害百分比，150表示造成150%伤害。"
	},
	"projectile_count": {
		"display_name": "投射物数量",
		"category": CATEGORY_PROJECTILE,
		"default": 1,
		"min": 0,
		"max": 999,
		"is_integer": true,
		"is_percent": false,
		"description": "一次攻击产生的投射物数量。"
	},
	"pierce_count": {
		"display_name": "穿透次数",
		"category": CATEGORY_PROJECTILE,
		"default": 0,
		"min": 0,
		"max": 999,
		"is_integer": true,
		"is_percent": false,
		"description": "投射物可额外穿透的目标数量。"
	},
	"area_size": {
		"display_name": "范围加成",
		"category": CATEGORY_CONTROL,
		"default": 0,
		"min": -90,
		"max": 10000,
		"is_integer": true,
		"is_percent": true,
		"description": "整数百分比攻击范围加成，统一影响近战、远程、范围武器的命中或影响半径。"
	},
	"control_power": {
		"display_name": "控制强度",
		"category": CATEGORY_CONTROL,
		"default": 0,
		"min": 0,
		"max": 100,
		"is_integer": true,
		"is_percent": false,
		"description": "影响减速、定身等控制效果强度。"
	},
	"pickup_radius": {
		"display_name": "拾取范围",
		"category": CATEGORY_REWARD,
		"default": 80,
		"min": 0,
		"max": 3000,
		"is_integer": true,
		"is_percent": false,
		"description": "自动吸附经验球、奖励物的半径。"
	},
	"exp_gain_percent": {
		"display_name": "经验获取加成",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -95,
		"max": 10000,
		"is_integer": true,
		"is_percent": true,
		"description": "经验获取百分比加成。"
	},
	"drop_rate_percent": {
		"display_name": "掉落率加成",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -95,
		"max": 10000,
		"is_integer": true,
		"is_percent": true,
		"description": "局内掉落概率百分比加成。"
	},
	"luck": {
		"display_name": "幸运",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": 0,
		"max": 9999,
		"is_integer": true,
		"is_percent": false,
		"description": "影响稀有遗物、稀有升级选项、额外掉落等概率。"
	},
	"currency_gain_percent": {
		"display_name": "货币获取加成",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -95,
		"max": 10000,
		"is_integer": true,
		"is_percent": true,
		"description": "局内或结算货币获取百分比加成。"
	},
	"finance": {
		"display_name": "理财",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": 0,
		"max": 999999999,
		"is_integer": true,
		"is_percent": false,
		"description": "每波开始前可存入或取出的局内金币本金。"
	},
	"interest_rate": {
		"display_name": "利率",
		"category": CATEGORY_REWARD,
		"default": 5,
		"min": 0,
		"max": 10000,
		"is_integer": false,
		"is_percent": true,
		"description": "当前有效利率，默认 5；支持 0.2% 和 0.3% 等小数成长，波末利息公式为 ceil(finance * interest_rate / 100)。"
	},
	"shop_price_percent": {
		"display_name": "商店折扣",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": 0,
		"max": 90,
		"is_integer": true,
		"is_percent": true,
		"description": "局内商店价格折扣；10 表示商店价格降低 10%。"
	},
	"load_capacity": {
		"display_name": "负载上限",
		"category": CATEGORY_BUILD,
		"default": 100,
		"min": 0,
		"max": 9999,
		"is_integer": true,
		"is_percent": false,
		"description": "玩家可装备武器的总负载上限。"
	},
	"summon_count": {
		"display_name": "召唤数量",
		"category": CATEGORY_SUMMON,
		"default": 0,
		"min": 0,
		"max": 999,
		"is_integer": true,
		"is_percent": false,
		"description": "额外召唤物或眷族数量。"
	},
	"enemy_spawn_rate_percent": {
		"display_name": "怪物数量增幅",
		"category": CATEGORY_WAVE,
		"default": 0,
		"min": 0,
		"max": 300,
		"is_integer": true,
		"is_percent": true,
		"description": "每次刷怪的数量增幅；20 表示每组生成数量增加 20%。"
	},
	"humanity": {
		"display_name": "人性",
		"category": CATEGORY_ELDRITCH,
		"default": DEFAULT_HUMANITY,
		"min": 0,
		"max": 100,
		"is_integer": true,
		"is_percent": false,
		"description": "理智值/人性，初始满值；越低，侵蚀度积蓄越快。"
	},
	"divinity": {
		"display_name": "神性",
		"category": CATEGORY_ELDRITCH,
		"default": DEFAULT_DIVINITY,
		"min": 0,
		"max": 100,
		"is_integer": true,
		"is_percent": false,
		"description": "侵蚀度/神性，初始为0；表示与克苏鲁外神的靠近程度。"
	}
}

static func has_stat(stat_id: String) -> bool:
	return STAT_DEFINITIONS.has(stat_id)


static func get_stat_definition(stat_id: String) -> Dictionary:
	if not has_stat(stat_id):
		return {}
	return STAT_DEFINITIONS[stat_id].duplicate(true)


static func get_default_value(stat_id: String) -> float:
	return float(_get_stat_property(stat_id, "default", 0.0))


static func get_min_value(stat_id: String) -> float:
	return float(_get_stat_property(stat_id, "min", -INF))


static func get_max_value(stat_id: String) -> float:
	return float(_get_stat_property(stat_id, "max", INF))


static func clamp_stat_value(stat_id: String, value: float) -> float:
	if not has_stat(stat_id):
		return value
	var clamped_value := clampf(value, get_min_value(stat_id), get_max_value(stat_id))
	if is_integer_stat(stat_id):
		return float(roundi(clamped_value))
	return clamped_value


static func is_percent_stat(stat_id: String) -> bool:
	return bool(_get_stat_property(stat_id, "is_percent", false))


static func is_integer_stat(stat_id: String) -> bool:
	return bool(_get_stat_property(stat_id, "is_integer", false))


static func get_display_name(stat_id: String) -> String:
	return str(_get_stat_property(stat_id, "display_name", stat_id))


static func get_category(stat_id: String) -> String:
	return str(_get_stat_property(stat_id, "category", "未知"))


static func get_description(stat_id: String) -> String:
	return str(_get_stat_property(stat_id, "description", ""))


static func get_all_stat_ids() -> Array[String]:
	var stat_ids: Array[String] = []
	for stat_id in STAT_DEFINITIONS.keys():
		stat_ids.append(stat_id)
	stat_ids.sort()
	return stat_ids


static func get_stat_ids_by_category(category: String) -> Array[String]:
	var stat_ids: Array[String] = []
	for stat_id in STAT_DEFINITIONS.keys():
		if get_category(stat_id) == category:
			stat_ids.append(stat_id)
	stat_ids.sort()
	return stat_ids


static func calculate_damage_taken_from_armor(armor: float) -> float:
	# 护甲使用曲线衰减，避免高护甲无限接近 0 伤害。
	var safe_armor := maxf(armor, 0.0)
	var damage_taken_percent := ARMOR_K / (ARMOR_K + safe_armor)
	return maxf(damage_taken_percent * 100.0, MIN_DAMAGE_TAKEN_PERCENT)


static func calculate_attack_interval(base_interval: float, attack_speed: float) -> float:
	# 攻速采用倍率式换算，保持数值直观且便于叠加。
	var speed_multiplier := maxf(1.0 + attack_speed / 100.0, 0.1)
	return base_interval / speed_multiplier


static func calculate_attack_radius(base_radius: float, area_size: float) -> float:
	# area_size 是唯一攻击范围加成属性，基础半径只来自武器配置。
	var radius_percent := clamp_stat_value("area_size", area_size)
	return maxf(base_radius, 0.0) * maxf(1.0 + radius_percent / 100.0, 0.0)


static func calculate_finance_interest_gain(finance: float, interest_rate: float) -> int:
	# 理财收益向上取整，方便小额本金也能获得清晰反馈。
	var safe_finance := clamp_stat_value("finance", finance)
	var safe_rate := clamp_stat_value("interest_rate", interest_rate)
	return int(ceil(safe_finance * safe_rate / 100.0))


static func calculate_shop_cost(base_cost: int, shop_price_percent: float) -> int:
	var discount_percent := clamp_stat_value("shop_price_percent", shop_price_percent)
	return maxi(0, int(ceil(float(maxi(0, base_cost)) * (1.0 - discount_percent / 100.0))))


static func calculate_enemy_spawn_count(base_count: int, enemy_spawn_rate_percent: float) -> int:
	var spawn_rate_percent := clamp_stat_value("enemy_spawn_rate_percent", enemy_spawn_rate_percent)
	return maxi(0, int(ceil(float(maxi(0, base_count)) * (1.0 + spawn_rate_percent / 100.0))))

static func get_humanity_stage(humanity: float) -> String:
	var value := clamp_stat_value("humanity", humanity)
	if value >= 80.0:
		return "stable_humanity"
	if value >= 50.0:
		return "shaken_humanity"
	if value >= HUMANITY_LOW_THRESHOLD:
		return "fractured_humanity"
	return "fading_humanity"


static func get_divinity_stage(divinity: float) -> String:
	var value := clamp_stat_value("divinity", divinity)
	if value < 30.0:
		return "dormant_divinity"
	if value < 50.0:
		return "stirring_divinity"
	if value < DIVINITY_HIGH_THRESHOLD:
		return "ascending_divinity"
	return "outer_divinity"


static func _get_stat_property(stat_id: String, property_name: String, default_value: Variant) -> Variant:
	if not has_stat(stat_id):
		return default_value
	return STAT_DEFINITIONS[stat_id].get(property_name, default_value)
