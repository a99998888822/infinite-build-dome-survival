# 结霜降级与战斗特效绘制审计

> 后续更新（2026-10-07）：经用户审阅批准，像素特效 PNG／GPU R01 已安装。结霜完整冰晶及满池新飞溅已恢复，本文保留为安装前的历史诊断，下面的“当前”与源码行号均指当时版本。安装范围及验证见 [R01 安装记录](D:/project/useless/resources/infinite-build-dome-survival/docs/main/checklist/pixel_effects_png_r01_2026-10-07.md)。

2026-10-07，基于当时正式项目工作区。闪电命中 PNG R02 已安装；本次对结霜及其他特效进行诊断，没有更换它们的美术或调整效果参数。范围为元素、武器及相关战斗反馈，不将普通 UI 绘制和场景背景着色器全部列为战斗粒子。

## 结霜为什么会降级

结霜地面冰晶仍由代码画像素线条和多边形。它同时受到固定外观削弱、自动细节分级和共享粒子池容量三方面影响。

### 自动分级：第 3 个和第 5 个附近冰场明显变简略

[pixel_effect_draw.gd:8](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/pixel_effect_draw.gd:8) 在生成效果时计数：同类已有对象距离小于 160 像素，或全局已注册的存活效果数量达到阈值，便选择较低细节。

| 新冰场生成前的数量 | 新冰场细节 | 结霜外观 |
| --- | --- | --- |
| 附近同类少于 2、全局少于 24 | 2 | 中心晶体、分支／晶面、6 个外围小晶体和闪点 |
| 附近同类达到 2，或全局达到 24 | 1 | 去掉 6 个外围小晶体／闪点和中心晶面，保留中心分支 |
| 附近同类达到 4，或全局达到 48 | 0 | 进一步去掉中心分支，只保留主要骨架和底层形状 |

更低级别条件优先。全局数量只统计注册到 `pixel_combat_effects` 的对象；其中包括已经改用 PNG、但仍调用同一个注册函数的水流和碎冰反应。它不是依据实测帧率自适应。

[ice_field_effect.gd:33](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/ice_field_effect.gd:33) 只在生成时记录细节，附近效果消失后也不恢复。[绘制分支:124](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/ice_field_effect.gd:124) 和 [frost_pattern.gd:26](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/frost_pattern.gd:26) 实际删除装饰；生长／淡出画面按 12 Hz 更新。分级本身不改变伤害和控制判定。

### 固定参数也比早期版本更淡、更少

Git 历史中，`f531cc5`（2026-09-27）将结霜基础半径从 64 改为 51.2，地面投影比例改为 0.55，晶体透明度额外乘 0.58，并调整为更暗的色板。粒子生成从约 29 颗减为 13 颗：当前是 `round(72 × 0.6 × 0.3)`；尺寸系数从 0.65 降为 0.52，覆盖色 alpha 为 0.55，之后还会随寿命淡出。半径及投影变化也涉及当时的范围判定，不宜为了视觉恢复直接整体回滚。

`dd3f54f`（2026-10-02）又把冰场接入细节分级，并限制外围晶体绘制。上述代码不在本次闪电 R02 安装清单内。

### 粒子池满时，起手碎屑可以完全不生成

[结霜生成调用:47](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/ice_field_effect.gd:47) 仍使用 `ice_burst`。在 [particle_world.gd:568](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/particle_world.gd:568)，请求数量被剩余容量截断；900 槽已满时，新增数量为 0。地面晶体本体不占这些槽，所以会出现“还有冰场，但没有起手飞溅”的情况。

### 正式脚本运行证据

使用真实 `IceFieldEffect.spawn` 连续生成 5 个同位置冰场，所得细节是 `[2, 2, 1, 1, 0]`，起手碎屑合计 65 颗；移除／移开其他冰场后，低级别仍为 0。填满 900 槽后再生成一个冰场，普通粒子数量仍为 900，没有新增碎屑。

下图取自当前正式脚本的 GPU 运行。三个对象先真实生成，再分开放置，以相同半径、生长时刻和透明度作 2 倍显示对照；隐藏起手碎屑以便观察冰晶结构。这是诊断图，不是三套新美术方案，也不是战斗录像。

![结霜细节 2、1、0 对照](D:/project/useless/review-archives/frost-effect-audit-20261007/frost-detail-levels.png)

[运行结果](D:/project/useless/review-archives/frost-effect-audit-20261007/result.json) · [诊断脚本](D:/project/useless/review-archives/frost-effect-audit-20261007/probe.gd) · [GPU 运行记录](D:/project/useless/review-archives/frost-effect-audit-20261007/gpu.json)

Headless 与 GPU 运行均退出 0，断言通过。GPU 使用专用 Windows 桌面，实际引擎桌面与目标一致，`foreground_samples=0`，未占用用户前台。

## 还有哪些没有使用 PNG 美术帧

不能只检查是否调用 `draw_texture`：纹理也可能由程序现场生成。下表区分像素几何／粒子、程序着色器与读取 PNG 的情况。

| 效果 | 当前绘制方式与入口 | 容量／细节说明 |
| --- | --- | --- |
| 结霜地面晶体、减速脚下霜纹、持续冻结冰壳、风扩散霜线 | `ice_field_effect.gd:124`、`frost_pattern.gd:9`、`enemy_status_visual.gd:135`、`element_reaction_visual.gd:167`，程序像素几何 | 冰场有上述分级；起手 `ice_burst` 用共享池。脚下霜纹与冰壳不能直接套用冰场分级结论 |
| 光辉剑、落地碎片和地面细节 | `light_sword_effect.gd:143`，像素块／路径 | 有分级；低级别减少或省略碎片、拖尾、地面细节 |
| 黑洞及吸入碎线 | `black_hole_effect.gd:127`，像素椭圆／弧／线 | 有分级，最低级省略吸入碎线和吸积环 |
| 光折射光束、晶体碎片 | `light_reflection_effect.gd:136`、`reflection_pixel_batch.gd:42`，程序像素线段 | 低级别省略侧光束，碎片由 7 组减为 3 组 |
| 闪电链／落雷的闪电线条 | `lightning_pixel_bolt.gd`，像素栅格转网格 | R02 只迁移命中飞溅，线条仍为程序绘制 |
| 落雷预警黄色环绕粒子、落地扩散圈 | `electric_spark_effect.gd:130`、`lightning_particle_effect.gd:451`，矩形／圆／弧 | 独立于普通粒子池 |
| 感电、传导蓝色火花 | `lightning_status_visual.gd:59`、`element_reaction_visual.gd:125`，像素块／线 | 传导反馈受反应提示的总数上限及合并规则影响 |
| 震荡、雷火反应爆炸、地形碎屑、普通非电浆投射物拖尾 | `explosion_effect.gd:69`、`:108`、`:176`，`projectile_instance.gd:105`、`:353`，ParticleWorld 方块粒子 | 仍受共享池容量限制；拖尾最多使用前 720 槽，给命中保留 180 槽，但池满时命中仍会被丢弃 |
| 铸铁榴弹炮弹体、落点闪点、爆炸烟团／火星 | `grenade_projectile.gd:194`、`:207`，直接绘制像素方块 | 自己的绘制循环，不占 ParticleWorld；烟团 18 组、外圈火星 44 组、早期核心 13 组 |
| 坤舆秘仪书命中纹路、钱币命中飞溅 | `ritual_coin_hit.gd:43`，像素路径和方块 | 独立绘制；秘仪领域底图是 PNG，但领域漂浮小方块仍由 `ritual_domain.gd:168` 绘制 |
| 流星摆锤、守夜长枪、异化触手的部分拖尾／碎屑；钱币拖尾 | `meteor_flail.gd:211`、`nightwatch_spear.gd:187`、`mutant_tentacle.gd:116`、`coin_projectile.gd:198` | 武器主体使用 PNG，这些附属视觉为程序几何／小方块 |
| 蒸汽、水状态扩散带、湿润／光／暗状态标识 | `element_reaction_visual.gd:94`、`:153`、`enemy_status_visual.gd:94` | 程序形状；反应提示有合并和上限 |
| 风刃 | `wind_blade_effect.gd:80`，多边形和抗锯齿线 | 程序几何，不应称为普通像素粒子 |
| 地面火焰、燃烧状态、火种 | `pixel_fire_visual.gd:4` + `shaders/effects/pixel_fire.gdshader`，GPU 程序火焰 | 非 PNG，也不占普通 900 槽池 |
| 赤铜炉灯喷火 | `copper_lamp_flame.gd:22`，着色器 + 现场生成的噪声纹理 | 非 PNG，不占普通池 |
| 电浆球核心及周围电弧／火花 | `plasma_ball_visual.gd:121` 通过 `Image.create/set_pixel` 生成核心帧，外围程序绘制 | 虽然核心调用 `draw_texture`，源头仍是程序生成，未加载 PNG 美术帧 |
| 通用地面光场 | `particle_light_field.gd:65`，4 层透明圆盘网格 | 独立 96 槽，满时覆盖最旧光源。R02 仍保留辅助地面光场；单颗命中粒子的辉光已经从 PNG 取帧 |

表中的源码路径以项目根目录 `scripts/effects/` 为默认；武器脚本位于 `scripts/weapons/`。这些项核对了运行调用或绘制入口，未把所有历史粒子配置都算成正在显示的特效。

另有精英冲锋预警里的红色闪点（`scripts/enemies/elite_rusher.gd:288`）和遗物拾取物周围的漂浮亮点（`scripts/pickups/relic_pickup.gd:164`）仍由代码绘制。攻击范围指示、地面标记、拾取光晕等也存在程序几何，但属于提示层，不等同于命中飞溅。

普通绿色命中粒子 `impact_green` 的实现仍在 `hit_particle_burst.gd`，但当前通用投射物的 `ENABLE_ENEMY_HIT_GREEN_PARTICLES=false`；`weapon_loadout.gd` 的同类辅助函数未查到调用。因此将它列为保留／禁用路径，不能据此说每次普通攻击仍在播放绿色粒子。

## 已经使用 PNG 的主要效果

| 效果 | 当前实现 | 仍需注意 |
| --- | --- | --- |
| 电火花／闪电链与落雷命中飞溅 | `lightning_hit_sprite_burst.gd:8`，4 张核心／辉光 PNG 图集 | 本次 R02 已安装；数量减半、飞溅距离减半，辉光半径保持审阅值，独立于普通粒子池 |
| 水流主体 | `water_wave_effect.gd:13`，`water_d0/d1/d2_p0..3.png` | 仍按细节级别选择不同 PNG，PNG 不代表永不降级 |
| 冻结瞬间／解冻碎冰 | `element_reaction_visual.gd:13`，`freeze_d0/d1.png`、`thaw_d0/d1.png` | 与持续结霜地面、冰壳是不同效果；仍会选低细节 PNG |
| 裂地战锤地裂及多数武器主体 | 如 `earth_hammer.gd:5`、`:223`，读取对应 PNG／图集 | 不能据此推断所有附属命中、拖尾也都是 PNG |

冻结／解冻反应还有单独的限制：反应提示全局上限 96；同种反应在 0.08 秒内、距离小于 8 像素时会合并（湿润扩散除外）。所以“碎冰没有出现”也可能来自反应提示限额／合并，而不是普通粒子池。

## 后续修改建议

优先处理结霜的完整视觉链：地面冰晶、起手碎屑、冻结冰壳和冻结／解冻反馈。先确定要保留的完整外观，再将对应形状烘焙为共享 PNG 帧；把自动省略外围晶体／骨架的规则改为明确的视觉质量下限，并为起手和命中反馈使用独立容量或覆盖旧效果策略。

仅把绘制改为 PNG、继续沿用当前分级和丢弃规则，仍然会出现现在的降级。PNG 可以减少重复生成几何的开销，但显存、透明叠加面积和绘制批次仍需要实机验证；不建议因为“非 PNG”就统一重做所有效果。结霜之后可优先看震荡／雷火和榴弹爆炸，再看光辉剑／黑洞／光折射。
