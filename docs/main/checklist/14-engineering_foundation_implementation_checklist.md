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
