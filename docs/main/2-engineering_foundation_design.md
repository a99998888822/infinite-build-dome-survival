# 工程基础设施模块详细设计方案

本文档定义项目的工程骨架、目录规范、Autoload 边界、调试入口和模块通信方式。它不承载具体玩法逻辑，而是为后续玩家、敌人、武器、掉落、营地等模块提供稳定底座。

## 1. 模块目标

1. 统一 Godot 工程目录与命名规范。
2. 统一全局入口、调试入口和最小运行流程。
3. 统一场景、脚本、数据和信号的组织方式。
4. 为局内模块提供可复用的实体基类和通信约定。
5. 降低后续模块联调成本，避免“先写玩法再补底座”的返工。

## 2. 模块边界

工程基础设施模块只负责“如何组织工程和运行时骨架”，不负责具体玩法规则。

### 包含内容

1. 目录结构与文件命名。
2. Autoload 规划。
3. Bootstrap 启动入口。
4. 全局调试与测试入口。
5. 基础信号与事件总线的使用边界。

### 不包含内容

1. 玩家移动与战斗表现。
2. 敌人 AI 与波次生成。
3. 武器自动攻击与伤害结算。
4. 掉落、经验、遗物、羁绊、营地建筑的规则实现。
5. UI 业务逻辑和美术资源本体。

## 3. 工程目录约定

建议保持以下目录结构：

```text
res://
├─ autoloads/
├─ data_config/
├─ docs/
├─ scenes/
│  ├─ core/
│  ├─ player/
│  ├─ enemy/
│  ├─ weapon/
│  ├─ reward/
│  ├─ camp/
│  └─ ui/
├─ scripts/
│  ├─ core/
│  ├─ data/
│  ├─ modifiers/
│  ├─ player/
│  ├─ enemy/
│  ├─ weapon/
│  ├─ reward/
│  ├─ camp/
│  └─ ui/
└─ assets/
   ├─ ui/
   ├─ sprites/
   ├─ audio/
   └─ font/
```

### 目录使用原则

1. `scenes/` 只放场景资源与节点组合。
2. `scripts/` 只放逻辑脚本。
3. `data_config/` 只放静态配置表。
4. `assets/` 只放美术、音频、字体等资源。
5. `docs/` 只放设计、清单与实施记录。

## 4. 命名规范

### 4.1 工程与文件名

1. 项目工程名使用 `kebab-case`。
2. Godot 场景名和脚本名尽量使用 `snake_case`。
3. 配置表 `id` 使用稳定、可读、可搜索的 `snake_case`。
4. 常量名使用 `UPPER_SNAKE_CASE`。

### 4.2 推荐命名格式

1. 场景：`bootstrap.tscn`、`player_root.tscn`、`enemy_basic.tscn`
2. 脚本：`bootstrap.gd`、`player_controller.gd`、`enemy_ai.gd`
3. 配置：`weapon_void_blade`、`relic_flying_teeth`、`camp_armory_workshop`

### 4.3 命名约束

1. 运行时类名与配置 `id` 不强绑定，避免重命名带来联动风险。
2. 场景名优先表达职责，不优先表达美术实现。
3. 资源路径和配置 `id` 保持稳定，不轻易改动。

## 5. Autoload 规划

建议最小 Autoload 集合如下：

| 名称 | 路径 | 职责 |
| ---- | ---- | ---- |
| `DataRegistry` | `res://autoloads/data_registry.gd` | 统一配置加载、查询与校验 |
| `GameGlobal` | 后续补充 | 局内外通用状态、调试开关、全局事件 |

### 当前状态

1. `DataRegistry` 已落地并接入启动流程。
2. 其余 Autoload 先在设计层预留，不急于一次性全建。

## 6. 启动入口设计

项目当前使用 `scenes/core/bootstrap.tscn` 作为最小运行入口。

### 启动职责

1. 初始化基础服务。
2. 触发 `DataRegistry.reload_all()`。
3. 输出配置加载与校验结果。
4. 可选执行自检逻辑，如 modifier 计算、引用查询、公式验证。

### 启动原则

1. Bootstrap 只做初始化和自检，不承载业务玩法。
2. 任何后续模块都应能在 `bootstrap` 下独立运行自检。
3. 调试失败时，优先在控制台定位，不依赖 UI 提示。

## 7. 场景分层约定

### 7.1 顶层场景建议

1. `scenes/core/bootstrap.tscn`：最小启动与自检。
2. `scenes/core/game_root.tscn`：正式运行根场景。
3. `scenes/core/debug_root.tscn`：仅用于调试和联机/数值测试。

### 7.2 局内实体建议

1. `player_root.tscn`：玩家实体根节点。
2. `enemy_root.tscn`：敌人实体根节点。
3. `weapon_root.tscn`：武器或武器管理器根节点。
4. `drop_root.tscn`：经验球、金币、血包等掉落物根节点。
5. `summon_root.tscn`：召唤物与友方实体根节点。

### 7.3 场景层次原则

1. 根节点只做职责分派，不堆业务逻辑。
2. 子节点尽量按“输入、逻辑、表现”分层。
3. 可复用实体优先做成独立场景，不直接写死在管理器脚本里。

## 8. 信号与事件边界

### 8.1 推荐通信方式

1. 同层实体之间优先使用信号。
2. 管理器到实体优先使用方法调用或事件广播。
3. 数据层到玩法层通过查询接口，不直接互相持有场景引用。

### 8.2 推荐信号类型

1. `entity_died`
2. `exp_collected`
3. `weapon_fired`
4. `damage_taken`
5. `upgrade_selected`
6. `wave_started`
7. `wave_finished`

### 8.3 边界原则

1. 数据校验层不反向依赖具体玩法场景。
2. 业务模块不直接读取 JSON 文件路径。
3. UI 只订阅状态变化，不直接写核心规则。

## 9. 调试与测试入口

### 当前调试入口

项目当前已复用 `bootstrap.tscn` 作为基础数据自检入口。

### 后续建议

1. 预留一个独立调试场景入口，用于性能与战斗逻辑测试。
2. 预留控制台命令或调试按钮，用于刷怪、加资源、查看属性来源。
3. 自检脚本统一输出可读日志，避免只靠断点定位问题。

## 10. 与基础数据模块的关系

1. 工程基础设施模块为 `DataRegistry`、`DataValidator`、`ModifierStack` 提供运行环境。
2. `DataRegistry` 负责数据，`ModifierStack` 负责数值，工程基础设施负责组织它们如何启动和协作。
3. 后续所有模块都应遵循本模块定义的目录、命名、Autoload 和通信约定。

## 11. MVP落地建议

工程基础设施模块的 MVP 只需要做到以下几点：

1. `bootstrap.tscn` 能稳定启动。
2. `DataRegistry` 能加载并校验配置。
3. 控制台能看到清晰的自检输出。
4. 项目目录和命名规范已统一。
5. 后续实体、掉落、武器、敌人模块能直接复用约定。

## 12. 验收标准

1. 工程目录稳定，无明显职责混乱。
2. `bootstrap.tscn` 能作为统一调试入口。
3. 后续模块可按目录直接落文件，不需要重新讨论工程骨架。
4. `DataRegistry`、调试入口、场景分层的边界清晰。
5. 新增模块时，不需要修改已冻结的工程规范文档。

