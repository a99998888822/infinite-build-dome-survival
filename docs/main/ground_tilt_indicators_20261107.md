# 地面倾斜与指示器口径（2026-11-07）

主战斗场景使用斜俯视投影：地面上的圆，垂直半轴 = 水平半轴 × 145/220 ≈ 0.659。比例的唯一来源是 [attack_footprint.gd](../../scripts/battle/attack_footprint.gd) 的 `ELLIPSE_RATIO`；`AttackFootprint.project/ground_transform`、`ground_projection_r05.gd` 的 `projected_axes()`、`spell_footprint.gd` 的 `GROUND_FLATTEN` 都由它派生。像素着色器（铜灯喷焰、手炮喷焰、熔炉环、附魔爆炸冲击波）用 `projection_ratio` uniform 接收同一数值。

## 当前结论

| 对象 | 现用 y/x | 说明 |
| --- | --- | --- |
| 突进短刃 · 移动范围 / 落点范围 / 落点判定 | 0.659 | 指示器与 `MobilityWeaponRuntime` 的落点判定统一为投影椭圆 |
| 移星秘典 · 移动范围与落点环 | 0.659 | — |
| 剑刃冲刺 · 移动范围与落点 | 0.659 | 冲刺位移本身也按椭圆钳制 |
| 巨型手持火炮 · 后撤落点标记 | 0.659 | — |
| 榴弹炮 · 射程与爆炸范围 | 0.659 | — |
| 铜灯喷焰扇面、营地匕首扇面、熔炉范围 | 0.659 | 扇面经 `ground_transform` 绘制 |
| 陨星锤 · 扇面与碰撞区域 | 0.659 | 锤头半径改为投影前叠加 |
| 坤舆秘仪书 · 法阵（视觉 + 判定） | 0.659 | 垂直半轴由水平半轴派生，不再单独配置 |
| 环绕 / 卫星环与弹体轨迹 | 0.659 | 环、体标记与 `PatternFlightRuntime` 的实际位置同投影 |
| 附魔爆炸 · 冲击波环 | 0.659 | 着色器 `projection_ratio` |
| 光剑落地标记、落雷触地扩散、电火花预警、火焰地面 | 0.659 | — |
| 水元素 · 扩散水波 | 0.659 | — |
| 冰霜领域 · 碰撞与地面霜纹 | 0.659 | 冰、水共用同一地面比例 |
| 水冰反应 · 霜冻前沿贴图 | 0.659 | 贴图原比例为 0.526，绘制时按 `FROST_FRONT_ART_FLATTEN` 校正 |
| 角色脚下接地标记 | 0.659 | — |
| 直射武器箭形（虚空弓、等离子炮、钱袋、暗夜矛、地裂战锤） | — | 箭头随瞄准方向旋转，命中为圆形投射体，不属于地面投影 |

## 审阅与回归

- 审阅入口：`scenes/tests/indicator_ground_tilt_review.tscn`。GPU 截图需走 `scripts/tools/run_godot_background.py` 并传 `--capture-dir=`；同目录 `review.json` 记录每项实测 y/x、期望值与 `follows_tilt`，偏离项会打印 `AUDIT_DEVIATION`。
- 专项断言：`mobility_weapon_integration_test.gd`（突进短刃落点比例）、`element_reaction_test.gd`（冰霜投影覆盖）、`spell_terminal_range_test.gd`（法术落点轴）、`tome_purse_weapon_test.gd`（法阵比例）、`resolution_unification_test.gd`（法阵轴）。
- 修改指示器或法术地面图形后，重跑上述用例，并核对 `ground_projection_review.tscn` 的地面特效截图。
