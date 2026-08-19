# Godot 验收总清单

> 目标：把 `docs/main/checklist/` 下所有实施清单，连同 `docs/main/godot_manual_scene_setup_checklist.md`，整理成一份可以在 Godot 电脑上直接照着执行的总验收文档。  
> 验收顺序固定为：`bootstrap.tscn` → `game_root.tscn` → 各模块场景/UI/手工排布。  
> 说明：已完成模块只保留最关键结果；未完成模块按“在 Godot 里做什么 / 预期看到什么 / 如何判定通过”来写。

## 1. 总体顺序

1. 先运行 `scenes/core/bootstrap.tscn`，确认所有模块自检通过。  
2. 再运行 `scenes/core/game_root.tscn`，确认主场景树、Autoload、主流程协调器与 UI 根节点接通。  
3. 然后按模块逐个检查 scene、UI、营地、战斗、区域、存档等手工搭建项。  
4. 最后补齐缺失素材后，再回头复测对应模块。

### 当前验收进度

- [x] 第 1 步：`scenes/core/bootstrap.tscn` 已运行验证，用户确认无问题。
- [x] 第 2 步：`scenes/core/game_root.tscn` 已运行验证，用户确认无问题。
- [x] 第 3 步：玩家、武器、敌人、经验球、血包、波次管理器和召唤物场景已完成结构、素材、碰撞及运行时验证，用户确认无问题。
- [x] 第 4 步：营地场景与建筑位排布验证，已运行确认无问题。
- [ ] 第 5 步：UI 场景与交互流程验证。
- [ ] 第 6 步：完整战斗流程验证。
- [ ] 第 7 步：存档与设置持久化验证。

## 2. 已完成项：只看结果

这些模块已经完成核心编码，Godot 电脑上主要看启动结果，不需要再重复设计：

- `1-base_data_implementation_checklist.md`：基础数值、配置校验、`ModifierStack`、`DataRegistry`、基础公式已闭环。  
- `2-engineering_foundation_implementation_checklist.md`：工程基础设施、自检入口、Autoload、主根场景框架已具备。  
- `4-weapon_loadout_implementation_checklist.md`：武器加载、升级、索敌、伤害计算、负载校验已接入。  
- `6-enemy_wave_implementation_checklist.md`：敌人与波次的核心逻辑已接入，等待实机验证。  
- `9-drop_reward_implementation_checklist.md`：掉落表、经验球、局内金币同步、共享奖励/商店候选池已接入。  
- `10-audio_atmosphere_implementation_checklist.md`：音频管理与音量持久化已接入。  
- `11-save_progress_implementation_checklist.md`：存档与本地进度已接入。  
- `12-run_combat_loop_implementation_checklist.md`：主流程协调器、战斗循环、结算顺序、胜负页已接入。  
- `14-engineering_foundation_implementation_checklist.md`：工程基础设施主场景骨架已接入。  
- `15-summon_ally_implementation_checklist.md`：召唤物主链路已接入。

这些模块的共同判定标准：

- 启动后没有 `validation errors`。  
- 对应自检项输出 `passed`。  
- 没有新的脚本报错、节点找不到、资源丢失。

## 3. 第一步：先验 `bootstrap.tscn`

### 你在 Godot 里要做什么

1. 打开项目根目录下的 `project.godot`。  
2. 直接运行 `scenes/core/bootstrap.tscn`。  
3. 打开 Output 面板，看控制台输出。  
4. 先不要手动点其他 scene，先确认启动自检是否完整。

### 你应该看到什么

控制台应至少出现这些分组：

- `config load summary`  
- `data self-test started`  
- `modifier stack checks`  
- `relic bond checks`  
- `player checks`  
- `weapon checks`  
- `enemy wave checks`  
- `summon checks`  
- `camp meta progression checks`  
- `zone streak fortune checks`  
- `zone ui checks`  
- `audio checks`  
- `ui flow checks`  
- `main flow checks`

### 如何判定通过

- 每组下面的子项都输出 `passed`。  
- 最后能看到 `validation warnings: 0`。  
- 最后能看到 `validation errors: 0`。  
- 最终输出 `data self-test passed`。

### 失败时怎么判断

- 如果是 `validation errors`，先回对应 JSON / 资源 / 脚本。  
- 如果是 `failed`，直接看那一行的检查名，再回对应模块。  
- 如果是节点找不到，优先检查 scene 节点名和脚本绑定。  
- 如果是资源丢失，先补资源，不要先改逻辑。

## 4. 第二步：再验 `game_root.tscn`

### 你在 Godot 里要做什么

1. 打开并运行 `scenes/core/game_root.tscn`。  
2. 确认这是正式主场景入口。  
3. 查看场景树里是否有这些节点：`CoreRoot`、`WorldRoot`、`UiRoot`、`DebugRoot`。  
4. 观察 `MainFlowCoordinator` 是否挂在 `CoreRoot` 下。  
5. 观察 `ZoneUIController` 是否挂在 `UiRoot` 下。

### 你应该看到什么

- 主场景不报错。  
- 运行后场景树结构完整。  
- UI 根层、世界层、调试层都存在。  
- 主流程协调器能正常初始化。

### 如何判定通过

- `GameRoot` 能正常实例化。  
- `MainFlowCoordinator` 存在。  
- `ZoneUIController` 存在。  
- 没有运行时报错。

## 5. 各模块逐项验收

### 5.1 基础数值与数据配置

这部分通常只需要看 `bootstrap.tscn` 输出。

你要确认：
- `DataRegistry` 能读完所有配置表。  
- `attack_speed=100`、`armor=100`、`area_size=40`、`finance=101 interest_rate=5` 这些公式检查正确。
- `modifier stack` 的加法、百分比、覆盖规则正确。  
- 没有任何验证错误。

通过标准：
- 基础公式输出与设计一致。  
- 配置表数量与预期一致。  
- 无 `validation errors`。

### 5.2 工程基础设施

关注点：`scenes/core/game_root.tscn`、`scenes/core/debug_root.tscn`、`project.godot` 主入口。

你要确认：
- `project.godot` 的主场景指向 `game_root.tscn`。  
- `GameRoot` 下确实有 `CoreRoot`、`WorldRoot`、`UiRoot`、`DebugRoot`。  
- `bootstrap.tscn` 仍然保留，用作最小自检入口。

通过标准：
- 主入口切换正确。  
- Root 节点层级正确。  
- 不影响后续模块挂接。

### 5.3 玩家与角色

当前状态：已完成 Godot 场景与运行验证；正式素材、节点结构、碰撞和拾取范围均已确认无问题。

关注场景：`scenes/player/player_root.tscn`。

你要在 Godot 里做什么：
1. 打开场景，确认根节点是 `CharacterBody2D`。  
2. 确认有 `VisualAnchor`、`VisualAnchor/Sprite2D`、`PickupArea/CollisionShape2D`、`WeaponAnchor`、`Camera2D`。  
3. 把正式角色图挂到 `Sprite2D.texture`。  
4. 检查角色朝向、尺寸、拾取范围、碰撞体大小。  
5. 运行自检，看角色初始属性和开局武器是否正确。

预期：
- 角色能正确实例化。  
- 初始属性能从角色配置加载。  
- 开局武器 ID 列表能同步。  
- 角色图像和碰撞没有明显错位。

通过标准：
- `player checks` 全部 `passed`。  
- 场景节点存在且命名正确。  
- 运行中不报错。

### 5.4 局内武器

关注场景：`scenes/weapons/weapon_loadout.tscn`。

你要在 Godot 里做什么：
1. 打开场景，确认有 `TargetingService`。  
2. 验证武器配置能正确加载。  
3. 验证武器升级、索敌、负载、攻击间隔、范围、投射物速度、散射角都生效。  
4. 检查 `weapon checks` 输出。

预期：
- 三把武器能被初始化。  
- 武器升级能推动数值变化。  
- 负载超限时购买失败。  
- 远程、近战、范围武器的命中逻辑能按配置工作。

通过标准：
- `weapon checks` 全部 `passed`。  
- 没有配置字段缺失。  
- 没有重复购买同一把新武器。

### 5.5 局内遗物与羁绊

当前主要看控制台和后续 UI。

你要确认：
- `relics.json`、`bonds.json` 能被读取。  
- 同名遗物受 `max_stack` 控制。  
- 武器标签 + 遗物标签能一起统计羁绊。  
- 羁绊阈值生效。  
- 特殊效果暂时只记录，不要求执行。

通过标准：
- `relic bond checks` 输出通过。  
- 遗物上限和羁绊统计不冲突。  
- 商店不再刷出超过上限的遗物。

### 5.6 敌人与波次

关注场景：`scenes/enemy/mutated_grub.tscn`、`scenes/pickups/exp_orb.tscn`、`scenes/waves/wave_manager.tscn`。

你要在 Godot 里做什么：
1. 打开敌人场景，确认根节点、碰撞体、精灵都正常。  
2. 打开经验球场景，确认可拾取区域正常。  
3. 打开波次管理器，确认 `EnemyRoot`、`PickupRoot`、`SummonRoot` 存在。  
4. 在运行中确认敌人会追踪、碰撞、弹开、掉经验球。

预期：
- 敌人能生成并追踪。  
- 波次计时正常。  
- 经验球能统一吸取和结算。  
- 波次结束后场上敌人清空。

通过标准：
- `enemy wave checks` 全部 `passed`。  
- 没有刷怪区域或碰撞报错。

### 5.7 局外营地与成长

当前状态：已完成营地场景运行验证；配置加载正常，7 个建筑位生成正常，建筑位节点结构和显示结果无问题。

关注场景：`scenes/camp/camp_root.tscn`、`scenes/camp/camp_building_slot.tscn`。

你要在 Godot 里做什么：
1. 打开营地主场景，先确认背景层、装饰层、建筑层存在。  
2. 按需要把大草地、河流、树木、石头、花草、篝火摆进去。  
3. 打开建筑位场景，确认废墟 / 正式建筑 / 初始自带建筑的显示切换。  
4. 确认 7 个建筑入口位置合适。

预期：
- 未解锁建筑显示废墟。  
- 初始自带建筑直接显示正式图。  
- 建筑层不压住背景。  
- 场景能支持后续新增建筑。

通过标准：
- `camp meta progression checks` 通过。  
- 7 个建筑位正常显示。
- 选择和解锁逻辑不乱。

### 5.8 UI 交互

关注场景：`scenes/ui/zones/zone_ui_controller.tscn`、`scenes/ui/zones/zone_select_popup.tscn`、`scenes/ui/zones/zone_harvest_result_popup.tscn`、`scenes/ui/zones/zone_select_card.tscn`、`scenes/ui/rewards/reward_option.tscn`。

你要在 Godot 里做什么：
1. 确认 `UiRoot` 下的分层存在。  
2. 确认区域选择弹窗、收割结果弹窗、奖励/商店候选卡都能实例化。  
3. 观察按钮文字、稀有度边框、卡片布局。  
4. 后续再补 HUD、失败弹窗、营地详情面板。

预期：
- UI 层不互相遮挡。  
- 弹窗能开能关。  
- 候选卡能复用同一 prefab。  
- 共享奖励页和商店页共享同一套候选项。

通过标准：
- `zone ui checks` 和 `ui flow checks` 通过。  
- 运行中能看到正确的弹窗层级。

### 5.9 音频与氛围

当前核心只验证音频管理器和音量保存。

你要确认：
- `AudioManager` 能初始化。  
- BGM / SFX 音量能持久化。  
- 缺失音频资源时会有 fallback，而不是崩溃。

通过标准：
- `audio checks` 通过。  
- 保存和重启后音量不丢。

### 5.10 存档与本地进度

你要确认：
- 只保存局外进度。  
- 只有一个存档槽 `profile_01`。  
- 存档能写入和读回。  
- 音量设置会跟着存档走。  
- 不会保存战斗过程。

通过标准：
- `save` 相关自检通过。  
- 重启后局外货币、建筑等级、升级项等级能读回。

### 5.11 局内战斗循环与主流程

关注场景：`scenes/core/main_flow_coordinator.tscn`、`scenes/core/game_root.tscn`。

你要在 Godot 里做什么：
1. 运行主流程，确认状态机能从启动页进入角色选择。  
2. 确认第一波开始、战斗中升级、波次结束、经验吸收、补升级、利息、商店、理财、区域选择的顺序正确。  
3. 确认 `battle_result` 只是简单胜负页。  
4. 确认战斗、营地、区服流程能切换。

预期：
- 主流程能串起来。  
- 波次结束后的固定顺序不乱。  
- Boss 波、事件波以后仍可复用同一状态机。

通过标准：
- `main flow checks` 通过。  
- 场景之间切换正常。  
- 没有状态卡死。

### 5.12 区域驻守与福缘

关注场景：`scenes/ui/zones/zone_ui_controller.tscn` 及 `ZoneProgression`。

你要确认：
- 第 1 波不选区。  
- 第 2 波开始前第一次选区。  
- 理财后进入下一波前进行区域选择。  
- 连驻层数能持续累积。  
- 切区会触发收割。  
- 福缘、区域压力、商店偏向能联动。

通过标准：
- `zone streak fortune checks` 通过。  
- 区域切换和收割结果能弹出。  
- 连驻和 debuff 不会乱清。

### 5.13 召唤物与友方实体

关注场景：`scenes/summons/summon_root.tscn`、`scenes/summons/summon_unit.tscn`。

你要确认：
- 召唤物根场景能实例化。  
- 召唤物会绑定玩家。  
- 召唤物会追踪最近敌人。  
- 召唤物数量上限裁剪正常。  
- 波次结束会清理召唤物。

通过标准：
- `summon checks` 通过。  
- 召唤物和敌人交互正常。

## 6. 手工场景搭建总表

这部分来自 `docs/main/godot_manual_scene_setup_checklist.md`，现在统一并入总验收文档。

### 6.1 必先看

- `scenes/core/bootstrap.tscn`：只做自检，不摆美术。  
- `scenes/core/game_root.tscn`：主根场景。  
- `scenes/core/main_flow_coordinator.tscn`：主流程协调器。  
- `scenes/ui/zones/zone_ui_controller.tscn`：区域 UI 根。

### 6.2 必手工

- `scenes/player/player_root.tscn`：替换正式角色图，微调碰撞和拾取。  
- `scenes/weapons/weapon_loadout.tscn`：只看逻辑容器，不摆美术。  
- `scenes/enemy/mutated_grub.tscn`：替换敌人图，调整朝向和碰撞。  
- `scenes/pickups/exp_orb.tscn`：替换经验球图，确认拾取范围。  
- `scenes/waves/wave_manager.tscn`：确认敌人根、掉落根、召唤根都在。  
- `scenes/camp/camp_root.tscn`：搭背景、树木、石头、花草、篝火。  
- `scenes/camp/camp_building_slot.tscn`：确认废墟 / 建筑切换。  
- `scenes/ui/zones/zone_select_popup.tscn`：区域选择页。  
- `scenes/ui/zones/zone_harvest_result_popup.tscn`：收割结果页。  
- `scenes/ui/rewards/reward_option.tscn`：奖励 / 商店候选卡。

## 7. 最后判定

一轮 Godot 验收结束后，只要同时满足下面三条，就可以认为当前阶段通过：

1. `bootstrap.tscn` 所有自检通过。  
2. `game_root.tscn` 主流程和场景树正常。  
3. 本轮手工调整的 scene 没有新增报错，且视觉/交互结果符合预期。

## 8. 模块实施清单汇总
> 以下内容汇总各模块实施清单，作为 Godot 验证与后续回溯的补充参考。

### 1-base_data_implementation_checklist.md
# 基础数值与数据配置模块实施清单

本文档用于跟踪“基础数值与数据配置模块”的工程实施进度。该模块已完成结项，当前作为冻结参考版保留，后续仅在需要回溯设计或补充说明时再更新。

## 总体目标

1. 建立统一配置入口 `DataRegistry`。
2. 建立统一属性计算入口 `ModifierStack`。
3. 建立通用属性表与护甲/人性/神性等基础数值规则。
4. 建立最小 JSON 配置表与基础校验能力。
5. 建立一个测试场景或测试脚本验证数据加载和属性计算。

## 进度状态说明

| 状态 | 含义 |
| ---- | ---- |
| 未开始 | 尚未执行 |
| 进行中 | 正在实施 |
| 已完成 | 已完成并通过基础检查 |
| 暂缓 | 当前阶段不做，后续再补 |

## 实施清单总览

| 步骤 | 任务 | 状态 | 产出 |
| ---- | ---- | ---- | ---- |
| 1 | 搭建工程目录 | 已完成 | `autoloads/`、`scripts/data/`、`scripts/modifiers/`、`data_config/` 等目录 |
| 2 | 编写基础属性定义 | 已完成 | `scripts/data/stat_definitions.gd` |
| 3 | 编写 modifier 数据结构 | 已完成 | `scripts/modifiers/modifier.gd` |
| 4 | 编写 ModifierStack | 已完成 | `scripts/modifiers/modifier_stack.gd` |
| 5 | 编写 DataRegistry | 已完成 | `autoloads/data_registry.gd`，已注册 Autoload |
| 6 | 编写最小配置表 | 已完成 | `data_config/*.json`，已完成当前确认版配置 |
| 7 | 编写最小校验器 | 已完成 | `scripts/data/data_validator.gd` |
| 8 | 加入跨表引用校验 | 已完成 | ID引用校验规则与 `scripts/data/unlock_registry.gd` |
| 9 | 创建测试场景/脚本 | 已完成 | 复用 `scenes/core/bootstrap.tscn` 与 `scripts/core/bootstrap.gd` |
| 10 | 准备占位素材 | 已完成 | `assets/ui/icons/placeholder_icon.png` |
| 11 | 验收基础模块 | 已完成 | 启动加载、查询、modifier计算、错误提示全部可用 |

## 结项说明

1. 基础数值与数据配置模块已通过 Godot 启动自检。
2. `DataRegistry`、`DataValidator`、`ModifierStack`、`bootstrap.tscn` 的最小闭环已可用。
3. 本文档后续默认冻结，仅作为实施记录和回溯依据。
4. 如后续出现基础规则大改，再单独开新版本实施清单，不直接覆盖当前结项版。

## 第 1 步：搭建工程目录

### 目标

建立基础数据模块后续代码与配置需要的目录结构。

### 需要创建

```text
res://
├─ autoloads/
├─ scripts/
│ ├─ data/
│ └─ modifiers/
├─ data_config/
│ └─ schemas/
├─ scenes/
│ └─ core/
└─ assets/
  └─ ui/
    └─ icons/
```

### 验收标准

1. 上述目录均存在。
2. 不覆盖已有 Godot 项目文件。
3. 暂不创建正式 GDScript 代码。
4. 暂不创建正式素材文件。

## 第 2 步：编写基础属性定义

### 目标

定义全项目统一属性ID、默认值、上下限、显示名称与护甲减伤函数。

### 文件

`res://scripts/data/stat_definitions.gd`

### 必须包含的属性

1. 生存：`max_hp`、`hp_regen`、`shield`、`revive_count`、`on_kill_heal`、`armor`、`damage_taken_percent`
2. 移动：`move_speed`
3. 攻击：`melee_damage`、`ranged_damage`、`summon_damage`、`damage_percent`、`attack_speed`
4. 暴击：`crit_chance`、`crit_damage`
5. 投射物：`projectile_count`、`pierce_count`
6. 范围与控制：`area_size`、`control_power`
7. 掉落与成长：`pickup_radius`、`exp_gain_percent`、`drop_rate_percent`、`luck`、`currency_gain_percent`、`finance`、`interest_rate`、`shop_price_percent`
8. 构筑：`load_capacity`
9. 召唤：`summon_count`
10. 波次：`enemy_spawn_rate_percent`
11. 精神/外神：`humanity`、`divinity`

### 验收标准

1. 所有属性ID可通过函数校验是否合法。
2. 每个属性有默认值、最小值、最大值。
3. 护甲可以换算为整数受到伤害百分比。
4. 护甲减伤不会达到100%。

## 第 3 步：编写 modifier 数据结构

### 目标

定义单个 modifier 的字段、初始化、基础校验和复制能力。

### 文件

`res://scripts/modifiers/modifier.gd`

### 必须字段

`id`、`source_type`、`source_id`、`target_scope`、`stat`、`operation`、`value`、`duration`、`stack_rule`、`priority`、`tags`

### 验收标准

1. 可以从 Dictionary 创建 modifier。
2. 可以导出为 Dictionary。
3. 能校验必填字段。
4. 能判断是否为永久 modifier。

## 第 4 步：编写 ModifierStack

### 目标

统一管理属性叠加、持续时间、来源移除和最终属性计算。

### 文件

`res://scripts/modifiers/modifier_stack.gd`

### 必须支持

1. `add_flat`
2. `add_percent`
3. `multiply`
4. `override`
5. `min_cap`
6. `max_cap`
7. `unique`
8. `replace_same_source`
9. `stack_add`
10. `refresh_duration`

### 验收标准

1. 可以添加、移除、按来源移除 modifier。
2. 可以计算最终属性。
3. 可以更新持续时间并移除过期 modifier。
4. 可以输出某个属性的来源链。

## 第 5 步：编写 DataRegistry

### 目标

集中加载、缓存、查询所有配置表。

### 文件

`res://autoloads/data_registry.gd`

### 必须支持

1. 启动加载配置。
2. 按ID查询配置。
3. 查询全部配置。
4. 按tag筛选配置。
5. 发出 `data_ready` 信号。
6. 失败时给出错误列表。

### 验收标准

1. Godot启动时能作为 Autoload 加载。
2. 业务模块不需要知道 JSON 文件路径。
3. 找不到配置时有明确错误。

## 第 6 步：编写最小配置表

### 目标

提供可用于测试加载和查询的最小数据。

### 文件

1. `data_config/weapons.json`
2. `data_config/relics.json`
3. `data_config/bonds.json`
4. `data_config/characters.json`
5. `data_config/enemies.json`
7. `data_config/camp_buildings.json`
8. `data_config/waves.json`
9. `data_config/drop_tables.json`

### 验收标准

1. 每个文件至少有1条测试数据。
2. 所有记录都有稳定ID。
3. 跨表引用都能找到目标。

## 第 7 步：编写最小校验器

### 目标

在启动时发现配置错误，避免运行中才崩溃。

### 文件

`res://scripts/data/data_validator.gd`

### MVP校验项

1. 必填字段存在。
2. ID不重复。
3. 属性ID合法。
4. modifier operation 合法。
5. modifier stack_rule 合法。
6. 跨表引用存在。

## 第 8 步：加入跨表引用校验

### 目标

保证配置表之间引用关系正确。

### 必须校验

1. `characters.start_weapons -> weapons.id`
2. `relics.bond_id -> bonds.id`
3. `enemies.drop_table_id -> drop_tables.id`
4. `waves.spawn_groups.enemy_id -> enemies.id`
5. `camp_buildings.levels.*.unlock -> 解锁ID注册表`
6. `camp_buildings.unlock_condition.building / camp_buildings.unlock_condition.currency`
7. `camp_buildings.upgrade_options.required_building_level` 为正整数。

## 第 9 步：创建测试场景/脚本

### 目标

用一个最小测试场景验证基础模块可用。

### 文件

1. `scenes/core/bootstrap.tscn`
2. `scripts/core/bootstrap.gd`

说明：当前不再额外创建 `data_test_scene.tscn`，直接复用项目主启动场景 `bootstrap.tscn` 执行数据自检。

### 验收标准

1. 启动后打印配置加载数量。
2. 能查询测试角色、武器、遗物、羁绊、敌人、掉落表、波次。
3. 能输出 `attack_speed=100`、`armor=100`、`area_size=40`、`finance=101 interest_rate=5` 的公式检查。
4. 能打印 `DataRegistry` 的 warnings/errors。
5. 能输出 `ModifierStack` 实例计算与 `debug_stat()` 来源链测试。

## 第 10 步：准备占位素材

### 目标

为配置图标和调试UI提供兜底素材。

### 文件

`assets/ui/icons/placeholder_icon.png`

### 说明

该步骤已完成，当前已提供 `res://assets/ui/icons/placeholder_icon.png` 作为所有缺失图标的兜底资源。正式素材清单见 `docs/asset/base_data_asset_checklist.md`。

## 第 11 步：验收基础模块

### 验收标准

1. 游戏启动时 `DataRegistry` 能成功加载 MVP 配置表。
2. 配置错误时能输出明确错误。
3. 可以通过 ID 查询任意测试配置。
4. 可以计算角色最终属性。
5. 护甲能正确换算减伤，且不会达到100%减伤。
6. modifier 能按来源添加、替换、移除。
7. `debug_stat()` 能输出属性来源链。
8. 后续新增武器、遗物、羁绊、营地建筑时，不需要修改基础数据模块核心逻辑。

## 换机 Godot 验证步骤

当切换到安装了 Godot 的电脑后，按以下顺序验证基础数据模块。

### 1. 打开项目

1. 使用 Godot 4 打开项目根目录。
2. 确认主场景为 `res://scenes/core/bootstrap.tscn`。
3. 确认 Autoload 中存在 `DataRegistry="*res://autoloads/data_registry.gd"`。

### 2. 运行启动自检

1. 直接运行项目或运行 `scenes/core/bootstrap.tscn`。
2. 打开 Godot 控制台输出。
3. 确认出现 `[Bootstrap] data self-test started`。
4. 确认每张配置表都有记录数输出：`weapons`、`relics`、`bonds`、`characters`、`enemies`、`camp_buildings`、`waves`、`drop_tables`。
5. 确认输出 `[Bootstrap] data self-test passed`。

### 3. 检查公式输出

控制台应能看到以下类型输出：

1. `attack_speed=100: 1.00s -> 0.50s`。
2. `armor=100: damage_taken_percent=...`，具体数值由护甲函数决定，但必须大于最低承伤下限。
3. `area_size=40: radius 100 -> 140`。
4. `finance=101 interest_rate=5: gain 6`。

### 4. 检查错误提示

可临时复制一个配置错误进行验证，验证后务必还原：

1. 将 `data_config/waves.json` 中某条 `enemy_id` 临时改成不存在的 ID。
2. 重新运行项目。
3. 控制台应输出指向 `waves.*.spawn_groups.*.enemy_id` 的 invalid reference 错误。
4. 还原 `enemy_id`，再次运行项目，应恢复 `data self-test passed`。

### 5. 后续补充验证

1. 增加 `ModifierStack` 实例计算测试。
2. 增加 `debug_stat()` 来源链输出测试。
3. 在新增武器、遗物、羁绊、营地建筑后，优先运行 `bootstrap.tscn` 确认配置未破坏。

## 当前进度提醒

当前状态：基础数值与数据配置模块已结项，本文档已冻结为参考版。

下一步建议：进入“最小局内闭环”模块，优先实现玩家移动、敌人追踪、基础武器自动攻击、敌人死亡掉落与经验拾取。






### 10-audio_atmosphere_implementation_checklist.md
# 音频与氛围表现模块实施 Checklist

本文档记录第 10 模块的实施事项。整体设计保持极简，只实现三类 BGM、武器命中音效和基础音量控制。

## 1. 当前状态

模块设计已完成，核心编码已完成，等待 Godot 环境验证和音频资源接入。

## 2. 已确认规则

1. 不制作玩家攻击、敌人死亡、拾取、升级、波次和 UI 操作音效。
2. 不制作环境氛围音和稀有度提示音。
3. 敌人受击音效绑定到具体武器。
4. 近战和范围武器每次攻击最多播放一次命中音效。
5. 远程武器每个投射物最多播放一次命中音效。
6. 穿透投射物后续命中不重复播放。
7. 缺少音频素材时静默降级。

## 3. 配置任务

- [x] 在武器 schema 中增加可选字段 `hit_sfx`
- [x] 在 `weapons.json` 的三把武器中配置命中音效路径
- [x] 更新数据校验器，允许并校验 `hit_sfx` 字符串路径
- [x] 更新武器配置字段文档

## 4. 编码任务

- [x] 新建全局音频管理器脚本 `autoloads/audio_manager.gd`
- [x] 接入 `master/bgm/sfx` 音量分组
- [x] 实现菜单、营地和战斗 BGM 切换
- [x] 实现武器命中音效资源读取
- [x] 近战和范围攻击命中后一次攻击只请求一次音效
- [x] 远程投射物记录自身是否已播放命中音效
- [x] 为同一帧大量远程命中增加轻量并发限制
- [x] 缺失音频资源时静默返回
- [x] 在 Bootstrap 中加入音频模块自测

## 5. 不实施事项

- [x] 玩家攻击音效
- [x] 敌人死亡音效
- [x] 经验球和血包拾取音效
- [x] 角色升级音效
- [x] 波次开始和结束音效
- [x] UI 确认、取消和错误音效
- [x] 环境氛围音
- [x] 稀有度提示音
- [x] 复杂分轨和动态混音

## 6. 建议自测输出

```text
[Bootstrap] audio checks
[Bootstrap] - audio manager initialize: passed
[Bootstrap] - bgm switch: passed
[Bootstrap] - weapon hit sfx lookup: passed
[Bootstrap] - melee hit sfx once: passed
[Bootstrap] - area hit sfx once: passed
[Bootstrap] - projectile hit sfx once: passed
[Bootstrap] - missing audio silent fallback: passed
```

## 7. 结项判断

1. 三类 BGM 可以正常切换。
2. 三把武器可以读取各自的命中音效路径。
3. 近战和范围攻击不会按命中敌人数重复播放。
4. 每个远程投射物最多播放一次。
5. 音频缺失时不报致命错误。


### 11-save_progress_implementation_checklist.md
# 存档与本地进度模块实施清单

本清单对应 `11-save_progress_design.md`。当前模块已完成核心编码，本文档主要用于收口、验收和后续复查。

## 1. 当前状态

- [x] 已确认只保留局外进度存档。
- [x] 已确认当前仅使用一个存档槽 `profile_01`。
- [x] 已确认不保存战斗过程、中途退出继续本局、`void_shards`、`settlement_id` 等字段。
- [x] 已完成 `CampProgression` 读写、迁移、备份、原子写盘。
- [x] 已完成音量设置持久化。
- [x] 已在 `bootstrap` 中加入存档自检。

## 2. 已完成的编码项

- [x] 注册 `CampProgression` 为 Autoload。
- [x] 注册 `AudioManager` 为 Autoload。
- [x] 存档路径统一为 `user://saves/profile_01.json`。
- [x] 备份路径统一为 `user://saves/profile_01.backup.json`。
- [x] 临时写入路径统一为 `user://saves/profile_01.tmp.json`。
- [x] 存档结构仅保留 `currencies.camp_currency`、`building_levels`、`upgrade_levels`、`settings`。
- [x] 支持旧存档 `user://camp_progression.json` 迁移。
- [x] 保存时自动写入备份文件，降低异常中断风险。
- [x] 音量设置会随存档加载与保存自动同步。

## 3. 待验证项

- [ ] 在具备 Godot 的电脑上启动项目，确认无报错。
- [ ] 确认能正常生成 `profile_01.json`。
- [ ] 确认重启后能正确读取 `camp_currency`、`building_levels`、`upgrade_levels`、`settings`。
- [ ] 确认音量设置修改后可以持久化。
- [ ] 确认旧存档迁移流程可用。
- [ ] 确认战斗中不会写入正式存档。
- [ ] 确认仅在死亡或通关后的结算阶段触发正式保存。

## 4. 结项标准

- [ ] 单槽存档行为正确。
- [ ] 仅保留局外进度字段。
- [ ] 音量设置可读写。
- [ ] 旧存档可迁移。
- [ ] 战斗中不落盘，战斗结束后才正式写入。


### 12-run_combat_loop_implementation_checklist.md
# 局内战斗循环与主流程编排模块实施清单

> 当前没有可用 Godot 环境，实机验证暂缓；后续拿到 Godot 电脑后按“待验证项”逐条执行。

本清单对应 `12-run_combat_loop_design.md`。本模块已完成核心协调器代码落地，当前主要剩余 Godot 运行验证与后续扩展校验。

## 1. 当前状态

- [x] 已确认本模块由场景脚本承载，不做全局 Autoload。
- [x] 已确认第一波直接开战；第 2 波起波次结束顺序固定为：吸收经验 -> 补共享奖励/商店页 -> 利息 -> 商店 -> 理财 -> 区域选择。
- [x] 已确认 `battle_result` 只做简单胜负页。
- [x] 已确认未来 Boss 波、事件波继续复用同一套状态机。
- [x] 已完成 `MainFlowCoordinator` 场景脚本与对应场景文件。
- [x] 已接入 `bootstrap` 自测。
- [x] 已兼容旧 `free_shop_requested` 信号，并对重复共享奖励/商店页请求做去重。

## 2. 已完成的编码项

- [x] 新增 `scripts/core/main_flow_coordinator.gd`。
- [x] 新增 `scenes/core/main_flow_coordinator.tscn`。
- [x] 新增 `scripts/core/main_flow_coordinator.gd.uid`。
- [x] 主流程状态机已包含启动页、角色选择、战斗准备、波次战斗、共享奖励/商店页、波次收尾、利息结算、商店、理财、区域选择、福缘收割结果、战斗结果、营地入口。
- [x] 支持绑定 `PlayerController`、`WeaponLoadout`、`WaveManager`。
- [x] 支持角色确认后初始化初始武器。
- [x] 支持战斗中共享奖励/商店页与波次结束后的共享奖励/商店补弹窗。
- [x] 支持第一波跳过理财直接开战；第 2 波起支持波次结束后顺序推进到利息、商店、理财、区域选择和下一波准备。
- [x] 支持死亡后进入简单战斗结果页。
- [x] 支持营地流程入口切换。
- [x] 在 `bootstrap.gd` 中加入主流程自测。

## 3. 待验证项

- [ ] 在具备 Godot 的电脑上运行项目，确认 `bootstrap` 控制台输出包含 `[Bootstrap] main flow checks`。
- [ ] 确认主流程自测各项检查均通过。
- [ ] 确认战斗中升级会进入共享奖励/商店页。
- [ ] 确认第一波直接开战，且第 2 波起波次结束后顺序能依次推进到共享奖励/商店、利息、商店、理财、区域选择。
- [ ] 确认简单战斗结果页可返回启动页。
- [ ] 确认营地入口状态可正常切换。
- [ ] 确认后续 Boss 波与事件波可以复用同一套状态机。

## 4. 结项标准

- [ ] 启动页、战斗流、营地流三者可按设计稳定切换。
- [ ] 共享奖励/商店页、商店页、理财页、区域选择页、结果页的顺序不乱。
- [ ] 战斗结束后再做结果处理，不在战斗过程中正式落盘。
- [ ] 相关自测输出稳定无误。


### 13-zone_streak_fortune_implementation_checklist.md
# 13-区域驻守与福缘收割模块实施清单

> 当前已完成核心代码接入；本机暂无 Godot 可执行环境，启动验证留给具备 Godot 的电脑执行。

> 该模块先暂缓收口，后续回到具备 Godot 的电脑时再继续按待办逐条验证。

本清单对应 `docs/main/13-zone_streak_fortune_design.md`。本模块采用 `ZoneProgression` 全局 Autoload + `MainFlowCoordinator` 主流程编排的组合方式，负责区域选择、连驻、福缘积累、切区收割、区域压力与商店偏向。

## 1. 当前完成项

- [x] 新增 `data_config/zones.json`，并加入 3 个 MVP 区域。
- [x] 新增 `autoloads/zone_progression.gd`，记录当前区域、连驻层数、福缘储备与收割结果。
- [x] 将 `zones` 表接入 `DataRegistry` 加载与 `DataValidator` 校验。
- [x] 将区域压力接入敌人生成与玩家临时状态加成。
- [x] 将区域偏向接入商店候选池与商店权重。
- [x] 统一输出区域运行时上下文与收割上下文，供后续模块复用。
- [x] 将区域选择、收割结果与战斗主流程接线到 `MainFlowCoordinator`。
- [x] 将 `ZoneProgression` 注册为 Autoload，并纳入启动自检。
- [x] 在 `bootstrap.gd` 中补充区域相关自测。

## 2. 代码侧待确认

- [ ] 在 Godot 电脑上启动项目，确认控制台输出包含 `zone streak fortune checks`。
- [ ] 确认第一次选区发生在第 1 波结束后、第 2 波开始前。
- [ ] 确认连续选择同一区域时，玩家 debuff 会正确叠加。
- [ ] 确认切换区域时，旧区域 debuff 会被清理，收割结果会弹出。
- [ ] 确认区域偏向会影响商店候选池与刷新权重。
- [ ] 确认死亡/通关时区域状态会按单局态重置。

## 3. 验收标准

- [ ] `DataRegistry` 启动时能输出 `zones` 表数量。
- [ ] `bootstrap` 自检通过，且区域自测项全部通过。
- [ ] `MainFlowCoordinator` 第一波直接开战；第 2 波起波次结束顺序保持为：吸收经验 -> 补升级 -> 利息 -> 商店 -> 理财 -> 区域选择。
- [ ] `ZoneProgression` 在换区时正确生成收割 payload，并在确认后清空待处理状态。
- [ ] 区域压力与商店偏向只作为运行时上下文，不直接改静态配置表。

## 4. UI / 场景骨架待补

- [x] 在 `UiRoot` 下补齐 `HUDLayer`、`PopupLayer`、`FadeLayer` 分层。
- [x] 创建 `zone_select_popup.tscn`，用于显示 3 个区域卡和确认按钮。
- [x] 创建区域卡组件 `ZoneSelectCard`，优先复用 `reward_option.tscn` 的卡片风格。
- [x] 创建 `zone_harvest_result_popup.tscn`，用于展示换区后的收割结果。
- [x] 创建轻量 `zone_ui_controller.gd`，监听 `MainFlowCoordinator.modal_requested / modal_closed`。
- [x] 已移除 `ZoneUIController` 内联区域调试面板，正式流程只保留区域选择与收割结果 UI。
- [x] UI 先用 `PanelContainer + StyleBoxFlat` 占位，不新增区域专属美术。

## 5. 后续扩展

- [ ] 后续新增区域时，只补 `zones.json` 与对应运行时压力配置。
- [ ] 后续新增区域事件波、Boss 波时，复用现有状态机与区域上下文。
- [ ] 如果后续要做更复杂的区域表现，再补专属 UI 与美术素材。






### 14-engineering_foundation_implementation_checklist.md
# 工程基础设施模块实施 Checklist

本文记录 `第 14 模块：工程基础设施` 的落地状态。该模块只负责项目运行骨架，不承载具体玩法。

## 1. 当前状态

- [x] 创建正式运行根场景 `scenes/core/game_root.tscn`
- [x] 创建可选调试根场景 `scenes/core/debug_root.tscn`
- [x] 保持 `scenes/core/bootstrap.tscn` 作为最小自检入口
- [x] 将 `project.godot` 的主入口切换到 `game_root.tscn`
- [x] 让 `GameRoot` 统一管理 `CoreRoot`、`WorldRoot`、`UiRoot`、`DebugRoot`
- [x] 保持 `MainFlowCoordinator` 作为主流程容器，由 `GameRoot` 承载
- [x] 在 `bootstrap.gd` 中补充 `GameRoot` / `DebugRoot` 场景可加载自检

## 2. 还需验证

- [ ] 在有 Godot 的电脑上运行项目，确认无 Autoload 报错
- [ ] 运行 `bootstrap.tscn`，确认工程根场景自检输出正常
- [ ] 运行正式主场景，确认 `GameRoot` 可以正常生成容器节点
- [ ] 确认后续模块可以直接把实体、UI、调试面板挂到对应容器

## 3. 后续扩展接口

- [ ] 战斗实体优先挂到 `WorldRoot`
- [ ] UI 界面优先挂到 `UiRoot`
- [ ] 临时调试节点优先挂到 `DebugRoot`
- [ ] 后续如需独立调试入口，可直接复用 `scenes/core/debug_root.tscn`

## 4. 结项条件

本模块在代码层的结项条件是：根场景可加载、主入口可切换、基础容器可复用、自检可输出。


### 15-summon_ally_implementation_checklist.md
# 15-召唤物与友方实体模块实施清单

> 当前已完成 MVP 代码接入；本机暂无 Godot 运行环境，启动验证留给具备 Godot 的电脑执行。

本清单对应 `docs/main/15-summon_ally_design.md`。本模块当前目标是：能生成、能跟随、能索敌、能攻击、能清理。

## 1. 当前完成项

- [x] 新增召唤物详细设计文档：`docs/main/15-summon_ally_design.md`
- [x] 新增召唤物实体脚本：`scripts/summons/summon_controller.gd`
- [x] 新增召唤物管理根脚本：`scripts/summons/summon_root.gd`
- [x] 新增召唤物实体场景：`scenes/summons/summon_unit.tscn`
- [x] 新增召唤物管理根场景：`scenes/summons/summon_root.tscn`
- [x] 在 `scenes/waves/wave_manager.tscn` 中接入 `SummonRoot`
- [x] 在 `scripts/waves/wave_manager.gd` 中接入召唤物生成、批量生成和清理接口
- [x] 在 `scripts/core/main_flow_coordinator.gd` 的战斗解绑阶段调用 `clear_battle_entities()`
- [x] 在 `scripts/core/bootstrap.gd` 中增加召唤物控制台自测
- [x] 新增召唤物素材清单：`docs/asset/15-summon_ally_asset_checklist.md`

## 2. 当前代码能力

- [x] 召唤物绑定玩家 `owner_player`
- [x] 召唤物加入 `summons` 和 `friendly_entities` 分组
- [x] 召唤物默认环形跟随玩家
- [x] 召唤物复用 `TargetingService` 查找最近敌人
- [x] 召唤物在攻击半径内对敌人调用 `take_damage()`
- [x] 召唤物读取 `summon_damage`、`damage_percent`、`attack_speed`、暴击和范围加成
- [x] `summon_count` 作为额外召唤数量参与批量生成
- [x] `SummonRoot.hard_cap` 裁剪最大召唤数量
- [x] 波次结束和战斗重置会清理召唤物

## 3. 待 Godot 验证项

- [x] 启动 `scenes/core/bootstrap.tscn`
- [x] 确认控制台出现 `[Bootstrap] summon checks`
- [x] 确认 `summon test scene instantiate` 输出 `passed`
- [x] 确认 `summon root initialize` 输出 `passed`
- [x] 确认 `summon count bonus` 输出 `passed`
- [x] 确认 `summon inherited damage` 输出 `passed`
- [x] 确认 `summon attack enemy` 输出 `passed`
- [x] 确认 `summon hard cap` 输出 `passed`
- [x] 确认 `summon clear battle entities` 输出 `passed`
- [x] 确认最终没有新增 `validation errors`

## 4. 预期控制台片段

```text
[Bootstrap] summon checks
[Bootstrap] - summon test scene instantiate: passed
[Bootstrap] - summon root initialize: passed
[Bootstrap] - summon count bonus: passed
[Bootstrap] - summon inherited damage: passed
[Bootstrap] - summon attack enemy: passed
[Bootstrap] - summon hard cap: passed
[Bootstrap] - summon clear battle entities: passed
```

## 5. 后续非阻塞项

- [ ] 在具备 Godot 的电脑上补召唤物素材后，给 `summon_unit.tscn` 的 `Sprite2D` 绑定正式图片
- [ ] 若后续召唤物类型增多，新增 `data_config/summons.json` 并接入 `DataRegistry`
- [ ] 召唤类武器确定后，由武器模块调用 `WaveManager.spawn_summons()`
- [ ] 遗物或羁绊特殊效果执行器完成后，再调用 `WaveManager.spawn_summons()`
- [ ] 营地 `run_start_random_summon` 触发器完成后，再调用 `WaveManager.spawn_default_summons()` 或随机召唤池
- [ ] 若需要召唤物可受击，后续给敌人 AI 增加友方实体目标选择
- [ ] 若需要展示召唤物状态，后续在 HUD 增加召唤物数量或简化图标

## 6. 结项判断

1. Bootstrap 召唤物自测全部通过。
2. 召唤物能生成并对敌人造成伤害。
3. `summon_damage` 与 `summon_count` 的运行效果符合设计。
4. 波次结束和战斗重置不会残留召唤物。
5. 缺少召唤物美术素材时，不影响核心逻辑运行。


### 2-engineering_foundation_implementation_checklist.md
# 工程基础设施模块实施 Checklist

本文档记录“工程基础设施模块”实施状态。该模块目标是提供稳定的工程入口、全局状态、启动自检承载能力，不直接承载玩法规则。

## 1. 当前状态

模块 MVP 已完成，当前可作为后续模块的稳定基础设施。

## 2. 已完成事项

- [x] 注册 `DataRegistry` Autoload
- [x] 注册 `GameGlobal` Autoload
- [x] 注册 `ObjectPool` Autoload
- [x] 建立 `scenes/core/bootstrap.tscn` 作为启动入口
- [x] 建立 `scripts/core/bootstrap.gd` 启动自测脚本
- [x] 支持基础数据模块自测输出
- [x] 支持后续模块追加 Bootstrap 自测
- [x] 保持工程基础设施与具体玩法逻辑解耦

## 3. 待你验证事项

- [x] 在 Godot 中启动项目，确认 Autoload 无报错
- [x] 确认 Bootstrap 能正常输出各模块自测结果

## 4. 后续非阻塞事项

- [ ] 根据模块增长拆分更细的测试场景
- [ ] 接入正式主菜单后，再决定是否保留 Bootstrap 为开发入口

## 5. 结项判断

本模块的结项条件是：

1. 项目启动无 Autoload 报错。
2. Bootstrap 自测能正常执行。
3. 后续模块可以通过 Bootstrap 追加自测，不需要修改工程入口结构。



### 3-player_character_implementation_checklist.md
# 玩家与角色模块实施 Checklist

本文档记录“玩家与角色模块”当前实施状态、待验证事项与后续非阻塞事项。

## 1. 当前状态

模块 MVP 代码已完成，除正式素材替换与 Godot 启动验证外，可视为待验收状态。

## 2. 已完成事项

- [x] 新增玩家根场景：`scenes/player/player_root.tscn`
- [x] 新增玩家控制脚本：`scripts/player/player_controller.gd`
- [x] 从 `characters.json` 初始化角色基础属性
- [x] 接入 `ModifierStack`，支持局外、局内、临时 modifier 扩展
- [x] 预留角色被动加载入口：`passive_modifiers`
- [x] 读取并保存开局武器 ID 列表
- [x] 实现键盘移动控制
- [x] 实现左右朝向翻转
- [x] 实现生命、护盾、护甲减伤、受击、短暂无敌与死亡信号
- [x] 实现 `PickupArea` 拾取范围同步
- [x] 在 `bootstrap.gd` 中加入玩家初始化与受击自测
- [x] 更新玩家与角色模块设计文档实现状态

## 3. 待你完成事项

- [x] 在 Godot 中启动项目，确认控制台出现 `[Bootstrap] player checks`
- [x] 确认玩家相关自测全部输出 `passed`
- [ ] 生成正式玩家右向基础精灵图
- [ ] 生成正式玩家右向行走 spritesheet
- [ ] 生成角色图标，并在角色选择页面复用该图标
- [ ] 将正式素材放入素材清单指定路径
- [ ] 需要时告知我更新素材清单中的“是否存在/状态”字段

## 4. Godot 启动验证标准

启动项目后，控制台至少应看到以下内容：

```text
[Bootstrap] player checks
[Bootstrap] - player scene instantiate: passed
[Bootstrap] - player initialize character: passed
[Bootstrap] - player max_hp: passed
[Bootstrap] - player move_speed: passed
[Bootstrap] - player start weapons: passed
[Bootstrap] - player pickup radius: passed
[Bootstrap] - player armor damage: passed
[Bootstrap] - player extra revive: passed
```

若以上全部通过，本模块可正式标记为 MVP 结项。

## 5. 后续非阻塞事项

- [ ] 接入正式动画状态机
- [ ] 接入角色选择 UI
- [ ] 接入营地到战斗的数据流转
- [ ] 接入拾取物吸附与结算
- [ ] 接入武器实例化与挂载
- [ ] 扩展复杂角色被动效果注册器

## 6. 结项判断

本模块的结项条件是：

1. Godot 启动自测全部通过。
2. 正式或临时玩家素材可被 Godot 正常导入。
3. 后续武器、敌人、掉落模块可以通过玩家公开接口读取属性与位置。


### 4-weapon_loadout_implementation_checklist.md
# 局内武器模块实施 Checklist

本文档记录“局内武器模块”MVP 实施状态。当前目标只覆盖：能加载、能升级、能算伤害、能强校验负载。

## 1. 当前状态

模块 MVP 代码已完成，等待 Godot 启动验证。

## 2. 已完成事项

- [x] 新增武器运行实例：`scripts/weapons/weapon_instance.gd`
- [x] 新增武器负载管理器：`scripts/weapons/weapon_loadout.gd`
- [x] 新增伤害事件对象：`scripts/weapons/damage_event.gd`
- [x] 新增最近敌人索敌服务占位：`scripts/weapons/targeting_service.gd`
- [x] 新增武器管理场景：`scenes/weapons/weapon_loadout.tscn`
- [x] 支持从玩家开局武器 ID 初始化武器
- [x] 支持装备与购买时负载强校验
- [x] 支持购买新武器超载失败
- [x] 支持武器升级并应用 `stat` 与 `attack_interval_ms`
- [x] 支持 `attack_speed` 攻击间隔计算
- [x] 支持近战、远程、混伤拆段伤害计算
- [x] 支持 `hit_radius` 基础半径、`area_size` 最终范围加成、`projectile_speed`、`spread_angle` 运行字段读取
- [x] 在 `bootstrap.gd` 中加入武器模块自测

## 3. 待你验证事项

- [x] 在 Godot 中启动项目，确认控制台出现 `[Bootstrap] weapon checks`
- [x] 确认武器相关自测全部输出 `passed`
- [ ] 若出现配置校验错误，先反馈控制台完整错误信息

## 4. Godot 启动验证标准

启动项目后，控制台至少应看到以下内容：

```text
[Bootstrap] weapon checks
[Bootstrap] - weapon test scene instantiate: passed
[Bootstrap] - weapon loadout initialize: passed
[Bootstrap] - weapon load cost: passed
[Bootstrap] - weapon config runtime fields: passed
[Bootstrap] - weapon area_size radius: passed
[Bootstrap] - weapon attack interval base: passed
[Bootstrap] - weapon attack_speed interval: passed
[Bootstrap] - weapon upgrade: passed
[Bootstrap] - weapon damage event: passed
[Bootstrap] - weapon mixed damage split: passed
[Bootstrap] - weapon purchase load limit: passed
```

## 5. 后续非阻塞事项

- [ ] 接入真实敌人查询与受击接口
- [ ] 接入投射物场景与边界销毁
- [ ] 接入近战/范围命中判定
- [ ] 接入武器商店 UI
- [ ] 接入武器升级选项 UI
- [ ] 接入武器特效与音效

## 6. 结项判断

本模块 MVP 的结项条件是：

1. Godot 启动自测全部通过。
2. 默认武器能从玩家开局武器列表初始化。
3. 武器升级、伤害计算、负载校验结果符合设计文档。


### 5-relic_bond_implementation_checklist.md
# 局内遗物与羁绊模块实施 Checklist

本文档记录“局内遗物与羁绊模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能读取 `relics.json` 与 `bonds.json`
- [ ] 能记录局内遗物持有数量
- [ ] 能按 `max_stack` 限制同名遗物刷新
- [ ] 能统计武器 + 遗物标签
- [ ] 能计算羁绊层数并应用阈值效果
- [ ] 能把遗物效果与羁绊效果提交到 `ModifierStack`
- [ ] 能在 `bootstrap.gd` 中打印自测结果

## 3. 待确认规则

1. 羁绊统计范围：武器标签 + 遗物标签。
2. 同名遗物允许重复获得，受 `max_stack` 限制。
3. 当前阶段不做解锁、装填、互斥切换。
4. 特殊效果只记录，不执行。

## 4. 建议自测输出

```text
[Bootstrap] relic bond checks
[Bootstrap] - relic config load: passed
[Bootstrap] - relic max_stack limit: passed
[Bootstrap] - relic add modifier: passed
[Bootstrap] - bond tag count: passed
[Bootstrap] - bond threshold apply: passed
[Bootstrap] - special effects reserved: passed
```

## 5. 后续非阻塞项

- [ ] 遗物选择 UI 复用 `scenes/ui/rewards/reward_option.tscn`
- [ ] 图鉴界面
- [ ] 稀有度权重系统
- [ ] 特殊效果执行器
- [ ] 羁绊界面预览

## 6. 结项判断

本模块可正式结项的条件是：

1. Godot 启动后能读取遗物与羁绊配置。
2. 能正确限制同名遗物最大数量。
3. 能正确统计标签并生效羁绊。
4. 能正确输出自测结果。


### 6-enemy_wave_implementation_checklist.md
# 敌人与波次模块实施 Checklist

本文档记录“敌人与波次模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块 MVP 编码已完成，等待在 Godot 中启动验证控制台输出。

## 2. 实施目标

- [x] 能读取 `enemies.json` 与 `waves.json`
- [x] 能实例化敌人场景
- [x] 能按 `duration_seconds` 单波计时刷怪
- [x] 能在玩家周围 1000~1500 范围内生成敌人
- [x] 能处理敌人追踪玩家
- [x] 能处理敌人一次碰撞伤害与弹开
- [x] 能处理敌人受击与死亡
- [x] 能在敌人死亡时引用掉落表并掉落经验球
- [x] 能在波次结束后统一吸取经验球并清场
- [x] 能在角色升级时触发一次共享奖励/商店页事件
- [x] 能在 `bootstrap.gd` 中打印自测结果

## 3. 已确认规则

1. 目前只做普通怪。
2. 波次不使用 `time_start/time_end`，改为每波独立 `duration_seconds`。
3. 波次时间使用 `min(15 + 5 * wave_index, 50)`，第 1 波为 20 秒，最高 50 秒。
4. 刷怪区域在玩家周围 1000~1500 距离环内。
5. 波次结束后清空场上敌人。
6. 敌人碰撞玩家后立刻弹开；敌人与玩家拉开距离后重置碰撞状态，之后可再次造成一次独立碰撞伤害。
7. 敌人死亡后掉落经验球，拾取后获得经验和等额基础金币。
8. 波次结束后统一吸取并结算场上所有经验球。
9. 达到升级条件后立即触发一次无须花费的商店购买。
10. 复杂精英/Boss 机制暂不做。

## 4. Godot 验证步骤

1. 使用 Godot 打开项目并运行 `bootstrap.tscn`。
2. 确认控制台出现下方自测输出。
3. 若 `validation errors` 或敌人与波次检查出现 failed，则先暂停后续模块，回到本模块修复。

## 5. 建议自测输出

```text
[Bootstrap] enemy wave checks
[Bootstrap] - enemy wave test scene instantiate: passed
[Bootstrap] - enemy config load: passed
[Bootstrap] - wave config load: passed
[Bootstrap] - wave duration formula: passed
[Bootstrap] - enemy instantiate: passed
[Bootstrap] - enemy contact damage knockback: passed
[Bootstrap] - enemy damage and death: passed
[Bootstrap] - enemy kill heal: passed
[Bootstrap] - enemy spawn rate: passed
[Bootstrap] - enemy drop table link: passed
[Bootstrap] - wave collect exp orbs: passed
[Bootstrap] - shared reward/shop trigger: passed
```

## 6. 后续非阻塞项

- [ ] 精英怪词缀
- [ ] Boss 阶段技
- [ ] 寻路系统
- [ ] 屏幕外休眠

## 7. 结项判断

本模块可正式结项的条件是：

1. Godot 启动后能读取敌人和波次配置。
2. 能按波次持续刷出敌人。
3. 敌人能朝玩家移动并受击死亡。
4. 敌人死亡后能正确关联掉落表。
5. 控制台能输出自测通过结果。


### 7-camp_meta_progression_implementation_checklist.md
# 局外营地与成长模块实施 Checklist

本文档记录“局外营地与成长模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能读取 `camp_buildings.json`
- [ ] 能读取营地存档中的建筑等级与升级项等级
- [ ] 能在营地主界面展示 7 个建筑入口
- [ ] 能按解锁状态在“废墟 / 正式建筑”之间切换
- [ ] 能展示建筑等级效果与升级项列表
- [ ] 能购买局外升级项并写回存档
- [ ] 能把建筑升级效果转换为运行时属性或解锁状态
- [ ] 能把战斗结算结果回流到营地资源
- [ ] 能在 `bootstrap.gd` 中打印自测结果

## 3. 已确认规则

1. 营地采用固定场景，不做自由摆放。
2. 建筑只使用双态显示：未解锁显示废墟，已解锁显示正式建筑。
3. 营地建筑分为“建筑等级型”和“升级选项型”两类。
4. 建筑升级项只负责定义规则，当前购买等级写入存档。
5. 建筑升级项的属性必须对应 `StatDefinitions` 中已有字段。
6. 后续若新增建筑，只需补配置、补素材、补场景节点，不需要重写整套流程。

## 4. 建议自测输出

```text
[Bootstrap] camp meta progression checks
[Bootstrap] - camp config load: passed
[Bootstrap] - camp save load: passed
[Bootstrap] - camp ruins/unlocked swap: passed
[Bootstrap] - camp building levels: passed
[Bootstrap] - camp upgrade options: passed
[Bootstrap] - camp modifier sync: passed
[Bootstrap] - camp unlock sync: passed
```

## 5. 后续非阻塞项

- [ ] 营地主界面布局美化
- [ ] 建筑进入动画
- [ ] 建筑升级提示弹窗
- [ ] 局外资源统计面板
- [ ] 结算奖励回流提示

## 6. 结项判断

本模块可正式结项的条件是：

1. Godot 启动后能读取营地建筑配置与存档。
2. 营地里能按解锁状态切换废墟和正式建筑。
3. 能查看和购买建筑升级项。
4. 建筑升级效果能正确进入运行时数值或解锁状态。
5. 控制台能输出自测通过结果。


### 8-ui_flow_implementation_checklist.md
# UI 交互模块实施 Checklist

本文档记录“UI 交互模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能显示战斗 HUD
- [ ] 能显示共享奖励/商店页
- [x] 能实例化共享奖励 / 商店候选项 `reward_option.tscn`
- [ ] 能显示武器购买失败提示
- [ ] 能显示营地主界面
- [ ] 能显示建筑详情面板
- [ ] 能切换战斗 / 营地 / 共享奖励/商店 UI
- [ ] 能通过信号刷新 HUD
- [ ] 能在 `bootstrap.gd` 中打印 UI 自测结果
- [x] 能在 `bootstrap.gd` 中自测奖励选项按钮文案

## 3. 已确认规则

1. UI 只读状态，不直接修改战斗规则。
2. 弹窗互斥，不叠加多层模态。
3. 战斗层和局外层分离。
4. 升级、购买、波次结束都通过 UI 事件驱动。
5. 商店只提供新武器、遗物和武器升级，不提供单独属性购买。
6. 新武器不可重复获得；负载不足时仍可刷新，但购买必须失败并提示原因。
7. 免费奖励入口和付费商店入口共用同一套候选池、稀有度权重、类型权重和去重规则。
8. 同一轮商店不得重复出现同一把武器的同一级升级项。
9. 通用弹窗底板和奖励/商店页底板优先使用 Godot `PanelContainer` + `StyleBoxFlat`，不依赖单独底板 PNG。
10. 奖励选项统一使用 `scenes/ui/rewards/reward_option.tscn`，通过文本区分 `武器升级`、`新武器`、`遗物`。
11. 奖励选项通过边框颜色区分稀有度；免费入口按钮显示“选择”，商店入口按钮显示具体花费金额。

## 4. 商店实现范围

- [ ] 构建新武器、遗物、武器升级三类候选池
- [ ] 实现 `luck` 到六档稀有度权重的转换
- [ ] 实现剩余负载对新武器类型权重的修正
- [ ] 实现武器升级未出现时的权重积累与出现后清零
- [ ] 实现同一轮武器升级选项去重
- [ ] 免费奖励页与商店复用同一刷新服务
- [ ] 过滤已拥有武器和达到 `max_stack` 的遗物
- [x] 奖励选项 prefab 支持免费 / 商店两种按钮文案
- [x] 奖励选项 prefab 支持稀有度边框颜色
- [x] 奖励选项 prefab 不依赖独立卡底 PNG

## 5. 建议自测输出

```text
[Bootstrap] ui flow checks
[Bootstrap] - hud scene instantiate: passed
[Bootstrap] - shared reward/shop page open/close: passed
[Bootstrap] - reward option scene instantiate: passed
[Bootstrap] - reward option free button text: passed
[Bootstrap] - reward option shop button text: passed
[Bootstrap] - camp ui open/close: passed
[Bootstrap] - signal binding refresh: passed
```

## 6. 后续非阻塞项

- [ ] 过渡动画
- [ ] 图鉴分页
- [ ] 多语言
- [ ] UI 主题皮肤
- [ ] 高级拖拽交互

## 7. 结项判断

本模块可正式结项的条件是：

1. 战斗和营地界面能正常切换。
2. HUD 和弹窗能正确响应业务信号。
3. 控制台能输出自测通过结果。

## 8. 下一模块

- [ ] 第 10 模块：音频与氛围表现


### 9-drop_reward_implementation_checklist.md
# 9-掉落与奖励模块实施清单

> 当前已完成核心代码接入；本机暂无 Godot 可执行环境，启动验证留给具备 Godot 的电脑执行。

本清单对应 `docs/main/9-drop_reward_design.md`。本模块负责掉落表、经验球、局内金币、血包、波次结束吸取、共享奖励/商店候选与奖励快照。

## 1. 当前完成项

- [x] 配置 `data_config/drop_tables.json`，包含小怪、精英怪、Boss 三类基准掉落。
- [x] 普通怪掉落规则：1 经验、不掉落遗物、5% 血包。
- [x] 精英怪掉落规则：2 经验、5% 遗物、20% 血包。
- [x] Boss 掉落规则：10 经验、100% 遗物。
- [x] 经验球拾取时同时获得等量局内金币，并分别吃经验加成与局内货币加成。
- [x] 百分比掉落按 `drop_rate_percent` 计算最终概率。
- [x] 新增 `DropRewardSystem` 与 `RewardSnapshot`，统一处理掉落生成和奖励统计。
- [x] 新增经验球、血包拾取物脚本与基础场景。
- [x] 波次结束时统一吸取场上经验球并清理奖励拾取物。
- [x] 共享奖励/商店候选生成接入 `ShopOfferGenerator`，候选池支持新武器、遗物、武器升级。
- [x] `bootstrap.gd` 已通过敌人与波次、武器/商店相关自检覆盖本模块核心逻辑。

## 2. 待 Godot 验证

- [ ] 启动 `bootstrap.tscn`，确认控制台中 `enemy wave checks` 和 `shared reward/shop pool generation` 均通过。
- [ ] 在测试战斗中击杀小怪，确认能掉落经验球，拾取后经验和金币同时增加。
- [ ] 波次结束后，确认未拾取的经验球会被统一吸取并结算。
- [ ] 确认血包可生成、可拾取，并正确恢复生命。
- [ ] 确认商店候选只包含新武器、遗物、武器升级，不出现单独属性购买。
- [ ] 确认达到 `max_stack` 的遗物不会继续进入候选池。

## 3. 后续非阻塞项

- [ ] 精英怪和 Boss 的真实敌人配置接入后，复测对应掉落表。
- [ ] 区域福缘收割后，将 `gold_gain`、额外候选和定向倾向转为更明确的奖励表现。
- [ ] 若后续加入材料、钥匙、事件道具，沿 `DropRewardSystem` 增加新 `type`。
- [ ] 若需要结算页统计，扩展 `RewardSnapshot` 的击杀、掉落和构筑字段。

## 4. 结项判断

1. 小怪、精英怪、Boss 的基准掉落符合设计。
2. 经验球能同时结算经验和金币。
3. 波次结束能统一吸取经验球。
4. 共享奖励/商店候选能稳定生成并去重。
5. 缺少美术资源时不影响核心逻辑运行。
