# 战斗特效显示层级核对（2026-10-23）

已按[分层方案](combat_effect_layer_proposal_20261023.md)完成迁移。当前实现以本节表格为准；下方保留迁移前审计，用于追溯原问题。测试场景、宣传专用装饰和交易 UI 动画不作为正式战斗层级。

## 当前实现（迁移后）

下列数值为同一世界画布中的最终 Z；角色局部效果为相对 Z 0，与所属角色一起参与脚底排序。

| 最终 Z | 内容与遮挡规则 |
| --- | --- |
| -256 / -240 / -239 | 地面、贴片与碎屑，保留原值。 |
| -192 | 草簇，始终在角色及战斗效果后面。 |
| -136～-129 | 领域、水流、冰面、扩散冰沿、脚底霜花、裂痕、位移地圈/锚点、手雷落点/投影、落雷地圈；保持地面性质。 |
| -123 / -113 / -86 | 等离子接地光点、粒子光晕、地块火焰。 |
| -50 | 纯控制震荡波；不随雷火爆心一起提升。 |
| -32 | 敌人脚底阴影。 |
| -8 | 冥狼、蝙蝠、冲锋怪预警；手动施法、位移瞄准、移动目标标记。 |
| -4 | 冲刺拖尾、铜灯与冥狼喷火的大块背景。 |
| -2 / -1 | 原有玩家可见性光晕、撤离地圈 / 玩家脚底标记。 |
| 0，脚底排序 | 玩家、怪物、障碍；黑洞与等离子球通过视觉代理加入同一排序树，碰撞节点不变。 |
| 0，所属角色内部 | 燃烧/圣焰/暗焰、冻结冰壳、导电电弧、霸体描边在身体之后画；复活翅膀在身体之前画。前方角色可遮住后方角色的身体状态。 |
| +8 | 箭矢、金币、手雷飞行主体、飞行火种、声波、近战攻击主体及弹道拖尾。 |
| +12 | 风刃、落雷/闪电链、光反射、光辉剑；喷火仅稀疏边缘/火星进入此层。 |
| +16 | 蒸汽，降低透明度以保留身体可读性。 |
| +24 | 命中爆点、雷火爆心、手雷爆炸、手炮喷焰、移星离开/到达/返回。 |
| +28 | 冻结瞬间与解冻碎冰、碎冰粒子；解冻后留在发生位置消散。 |
| +64 | 湿润/光/暗图标、闪电状态图标、债务标记、霸体文字。 |
| +100 / +104 | 伤害数字 / 元素反应文字，保留原值。 |

`CombatRenderWorld.set_world_layer()` 直接接收最终 Z；`set_actor_local()` 设置相对 Z 0。旧 `set_effect_layer()` 仍执行 `-128 + authored_layer`，只保留给既有地面及明确保留的路径，不能把前景值直接传入旧接口。

持续状态采用角色内的绘制顺序，不使用统一前景 Z。火焰局部 MultiMesh 共享纹理、材质与时钟，不再重复进入全场火焰批次；这会增加有状态角色的绘制提交数。黑洞组内部顺序为后漩涡、球体、前漩涡。

铜灯/冥狼喷火通过互补 Shader 区域拆为前后两部分，同一个可见像素只进入一个部分。共享粒子按用途分成少量渲染批次，仍沿用一个模拟池和总计 900 粒子的预算。

验证入口：`combat_layer_semantics_test` 检查身体状态实际像素遮挡、排序交错、喷火互补、粒子预算与清理；`combat_effect_depth_test` 检查真实草簇/角色/地面效果；`combat_layer_visual_review` 使用正式素材和玩家脚底锚点复核。详细结果见[实施记录](combat_effect_layer_validation_20261023.md)。

## 迁移前审计（历史记录）

以下内容描述本次调整前的实现，数值和“尚未实施”等措辞仅用于历史对照，不代表当前代码。

## 结论与排序规则

大多数武器攻击、附魔和粒子确实在草簇之上、玩家与怪物身体之下，但不是全部。身体状态覆盖、状态图标、文字以及部分敌人技能采用其他层级。

- 同一画布内，最终有效 `z_index` 越大，越靠前；数字比较不跨 `CanvasLayer` 或不同 Viewport。
- `CombatRenderWorld.set_effect_layer(item, n)` 设置绝对层级 `-128 + n`，并关闭父节点层级叠加。例如传入 `82`，实际为 `-46`，并不是前景 `82`。
- 普通子节点默认继承父节点 Z；共享火焰、粒子批次有自己的最终绘制节点，不能以逻辑节点挂在谁身上判断前后关系。
- 玩家身体和敌人通常为有效 Z `0`，同层内再按脚底/Y 排序及场景树绘制顺序决定遮挡。不同 Z 的对象不会因 Y 排序而互换前后。
- `show_behind_parent` 只描述相对父绘制对象的顺序；例如冰壳图集的辅助绘制面仍继承冰壳的前景 Z，不会因此回到怪物后方。

依据：[统一层级换算](../../scripts/effects/combat_render_world.gd)、[正式战斗场景](../../scenes/battle/battle_root.tscn)、[角色脚底排序](../../scripts/battle/cavern_battle_backdrop.gd)、[草簇批次](../../scripts/battle/cavern_population_backdrop.gd)。

## 世界画面：由后到前

下表列出当前正式战斗父节点为 Z `0` 时的最终有效层级。带“相对”的项目会随父节点 Z 改变；统一特效函数设置的绝对层级不会。

| 最终 Z | 绘制内容 | 主要来源 |
| --- | --- | --- |
| -256 | 地面底色/地板 | `cavern_battle_backdrop.gd` |
| -240 / -239 | 地面贴片、细节碎屑 | `cavern_battle_backdrop.gd` |
| -192 | 草簇，包括前后两组草批次 | `cavern_population_backdrop.gd::_grass_batch` |
| -136 | 仪式领域；光辉剑范围底色 | `ritual_domain.gd`、`light_sword_effect.gd` |
| -135 | 水流；湿润传播水带；通用法术范围底色；光辉剑地面纹样 | `water_wave_effect.gd`、`element_reaction_visual.gd`、`spell_ground_area.gd` |
| -134 | 结霜冰面主体 | `ice_field_effect.gd` |
| -133 | 风扩散冰面的前沿 | `element_reaction_visual.gd` 的 `ice_expand` |
| -130 | 冲刺地圈、移星冲击波、回返锚点、后坐力尘土 | `mobility_atlas_effect.gd` |
| -129 | 减速脚底霜花；大地锤裂痕、地面冲击反馈 | `enemy_status_visual.gd`、`earth_hammer.gd`、`combat_impact_r02.gd` |
| -123 | 等离子球接地光斑/放电端点 | `plasma_ball_visual.gd` |
| -113 | 粒子光照晕染 | `particle_light_field.gd` |
| -103 | 怪物身上的燃烧火舌，包括普通、圣焰、暗焰配色 | `pixel_fire_visual.gd::setup_status` 的共享火焰批次 |
| -88 | 冲刺拖尾；移星离开、到达、返回；霰弹命中；手炮喷焰 | `mobility_atlas_effect.gd`、`cannon_jet_flame.gd` |
| -86 | 火焰地块火舌 | `fire_patch.gd`、`pixel_fire_visual.gd::setup_field` |
| -85 | 飞行火种火舌 | `pixel_fire_visual.gd::setup_single` |
| -83 | 金币命中特效 | `ritual_coin_hit.gd` 的非典籍分支 |
| -78 | 通用投射物、金币、霰弹、手雷及其自身绘制；匕首、长矛/碎片、流星连枷、大地锤主体、触手、铜灯喷火；等离子球主体 | `projectile_instance.gd`、`coin_projectile.gd`、`grenade_projectile.gd`、`directed_weapon_runtime.gd` 及对应武器实现 |
| -58 | 典籍命中特效 | `ritual_coin_hit.gd` 的典籍分支 |
| -50 | 风刃；震荡波；雷火爆炸主体；黑洞后部漩涡 | `wind_blade_effect.gd`、`enchantment_block_vfx.gd`、`reaction_block_visual.gd`、`black_hole_effect.gd` |
| -49 | 黑洞球体主体 | `black_hole_effect.gd` |
| -48 | 黑洞前部漩涡；共享粒子池（受击、拖尾、碎屑等）；闪电命中爆点 | `black_hole_effect.gd`、`particle_world.gd`、`lightning_hit_sprite_burst.gd` |
| -47 | 落雷/电火花预警主体；闪电链；光反射 | `electric_spark_effect.gd`、`lightning_particle_effect.gd`、`light_reflection_effect.gd` |
| -46 | 光辉剑空中剑体 | `light_sword_effect.gd` |
| -45 | 蒸汽、导电视觉、当前正式解冻视觉 | `element_reaction_visual.gd`、`reaction_block_visual.gd::draw_thaw` |
| -2（相对） | 敌人地面阴影、玩家可见性光晕、撤离地圈 | `enemy_ground_shadow.gd`、`player_root.tscn`、`night_evacuation_visual.gd` |
| -1（相对） | 玩家脚底标记、手动施法指示器、移动目标标记、位移指示器、复活翅膀；冥狼预警/落地反馈及喷火；蝙蝠预警 | 对应玩家/战斗指示器脚本、`revive_angel_wings.gd`、`underworld_wolf.gd`、`underworld_wolf_flame.gd`、`echo_bat.gd` |
| 0 | 玩家、怪物、参与脚底排序的立体障碍；蝙蝠蓄力/声波及命中图；冲锋怪直接绘制的冲锋预警和血条 | 正式角色场景、`echo_bat.gd`、`echo_bat_sonic.gd`、`elite_rusher.gd` |
| +1（相对身体） | 霸体描边 | `enemy_super_armor_visual.gd` |
| +3（相对） | 债务指定目标头顶标记 | `debt_target_marker.gd` |
| +20（相对） | 霸体文字 | `enemy_super_armor_visual.gd` |
| +25 | 冻结冰壳；冻结瞬间碎冰；湿润/光/暗状态图标 | 冰壳、图标继承 `enemy_status_visual.gd` 的相对 +25；冻结碎冰由 `element_reaction_visual.gd` 设置绝对 +25 |
| +100（相对） | 伤害数字、闪电状态头顶环绕粒子 | `enemy_controller.gd`、`lightning_status_visual.gd` |
| +104（相对） | 元素反应文字绘制器（导电/雷火） | `element_reaction_text.gd` |

通用图集、块状 Shader、像素绘制工具通常继承调用方层级，不另占一层。弹射复用对应武器路径，分裂子弹复用对应投射物路径，因此没有一个单独的“弹射层”或“分裂层”。受击闪白/抖动直接作用于怪物 Sprite，玩家复活闪烁直接修改玩家 Sprite 透明度，也没有额外前景层。

## 必须区分的几组效果

| 视觉上容易被当成同一类的内容 | 当前实际情况 |
| --- | --- |
| 结霜、减速、冻结、解冻 | 冰面 -134；脚底霜花 -129；冰壳/冻结碎冰 +25；解冻 -45。它们并不共用最终层级。 |
| 身上燃烧 vs 身上冻结 | 燃烧逻辑虽挂在状态节点下，实际共享批次为 -103；冰壳则继承前景 +25。 |
| 黑洞“前”漩涡 | -48 只表示位于黑洞主体 -49 的前面，依然在所有 Z 0 身体的后面。 |
| 闪电主体 vs 闪电状态提示 | 链条/落雷 -47，命中爆点 -48；头顶状态粒子 +100。 |
| 铜灯喷火 vs 冥狼喷火 | 铜灯 -78，冥狼 -1；两者都在身体之后，但冥狼火焰能盖住大量普通武器特效。 |
| 我方投射物 vs 蝙蝠声波 | 我方一般 -78；声波为默认 0。声波与身体的遮挡由同层绘制规则决定，不能保证始终在所有怪物后面。 |
| 不同敌人的预警 | 冥狼、蝙蝠预警 -1；冲锋怪预警直接绘制在自身 0 层，不是统一地面预警层。 |

解冻还有一次覆盖赋值：生成时先被设为 -133，但当前 `_draw()` 总会调用 `ReactionBlockVisual.draw_thaw()`，把实际绘制层改成 -45。只查生成函数会得到错误结论。

冻结冰壳当前采用统一前景层，因此不仅高于被冻结的怪物，也高于同一世界画布中其他 Z 0 身体，包括玩家；它并不是“只盖住所属怪物、仍参与其他角色前后排序”的实现。

## 屏幕覆盖与环境

战斗世界通常渲染到独立 SubViewport，再由主视口的 `WorldViewportLayer`（CanvasLayer -3）展示。环境底色层 -4、远景层 -2、洞窟边缘层 -1 以及夜幕/界面覆盖使用 CanvasLayer，不能把它们的层号与上表 Z 值混排。

- 夜幕覆盖使用主视口 CanvasLayer 19，撤离方向提示使用 20。
- HUD 使用 CanvasLayer 29，战斗工具覆盖 30，当前武器鼠标图标 40；属于界面/屏幕显示，不受“草簇与怪物之间”的规则约束。
- 场景光照、云影和受击屏幕反馈还会修改 Shader、颜色或画面表现；它们不是一组可用世界 Z 排序的攻击实体。

依据：[世界视口展示](../../scripts/core/game_root.gd)、[夜幕与撤离](../../scripts/battle/night_evacuation_visual.gd)、[鼠标图标](../../scripts/battle/active_combat_controller.gd)、[屏幕受击反馈](../../scripts/effects/combat_hit_feedback.gd)。

## 后续调整建议（尚未实施）

适合继续保留在身体后方的是地面范围、脚底霜花、裂痕、锚点与预警。需要逐项评估的是空中攻击主体、命中闪光和附着于身体的状态特效；目前把它们一并压到身体后方，会让密集怪群遮住攻击表现。

建议后续明确“地面表现、空中攻击、身体状态、信息提示”四类，再按每种效果拆分前后部分。不要直接整体抬高 `EFFECT_BASE_Z`，否则冰面和范围提示也会覆盖角色。冻结/解冻、燃烧、敌人预警的层级差异应优先统一设计规则。

已有文档 `battle_environment.md` 关于草簇与人物脚底排序的描述不足以代表当前遮挡结果：当前正式草簇批次强制为绝对 -192，始终在 Z 0 身体后方。`combat_render_world.gd` 的统一规则注释也不包含冻结等前景例外。后续调整应同步这些说明，以及 `combat_effect_depth_test.gd` 中针对普通攻击位于身体后方的断言。
