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
- [x] 召唤物读取 `summon_damage`、`damage_percent`、`attack_speed`、`cooldown_reduction`、暴击和范围加成
- [x] `summon_count` 作为额外召唤数量参与批量生成
- [x] `SummonRoot.hard_cap` 裁剪最大召唤数量
- [x] 波次结束和战斗重置会清理召唤物

## 3. 待 Godot 验证项

- [ ] 启动 `scenes/core/bootstrap.tscn`
- [ ] 确认控制台出现 `[Bootstrap] summon checks`
- [ ] 确认 `summon test scene instantiate` 输出 `passed`
- [ ] 确认 `summon root initialize` 输出 `passed`
- [ ] 确认 `summon count bonus` 输出 `passed`
- [ ] 确认 `summon inherited damage` 输出 `passed`
- [ ] 确认 `summon attack enemy` 输出 `passed`
- [ ] 确认 `summon hard cap` 输出 `passed`
- [ ] 确认 `summon clear battle entities` 输出 `passed`
- [ ] 确认最终没有新增 `validation errors`

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
