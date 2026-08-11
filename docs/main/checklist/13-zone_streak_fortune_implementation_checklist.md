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
- [ ] `MainFlowCoordinator` 的波次结束顺序保持为：吸收经验 -> 补升级 -> 利息 -> 商店 -> 理财 -> 区域选择。
- [ ] `ZoneProgression` 在换区时正确生成收割 payload，并在确认后清空待处理状态。
- [ ] 区域压力与商店偏向只作为运行时上下文，不直接改静态配置表。

## 4. UI / 场景骨架待补

- [x] 在 `UiRoot` 下补齐 `HUDLayer`、`PopupLayer`、`FadeLayer`、`DebugLayer` 分层。
- [x] 创建 `zone_select_popup.tscn`，用于显示 3 个区域卡和确认按钮。
- [x] 创建区域卡组件 `ZoneSelectCard`，优先复用 `reward_option.tscn` 的卡片风格。
- [x] 创建 `zone_harvest_result_popup.tscn`，用于展示换区后的收割结果。
- [x] 创建轻量 `zone_ui_controller.gd`，监听 `MainFlowCoordinator.modal_requested / modal_closed`。
- [ ] 如需调试，可后续再独立拆分 `zone_debug_panel.tscn`；当前已在 `ZoneUIController` 里内联调试面板。
- [x] UI 先用 `PanelContainer + StyleBoxFlat` 占位，不新增区域专属美术。

## 5. 后续扩展

- [ ] 后续新增区域时，只补 `zones.json` 与对应运行时压力配置。
- [ ] 后续新增区域事件波、Boss 波时，复用现有状态机与区域上下文。
- [ ] 如果后续要做更复杂的区域表现，再补专属 UI 与美术素材。




