# 粒子表现系统模块设计

本文档定义基于现有命中粒子效果扩展的战斗粒子表现系统。目标是先统一投射物、射线、爆炸和实体攻击的视觉事件，再逐步增加拖尾、材质粒子和粒子交互；MVP 不追求完整的 Noita 像素物理，而优先保证像素风格统一、可配置、可控性能和容易扩展。

当前已落地：ParticleEvent、ParticleWorld、impact_green、projectile_trail、impact_terrain，以及按武器当前稀有度着色的木箭拖尾。

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
| beam_core | 射线主体预留 | 由线段或窄矩形绘制，不做材质交互 |
| explosion_debris | 爆炸碎片预留 | 多方向碎片，数量受爆炸强度限制 |
| entity_spawn | 实体生成 | 环绕生成点的短时环形粒子 |

MVP 实际优先完成 impact_green、impact_terrain 和 projectile_trail；其余预设只要求配置结构和调用接口稳定。

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

## 5. 与现有武器系统的接口

### 5.1 投射物

ProjectileInstance 在命中敌人或场景时发送 attack_hit_enemy 或 attack_hit_terrain。当前 HitParticleBurst.spawn() 可以作为 ParticleWorld 的兼容适配层，迁移期间不要求一次性重写所有调用者。

### 5.2 射线

射线 MVP 只需要发送 beam_started、beam_hit 和 beam_ended。主体由 BeamRenderer 绘制，末端命中仍由 ParticleWorld 负责。射线沿途粒子必须设置数量上限，不能为每个采样点创建独立 Node2D。

### 5.3 爆炸

爆炸系统发送 explosion_started，并提供半径、方向和强度。ParticleWorld 负责闪光、碎片、烟尘和冲击环；伤害和场景破坏由其他模块处理。

### 5.4 实体

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
