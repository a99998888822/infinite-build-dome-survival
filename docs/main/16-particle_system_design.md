# 粒子表现系统模块设计

本文档定义基于 Noita 中文站资料方向的战斗粒子表现系统：以“法术组合 + 粒子群表现 + 材料/场景反应”作为统一设计语言，覆盖投射物、射线、爆炸、实体、元素附魔、状态效果和场景破坏。MVP 不复制 Noita 的素材或实现，也不直接实现完整像素物理，而是先建立可运行、事件驱动、粒子可组合的基础。

当前已落地：ParticleEvent、ParticleWorld、impact_green、projectile_trail、impact_terrain，以及按武器当前稀有度着色的木箭拖尾。

## 0. Noita 中文站整体参考基线

本模块的视觉和运行时设计整体参考 Noita 中文站中关于法术、投射物、材料反应、元素状态和粒子表现的组织方式，而不是只参考闪电：

1. **法术组合**：武器负责发射载体，附魔/术士卷轴负责追加效果、参数和视觉标签；粒子系统读取最终 EffectContext，不把附魔硬编码进单个投射物。
2. **投射物表现**：投射物由本体、拖尾、命中爆发和后续元素事件组合而成；飞行中的粒子只表现运动，不承担伤害碰撞。
3. **射线表现**：射线使用带有抖动、分叉和衰减的随机路径，并沿控制点段绘制小型方形粒子；命中爆发仍由粒子系统表现，路径采样不创建独立粒子对象。
4. **爆炸表现**：爆炸由瞬时核心、向外扩散的亮粒子、碎片、烟尘和材质反应共同组成；范围伤害、场景破坏和视觉粒子分层处理。
5. **元素状态**：火焰、闪电等状态由持续生成的粒子群表现，并可影响敌人状态、背景染色、发光层和其他效果；状态本身不直接等同于一张贴图。
6. **材料与场景反应**：MVP 使用独立的场景破坏与效果事件模拟材料反应；最终版本再扩展液体、气体、粉末和燃烧传播等像素级材料系统。
7. **像素可读性**：优先使用少量高对比、短生命周期、具有方向性的方块/像素粒子，避免大面积平滑线条和连续几何体掩盖粒子结构。
8. **性能边界**：所有效果都必须接受粒子预算、发射频率、可见范围和优先级裁剪；命中核心粒子优先于拖尾、烟尘和远处装饰粒子。

参考入口：Noita Wiki 中文站（仅作机制与视觉方向参考，不复制素材、数据或代码）：https://noita.wiki.gg/zh

## 1. 模块目标

1. 将现有 HitParticleBurst 从单一命中火花扩展为通用 ParticleWorld。
2. 用数据配置描述粒子数量、颜色、速度、重力、阻力、生命周期和形状。
3. 让武器逻辑只发送攻击/命中/爆炸事件，不直接拼接具体粒子表现。
4. 为投射物、射线、爆炸、实体四类攻击提供统一的视觉入口。
5. 为后续元素附魔、拖尾、材质反应和场景破坏预留事件与配置字段。

## 2. 当前基础

当前命中粒子实现位于 scripts/effects/hit_particle_burst.gd，特点是：

1. 动态创建 Node2D，不依赖粒子场景。
2. 每次生成 14 个像素矩形粒子。
3. 粒子拥有速度、重力、阻力、旋转、自转、大小和生命周期。
4. 通过 _draw() 绘制，位置取整以保持像素清晰度。
5. 通过 burst_direction 让粒子沿攻击方向散开。

MVP 应保留这套实现的优点，不立即改成大量 GPUParticles2D 节点。后续如果粒子数量成为瓶颈，再把多个 Burst 合并到一个 ParticleWorld 中统一更新和绘制。

## 3. MVP 范围

### 3.1 主要交付内容

1. ParticleEvent：统一描述发射点、方向、强度、标签和来源。
2. ParticleProfile：统一描述一种粒子预设的视觉和运动参数。
3. ParticleEmitter：根据事件和预设生成粒子。
4. ParticleWorld：集中管理粒子、暂停、上限、清理和绘制层级。
5. ImpactProfile：命中敌人、命中地形、爆炸和实体生成分别使用独立预设。
6. 武器接入适配：将当前 WeaponLoadout、ProjectileInstance 的命中特效入口改为事件派发。
7. 视觉去重：保留当前按物理帧限制反馈的规则，避免多目标命中时粒子过密。

### 3.2 MVP 粒子种类

| 预设 | 用途 | 基础表现 |
| --- | --- | --- |
| impact_green | 木箭命中敌人 | 绿色方块向攻击方向爆散 |
| impact_terrain | 木箭命中墙体 | 土石碎片，速度较低，重力更明显 |
| projectile_trail | 木箭飞行 | 少量短命淡色方块，不参与伤害 |
| beam_core | 射线主体预留 | 由小型方形粒子绘制，不做材质交互 |
| explosion_burst | 爆炸附魔 | 同尺寸小方块向四周散开，无重力下坠 |
| electric_spark | 电火花附魔 | 命中点旋转黄色虚线圈，延迟落下高空闪电 |
| entity_spawn | 实体生成 | 环绕生成点的短时环形粒子 |

MVP 实际优先完成 impact_green、impact_terrain、projectile_trail、explosion_burst 和 electric_spark；其余预设只要求配置结构和调用接口稳定。

### 3.3 粒子配置结构

~~~json
{
  "id": "impact_green",
  "shape": "rect",
  "count": 14,
  "colors": ["#2B6145", "#5DBA79"],
  "size": {"min": [4, 4], "max": [7, 8]},
  "speed": {"min": 60, "max": 170},
  "lifetime": {"min": 0.34, "max": 0.58},
  "gravity": {"min": 55, "max": 120},
  "drag": {"min": 35, "max": 80},
  "spread_degrees": 130,
  "fade": "quadratic",
  "pixel_snap": true
}
~~~

字段只描述表现，不携带伤害、碰撞和掉落规则。表现参数与攻击规则分离，才能让同一套粒子预设被武器、敌人技能和场景破坏复用。

## 4. 运行时结构

~~~text
BattleRoot
├─ ParticleWorld
├─ DestructibleTerrain
├─ Player
├─ Loadout
├─ WaveManager
└─ HUD

ParticleWorld
├─ ParticleEmitter
├─ ParticleBuffer
├─ ParticleProfileRegistry
└─ ParticleDebugOverlay
~~~

### 4.1 事件结构

攻击模块只发送以下事件：

~~~text
attack_started
projectile_spawned
projectile_trail_tick
attack_hit_enemy
attack_hit_terrain
explosion_started
entity_spawned
entity_expired
~~~

每个事件至少包含：

~~~text
position
 direction
 intensity
 source_weapon_id
 tags
 visual_profile_id
~~~

附魔或元素效果只增加 tags 和 profile_id，例如 fire、ice、split、terrain_break，不直接修改 ParticleWorld 的内部状态。

### 4.2 生命周期

1. ParticleWorld 接收事件。
2. 根据 profile_id 读取 ParticleProfile。
3. 按 intensity 缩放数量、速度或范围，并应用全局上限。
4. ParticleEmitter 将粒子写入统一缓冲区。
5. 每帧更新运动、透明度和旋转。
6. 粒子生命周期结束后从缓冲区移除或回收到对象池。
7. 战斗暂停时停止模拟，不清除尚未结束的粒子。

### 4.3 动态效果运行时

粒子不直接读取角色或武器属性，而是由 `EffectContext` 合并角色、武器等级、附魔和卷轴的效果修改器，再交给动态发射器运行。玩法参数与表现参数分离：伤害、范围、持续时间和连锁次数在效果创建时确定；粒子速率、速度、颜色、发光和扰动可在运行时刷新。

```text
属性/附魔/卷轴
  -> EffectContext + EffectModifier
  -> ParticleEmitterRuntime / EffectRuntime
  -> ParticleWorld
```

运动行为采用可插拔模式，MVP 先支持 `attached`、`linear`、`boomerang` 和 `orbit`。`projectile_count` 控制独立投射物/发射器数量，`area_size` 控制效果范围与粒子散布，`control_power` 由具体效果绑定控制强度或连锁参数；穿透与分裂属于投射物附魔行为，不属于角色属性。粒子本身不承担伤害碰撞；回旋、火焰池、闪电连锁等效果由独立运行时处理，ParticleWorld 只负责动态视觉。

当前编码阶段先实现 `EffectContext`、`EffectModifier`、`EffectParameterResolver`、`ParticleEmitterRuntime` 和 `ParticleMotionBehavior`，并将木箭拖尾迁移到动态发射器；火焰、爆炸和闪电在此基础上扩展。

MVP 附魔卷轴：`scroll_split` 在命中敌人后生成有限数量子投射物，子投射物只分裂一次并优先寻找未命中的敌人；`scroll_pierce` 通过 `extra_target_hits` 提供投射物级后续命中次数。两者均由物品实例参数驱动，不再依赖角色全局投射物属性。

## 5. 与现有武器系统的接口

### 5.1 投射物

ProjectileInstance 在命中敌人或场景时发送 attack_hit_enemy 或 attack_hit_terrain。当前 HitParticleBurst.spawn() 可以作为 ParticleWorld 的兼容适配层，迁移期间不要求一次性重写所有调用者。

### 5.2 射线

射线 MVP 只需要发送 beam_started、beam_hit 和 beam_ended。主体由轻量路径节点绘制小型方形粒子，末端命中仍由 ParticleWorld 负责。射线沿途采样只写入共享路径数组，不能为每个采样点创建独立 Node2D。

### 5.3 爆炸

爆炸系统发送 explosion_started，并提供半径、方向和强度。ParticleWorld 负责闪光、碎片、烟尘和冲击环；伤害和场景破坏由其他模块处理。

### 5.4 电火花附魔

ProjectileInstance 命中敌人或场景后发送电火花效果事件。效果节点固定保存命中点，在 `0.5` 秒预警窗口内绘制旋转的黄色虚线圆圈；延迟结束后在圆心触发一次从 `260px` 高度落下的闪电像素路径，并重新查询圆圈范围内的敌人造成伤害。闪电路径复用闪电附魔的随机控制点和小型方块采样逻辑。

### 5.5 实体

实体类武器只发送 entity_spawned、entity_hit 和 entity_expired。实体自身可持有一个或多个 emitter 配置，但不能直接访问全局绘制缓冲区。

## 6. 性能与约束

MVP 必须具备以下硬限制：

1. 全场粒子数量上限。
2. 单次事件粒子数量上限。
3. 拖尾发射频率上限。
4. 只更新当前战斗场景可见范围内的粒子。
5. 视觉粒子默认不参与物理碰撞。
6. 超出上限时优先丢弃拖尾和烟尘，保留命中核心粒子。
7. 调试模式显示当前粒子数量、每帧发射量和丢弃量。

## 7. MVP 验收标准

1. 木箭命中敌人时，视觉效果与当前 HitParticleBurst 一致或更稳定。
2. 木箭飞行时可以显示短拖尾，拖尾不影响伤害和碰撞。
3. 命中地形时可以使用另一套碎片预设。
4. 同一物理帧的多次命中不会无限叠加核心特效。
5. 暂停战斗时粒子停止运动，恢复后继续。
6. 粒子预设只通过配置切换颜色、数量和运动参数，不改攻击脚本。
7. 后续新增火焰、冰霜或虚空粒子时，不需要修改 ProjectileInstance 的核心生命周期。

## 8. 非 MVP 内容

MVP 暂不实现：

1. 粒子之间的真实碰撞。
2. 粒子对材质的直接反应。
3. 液体、气体、火焰的连续模拟。
4. GPU 粒子和计算着色器方案。
5. 粒子永久改变场景状态。

## 9. 最终版本期望

最终粒子系统应成为一个按事件驱动的表现层：同一攻击事件可以同时驱动投射物拖尾、命中碎片、爆炸烟尘、元素粒子和材质反应粒子；粒子拥有有限的碰撞和材质标签，可与场景破坏系统交换事件，但仍与伤害结算解耦。系统最终支持对象池、分块更新、GPU 辅助绘制、元素附魔预设、屏幕空间后处理和可回放的确定性随机种子。

## 10. Current MVP Implementation

- Wood-arrow impact events enter `CombatEffectWorld`; the starter wood arrow has the `lightning` effect.
- Fire uses invisible scattered seed logic and `FirePatch` collision; its visible seeds, embers and ground fire are all emitted particles. The pool distributes flame clusters across an elliptical footprint instead of drawing a pool shape, lasts about two seconds, and burning damage is an independent enemy status.
- `FirePatch` is logic-only: it has no `_draw()` flame geometry. Each pool uses four low-rate child emitters for base flame, tongues, hot core and embers, all rendered by the shared `ParticleWorld`.
- Fire particles use a shared active-particle budget (`MAX_FIRE_PARTICLES`) and pool-level light refresh, avoiding one light source per particle and preventing stacked fire pools from flooding the frame.
- Explosion uses one unified `explosion_burst` profile: identical `4x4` square particles (96 base particles) are born at the exact explosion center and spread in all directions with zero gravity, zero drag and no falling debris. Explosion damage falloff is configurable and defaults to 0.0 for fixed damage inside the radius; terrain destruction can add one secondary burst at the same center.
- Lightning is triggered only after a projectile hits an enemy: the first target is the impact source, and a lethal projectile hit still allows the chain to search for the next live enemy.
- Lightning paths use short-lived randomized white pixel arcs: 24-pixel control points, densely sampled small rectangular particles with per-particle random rotation and subtle white glows; no continuous line geometry is drawn, and hit flashes and sparks remain ParticleWorld effects.
- Split child projectiles have no trail and do not create projectile-trail emitters.
- Each chained hit emits a white flash, radial white sparks and a particle-only caterpillar-like paralysis visual; the gameplay stun is a separate short-lived enemy status.
- `ParticleLightField` provides short-lived background tint and glow; `EffectContext` can modify emission, size, speed, glow and damage.
- Enchantment scrolls and wizard scrolls live in `augmentations.json`, use `EffectModifier`, and use the existing `drop_rate_percent` formula.
- Each dropped lightning scroll rolls independent instance parameters: `chain_count` 2–5 follow-up transfers, `chain_interval` 0.08–0.16 seconds, and `stun_duration` 0.45–1.10 seconds; the starter scroll remains fixed at 3, 0.10 seconds and 0.70 seconds.
- The `scroll_electric_spark` enchantment marks the projectile impact position with a rotating yellow dashed ring, waits 0.5 seconds, then calls a high-altitude pixel lightning strike and damages enemies inside the marked radius.
- This is an executable MVP, not full Noita pixel physics: particles do not own collision, and terrain destruction remains a separate system.

### 10.1 Noita 中文站整体对标清单

- **投射物**：本体 + 短拖尾 + 命中粒子 + 附魔事件；附魔只有在命中有效目标后生效。
- **射线**：沿 24 像素控制点以约 3.25 像素间隔绘制带微抖动和随机旋转的白色小型像素矩形，叠加低透明度白色光晕，不绘制连续线段；命中点继续使用粒子爆发。
- **火焰**：由多层橙/红/黄正方形粒子、上升运动、短寿命、局部光照和背景染色组合成火焰形状；火焰池与燃烧状态分离。
- **火焰池 MVP**：发射器只在地面附近生成正方形粒子；横向位置决定可达到的最大高度与寿命，中心粒子上升更高、边缘粒子更快消散；颜色按橙色→黄色→黄白色三阶段渐变，不绘制三角形或其他火焰几何体。
- **爆炸**：由同尺寸的 `4x4` 小型方形粒子从爆炸中心向四周散开，基础数量为 96，不使用重力、阻力或下坠碎片；视觉、伤害、场景破坏分别处理。
- **闪电**：由白色小型像素矩形沿随机路径连接敌人，粒子带随机旋转和轻微白色发光以打散虚线观感；命中点使用白色径向粒子爆发；麻痹状态使用跟随敌人的环绕粒子，并由独立状态控制短暂停止移动。掉落卷轴的连锁次数、传递间隔和麻痹时间按实例独立随机。
- **电火花**：命中点先显示旋转的黄色虚线圆圈，延迟 0.5 秒后从较高位置劈下参考闪电附魔的白色像素闪电；落雷路径上部和下部较窄、中段较宽，并在圆圈范围内造成伤害。
- **实体**：实体拥有独立生命周期和粒子发射器，可追加跟随、围绕、返回等运动行为。
- **材料反应**：最终版本允许粒子标签与材料系统交换事件；MVP 保持场景破坏系统独立，避免把伤害碰撞写入粒子层。

所有参考仅用于机制拆解、视觉语言和验收标准，不复制 Noita 的素材、实现或数据。
