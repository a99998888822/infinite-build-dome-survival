# 高侵蚀 / 高怪物增幅 / 满法术战斗性能问题概述

更新：2026-11-12。本文整理最初报告的“侵蚀度与怪物数量增幅很高（至少数百）、武器与法术拉满时正常战斗非常卡顿”问题，以及后续经验球堆积问题的实测与处理现状。

## 结论摘要

1. **战斗卡顿属实，而且不需要同屏数百只怪。** 当前配置的同屏活怪上限是 48 / 72 / 96（按难度）；本报告按“侵蚀/增幅数值至少数百（取 200）”复现。若你实际看到同屏数百只活怪，说明另开了上限或使用了特殊波次，性能只会更差，根因判断不变。项目记录里，30～48 只移动怪、满附魔时已经掉出 60FPS；150 只时数量级过载。
2. **主因不是“切武器”本身，而是每次命中后的同步附魔/元素链扇出。** 电浆炮每目标最多 5 次附魔，分裂/多投再乘；闪电链会引爆燃烧并生成范围爆炸；赤铜炉灯/火池持续制造燃烧目标。每次命中还叠加伤害数字、受击闪白、信号、音频与逐敌查询。
3. **高侵蚀把“命中次数”放大。** 侵蚀 200 时普通怪最大生命约 ×10、伤害/护甲约 ×3.7、刷怪数量 ×3；再叠加“怪物数量增幅 +200%”理论刷怪 ×9，被 48/72/96 上限截住，表现为“人口始终顶满、死一个立刻补一个”。每只怪承受约 10 倍命中，特效/链/范围查询随之放大。
4. **战斗侧尚未完成收敛。** 现有优化主要压视觉装饰和部分联络几何；项目自己的文档仍写明“未达到密集多法术场景稳定 60FPS”。视觉预算只降低装饰，不限制链跳、伤害事件和范围查询。
5. **经验球堆积已处理到可控范围。** 原本每个球每物理帧跑脚本，10,000 颗约 22ms；现在休眠 + 远处退出物理世界 + 节点硬上限 1,000（每组优先 16 次独立贡献，满组时仍并入以保住节点上限），10,000 次掉落的拾取段从 37.27ms 降到 24.25ms，经验/金币逐贡献精确不变；代价是可见球数下降。

## 复现配置

- 难度：标准 / 高难（敌人上限 48 / 72 / 96）。
- 波次：第 8～10 波。
- 侵蚀度：200（“至少数百”的中段）；怪物数量增幅：+200%。
- 武器：电浆炮 Lv.5（多投、分裂、闪电）＋赤铜炉灯 Lv.5（火焰），部分记录还带钱袋（水）或木弓（火）。
- 玩家：高生命/护盾、静止或小范围移动，满附魔。
- 环境：Godot 4.7.1，GL Compatibility / ANGLE / D3D11，GTX 1060 6GB；项目记录机器为 i7-8700。正式 GPU 复核在私有后台桌面运行，`foreground_samples=0`。

## 实测数据

| 来源 / 场景 | 配置 | 结果 |
|---|---|---|
| [电浆炮压力测试](artifacts/reports/saved_stress_analysis.md) | 侵蚀 200、怪物数量 +200%、第 10 波；电浆炮+多投+分裂+闪电，木弓+火，钱袋+水；活怪峰值 48 | GPU 平均 **17.56ms**、P95 **36.79ms**、最大 **67.91ms**；900 帧中 **354 帧**超过 16.67ms |
| 同上 CPU 对照 | 同上，headless | 平均 8.26ms、P95 16.60ms；同场采样到约 416 个存活闪电效果 |
| 同上逐项对照 | 去掉分裂 / 去掉雷 / 去掉火 / 去掉水 | 去掉分裂时 P95 约降低三分之一；雷链路被记录为优先分析对象 |
| [plasma_combo_live.json](artifacts/reports/plasma_combo_live.json) | 同组合，48 怪 | 平均 7.38ms、P95 **22.29ms**、最大 35.46ms；20～30ms 尖峰帧内同帧出生 15～34 个闪电效果 |
| [四武器效果性能记录](docs/approved_weapon_vfx_performance_20261107.md) | 4 武器满附魔，30 只移动怪 | 平均 **21.55ms**、P95 **54.51ms**、最大 121.64ms；150 只时过载到 1762ms/帧（仅 4 个样本） |
| 同上，固定步长 CPU | 150 只静止怪，四武器混合 | 平均 **42.21ms**、P95 **87.31ms**、峰值子节点 2197 |
| [电浆/战锤密集接触](docs/hammer_plasma_performance_20261107.md) | 300 只静止高血量怪，等离子+水+落雷 | 等离子 P95 仍为 **52～61ms**；文档明确写“仍超出 16.7ms 预算，不能声称稳定 60FPS” |

补充复核（本次，headless 固定步长，静止高血量目标）：`plasma_combo_perf_test` 在 96 怪时 P95 约 19.8ms，200 怪时 P95 约 34.4ms；该测试不计渲染和 AI，只作趋势证据。

## 根因分析

### 1. 每次命中的同步附魔/元素链扇出

- [active_weapon_casting.gd](scripts/weapons/active_weapon_casting.gd#L26-L39)：所有自动武器逐帧检查并施法；高攻速下多武器同时输出。
- [weapon_instance.gd](scripts/weapons/weapon_instance.gd#L130-L159)：每次施法复制武器快照、重建附魔、遍历属性。
- [projectile_instance.gd](scripts/weapons/projectile_instance.gd#L12-L16)：`PLASMA_ENCHANT_CASTS_PER_TARGET = 5`，每个等离子球对每个目标最多触发 5 次完整附魔后缀；分裂子球各自还有独立预算。
- [combat_effect_world.gd](scripts/effects/combat_effect_world.gd#L19-L73)：每次命中按顺序执行整条附魔链（火焰、闪电、落雷、爆炸、分裂、弹跳等）。
- [lightning_particle_effect.gd](scripts/effects/lightning_particle_effect.gd#L158-L196)：闪电链命中带燃烧目标时引爆，生成 72 半径的 `thunder_fire` 爆炸；每个受害者再触发伤害、状态、伤害数字与反馈。
- [element_reaction_resolver.gd](scripts/effects/element_reaction_resolver.gd#L62-L91)：电+燃烧、电+湿润等反应在每次接触时结算。
- [copper_lamp.gd](scripts/weapons/copper_lamp.gd#L111-L168)：炉灯每个 tick 对锥形内所有敌人结算一次伤害，并先对全部敌人排序；火焰/火池持续为电链提供新的燃烧目标。

这不是一个无限递归，而是**乘法式扇出**：命中频率 × 附魔数量 × 链跳数 × 范围目标数 × 每目标特效数。分裂和多投是最稳定的放大器，雷链/爆炸是第二层放大器。

### 2. 每次命中的固定成本

[enemy_controller.gd](scripts/enemies/enemy_controller.gd#L642-L690)：每次伤害都会发多个信号、生成伤害数字、受击闪白、随机采样和死亡判定；密集范围伤害还会触发 [combat_hit_feedback.gd](scripts/effects/combat_hit_feedback.gd#L159-L188) 的 O(n²) 局部命中中心搜索。命中几百次/秒时，这些固定成本不可忽略。

### 3. O(怪物数) 的选敌、排序与范围查询

- 自动索敌每次扫描全部注册敌人并做精确形状相交（[active_weapon_casting.gd](scripts/weapons/active_weapon_casting.gd#L41-L65)、[weapon_contact_query.gd](scripts/battle/weapon_contact_query.gd#L43-L51)）。
- 炉灯 tick 全量排序；爆炸、落雷、水波等效果用 `intersect_shape` 查询范围并逐敌结算。
- 高侵蚀下敌人存活更久，命中次数和范围查询次数同步上升。

### 4. 侵蚀与刷怪增幅

[erosion_pressure_rules.json](data_config/erosion_pressure_rules.json)、[enemy_wave_pressure.gd](scripts/waves/enemy_wave_pressure.gd#L17-L29)：

- 侵蚀 200：普通怪最大生命约 **×10.2**，伤害/护甲约 **×3.7**，刷怪数量 **×3**。
- 怪物数量增幅 +200%：刷怪数量再 **×3**。
- 理论上单批刷怪 ×9，但 [battle_difficulty.gd](scripts/data/battle_difficulty.gd#L22-L46) 把默认活怪限制在 48/72/96；按当前配置实际表现是“人口始终顶满、死一个立刻补一个”。若实测同屏数百，则说明该上限被绕过或场景另有配置，单帧成本只会更高。
- 每只怪多承受约 10 倍命中，才是特效负载真正被放大的原因。

### 5. 视觉预算不限制逻辑

闪电/爆炸/火焰有视觉档位与抑制预算，但**附魔触发、链跳、范围查询、伤害事件、状态结算**仍按原频率执行；画面降级不等于 CPU 降下来。

## 经验球堆积问题（附带）

- 夜幕撤离没有时限，只有进入庇护所或死亡才结束；普通怪 100% 掉经验球，球没有 TTL、上限、合并或离屏清理，波末才统一吸取。
- 原实现每个球每物理帧执行 `_physics_process`，实测约 **2.2µs/球**；10,000 球约 **22ms/帧**，且地上球不捡也会一直跑。
- 已处理：
  - 超出拾取范围的球休眠（不再每帧跑脚本）；
  - 远处球退出物理世界（分片扫描、关闭碰撞）；
  - 场上节点**硬上限 1,000**，第 1,001 次掉落开始合并，每组优先保留 **16 次独立贡献**；所有兼容组都满时仍并入最近的满组，而不是继续新建节点；
  - 波末吸取在整球所有贡献到账后通知完成，避免最后一个合并球提前触发波次结算；
  - 新区域无近邻时迁移最远一组，避免旧战场堆积、新战场空掉；
  - 经验/金币 HUD 每帧刷新一次，逐贡献仍精确结算。
- 实测：10,000 次掉落的压力场拾取段 **37.27 → 24.25ms**，整体 **37.98 → 27.20ms**，节点 **10,000 → 1,000**；5,000 次掉落专项测试经验/金币/快照计数完全一致。
- 取舍：可见球密度下降；正常情况下每组最多代表 16 次掉落，极端堆积时单个节点可能代表更多次掉落。完整数据见 [performance_after_culling.md](artifacts/reviews/exp_orb_field_20261112/performance_after_culling.md)。

## 当前状态

- **战斗卡顿**：算法和实测都确认属实；现有改动主要处理经验球，战斗侧的“每次命中同步附魔/元素链扇出”尚未做全局预算或合并，项目文档也仍不宣称稳定 60FPS。
- **经验球**：休眠 + 物理剔除 + 节点硬上限已把压力场拾取段降到约 24ms（该压力场基线约 21ms），但低端移动端仍需结合怪物/特效预算验证。
- 波末一次性吸取超多球仍是一次性尖峰，按产品确认保留。

## 建议的后续优先级

1. **战斗侧每帧全局预算**：限制每帧链跳、爆炸、范围查询和附魔生成数量；优先压电浆“每目标 5 次 × 分裂子球”与雷链/爆炸的乘数。
2. **空间索引复用**：选敌、链跳、范围伤害统一走 `EnemyRegistry` 的空间索引，避免每次全量扫描/排序。
3. **每命中固定成本**：密集命中时合并伤害数字/受击反馈更新，保留伤害总量与状态；HUD 只做批量刷新。
4. **移动端专项**：以 30/60FPS 两种目标分别测 48/72/96 怪；把敌人 AI、物理查询和特效预算分开测量。
5. **经验球**：如必须保留 10,000 颗外观，需要重新评估自绘批渲染；当前 MultiMesh 方案在生成约 450～500 颗时停滞，已回退。否则维持合并上限，按平台调整上限。

## 回归

- 经验球专项 headless 回归：2026-11-14 实测 66 项通过，覆盖休眠/唤醒、节点上限与满组兜底、逐贡献结算、合并球最后吸取，以及波次完成后立即冻结统计。专项脚本与场景已按清理要求移除，此处保留验证记录；
- [dense_combat_regression_test.gd](scripts/tests/dense_combat_regression_test.gd)：45 项通过；
- [challenge_expansion_test.gd](scripts/tests/challenge_expansion_test.gd)：96 项通过；
- 编辑器 headless 解析通过。

## 数据来源

- [saved_stress_analysis.md](artifacts/reports/saved_stress_analysis.md)
- [plasma_combo_live.json](artifacts/reports/plasma_combo_live.json)
- [approved_weapon_vfx_performance_20261107.md](docs/approved_weapon_vfx_performance_20261107.md)
- [hammer_plasma_performance_20261107.md](docs/hammer_plasma_performance_20261107.md)
- [battle_performance_optimization_checklist.md](battle_performance_optimization_checklist.md)
- [经验球最终性能报告](artifacts/reviews/exp_orb_field_20261112/performance_after_culling.md)
- 经验球实战复核页：[review.html](artifacts/reviews/exp_orb_field_20261112/review.html)
