# 15-召唤物与友方实体模块详细设计文档

本文档定义“召唤物与友方实体”模块的 MVP 规则、运行时结构、和其他模块的接入方式。当前阶段先做到：**能生成、能跟随、能索敌、能攻击、能清理**，暂不做复杂召唤流派、召唤物专属 UI、召唤物存档和特殊效果执行。

## 1. 模块目标

1. 提供统一的友方实体基类，支持后续武器、遗物、羁绊和营地效果生成召唤物。
2. 让召唤物复用现有 `ModifierStack`、`TargetingService` 和敌人受击接口。
3. 明确召唤物的伤害归属、生命周期和战斗清理规则。
4. 为 `summon_damage`、`summon_count` 等基础属性提供可运行的落点。
5. 在缺少美术素材时，仍能通过代码和控制台自测验证核心逻辑。

## 2. 模块边界

### 2.1 本模块负责

1. 召唤物节点创建、初始化、跟随玩家、索敌、攻击和消失。
2. 召唤物数量上限和单次生成数量裁剪。
3. 召唤物伤害计算与敌人受击调用。
4. 波次结束、战斗重置、死亡或通关后的召唤物清理。
5. 向外发出 `summon_spawned`、`summon_died`、`damage_dealt` 等事件，供后续统计或 UI 使用。

### 2.2 本模块不负责

1. 召唤物来源的商店刷新规则。
2. 召唤物专属武器、遗物和羁绊特殊效果的详细设计。
3. 召唤物图鉴、召唤物升级树、召唤物专属 UI。
4. 召唤物永久存档；召唤物属于单局运行态。
5. 复杂 AI，例如阵型协同、仇恨系统、治疗友军、主动技能链。

## 3. 玩法规则

### 3.1 归属规则

1. 召唤物必须绑定一个 `owner_player`。
2. 召唤物造成的伤害归属于玩家，后续结算统计可以按 `source_type`、`source_id`、`summon_id` 继续拆分。
3. 召唤物不写入正式存档，也不跨局保留。
4. 召唤物死亡或波次结束后即清理。

### 3.2 生成来源

MVP 支持运行时传入召唤配置，由以下模块在后续调用：

1. 武器：召唤类武器发起召唤请求。
2. 遗物：遗物特殊效果发起召唤请求。
3. 羁绊：羁绊阈值特殊效果发起召唤请求。
4. 营地：`camp_kin_nursery` 的 `run_start_random_summon` 后续可在开局时调用默认召唤。

当前不新增 `summons.json`。如果后续召唤物类型明显增多，再把召唤配置迁移为独立配置表，并由 `DataRegistry` 统一加载。

### 3.3 数量规则

1. 单个召唤来源提供 `base_count`，默认 1。
2. 最终生成数量 = `base_count + 玩家 summon_count`。
3. 结果会被 `SummonRoot.hard_cap` 裁剪，MVP 默认硬上限为 12。
4. 达到硬上限后，新生成请求不会替换旧召唤物，只生成剩余可用槽位。
5. `summon_count` 只表示额外召唤数量，不单独决定是否存在召唤来源。

### 3.4 跟随与索敌

1. 召唤物默认围绕玩家形成简单环形跟随点。
2. 附近有敌人时，召唤物会在 `chase_radius` 内追逐最近敌人。
3. 召唤物距离玩家超过 `leash_distance` 时，优先返回玩家身边。
4. 索敌复用 `TargetingService`，目标规则与当前武器模块保持一致：最近敌人。

### 3.5 攻击与伤害

1. MVP 召唤物只做近距离自动攻击，不做投射物。
2. 召唤物攻击半径由配置中的 `attack_radius` 决定，可被 `area_size` 加成。
3. 攻击间隔由配置中的 `attack_interval_ms` 决定，默认吃 `attack_speed`。
4. 召唤物基础伤害使用 `summon_damage`，再叠加通用 `damage_percent`。
5. 暴击使用全局随机，读取玩家暴击率和暴击伤害。

伤害公式：

```text
基础伤害 = 召唤物自身 summon_damage + 玩家 summon_damage
伤害倍率 = 1 + damage_percent / 100
暴击倍率 = crit_damage / 100，未暴击时为 1
最终伤害 = round(基础伤害 * 伤害倍率 * 暴击倍率)
```

敌人仍会通过自己的 `damage_taken_percent` 承受最终修正。

### 3.6 生命周期

1. `lifetime_seconds < 0` 表示永久持续到波次结束或战斗结束。
2. `lifetime_seconds >= 0` 表示倒计时结束后自动消失。
3. 召唤物可拥有 `max_hp`，但 MVP 暂无敌人主动攻击召唤物。
4. 波次结束时统一清理所有召唤物，避免跨波残留数值。

## 4. 运行时配置结构

MVP 使用运行时字典传入配置，后续可以平移到 `summons.json`。

```json
{
  "id": "summon_kinling",
  "display_name": "眷族幼体",
  "tags": ["summon", "kin"],
  "base_stats": {
    "max_hp": 20,
    "move_speed": 240,
    "summon_damage": 4
  },
  "attack_interval_ms": 700,
  "attack_radius": 72,
  "follow_distance": 96,
  "chase_radius": 320,
  "leash_distance": 420,
  "lifetime_seconds": -1
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id` | String | 是 | 召唤物唯一 ID，运行期和统计使用 |
| `display_name` | String | 否 | 显示名，MVP 暂不进入 UI |
| `tags` | Array[String] | 否 | 标签，供后续羁绊、统计、筛选使用 |
| `base_stats` | Dictionary | 是 | 召唤物基础属性，复用基础数值表字段 |
| `attack_interval_ms` | int | 是 | 基础攻击间隔，单位毫秒 |
| `attack_radius` | int | 是 | 攻击半径，单位像素 |
| `follow_distance` | int | 否 | 跟随玩家的环形距离 |
| `chase_radius` | int | 否 | 离召唤物多远内会追敌 |
| `leash_distance` | int | 否 | 离玩家多远后强制回到玩家身边 |
| `lifetime_seconds` | float | 否 | 生命周期，`-1` 表示随波次持续 |

## 5. 场景与脚本结构

```text
scenes/waves/wave_manager.tscn
├─ EnemyRoot
├─ PickupRoot
└─ SummonRoot

scenes/summons/summon_root.tscn
└─ TargetingService

scenes/summons/summon_unit.tscn
├─ CollisionShape2D
└─ VisualAnchor
   └─ Sprite2D
```

| 文件 | 职责 |
|---|---|
| `scripts/summons/summon_root.gd` | 召唤物创建、数量裁剪、清理、事件转发 |
| `scripts/summons/summon_controller.gd` | 单个召唤物移动、索敌、攻击、生命周期 |
| `scripts/waves/wave_manager.gd` | 持有 `SummonRoot`，在波次结束和战斗重置时清理召唤物 |
| `scripts/core/bootstrap.gd` | 启动自测召唤物生成、攻击、清理 |

## 6. 对外接口

### 6.1 `SummonRoot`

1. `initialize(player)`：绑定玩家并清理旧召唤物。
2. `spawn_summon(summon_data, spawn_position, use_spawn_position)`：生成单个召唤物。
3. `spawn_summons(summon_data, base_count)`：按 `base_count + summon_count` 批量生成。
4. `spawn_default_summons(base_count)`：生成 MVP 默认眷族。
5. `clear_summons()`：清理全部召唤物。
6. `get_active_summons()`：返回当前有效召唤物列表。

### 6.2 `WaveManager`

1. `spawn_summon(summon_data, position, use_position)`：生成单个召唤物，支持指定位置。
2. `spawn_summons(summon_data, base_count)`：供武器、遗物、羁绊、营地模块批量调用。
3. `spawn_default_summon(base_count)`：生成默认眷族并返回第一个召唤物。
4. `spawn_default_summons(base_count)`：供 MVP 和后续开局随机召唤占位。
5. `clear_summons()`：清理召唤物。
6. `clear_battle_entities()`：统一清理敌人、掉落和召唤物。

## 7. 与其他模块关系

### 7.1 与基础数值模块

1. `summon_damage` 是召唤物固定伤害加成。
2. `summon_count` 是额外召唤数量。
3. `damage_percent`、`attack_speed`、`crit_chance`、`crit_damage` 作为通用攻击属性可被召唤物读取。
4. 所有属性仍通过 `ModifierStack` 计算，不直接改最终数值。

### 7.2 与武器模块

1. 武器模块后续只发起召唤请求，不直接管理召唤物 AI。
2. 召唤类武器的负载、升级、商店刷新仍由武器模块处理。
3. 召唤物攻击不占用武器攻击计时器，具体限制由召唤来源配置决定。

### 7.3 与遗物和羁绊模块

1. 遗物或羁绊可以通过特殊效果记录召唤请求。
2. 当前特殊效果仍只记录，不自动执行；执行器后续再接入 `WaveManager.spawn_summons()`。
3. 召唤物自身标签暂不参与羁绊计数，羁绊仍按“武器 + 遗物”统计。

### 7.4 与营地模块

1. `camp_kin_nursery` 提供召唤体系局外入口。
2. `camp_upgrade_summon_damage` 通过局外升级提供 `summon_damage` 加成。
3. `run_start_random_summon` 后续在开局时触发，MVP 可先调用默认召唤物。

### 7.5 与主流程和存档模块

1. 召唤物只存在于局内战斗，不进入存档。
2. 波次结束会清理召唤物。
3. 玩家死亡、通关、退出战斗时，通过 `clear_battle_entities()` 统一清理。

## 8. MVP 实现范围

当前直接实现：

1. 一个通用召唤物节点。
2. 一个召唤物管理根节点。
3. 召唤物跟随玩家。
4. 召唤物最近敌人索敌。
5. 召唤物近距离攻击敌人。
6. 召唤物伤害读取 `summon_damage` 和通用攻击属性。
7. 召唤物数量受 `summon_count` 和 hard cap 控制。
8. 波次结束、战斗重置时清理召唤物。
9. Bootstrap 控制台自测。

暂不实现：

1. 召唤物专属配置表。
2. 多种召唤物 AI。
3. 召唤物投射物。
4. 召唤物治疗、防御、嘲讽、光环。
5. 召唤物受击表现和死亡动画。
6. 召唤物 UI 面板。

## 9. 验收标准

1. `SummonRoot` 能绑定玩家并生成召唤物。
2. 召唤物能进入 `summons` 和 `friendly_entities` 分组。
3. 召唤物能读取玩家 `summon_damage` 加成。
4. 召唤物能对最近敌人造成伤害。
5. `summon_count` 能增加批量生成数量，并受 hard cap 限制。
6. 波次结束和战斗重置能清理召唤物。
7. 缺少召唤物美术素材时，核心逻辑仍可运行。

## 10. 后续扩展

1. 添加 `summons.json`，把默认眷族、召唤武器、特殊遗物召唤体全部配置化。
2. 添加召唤物远程攻击和投射物。
3. 添加召唤物主动技能、光环、嘲讽和治疗。
4. 添加召唤物图鉴和营地培养分支。
5. 添加召唤物专属表现资源和简单 HUD 状态展示。

## 11. 素材清单入口

1. 模块专用素材清单：`docs/asset/15-summon_ally_asset_checklist.md`。
2. 全局素材汇总：`docs/asset/asset_checklist_summary.md`。
3. 当前 MVP 必需素材只有默认眷族幼体单帧；行走帧表、攻击特效和 UI 图标均为可选增强。
