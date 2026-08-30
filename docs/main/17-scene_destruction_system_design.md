# 场景破坏系统模块设计

本文档定义战斗场景中可破坏地形、材质状态和攻击交互的基础方案。

当前已落地：DestructibleTestArea 作为独立战斗测试区域，使用 16 像素网格、StaticBody2D 单元碰撞和木箭点破坏。目标不是立刻复制完整 Noita，而是先建立一个能被投射物、爆炸和射线调用的破坏接口，再逐步增加液体、气体、温度和材质反应。

## 1. 模块目标

1. 让武器命中场景时可以删除、替换或损伤地形单元。
2. 让破坏结果同步更新视觉、碰撞、碎屑和掉落。
3. 将地形材质从 Sprite2D/StaticBody2D 中抽离为可查询的数据。
4. 为木头、石头、土、水、油和火焰等材质交互预留统一接口。
5. 先用分块网格实现稳定 MVP，最终再向像素级材质模拟演进。

## 2. 当前限制

当前战斗场景的主要地面是 ColorRect 加 ShaderMaterial，营地障碍物主要是 StaticBody2D、Sprite2D 和 CollisionShape2D。这些节点适合整体显示和整体碰撞，不适合逐格挖洞、燃烧、流动或重建碰撞。

因此场景破坏不能只在现有 HitParticleBurst 上增加代码，必须增加独立的 DestructibleTerrain 数据层和碰撞同步层。MVP 可以与现有地面视觉并存，先把少量可破坏区域叠加到战斗场景中。

## 3. MVP 方案

### 3.1 技术选择

MVP 使用固定尺寸的二维网格和分块更新，不做真实像素级流体模拟。

建议参数：

1. 网格单元尺寸：8 或 16 个世界像素，根据战斗镜头比例选择。
2. 分块尺寸：每块 16x16 或 32x32 个单元。
3. 每个单元只保存材质 ID、生命值和占用状态。
4. 只有受攻击影响的分块进入更新队列。
5. 视觉使用 TileMapLayer、分块纹理或统一 CanvasItem 绘制。
6. 碰撞按分块重建，不为每个单元创建独立物理节点。

### 3.2 MVP 材质

| 材质 | 固体 | 可破坏 | 反应 |
| --- | --- | --- | --- |
| empty | 否 | 否 | 无 |
| soil | 是 | 是 | 被爆炸挖除 |
| wood | 是 | 是 | 受火焰标记，逐步损坏 |
| stone | 是 | 是 | 需要更高破坏强度 |
| water | 否/液体占位 | 否 | MVP 只作为预留数据 |
| oil | 否/液体占位 | 否 | MVP 只作为预留数据 |

MVP 实际优先完成 empty、soil、wood、stone。water、oil 只要求材料 ID 和事件接口存在，不实现流动。

### 3.3 运行时结构

~~~text
BattleRoot
├─ DestructibleTerrain
│  ├─ TerrainGrid
│  ├─ TerrainChunkRenderer
│  ├─ TerrainCollisionManager
│  ├─ TerrainMaterialRegistry
│  └─ TerrainDebugOverlay
├─ ParticleWorld
├─ Player
└─ Loadout
~~~

### 3.4 单元数据

~~~json
{
  "material_id": "stone",
  "health": 100,
  "solid": true,
  "temperature": 20,
  "flags": []
}
~~~

MVP 可以只实际使用 material_id、health 和 solid，temperature、flags 为最终版本预留字段。

## 4. 破坏事件

所有攻击通过统一 DestructionEvent 进入场景破坏系统：

~~~text
position
shape
radius
strength
damage_type
source_weapon_id
tags
~~~

MVP 支持三种形状：

1. circle：爆炸和冲击波。
2. line：射线或钻取攻击。
3. point：投射物命中点。

处理流程：

~~~text
武器命中
  -> 生成 DestructionEvent
  -> TerrainGrid 查询受影响单元
  -> 根据材质抗性扣除 health
  -> health <= 0 时置为 empty
  -> 标记对应 chunk dirty
  -> 重建视觉和碰撞
  -> 生成 TerrainDebris 粒子
  -> 通知掉落系统
~~~

## 5. 碰撞同步

### 5.1 MVP 规则

1. 只为 solid 单元参与碰撞。
2. 破坏发生后只重建受影响分块及其相邻分块。
3. 使用分块合并后的矩形或多边形碰撞，不创建单元级 StaticBody2D。
4. 投射物命中查询必须同时支持敌人和 DestructibleTerrain。
5. 玩家和敌人是否能穿过被破坏区域，由重建后的碰撞直接决定。
6. 碰撞重建在事件批次结束后执行，避免同一帧反复创建形状。

### 5.2 与当前场景的接入

1. 保留当前 BattleEnvironment 的 ColorRect 作为背景和氛围层。
2. 在 BattleRoot 下新增 DestructibleTerrain 节点。
3. 第一张测试地图只放置有限数量的 soil、wood、stone 分块。
4. 将现有 ProjectileInstance 的碰撞查询扩展为敌人或地形二选一。
5. 破坏后由 ParticleWorld 使用 impact_terrain 或 explosion_burst 预设表现碎片。
6. 初期不改写营地障碍物场景，战斗可破坏地形使用独立的战斗地图数据。

## 6. MVP 材质规则

### soil

1. 受到 point 或 circle 破坏时直接扣除 health。
2. 破坏后生成少量土色碎片。
3. 不产生连锁反应。

### wood

1. 普通投射物可以造成少量损伤。
2. 爆炸造成较高损伤。
3. 被 fire 标签命中后进入 burning 标记。
4. MVP 中 burning 只按固定间隔扣血，不传播到相邻单元。

### stone

1. 普通木箭只造成很小损伤或不造成损伤。
2. 爆炸按 strength 扣血。
3. 被破坏后生成较重、速度较低的碎片。

## 7. 掉落和破坏反馈

MVP 不把每个地形单元都设计成掉落源，只在以下情况生成掉落：

1. 一次爆炸破坏达到配置阈值。
2. 破坏特殊材质块。
3. 破坏预设宝箱或矿脉节点。

地形碎屑属于视觉粒子，不进入拾取系统；术士卷轴等正式掉落由 DestructionSystem 发出统一的 drop_requested 事件，再由现有 DropRewardSystem 决定实例化哪种拾取物。

## 8. 性能与安全边界

1. 只更新 dirty chunk，不全图扫描。
2. 单次攻击设置最大破坏单元数。
3. 单帧合并相邻 DestructionEvent。
4. 碰撞重建设置每帧预算。
5. 地形渲染、碰撞和材质数据分离。
6. 破坏数据不通过大量 Godot Node 表示。
7. 调试模式显示 dirty chunk、被修改单元数和碰撞重建耗时。
8. 移动端默认降低网格分辨率、粒子数量和碰撞更新频率。

## 9. MVP 验收标准

1. 测试房间包含 soil、wood、stone 三种可破坏材质。
2. 木箭可以命中地形并产生 point 破坏结果。
3. 爆炸可以按半径破坏一片连续区域。
4. 被破坏区域视觉上变为空洞，且玩家、敌人和投射物可以通过。
5. 破坏后只重建受影响分块，不影响整张地图的正常运行。
6. 地形碎片由粒子系统生成，不新增大量独立碎片节点。
7. 场景破坏事件可以触发后续掉落，但 MVP 不要求实现全部晶石和卷轴。
8. 暂停、重启波次和战斗结束时不会残留失效碰撞体。

## 10. 非 MVP 内容

MVP 暂不实现：

1. 真正的逐像素独立材质模拟。
2. 液体流动、气体扩散和压力传播。
3. 温度扩散、燃烧传播和熔化链。
4. 复杂材质反应，例如水灭火、油助燃、酸腐蚀。
5. 地形永久保存和跨房间恢复。
6. GPU/Compute Shader 驱动的全屏材料模拟。

## 11. 最终版本期望

最终系统应以分块像素材质网格为核心，支持固体、液体、气体和温度状态的局部模拟；攻击、粒子、材质反应和掉落通过事件互相连接。玩家可以用不同武器挖洞、点燃、冻结、融化、腐蚀或改变地形，场景结果可由种子确定性重演，并根据设备性能自动调整模拟分辨率和更新预算。

## 12. Current MVP Integration

- Wood arrows still only target enemies; terrain is damaged only when the flying projectile actually collides with it.
- Explosion enchantments call `destroy_radius_with_materials`, clearing test-area cells and disabling their collision shapes; the returned soil, wood and stone records drive material-specific debris particles.
- Fire pools affect entity status only and do not spread through neighboring terrain cells yet.
- `DropRewardSystem` spawns scroll, gem and wizard-scroll pickups; pickup applies the item to the current first weapon.
- Liquid, gas, temperature diffusion and pixel-material reactions remain final-version chunk simulation work.
