# 局内武器模块详细设计方案

本文档定义“局内武器模块”的职责、数据结构、运行时对象、伤害计算、索敌规则、升级规则与工程落地方式。该模块承接玩家与角色模块提供的角色属性、开局武器 ID 与武器挂点，向敌人模块输出伤害事件，向遗物/羁绊/营地成长模块开放可扩展的数值入口。

## 1. 模块目标

1. 根据玩家当前武器 ID 列表创建局内武器实例。
2. 统一管理武器等级、攻击间隔、冷却、伤害、范围、投射物与升级效果。
3. 让所有武器读取玩家最终属性，而不是直接修改玩家配置。
4. 支持近战、远程、范围伤害与后续召唤武器扩展。
5. 保持索敌、命中、弹体、伤害事件可替换，方便后续敌人模块接入。
6. 保持 `weapons.json` 精简，只配置稳定数值，不配置复杂运行逻辑。

## 2. 模块边界

### 包含内容

1. 武器管理器 `WeaponLoadout`。
2. 单个武器运行时实例 `WeaponInstance`。
3. 武器等级与升级效果应用。
4. 攻击间隔与冷却计算。
5. 近战、远程、范围武器的最小攻击流程。
6. 投射物基础对象与生命周期。
7. 最近敌人索敌逻辑。
8. 伤害事件打包与输出。

### 不包含内容

1. 敌人 AI 与敌人移动。
2. 敌人受击表现、死亡与掉落。
3. 遗物选择 UI、武器选择 UI。
4. 营地建筑解锁武器的长期规则。
5. 复杂特效、音效、屏幕震动。
6. 召唤物完整 AI。

## 3. 与现有模块的关系

### 玩家与角色模块

1. 玩家模块提供 `PlayerController.get_start_weapon_ids()`。
2. 玩家模块提供 `PlayerController.get_stat(stat_id)`。
3. 玩家场景提供 `WeaponAnchor`，用于挂载近战表现或发射点。
4. 武器模块不回写 `characters.json`，只读取玩家运行时状态。

### 基础数值与数据配置模块

1. 武器静态数据来自 `data_config/weapons.json`。
2. 属性计算统一使用 `ModifierStack` 与 `StatDefinitions`。
3. 武器升级效果中的 `stat` 必须是合法基础属性。
4. 武器升级效果中的 `field` 只允许修改武器自身运行字段，例如 `attack_interval_ms`。

### 敌人与波次模块

1. 武器模块需要敌人查询接口，用于获取最近敌人或范围内敌人。
2. 武器模块输出伤害事件，敌人模块负责实际扣血、死亡、掉落。
3. 在敌人模块未完成前，索敌接口可以返回空，武器只运行冷却自测。

### 遗物、羁绊与营地成长模块

1. 遗物/羁绊/营地成长通过玩家 `ModifierStack` 修改通用属性。
2. 若需要特殊武器效果，应通过后续 `WeaponEffectRegistry` 扩展，不污染基础属性表。
3. 武器自身等级升级只影响该武器实例，不影响玩家全局属性。

## 4. 核心运行流程

```text
战斗开始
  -> 玩家初始化完成
  -> WeaponLoadout 读取玩家 start_weapon_ids
  -> 为每个武器 ID 创建 WeaponInstance
  -> 每帧 tick 武器冷却
  -> 武器冷却结束后查询最近敌人
  -> 根据武器标签/类型执行攻击
  -> 生成伤害事件或投射物
  -> 敌人模块处理命中、扣血、死亡
```

## 5. 场景与脚本建议

### 场景结构

```text
combat_root.tscn
├── PlayerRoot
│   └── WeaponAnchor
├── WeaponLoadout
├── ProjectileRoot
└── EnemyRoot
```

### 文件建议

1. `scripts/weapons/weapon_loadout.gd`：玩家武器列表管理器。
2. `scripts/weapons/weapon_instance.gd`：单个武器运行时实例。
3. `scripts/weapons/projectile.gd`：基础投射物。
4. `scripts/weapons/damage_event.gd`：伤害事件数据对象。
5. `scripts/weapons/targeting_service.gd`：索敌服务，后续可被敌人模块替换或接入。
6. `scenes/weapons/weapon_loadout.tscn`：武器管理节点。
7. `scenes/weapons/projectile.tscn`：基础投射物节点。

## 6. `weapons.json` 字段说明

当前武器配置保持精简，字段含义如下：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String | 武器唯一 ID，用于跨表引用和实例化。 |
| `display_name` | String | 武器显示名。 |
| `icon` | String | UI 图标路径，可先使用占位图。 |
| `rarity` | String | 稀有度，例如 `common`、`rare`、`epic`、`legendary`。 |
| `tags` | Array[String] | 武器标签，用于识别近战、远程、范围、虚空、初始武器等。 |
| `weapon_type` | String | 武器负载类别，例如 `light`、`medium`、`heavy`。 |
| `load_cost` | int | 武器负载消耗，属于武器系统，不进入基础属性表。 |
| `max_level` | int | 单局内最大等级。 |
| `attack_interval_ms` | int | 武器基础攻击间隔，单位毫秒。 |
| `hit_radius` | int | 武器基础命中/影响半径。它不是成长属性，最终攻击范围统一由 `area_size` 加成。 |
| `projectile_speed` | int | 投射物速度。非远程武器填 `0`。 |
| `spread_angle` | int | 多投射物散射总角度。单投射物或非远程武器填 `0`。 |
| `use_cooldown_reduction_only` | bool | 是否只吃 `cooldown_reduction`，不吃 `attack_speed`。 |
| `base_stats` | Dictionary | 武器自身基础数值，只影响该武器实例。 |
| `level_upgrades` | Dictionary | 每级升级对象，从 2 级开始配置；对象包含 `rarity` 和 `effects`。 |

## 7. 武器类型约定

### 近战武器

代表：`weapon_mutated_cleaver`。

1. 攻击时以玩家当前位置为中心生成近战命中范围。
2. 伤害主属性读取 `melee_damage`。
3. 基础命中半径读取武器配置 `hit_radius`，最终攻击范围只受 `area_size` 加成。
4. 攻击方向跟随玩家朝向。
5. MVP 阶段可以不做挥砍动画，只做范围判定。

### 远程武器

代表：`weapon_void_blade`。

1. 攻击时寻找最近敌人。
2. 从 `WeaponAnchor` 或玩家位置发射投射物。
3. 伤害主属性读取 `ranged_damage`。
4. 投射物数量受 `projectile_count` 影响。
5. 穿透次数受 `pierce_count` 影响。
6. 投射物速度读取武器配置 `projectile_speed`。
7. 投射物基础命中半径读取武器配置 `hit_radius`，最终攻击范围只受 `area_size` 加成。
8. 多投射物采用散射，散射总角度读取武器配置 `spread_angle`。
9. 投射物不配置生命周期；命中敌人且穿透耗尽、或碰到战斗边界时消失。
10. `pierce_count = 1` 表示额外穿透 1 个敌人，即总共可命中 2 个敌人。

### 范围伤害武器

代表：`weapon_dome_shockwave`。

1. 攻击时以玩家当前位置为中心生成范围伤害。
2. 可以同时读取 `melee_damage` 与 `ranged_damage`，并拆成两个伤害数字结算。
3. 基础影响半径读取武器配置 `hit_radius`，最终攻击范围只受 `area_size` 加成。
4. 范围武器当前只做一次性伤害，不做持续区域。

### 召唤武器

当前仅预留，不在本模块 MVP 实现。

1. 伤害主属性读取 `summon_damage`。
2. 召唤物 AI、持续时间和行为由“召唤物模块”负责。
3. 武器模块只负责创建召唤请求，不直接管理复杂召唤物行为。

## 8. 数值计算规则

所有百分比字段继续使用整数语义。

### 攻击间隔

```text
基础间隔秒 = attack_interval_ms / 1000
实际间隔 = 基础间隔秒 / (1 + attack_speed / 100)
```

说明：

1. `attack_speed = 100` 表示攻击速度翻倍。
2. 武器自身 `base_stats.attack_speed` 与玩家最终 `attack_speed` 相加。
3. 若武器 `use_cooldown_reduction_only = true`，则不读取 `attack_speed`，改用 `cooldown_reduction` 计算实际间隔。
4. 攻击间隔应设置最小值保护，避免过高攻速导致性能问题。

### 冷却缩减

```text
实际冷却 = 基础冷却 * (1 - cooldown_reduction / 100)
```

说明：

1. 仅 `use_cooldown_reduction_only = true` 的武器读取 `cooldown_reduction`。
2. 这类武器不吃 `attack_speed` 加成。
3. 普通自动攻击默认读取 `attack_speed`。

### 基础伤害

```text
近战基础伤害 = 武器 melee_damage + 玩家 melee_damage
远程基础伤害 = 武器 ranged_damage + 玩家 ranged_damage
眷族基础伤害 = 武器 summon_damage + 玩家 summon_damage
混合武器近战段 = 武器 melee_damage + 玩家 melee_damage
混合武器远程段 = 武器 ranged_damage + 玩家 ranged_damage
```

### 通用伤害加成

```text
最终非暴击伤害 = 基础伤害 * (1 + damage_percent / 100)
```

说明：

1. `damage_percent = 10` 表示最终伤害增加 10%。
2. 混伤武器拆成两个伤害数字，分别计算近战段和远程段。
3. 神秘伤害等特殊加成后续用特殊效果注册器处理，不强行加入基础属性表。

### 暴击

```text
若命中暴击：最终伤害 = 非暴击伤害 * crit_damage / 100
```

说明：

1. `crit_chance` 来自武器与玩家最终属性叠加。
2. `crit_damage = 150` 表示暴击造成 150% 伤害。
3. 暴击随机使用 Godot 普通全局随机即可。

### 范围与持续时间

```text
最终攻击范围 = hit_radius * (1 + area_size / 100)
```

说明：

1. `area_size = 40` 表示近战、远程、范围武器的攻击范围都增加 40%。
2. `area_size` 是唯一攻击范围加成属性；其他基础数据属性不得再控制武器攻击范围。
3. `hit_radius` 只表示武器配置中的基础半径，不作为可成长属性。
4. `pickup_radius` 只控制掉落物吸附范围，不参与武器攻击范围计算。
5. 当前范围武器是一次性伤害，暂不读取 `duration_percent`。

## 9. 武器升级规则

武器升级只影响单局内当前武器实例。

### 升级数据格式

```json
"level_upgrades": {
  "2": [
    { "stat": "ranged_damage", "value": 2 },
    { "field": "attack_interval_ms", "value": -50 }
  ]
}
```

### `stat` 升级

1. 写入武器实例的运行时 stat bonus。
2. 必须经过 `StatDefinitions` 校验。
3. 只影响当前武器，不影响玩家全局属性。

### `field` 升级

1. 只允许修改武器实例白名单字段。
2. MVP 白名单只有 `attack_interval_ms`。
3. 后续如需新增武器运行字段，应加入武器字段白名单，不进入基础属性表。

### 等级限制

1. 武器初始等级为 1。
2. 升级不能超过 `max_level`。
3. 若某级没有配置升级效果，仍可升级但不产生数值变化；不建议正式配置这样做。

## 10. 运行时类设计

### `WeaponLoadout`

职责：管理玩家当前装备的全部武器。

关键字段：

1. `owner_player: PlayerController`
2. `weapon_instances: Array[WeaponInstance]`
3. `targeting_service: TargetingService`

关键接口：

1. `initialize(player: PlayerController) -> bool`
2. `equip_weapon(weapon_id: String) -> bool`
3. `remove_weapon(weapon_id: String) -> void`
4. `upgrade_weapon(weapon_id: String) -> bool`
5. `get_weapon_instances() -> Array`

### `WeaponInstance`

职责：保存单把武器的运行状态并执行攻击。

关键字段：

1. `weapon_id: String`
2. `weapon_data: Dictionary`
3. `level: int`
4. `runtime_stats: Dictionary`
5. `attack_interval_ms: int`
6. `attack_timer: float`
7. `owner_player: PlayerController`

关键接口：

1. `initialize(weapon_id: String, player: PlayerController) -> bool`
2. `tick(delta: float) -> void`
3. `can_attack() -> bool`
4. `try_attack() -> bool`
5. `upgrade() -> bool`
6. `get_stat(stat_id: String) -> float`
7. `calculate_damage(damage_kind: String) -> int`

### `Projectile`

职责：承载远程攻击的移动、命中与穿透。

关键字段：

1. `damage_event: DamageEvent`
2. `direction: Vector2`
3. `remaining_pierce: int`
4. `source_weapon_id: String`

MVP 默认值：

1. 投射物速度：读取武器配置 `projectile_speed`。
2. 投射物最大存在时间：不配置；命中后穿透耗尽或碰到战斗边界时消失。
3. 基础命中半径：读取武器配置 `hit_radius`；最终命中半径只受 `area_size` 加成。
4. 多投射物散射：读取武器配置 `spread_angle`。

### `DamageEvent`

职责：打包一次命中的伤害信息。

建议字段：

1. `source_player: PlayerController`
2. `source_weapon_id: String`
3. `damage: int`
4. `damage_kind: String`
5. `is_critical: bool`
6. `tags: Array[String]`
7. `hit_position: Vector2`

## 11. 索敌规则

索敌规则暂时写在代码中，不进入 `weapons.json`。

### MVP 规则

1. 优先寻找最近敌人。
2. 若没有敌人，武器不攻击，等待下一个攻击周期。
3. 最近敌人的判断依据是玩家全局坐标到敌人全局坐标的距离。

### 后续扩展

1. 最高生命敌人。
2. 最低生命敌人。
3. 随机敌人。
4. 面朝方向扇形索敌。
5. Boss 优先。

以上扩展应放在 `TargetingService` 中，不放进武器配置表。

## 12. 负载规则

武器负载属于局内武器模块，不属于基础数值模块。

### 当前规则

1. 玩家有 `load_capacity`。
2. 武器有 `load_cost`。
3. 装备武器时检查总负载不能超过玩家当前 `load_capacity`。
4. 初始武器来自角色或局外选择，MVP 阶段也必须强校验负载，初始化或装备失败时输出明确错误。
5. 局内商店购买新武器时，如果购买后总负载超过玩家 `load_capacity`，则不允许购买。
6. `weapon_type` 的 `light`、`medium`、`heavy` 只用于负载展示和 UI 分类，不影响攻击规则。
7. `WeaponAnchor` 只用于远程发射点和美术挂点；近战和范围伤害仍以玩家当前位置为中心。

### 后续扩展

1. 特殊武器槽。
2. 武器替换界面。
3. 超载惩罚或替换流程。
4. 营地建筑增加负载上限。

## 13. 特殊效果扩展

当前 `weapons.json` 不配置复杂攻击模式，也不配置索敌规则。若后续出现特殊武器效果，使用代码注册器处理。

### 建议设计

```text
WeaponEffectRegistry
  -> effect_id: String
  -> apply(context: Dictionary)
```

### 适用场景

1. 命中后分裂。
2. 击杀后爆炸。
3. 神秘伤害额外加成。
4. 持续领域。
5. 召唤随从。
6. 区域驻守影响特定武器。

### 原则

1. 普通数值进 `base_stats` 或 `level_upgrades`。
2. 复杂行为进代码注册器。
3. 不为了单个特殊效果新增基础属性字段。

## 14. MVP 实施范围

第一阶段只实现可验证的最小闭环。

### 必做

1. `WeaponLoadout` 能从玩家读取开局武器 ID。
2. `WeaponInstance` 能从 `weapons.json` 初始化。
3. 武器能计算实际攻击间隔。
4. 武器能应用等级升级效果。
5. 武器能计算近战、远程、混合伤害。
6. 装备武器时必须校验 `load_capacity` 与 `load_cost`。
7. 商店购买新武器时，若购买后总负载超出上限，则购买失败。
8. 最近敌人索敌接口存在，但本阶段不要求真实命中敌人。
9. Bootstrap 输出武器加载、升级、伤害公式与负载校验自测。

### 可先简化

1. 不做正式攻击动画。
2. 不做正式音效。
3. 不做武器选择 UI。
4. 不做复杂弹道。
5. 不做真实敌人受击，等敌人模块接入。
6. 不要求完整攻击循环闭环，只要求“能加载、能升级、能算伤害”。

## 15. 验收标准

1. 启动时能读取全部武器配置且无校验错误。
2. 玩家初始化后，`WeaponLoadout` 能创建 1 把默认武器。
3. `attack_speed = 100` 时，普通武器实际攻击间隔正确减半。
4. `use_cooldown_reduction_only = true` 时，武器只读取冷却缩减，不读取攻速。
5. 武器升级后，`ranged_damage`、`melee_damage` 或 `attack_interval_ms` 正确变化。
6. 混伤武器能拆成近战段和远程段两个伤害数字。
7. 超出负载上限的装备或购买请求必须失败。
8. 无敌人时武器不会报错。
9. 后续敌人模块接入后，只需实现敌人查询与受击接口，不需要重构武器基础结构。

## 16. 后续实施步骤

1. 新建 `scripts/weapons/weapon_instance.gd`。
2. 新建 `scripts/weapons/weapon_loadout.gd`。
3. 新建 `scripts/weapons/damage_event.gd`。
4. 新建 `scripts/weapons/targeting_service.gd`。
5. 新建最小 `scenes/weapons/weapon_loadout.tscn`。
6. 在 `bootstrap.gd` 加入武器模块自测。
7. 等敌人模块完成后接入真实索敌与伤害命中。

## 17. 武器朝向与素材使用标准

1. `icon` 只用于商店、背包、升级界面与武器卡片展示，不承担战斗朝向语义，可保持中性朝向。
2. 远程武器的 `projectile` 必须以“向右”为基础朝向制作，默认贴图应让弹体头部或尖端朝右。
3. 远程武器在运行时根据目标方向旋转或镜像，`projectile` 只保留一个标准朝向即可。
4. 近战武器的命中特效 `effect` 以“玩家中心 + 面向方向”来制作，建议使用右向半圆/弧形刀光作为标准帧。
5. 近战武器实际伤害判定可用以玩家为中心的圆形/扇形范围，但视觉表现应与朝向一致，敌人在玩家前方被刀光覆盖。
6. 范围伤害武器的 `props/effect` 以“玩家中心 + 完整圆形/扩散环”为标准，不要求方向性。
7. 近战与远程武器若需要单独的世界表现图，也统一以右向为基准，左向由 Godot 镜像或旋转实现。
8. 所有战斗向素材都应在单一文件里定义清晰的标准朝向，避免同一资源库里混用左右朝向作为基础图。

## 17. 待确认设计点

以下内容暂不阻塞本模块 MVP 实施，后续进入完整战斗闭环前再确认。

1. 神秘伤害规则：当前暂不设定，后续如需要再通过特殊效果注册器补充。
2. 战斗边界来源：投射物碰到边界消失，但边界由战斗循环模块或地图模块提供。
3. 超载失败后的 UI 表现：购买时不允许购买；替换弹窗如后续需要，由 UI/武器替换流程处理。

## 18. 已确认规则汇总

1. MVP 只做“能加载、能升级、能算伤害”。
2. 负载必须强校验；购买新武器后若超过负载上限，则不允许购买。
3. 近战武器和范围武器都以玩家当前位置为中心计算范围。
4. 近战、范围、远程武器的基础命中/影响半径都写入 `weapons.json` 的 `hit_radius`，所有攻击范围加成只使用 `area_size`。
5. 远程投射物速度写入 `weapons.json` 的 `projectile_speed`。
6. 投射物生命周期不配置，命中后穿透耗尽或碰到边界时消失。
7. `pierce_count = 1` 表示额外穿透 1 个敌人，总共可命中 2 个敌人。
8. 多投射物采用散射，散射总角度写入 `weapons.json` 的 `spread_angle`。
9. 暴击随机使用 Godot 普通全局随机。
10. 混伤武器拆成近战段和远程段两个伤害数字。
11. `use_cooldown_reduction_only = true` 表示该武器只吃冷却缩减，不吃攻速加成。
12. `weapon_type` 的 `light`、`medium`、`heavy` 只用于负载展示和 UI 分类。
13. 武器升级来自局内商店或升级选项，不依赖额外配置解锁条件。
14. 神秘伤害暂不设定。
15. `WeaponAnchor` 只用于远程发射点和美术挂点。
16. 新武器不允许重复获得；已拥有武器不再进入新武器候选池。
17. 武器升级选项与遗物共用六档稀有度，但使用升级项自身的稀有度，不读取武器本体稀有度。
18. 商店只提供新武器、遗物和已装备武器的下一等级升级项，不提供单独属性购买。
19. 同一轮商店中，同一把武器的同一级升级项最多出现一次。
20. 免费商店和付费商店共用同一套候选池和刷新规则。

## 19. 商店候选与升级稀有度

1. 新武器候选从已解锁且玩家尚未拥有的武器构建；负载不足不移出候选池，只在购买/装备时拒绝，并通过剩余负载比例降低新武器类型权重。
2. 武器升级候选从已装备且未满级的武器构建，只生成当前等级的下一等级升级项。
3. 武器升级稀有度写在对应 `level_upgrades` 条目中，与遗物和武器本体共用 `common/uncommon/rare/epic/mythic/legendary` 六档体系。
4. 当前三把武器的升级稀有度约定为：2 级绿、3 级蓝、4 级紫、5 级橙；后续武器可以使用普通或传说升级。
5. 商店生成器负责同轮去重，不能返回相同武器的相同目标等级升级项。
