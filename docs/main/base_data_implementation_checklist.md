# 基础数值与数据配置模块实施清单

本文档用于跟踪“基础数值与数据配置模块”的工程实施进度。该模块的目标是先完成数据底座，而不是制作正式美术、音频或完整战斗场景。

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
| 10 | 准备占位素材 | 暂缓 | `assets/ui/icons/placeholder_icon.png`，可后置 |
| 11 | 验收基础模块 | 未开始 | 启动加载、查询、modifier计算、错误提示全部可用 |

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

1. 生存：`max_hp`、`hp_regen`、`shield`、`armor`、`damage_taken_percent`
2. 移动：`move_speed`
3. 攻击：`melee_damage`、`ranged_damage`、`summon_damage`、`damage_percent`、`attack_speed`、`cooldown_reduction`
4. 暴击：`crit_chance`、`crit_damage`
5. 投射物：`projectile_count`、`pierce_count`
6. 范围与控制：`area_size`、`duration_percent`、`slow_percent`、`control_power`
7. 掉落与成长：`pickup_radius`、`exp_gain_percent`、`drop_rate_percent`、`luck`、`currency_gain_percent`
8. 构筑：`load_capacity`
9. 召唤：`summon_count`
10. 精神/外神：`humanity`、`divinity`

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
6. `camp_buildings.unlock_condition.building -> camp_buildings.id`
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
3. 能输出 `attack_speed=100`、`cooldown_reduction=40`、`armor=100` 的公式检查。
4. 能打印 `DataRegistry` 的 warnings/errors。
5. `ModifierStack` 实例计算与 `debug_stat()` 来源链测试后续补充。

## 第 10 步：准备占位素材

### 目标

为配置图标和调试UI提供兜底素材。

### 文件

`assets/ui/icons/placeholder_icon.png`

### 说明

该步骤暂缓，不阻塞基础数值模块开发。正式素材清单见 `docs/asset/base_data_asset_checklist.md`。

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
2. `cooldown_reduction=40: 10.00s -> 6.00s`。
3. `armor=100: damage_taken_percent=...`，具体数值由护甲函数决定，但必须大于最低承伤下限。

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

当前已完成：第 9 步核心测试入口，已复用 `bootstrap.tscn` 输出基础数据自检。

下一步建议：补充 `ModifierStack` 实例计算测试与 `debug_stat()` 来源链输出测试，然后在有 Godot 的电脑上执行“换机 Godot 验证步骤”。









