# data_config 配置目录说明

本目录存放游戏的静态配置表，供 `DataRegistry` 在启动时统一加载、缓存和查询。业务模块不应直接读取本目录下的 JSON 文件，而应通过 `DataRegistry` 获取配置。

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

1. `weapons.json` 只保留运行和UI最小必要字段，不写 `description`、`enabled`、空 `effects` 等冗余字段。
2. 武器基础攻击间隔使用 `attack_interval_ms`，单位为毫秒整数；例如 `700` 表示0.7秒。
3. 武器稀有度使用 `rarity`，当前白色/普通武器写 `common`。
4. 武器图标使用 `icon`，素材未完成时可先写占位路径。
5. 武器升级使用 `level_upgrades`：`stat` 表示属性升级，`field` 表示武器自身字段升级。
6. 每个 `level_upgrades` 目标等级使用对象结构：`rarity` 表示升级选项稀有度，`effects` 保存具体升级效果。
7. 索敌规则不写入配置，局内武器模块默认按最近敌人索敌。
8. 投射物/攻击模式暂不配置化，等武器差异变复杂后再单独设计。
9. `area_size` 只表示武器攻击距离/索敌距离；`damage_area_size` 只表示指定范围伤害的半径与视觉大小。
10. 木质弓箭与闪电链不受 `damage_area_size` 影响；电浆球、电火花、火焰、冰冻、爆裂受其影响；`pickup_radius` 只控制掉落物吸附。
11. `hit_sfx` 是可选的武器命中音效路径；音频缺失时静默处理，不影响伤害逻辑。

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
2. `upgrade_options`：该建筑开放的局外升级选项，例如近战伤害、投射物数量、眷族伤害、生存防御或掉落成长等。
3. `unlock_condition`：建筑解锁条件，可用前置建筑等级，也可用局外货币 `currency + cost` 购买解锁。

升级选项的购买进度不写在配置表，写入玩家存档。配置表只定义固定花费、等级上限和每级增量。若升级项需要建筑达到指定等级后才可购买，使用 `required_building_level` 标注。


当前营地建筑：

| 建筑ID | 名称 | 核心定位 |
| ---- | ---- | ---- |
| `camp_armory_workshop` | 军械工坊 | 武器图鉴解锁、武器基础强化 |
| `camp_relic_archive` | 遗物档案馆 | 遗物图鉴解锁、遗物套装预览 |
| `camp_blade_arena` | 利刃演武场 | 近战专属升级选项 |
| `camp_farstar_range` | 远星射靶台 | 远程与投射物升级选项 |
| `camp_kin_nursery` | 眷族培育栏 | 召唤体系强化 |
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





