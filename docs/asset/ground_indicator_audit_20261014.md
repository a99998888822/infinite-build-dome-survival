# 主战斗指示器投影检查 · 2026-10-14

> 正式修复已完成：下文检查发现的 2 处完整圆圈与 5 类扇形现已统一使用 145∶220 地面投影，并同步相关攻击范围、轨迹和自动索敌。已在正式主战斗中补拍 16 张 GPU 截图，见[正式效果与验证记录](../../artifacts/previews/ground_indicators_production_20261014/README.md)。下文保留为修改前的检查记录，旧截图未覆盖。

## 修改前检查记录

已检查当前洞穴主战斗配置、14 种武器指示器入口、四类怪物预警入口，并使用正式绘制代码补拍 10 张 GPU 截图。此次只检查与记录，没有修改正式指示器、伤害判定或投影开关。

结论：仍有 **2 处完整正圆、5 类圆弧扇形**没有应用地面投影。旧清单中其余 8 处已在 10 月 12 日正式启用椭圆表现，不能再次列为未修复。

## 统一基准与原因

当前项目是二维坐标配合斜视场景美术，各范围图形自行处理投影。地面既有比例为 `Y / X = 145 / 220 ≈ 0.659`，定义在 [AttackFootprint](../../scripts/battle/attack_footprint.gd:5)。图形没有局部投影时，即使地面看上去倾斜，正圆仍会以正圆显示。

移星的两处圆圈调用 `GROUND.axes()`。该方法只有 `ground_projection_r05_enabled` 为真时才返回椭圆半轴；默认关闭，正式战斗没有开启此标志。本轮实机确认值为 false。其他已修复的地面效果调用 `GROUND.projected_axes()` 或 `GROUND.arc()`，已不依赖旧开关。

## 剩余项目

| 项目 | 现状与代码入口 | 建议 |
| --- | --- | --- |
| 移星秘典落点范围圈 | [mobility_weapon_indicator.gd:166](../../scripts/battle/mobility_weapon_indicator.gd:166) 调用 `ring()`；外层可移动范围已经椭圆，内层落点圈仍为正圆 | 优先统一落点圈；同时记录当前落地伤害仍是圆形查询 |
| 移星秘典返回位置圈 | [mobility_weapon_indicator.gd:157](../../scripts/battle/mobility_weapon_indicator.gd:157) 调用半径 24 的 `ring()` | 叠加外圈改为地面椭圆；已压扁的星印 PNG 不重复压缩，中心识别符号保持可读 |
| 营地短刀 | [weapon_attack_indicator.gd:118](../../scripts/battle/weapon_attack_indicator.gd:118) 的内外弧都是等半径 X/Y | 地面扇形需按统一投影生成 |
| 流星摆锤 | 同上，共用 `_fan()` | 还需核对锤头、链条、拖影及实际接触路径 |
| 赤铜炉灯 | [weapon_attack_indicator.gd:124](../../scripts/battle/weapon_attack_indicator.gd:124) 将扇面裁在圆形射程上 | 与 [in_lamp_cone](../../scripts/battle/attack_footprint.gd:50) 的距离和角度判断一起核对 |
| 巨型手持火炮 | [mobility_weapon_indicator.gd:139](../../scripts/battle/mobility_weapon_indicator.gd:139) 的散射端点按同半径圆弧生成；后撤终点小圈已经椭圆 | 核对弹丸真实方向与射程，分别处理散射覆盖和后撤标记 |
| 冥狼吐息 | [underworld_wolf.gd:80](../../scripts/enemies/underworld_wolf.gd:80) 构造圆弧扇形；[335 行](../../scripts/enemies/underworld_wolf.gd:335) 绘制填充、外框，[343 行](../../scripts/enemies/underworld_wolf.gd:343) 绘制进度弧 | 高优先级。预警多边形与 [210 行](../../scripts/enemies/underworld_wolf.gd:210) 的碰撞使用同一形状，修改时一起保持一致 |

![移星圆圈、冥狼吐息及已修复跳扑的当前实机对照](../../artifacts/analysis/ground_indicator_audit_20261014/circles_and_enemy.png)

![四种武器的圆弧扇形](../../artifacts/analysis/ground_indicator_audit_20261014/weapon_fans.png)

## 已正确投影或不属于遗漏

- 冥狼出生圈、跳扑落点预警、落地扩散环已使用地面椭圆。跳扑伤害通过相同椭圆多边形与玩家真实碰撞体相交；本轮重跑其边界检查通过。
- 坤舆秘仪书领域、榴弹射程与落点、突进短刃的移动范围及落点、移星外层移动范围、手持火炮后撤终点均已是椭圆。
- 移星落地冲击、水波、光剑落点标记、落雷触地环已经正式投影。地面效果与当前仍为正圆的移星瞄准圈存在表现不一致。
- 玩家脚底标记虽使用 `draw_circle()`，其绘制变换已把 Y 压到 0.42；冥狼接触影压到 0.3。它们无需重复处理。
- 钢甲骑士冲锋、蝙蝠声波预警是路径条，没有完整圆形遗漏。头顶状态图标、球体本体、飘字和 HUD 按其自身空间表现，不统一压扁。
- 额外低优先级项：教程的移动目标双圈仍为屏幕圆形，[combat_guide_overlay.gd:27](../../scripts/ui/combat_guide_overlay.gd:27)。正式移动目的地已使用星形素材。

## 修改时需要保持的关系

建议先处理移星两圈与冥狼吐息，再统一四种武器的扇形。圆形地面轨迹采用 0.659；角色、竖直火焰和图标保持自身比例。方向性扇形要先在地面坐标中确定朝向，再投影至画面，确保水平、竖直和斜向的短轴始终服从地面视角，避免把已经压扁的整个节点直接旋转。

危险预警必须与伤害查询对齐。当前短刃和移星的冲击图像是椭圆，但 `MobilityWeaponRuntime._impact()` 仍用圆形查询；炉灯、摆锤及冥狼吐息也有与圆形几何相关的判定。后续应明确处理显示与命中的对应关系，避免单独压缩预警后产生“人在可见圈外仍受伤”的差异。

## 本轮验证

- 当前生产场景中使用正式绘制器，固定技能阶段，截取 10 张图；未启用旧审阅投影开关。
- 41 项检查通过，包括冥狼跳扑真实碰撞边界、开关状态、资源初始化及截图保存。
- 独立 Windows 桌面运行，实际桌面核验一致，`foreground_samples=0`。
- 原始截图、日志、捕获脚本与结果在 `artifacts/analysis/ground_indicator_audit_20261014/`。拼图只做等比裁切和标签排版，没有改变指示器形状。
