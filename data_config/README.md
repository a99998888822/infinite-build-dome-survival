# data_config 配置目录说明

本目录存放游戏的静态配置表，供 `DataRegistry` 在启动时统一加载、缓存和查询。业务模块不应直接读取本目录下的 JSON 文件，而应通过 `DataRegistry` 获取配置。

2026-10-05：正式主战斗采用主动施放。武器新增 `active_cooldown_ms`（动作结束后的冷却）和用户定义的 `combat_tags`；`attack_interval_ms` 保留为升级比例基准。当前敌我与掉落数值见 [正式接入记录](../docs/main/active_combat_implementation.md)，下方早期示例说明不代表当前平衡基准。

## 第 5 步前你需要预先准备什么

1. 配置文件本身必须存在：即使只有一条示例数据，也要先创建对应 JSON 文件，避免加载阶段全是“文件不存在”。
2. JSON 根节点统一为数组：每个文件都是 `[{...}, {...}]`，便于 DataRegistry 建立 ID 索引。
3. 每条记录必须有稳定 `id`：例如 `weapon_void_blade`、`character_void_hunter`。
4. 每条记录建议有 `name` 或 `display_name`、`description`、`enabled`、`tags` 等公共展示字段；具体简写表可按模块约定减少字段。
5. 跨表引用先保持可用：例如角色的 `start_weapons` 必须引用已存在的武器ID。
6. 素材路径可以暂时不填：基础数据模块不依赖真实图片、音频或场景资源。
7. 数值不需要平衡：当前示例只为验证加载、查询、索引和后续校验，不代表正式数值。

## 当前示例文件

| 文件 | 用途 | 示例ID |
| ---- | ---- | ---- |
| `weapons.json` | 武器静态配置 | `weapon_void_blade` |
| `relics.json` | 遗物静态配置 | `relic_piggy_bank` / `relic_finance_manager` / `relic_dividend_check` |
| `bonds.json` | 羁绊阈值与额外效果配置 | `bond_mighty` / `bond_sharpshooter` / `bond_chosen` |
| `characters.json` | 角色基础属性、开局武器 | `character_void_hunter` |
| `enemies.json` | 敌人基础属性、AI类型、掉落表引用 | `enemy_mutated_grub` |
| `erosion_pressure_rules.json` | 波初侵蚀对所有怪物生命、攻击、护甲的独立乘区；每100侵蚀增加 +180% / +90% / +135%，超过100继续线性增长 | `erosion_enemy_stats` |
| `camp_buildings.json` | 营地建筑等级效果与升级选项配置 | `camp_armory_workshop` / `camp_relic_archive` / `camp_dome_shelter` |
| `waves.json` | 波次刷怪配置 | `wave_stage_01` |
| `drop_tables.json` | 掉落表配置 | `drop_basic_enemy` / `drop_elite_enemy` / `drop_boss_enemy` |

## 公共字段约定

常规配置表建议包含：

```json
{
  "id": "unique_config_id",
  "display_name": "显示名称",
  "description": "说明文本",
  "enabled": true,
  "tags": ["tag_a", "tag_b"]
}
```

部分配置表可以采用更短的模块专用结构，例如 `bonds.json` 和 `camp_buildings.json`。

## characters.json 规则

1. `icon` 是角色列表、营地角色信息和存档展示使用的小图标路径。
2. `display_sprite` 是角色选择页面中间区域使用的右向站立图路径。
3. `display_stats` 是角色选择页面展示的属性 key 字符串数组，数组顺序就是界面顺序；未配置时回退展示全部基础属性。
4. `start_weapons` 保存初始武器 ID，并引用 `weapons.json`。
5. 角色场景表现只使用右向基础单帧和右向行走帧表；向左移动时由 Godot 水平翻转。
6. 当前不配置向上、向下动画资源。


## weapons.json 规则

以下属性说明描述现有正式战斗；主动战斗的 R02 独立审阅通过 `WeaponInstance.use_active_range_rules` 启用新范围规则，详见根目录方案第 17.8—17.9 节。`combat_tags` 单独保存用户指定的中文战斗标签（近战、远程、投射物、扇形、范围、法阵），不要与现有 `tags` 的附魔分类合并；秘仪书为“范围、法阵”。新模式中投射物外观缩放与原生碰撞分离，三把扇形武器按两项加成之和扩大最远距离。

1. `weapons.json` 保留运行与 UI 必要字段；`description` 必填，用于商店和图鉴展示。
2. 武器基础攻击间隔使用 `attack_interval_ms`，单位为毫秒整数；例如 `700` 表示0.7秒。
3. 武器稀有度使用 `rarity`，当前白色/普通武器写 `common`。
4. 武器图标使用 `icon`，素材未完成时可先写占位路径。
5. 武器升级使用 `level_upgrades`：`stat` 表示属性升级，`field` 表示武器自身字段升级。
6. 每个 `level_upgrades` 目标等级使用对象结构：`rarity` 表示升级选项稀有度，`effects` 保存具体升级效果。
7. 普通直线投射物按最近敌人索敌；榴弹选择密集怪群，秘仪书在椭圆领域内随机点名，钱袋以目标方向为中心扇状齐射。
8. `projectile_behavior` 区分普通弹体、`plasma`、`grenade`、`ritual_domain` 和 `coin`；`attack_kind=element` 使用元素武器伤害。
9. `area_size` 表示武器攻击距离/索敌距离属性；`damage_area_size` 表示指定范围伤害的半径、宽度与视觉大小属性。两者每点按0.5%生效，统一倍率为 `1 + 属性 / 200`；配置和面板保留原始属性值，基础距离、半径不变。短刀、炉灯、摆锤的两项属性相加后扩大原生扇形半径。
10. 木质弓箭与电火花连锁不受 `damage_area_size` 影响；电浆球、落雷、火焰、冰冻的伤害区域及震荡的击退区域受其影响；`pickup_radius` 只控制掉落物吸附。
    电浆炮的 `hit_radius` 是球体显示、接触灼击、物理碰撞和属性栏共用的基础半径，默认12像素，受 `damage_area_size` 缩放，最低4像素；`area_size` 只扩大射程。旧 `plasma_damage_radius`／`plasma_visual_radius` 已移除，接地电弧不参与伤害判定。
11. `hit_sfx` 是可选的武器命中音效路径；音频缺失时静默处理，不影响伤害逻辑。
12. 秘仪书的 `attack_range`、`domain_minor_axis` 分别为椭圆的水平和垂直半轴，均受 `area_size` 加成；`projectile_count` 对应每轮不同目标的点名数量。
13. 钱袋原生伤害为 `等级基础伤害 + 角色远程伤害×player_damage_coefficient + principal_damage_coefficient×sqrt(max(当前本金, 0))`，再计算通用增伤、暴击和取整；本金只读。默认 3 发，`projectile_spacing_degrees=10` 指相邻金币夹角，围绕瞄准方向对称齐射。
14. 木质弓箭的 `projectile_spacing_degrees=15`，裂地战锤为 10；异化触手、守夜长枪、电浆炮为 20，基础投射物均为 1。此字段优先于旧的总展开角 `spread_angle`；其他武器继续沿用各自规则。战锤额外投射物增加地裂路线，每路原生节点仍为 5 个、射程保持不变；落雷独立均匀布点，首点距身前 40px、末点位于射程末端、最大间距 64px。射程增加时自动增加落雷次数，分裂在前时同步增加分支落雷；伤害范围只扩大单雷半径。推进时长仍为 0.4 秒、每次预警仍为 0.5 秒。
14. 当前负载：木弓12、钱袋14、秘仪书18、电浆炮24、榴弹炮25，总计93；升级不增加负载，同种武器不可重复装备。长期按轻型12～14、中型16～18、重型24～25扩展武器池，支持100负载下4～8件的配装目标，当前正式种类上限仍为5件。
15. 木弓2～5级每级增加1点远程基础伤害、缩短50毫秒间隔，不再在五级自动增加箭矢。电浆炮2～5级每级增加2点灼击基础伤害，发射间隔、灼击间隔和接触半径不变；每次灼击触发的附魔使用20%的完整元素伤害基数，延迟至具体效果结算时取整。

## augmentations.json 规则

1. `description` 保存面向玩家的效果文案，支持 `\n` 换行；名称、类型和稀有度由共用提示框单独展示。理财背包、已装备附魔槽与 Esc 背包使用同一格式，不再追加粒子、辉光或实例参数说明。
2. `enchantment_type` 是展示分类：`buff`＝增益、`spell`＝法术、`element`＝元素。`category` 继续保留 `enchantment_scroll`，用于附魔装填和物品流转，不应改为展示分类。
3. `rarity` 同时用于提示文本、卡片颜色和掉落档位；会心当前为 `rare`（稀有）。
4. `weapon_bonuses` 保存当前武器的属性附魔加成。巨力为 `all_damage_percent: 20`，致命为 `crit_damage: 50`；暴击率与暴击伤害仍按百分点相加。
5. `scroll_electric_spark`（落雷）的 `damage_multiplier: 0.6` 直接参与实际落雷伤害结算，不再叠加旧的 `damage × 0.85`。`scroll_lightning`（电火花）基础与掉落实例的麻痹时长均为 0.5 秒。
6. 当前全部 19 条批准文案与数值说明见 [附魔提示文本清单](../docs/main/enchantment_tooltip_inventory.md)。

## bonds.json 简写规则

`bonds.json` 不直接写完整 `Modifier` 字段，只保留羁绊设计需要的最小信息。

普通属性效果：

```json
{ "stat": "melee_damage", "value": 2 }
```

特殊标签效果：

```json
{ "effect": "tagged_damage_percent", "target_tags": ["mystic"], "value": 10 }
```

运行时由后续“遗物与羁绊模块”补齐 `source_type/source_id/duration/stack_rule/priority` 等上下文字段，并提交给 `ModifierStack` 或 `ExtraEffectRegistry`。

## relics.json 规则

1. `max_stack = 0` 表示该遗物不限制持有数量。
2. `max_stack = 1` 或更大时，表示单局最多持有对应数量。
3. 遗物 `effects` 使用统一 modifier 结构，当前模块会直接读取并叠加到玩家。


## waves.json 简写规则

`waves.json` 只保留刷怪运行必需字段，不写 `display_name`、`description`、`enabled`、`tags`、`mode` 等展示或可推导字段。

```json
{
  "id": "wave_stage_01",
  "duration_seconds": 20,
  "spawn_groups": [
    { "enemy_id": "enemy_mutated_grub", "spawn_interval_ms": 1200, "count_per_spawn": 3 }
  ]
}
```

波次时间规则：每波单独计时，时长使用 `min(15 + 5 * wave_index, 50)`，即第1波20秒，第2波25秒，最高50秒。


## drop_tables.json 规则

`drop_tables.json` 使用基准掉落值，运行时再套用玩家当前加成：

1. `exp_orb.amount` 表示经验球基础经验值；敌人死亡后会掉落经验球。
2. 经验与金币各自独立受到加成影响：经验读取 `exp_gain_percent`，金币读取 `currency_gain_percent`。
3. 百分比掉落物使用 `chance_percent`，受到 `drop_rate_percent` 影响，最终概率 = 基础概率 * (1 + drop_rate_percent / 100)。
4. 血包的 `amount` 表示基础恢复量；拾取后的最终恢复量 = 基础恢复量 + `health_pack_heal_plus`，该属性不影响血包掉落概率。
5. 最终概率必须限制在0到100之间；BOSS遗物掉落通过 `type = relic`、`amount = 1`、`chance_percent = 100` 表达，运行时代码按“有且只有一个遗物”处理。
6. 拾取经验球时同时获得经验和等额基础金币；波次结束后统一吸取并结算场上所有经验球。配置中不使用 `sync_gold_on_pickup`、`max_drops`、`guaranteed` 等可由规则推导的字段。

## camp_buildings.json 结构规则

`camp_buildings.json` 分为两类内容：

1. `levels`：建筑等级效果，例如解锁武器库、遗物库、特殊槽位或提供全局属性加成。
2. `upgrade_options`：该建筑开放的局外升级选项，例如近战伤害、投射物数量、生存防御或掉落成长等。
3. `unlock_condition`：建筑解锁条件，可用前置建筑等级，也可用局外货币 `currency + cost` 购买解锁。

升级选项的购买进度不写在配置表，写入玩家存档。配置表只定义固定花费、等级上限和每级增量。若升级项需要建筑达到指定等级后才可购买，使用 `required_building_level` 标注。


当前营地建筑：

| 建筑ID | 名称 | 核心定位 |
| ---- | ---- | ---- |
| `camp_armory_workshop` | 军械工坊 | 武器图鉴解锁、武器基础强化 |
| `camp_relic_archive` | 遗物档案馆 | 遗物图鉴解锁、遗物套装预览 |
| `camp_blade_arena` | 利刃演武场 | 近战专属升级选项 |
| `camp_farstar_range` | 远星射靶台 | 远程、投射物与元素伤害升级选项 |
| `camp_dome_shelter` | 穹顶庇护所 | 生存防御类加成 |
| `camp_council_hall` | 议事大厅 | 套装、拾取、经验、掉落与货币成长 |

## 修改规则

1. ID 使用小写 snake_case。
2. ID 一旦被其他表或存档引用，不要随意改名。
3. 新增配置时，先复制现有示例，再逐步修改字段。
4. 删除配置前，先检查是否被其他表引用。
5. 字段含义不确定时，先在对应模块设计文档中补充说明，再修改配置。

## 与后续步骤的关系

- 第 5 步 `DataRegistry`：读取这些文件，建立缓存和ID索引。
- 第 6 步最小配置表：会继续完善这些示例数据。
- 第 7 步 `DataValidator`：会校验必填字段、属性ID、operation、stack_rule等。
- 第 8 步跨表引用校验：会校验 `start_weapons`、`bond_id`、`drop_table_id`、`enemy_id` 等引用是否存在。

## 注意

当前配置是“工程测试示例”，不是正式策划表。后续实现武器、遗物、敌人等模块时，可以迁移、扩展或替换这些示例。
