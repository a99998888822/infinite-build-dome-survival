# 工程入口与维护

项目使用 Godot 4、GDScript 和 UTF-8 文本资源。正式启动场景为 [game_root.tscn](../../scenes/core/game_root.tscn)，启动自检为 [bootstrap.tscn](../../scenes/core/bootstrap.tscn)。

| 目录 | 职责 |
| --- | --- |
| `autoloads/` | 数据注册、局外进度、全局状态、音频、语言、窗口与操作设置 |
| `scripts/core/` | 主流程编排 |
| `scripts/battle/`、`scripts/waves/`、`scripts/enemies/` | 战斗场景、波次与敌人 |
| `scripts/weapons/`、`scripts/effects/` | 武器施放、命中、状态与表现 |
| `scripts/ui/` | 战斗 HUD、奖励、理财、设置等界面 |
| `data_config/` | 运行配置及审阅配置，见[字段与维护说明](../../data_config/README.md) |
| `assets/`、`shaders/` | 正式资源与着色器 |
| `scripts/tests/`、`scenes/tests/` | 专项测试代码与可运行场景 |
| `scripts/tools/` | 素材检查、录制与其他维护工具 |

Autoload 的实际列表由 [project.godot](../../project.godot)维护，包含 `L10n`、`DataRegistry`、`GameGlobal`、`CampProgression`、`AudioManager`、`WindowSettings`、`CombatSettings`、`EnemyRegistry`、`EffectScheduler` 和 `CombatHitFeedback`。

## 验证入口

先定位本机 Godot 可执行文件，在项目根目录运行：

```text
<Godot> --headless --editor --path . --quit
<Godot> --headless --path . --scene res://scenes/core/bootstrap.tscn --quit-after 120
<Godot> --headless --path . --scene res://scenes/core/game_root.tscn --quit-after 120
```

行为变更还需运行对应专项场景，检查解析、脚本错误及测试断言。GPU 录制使用 [后台工具说明](../../scripts/tools/BACKGROUND_CAPTURE.md)指定的私有桌面流程，核对实际引擎桌面与 `foreground_samples=0`。

新文本使用 UTF-8，保持已有换行方式。临时副本放在 `temp/`；包含脚本的备份目录添加 `.gdignore`，避免被 Godot 扫描。性能测量的当前限制见[性能说明](../../battle_performance_optimization_checklist.md)。
