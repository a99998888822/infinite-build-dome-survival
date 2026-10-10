extends RefCounted
class_name StatDefinitions

const ARMOR_K: float = 100
const ATTACK_SPEED_SCALE: float = 300.0
const RANGE_BONUS_EFFICIENCY: float = 0.5
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
const CATEGORY_WAVE: String = "波次"
const CATEGORY_ELDRITCH: String = "精神/外神"

const STAT_DEFINITIONS: Dictionary = {
	"max_hp": {
		"display_name": "最大生命",
		"category": CATEGORY_SURVIVAL,
		"default": 100,
		"min": 1,
		"is_integer": true,
		"is_percent": false,
		"description": "角色或敌人的最大生命值。"
	},
	"hp_regen": {
		"display_name": "每秒回血",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": -9999,
		"max": 9999,
		"is_integer": false,
		"is_percent": false,
		"description": "每秒恢复的生命值；负值会抵扣正向回血，战斗结算时以 0 为下限（不会掉血），面板仍显示真实数值。"
	},
	"shield": {
		"display_name": "护盾",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 99999,
		"is_integer": true,
		"is_percent": false,
		"description": "每波开始时的初始护盾值；波初读取当前属性，优先承受伤害。"
	},
	"shield_regen": {
		"display_name": "每秒护盾",
		"category": CATEGORY_SURVIVAL,
		"default": 0,
		"min": 0,
		"max": 99999,
		"is_integer": false,
		"is_percent": false,
		"description": "每秒恢复护盾，优先补满已有上限；溢出部分使当前护盾与上限一起增长。"
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
		"is_integer": true,
		"is_percent": false,
		"description": "通过曲线函数换算为受到伤害百分比；正护甲减伤，负护甲增伤。"
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
	"element_damage": {
		"display_name": "元素伤害",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": 0,
		"max": 999999,
		"is_integer": true,
		"is_percent": false,
		"description": "元素武器、元素附魔及元素反应造成的固定伤害加成。"
	},
	"damage_percent": {
		"display_name": "伤害加成",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": -99999,
		"is_integer": true,
		"is_percent": true,
		"description": "通用伤害百分比加成，影响近战、远程和元素武器伤害。"
	},
	"attack_speed": {
		"display_name": "攻击速度",
		"category": CATEGORY_ATTACK,
		"default": 0,
		"min": -90,
		"is_integer": true,
		"is_percent": true,
		"description": "正攻速冷却倍率 = 1 / (1 + log2(1 + attack_speed / 100) / 3)。100 点保留 75% 冷却，300 点保留 60%。负攻速沿用 1 / (1 + attack_speed / 300)。不加快武器动作与喷射频率。"
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
	"area_size": {
		"display_name": "攻击距离",
		"category": CATEGORY_CONTROL,
		"default": 0,
		"min": -90,
		"is_integer": true,
		"is_percent": false,
		"description": "影响武器的攻击距离与索敌距离。"
	},
	"damage_area_size": {
		"display_name": "伤害范围",
		"category": CATEGORY_CONTROL,
		"default": 0,
		"min": -90,
		"is_integer": true,
		"is_percent": false,
		"description": "影响适用攻击的伤害半径或宽度，并同步对应视觉大小。"
	},
	"control_power": {
		"display_name": "控制强度",
		"category": CATEGORY_CONTROL,
		"default": 0,
		"min": 0,
		"max": 100,
		"is_integer": true,
		"is_percent": false,
		"description": "所有软控、硬控持续时间乘以（1 + 控制强度 / 100），再受敌人控制抗性修正；保留雷电连锁目标数加成。"
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
		"description": "局内掉落概率加成。附魔采用递减收益：正加成最多提高40%，负加成最多降低75%；其余掉落仍按百分比计算。"
	},
	"health_pack_heal_plus": {
		"display_name": "血包恢复量加成",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -99999,
		"max": 99999,
		"is_integer": true,
		"is_percent": false,
		"description": "血包拾取后的固定生命恢复量加成，可为负，不影响血包掉落概率。"
	},
	"luck": {
		"display_name": "幸运",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": 0,
		"max": 9999,
		"is_integer": true,
		"is_percent": false,
		"description": "影响稀有遗物与升级选项；附魔掉率随幸运递减增长，最多相对提高60%。每波每掉1个附魔，普通怪后续掉率乘45%；前5波最多3个，之后4个。连续两次完成且击杀至少8个敌人的战斗未掉附魔，第二次结算补1个。"
	},
	"currency_gain_percent": {
		"display_name": "货币获取加成",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -95,
		"is_integer": true,
		"is_percent": true,
		"description": "拾取金币的百分比加成，不直接加成利息、固定交易奖励或最终营地币。"
	},
	"finance": {
		"display_name": "理财",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": 0,
		"max": 999999999,
		"is_integer": true,
		"is_percent": false,
		"description": "仅影响开局初始本金；局内存取款和奖励独立修改实际本金余额。"
	},
	"interest_rate": {
		"display_name": "利率",
		"category": CATEGORY_REWARD,
		"default": 5,
		"min": 0,
		"is_integer": false,
		"is_percent": true,
		"description": "当前有效利率，默认 5；支持小数成长。名义利息为 ceil(本金×利率/100)，再受理智修正；实际利息加入随身金币，不自动增加本金。"
	},
	"shop_price_percent": {
		"display_name": "商店折扣",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -100,
		"max": 90,
		"is_integer": true,
		"is_percent": true,
		"description": "局内商店价格折扣；10 表示商店价格降低 10%，负值表示涨价；多个来源逐层乘算叠加。"
	},
	"shop_offer_count_bonus": {
		"display_name": "商店选择数量加成",
		"category": CATEGORY_REWARD,
		"default": 0,
		"min": -1,
		"max": INF,
		"is_integer": true,
		"is_percent": false,
		"description": "共享奖励和局内商店的候选数量加成，无上限；购买货架至少 3 件，升级奖励沿用原有数量规则。"
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
		"is_integer": true,
		"is_percent": false,
		"description": "理智初始为100，不设上下限。低于100时购买更贵、出售收益和利息降低；达到100时按原有价格和全额利息结算。"
	},
	"divinity": {
		"display_name": "侵蚀度",
		"category": CATEGORY_ELDRITCH,
		"default": DEFAULT_DIVINITY,
		"is_integer": true,
		"is_percent": false,
		"description": "波初读取侵蚀度，增强怪物属性并增加精英配额；普通刷怪数量乘以（1 + 非负侵蚀度 / 100），小数余量跨批累计，不改变刷新间隔。"
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
	if not STAT_DEFINITIONS.has(stat_id):
		return value
	# Read the immutable definition once, rather than repeating helper lookups.
	var definition: Dictionary = STAT_DEFINITIONS[stat_id]
	var clamped_value := clampf(value, float(definition.get("min", -INF)), float(definition.get("max", INF)))
	if bool(definition.get("is_integer", false)):
		return float(roundi(clamped_value))
	return clamped_value


static func is_percent_stat(stat_id: String) -> bool:
	return bool(_get_stat_property(stat_id, "is_percent", false))


static func is_integer_stat(stat_id: String) -> bool:
	return bool(_get_stat_property(stat_id, "is_integer", false))


static func get_display_name(stat_id: String) -> String:
	return L10n.source(_get_stat_property(stat_id, "display_name", stat_id))


static func get_category(stat_id: String) -> String:
	return str(_get_stat_property(stat_id, "category", L10n.text("ui.common.unknown")))


static func get_description(stat_id: String) -> String:
	return L10n.source(_get_stat_property(stat_id, "description", ""))


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
	# 正护甲减伤，负护甲增伤；接近 -ARMOR_K 时封顶，避免除零和无限伤害。
	var denominator := ARMOR_K + armor
	if denominator <= 0.0:
		return get_max_value("damage_taken_percent")
	var damage_taken_percent := ARMOR_K / denominator * 100.0
	return clampf(damage_taken_percent, MIN_DAMAGE_TAKEN_PERCENT, get_max_value("damage_taken_percent"))


static func calculate_attack_interval(base_interval: float, attack_speed: float) -> float:
	# 正攻速前段更陡、后段更缓：100 点保留 75%，300 点保留 60%。
	# 负攻速保持原线性惩罚，避免对数映射放大减速效果。
	var effective_attack_speed := attack_speed
	if attack_speed > 0.0:
		effective_attack_speed = 100.0 * log(1.0 + attack_speed / 100.0) / log(2.0)
	var speed_multiplier := maxf(1.0 + effective_attack_speed / ATTACK_SPEED_SCALE, 0.1)
	return base_interval / speed_multiplier


static func calculate_attack_range_multiplier(area_size: float) -> float:
	return 1.0 + clamp_stat_value("area_size", area_size) * RANGE_BONUS_EFFICIENCY / 100.0


static func calculate_control_duration(duration: float, control_power: float) -> float:
	return maxf(duration, 0.0) * (1.0 + clamp_stat_value("control_power", control_power) / 100.0)


static func calculate_damage_area_multiplier(damage_area_size: float) -> float:
	return 1.0 + clamp_stat_value("damage_area_size", damage_area_size) * RANGE_BONUS_EFFICIENCY / 100.0


static func calculate_attack_radius(base_radius: float, area_size: float) -> float:
	# Preserve raw equipment stats and base reach; scale only the bonus here.
	return maxf(base_radius, 0.0) * calculate_attack_range_multiplier(area_size)


static func calculate_damage_area_radius(base_radius: float, damage_area_size: float) -> float:
	return maxf(base_radius, 0.0) * calculate_damage_area_multiplier(damage_area_size)


static func calculate_finance_interest_gain(finance: float, interest_rate: float) -> int:
	# 理财收益向上取整，方便小额本金也能获得清晰反馈。
	var safe_finance := clamp_stat_value("finance", finance)
	var safe_rate := clamp_stat_value("interest_rate", interest_rate)
	return int(ceil(safe_finance * safe_rate / 100.0))


static func calculate_shop_cost(base_cost: int, shop_price_percent: float) -> int:
	return calculate_shop_cost_from_discounts(base_cost, [shop_price_percent])


static func calculate_shop_cost_from_discounts(base_cost: int, discount_layers: Array) -> int:
	# 折扣逐层乘算：两层 8% 折扣得到 0.92 * 0.92 = 84.64%，负折扣表示涨价。
	if base_cost <= 0:
		return 0
	return maxi(1, int(ceil(float(base_cost) * calculate_shop_price_multiplier(discount_layers))))


static func calculate_shop_price_multiplier(discount_layers: Array) -> float:
	var multiplier := 1.0
	for discount_layer in discount_layers:
		var discount_percent := clamp_stat_value("shop_price_percent", float(discount_layer))
		multiplier *= maxf(1.0 - discount_percent / 100.0, 0.0)
	return multiplier


static func calculate_shop_offer_count(base_count: int, shop_offer_count_bonus: float) -> int:
	var safe_base_count := maxi(0, base_count)
	var safe_bonus := roundi(clamp_stat_value("shop_offer_count_bonus", shop_offer_count_bonus))
	return maxi(2, safe_base_count + safe_bonus)


static func calculate_enemy_spawn_count(base_count: int, enemy_spawn_rate_percent: float) -> float:
	var spawn_rate_percent := clamp_stat_value("enemy_spawn_rate_percent", enemy_spawn_rate_percent)
	# Keep the expected count fractional; the live scheduler carries the remainder.
	return float(maxi(0, base_count)) * (1.0 + spawn_rate_percent / 100.0)

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
