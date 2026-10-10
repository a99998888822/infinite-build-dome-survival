# 主战斗场景：圆形与椭圆投影排查

日期：2026-10-10。此次仅排查与整理，未修改正式代码、美术资源或伤害判定。

确认仍有 **10 处地面标记／特效采用正圆逻辑或近正圆轮廓**；另有 **5 类圆弧扇形**尚未采用地面投影。主要集中在移星秘典、冥狼、水波、雷击落地环和光剑落点标记。

检查覆盖当前 14 种武器共用的指示器入口、位移武器、怪物技能预警、元素效果、移动标记、状态标记、拾取物与当前草地场景。核对了绘制入口、父级／局部缩放、实际 PNG 抽帧；不能仅凭 `draw_circle()`、正方形纹理尺寸或圆形碰撞器判定最终显示形状。

## 1. 当前投影基准

项目使用二维战斗坐标与斜视美术，当前 `CombatRenderWorld` 没有对所有对象统一压缩 Y 轴。因此某处直接画圆，未另做局部缩放或使用已压扁素材时，最终仍是圆形。

已有大面积地面范围采用高宽比 **145 / 220 ≈ 0.659**，定义于 [attack_footprint.gd](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/attack_footprint.gd:5)。可把它作为武器范围、落点预警与地面冲击环的共同参考；它是项目既有美术／范围约定，不是从真实三维摄像机反推的精确投影参数。

角色接触影、草根阴影可以更扁。球体、竖直法印、悬浮粒子、字体和 HUD 不应套用同一比例。

## 2. 明确仍为圆形的 10 处

这里按用途计数，多个描边／填充属于同一处；像素环的缺口与不规则碎片不改变其按圆形半径生成的事实。

| 编号 | 对象 | 当前证据 | 建议 |
| --- | --- | --- | --- |
| 01 | 移星秘典：闪现落点范围圈 | [mobility_weapon_indicator.gd:165](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/mobility_weapon_indicator.gd:165) 调用 `ring(landing, radius)`；`ring()` 用相等的 X／Y 半轴。外层可移动范围已是椭圆，内层落点圈却仍为圆 | 高优先级。与外层及其他地面范围统一为椭圆；核对落地伤害范围语义 |
| 02 | 移星秘典：可返回位置的指示圈 | [同文件:156](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/mobility_weapon_indicator.gd:156) 使用半径 24 的正圆；这是指示器叠加圈，区别于已经重绘的地面星印 PNG | 高优先级。改外圈与地面方向；中心星号作为识别符号可保持清晰 |
| 03 | 巨型手持火炮：后撤终点小圈 | [同文件:150](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/mobility_weapon_indicator.gd:150) 使用半径 12 的正圆 | 中优先级。作为地面落点标记改成小椭圆，后撤距离与终点不变 |
| 04 | 移星秘典：落地冲击环 PNG | `star_shockwave.png` 是圆形分段带；[mobility_weapon_runtime.gd:74](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/mobility_weapon_runtime.gd:74) 对移星仍使用 `Vector2.ONE`，仅短刃使用椭圆比例。抽帧可见范围 114×118，接近正圆 | 高优先级。与 01 配套调整环带轨迹、缺口和碎片落点；保留晶片的厚度与像素尺寸 |
| 05 | 水元素：水波扩散 PNG | [water_wave_effect.gd:143](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/water_wave_effect.gd:143) 等比绘制 112×112 图集格。检查 12 张图集的第 10–40 帧，共 372 帧，可见范围高宽比约 0.95–1.06；不是已烘焙好的地面椭圆 | 高优先级。水波主体改为椭圆扩散。水花可以保留向上的体积，不能一并压成薄片；检查原圆形作用范围 |
| 06 | 光剑附魔：落地前的小标记 | `assets/effects/pixel_baked/sword_mark.png` 可见范围 22×22；[light_sword_effect.gd:192](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/light_sword_effect.gd:192) 在地面层等比绘制。低细节级别会隐藏该标记 | 中优先级。只调整地面标记，保留竖直光剑本体。该小圈不是完整伤害半径的精确显示 |
| 07 | 冥狼：出生预警圈 | [underworld_wolf.gd:328](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/underworld_wolf.gd:328) 绘制半径 36 的整圆；前面的影子变换已重置，出生圈没有继承压扁 | 中优先级。与冥狼脚底接触影采用一致的地面方向 |
| 08 | 冥狼：跳扑落点预警 | [同文件:342](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/underworld_wolf.gd:342) 的红色填充、外轮廓与进度弧全按 `leap_radius` 画正圆 | 高优先级。三个层次一同调整；实际攻击入口和 `area_damage()` 目前仍按圆形距离判断，必须同时确定判定方案 |
| 09 | 冥狼：落地后的蓝色扩散环 | [同文件:353](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/underworld_wolf.gd:353) 正圆扩散，外围碎块也以等半径 X／Y 分布 | 高优先级。与跳扑预警配套，避免“椭圆预警、圆形收尾”；碎块的地面运动轨迹同步调整 |
| 10 | 落雷：触地后的黄色扩散环 | [lightning_particle_effect.gd:468](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/lightning_particle_effect.gd:468) 在约 0.42 秒内用 `draw_circle()` 和 `draw_arc()` 扩散，半径从 7 增至伤害半径。落雷前的黄色粒子预警已经是椭圆，前后不一致 | 高优先级。只调整触地扩散层与相关地面轨迹，保留竖直雷柱、命中闪光和飘字 |

## 3. 不是整圆，但仍使用圆弧扇形的 5 类

| 对象 | 入口／现状 | 调整时的重点 |
| --- | --- | --- |
| 营地短刀指示器 | [weapon_attack_indicator.gd:118](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/weapon_attack_indicator.gd:118)，内外弧都是 `Vector2.ONE * radius` | 地面范围扇形可以投影；持刀动作、目标命中路径不能只靠压扁整个武器节点处理 |
| 流星摆锤指示器 | 与短刀共用 `_fan()`，圆弧形扇面 | [摆锤拖影](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/meteor_flail.gd:201) 也按圆形挥动轨迹对齐锤头，尚未做地面 Y 压缩。若改变挥动平面，要联合检查锤头、链条、拖影与命中轨迹 |
| 赤铜炉灯指示器 | [weapon_attack_indicator.gd:124](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/weapon_attack_indicator.gd:124)，末端截在圆形半径上 | 已获批喷火的像素组织无需重做；指示器、火焰覆盖和射程裁剪须一致，不能只压扇面 |
| 巨型手持火炮散射扇面 | [mobility_weapon_indicator.gd:134](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/mobility_weapon_indicator.gd:134)，散射末端用等半径圆弧 | 对照真实弹道角度与射程，避免投影后的扇面不再覆盖实际弹丸 |
| 冥狼吐息预警 | [underworld_wolf.gd:74](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/underworld_wolf.gd:74) 构造圆弧扇形，同时交给绘制与碰撞形状；[338 行](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/underworld_wolf.gd:338) 还有进度弧 | 不能仅改变进度弧：填充、外框、吐息方向及碰撞多边形需要一起核对 |

这些扇形包含方向和命中信息，建议作为独立批次处理。若要表达地面上的扇形，应先在地面平面确定朝向，再投影并对齐最终屏幕方向。先压扁再随意旋转，会把椭圆的短轴一起转斜，仍然不符合统一地面视角。

## 4. 其他可优化项，不混入上述 10 处

| 对象 | 判断与建议 |
| --- | --- |
| 战斗教程中的移动目标双圈 | [combat_guide_overlay.gd:27](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/combat_guide_overlay.gd:27) 是画在界面上的两个圆，语义却是地面位置。可改椭圆或与正式移动标记统一，优先级低于实战危险预警 |
| 共享柔光／火场照明 | [particle_light_field.gd:72](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/particle_light_field.gd:72) 使用等半径圆盘；火场也调用此入口。地面照明可以扁一些，但该通道被多种效果共用，建议先区分地面光与悬浮辉光，不整体压缩所有光斑 |
| 榴弹飞行中的四点落点准星 | [grenade_projectile.gd:185](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/grenade_projectile.gd:185) 四个点按等距离十字分布，并非完整圆圈。可微调上下间距，与已是椭圆的爆炸指示器协调 |
| 旧非主动榴弹分支 | `GrenadeProjectile.elliptical_blast` 默认仍为 `false`，旧 `weapon_loadout._fire_grenades()` 未置为椭圆；当前主动战斗入口明确设为 `true`，反弹与分裂传递该行为。此项属于兼容分支，不当作当前默认战斗的未修复圆圈 |

## 5. 已是椭圆或已有地面投影，不应重复压缩

| 对象 | 核对结果 |
| --- | --- |
| 突进短刃移动范围、落点指示器、落地斩击 | 已使用 0.659 的显示比例。斩击 PNG 源格为正方形，但运行时会压扁，不能按文件尺寸误判。现有圆形碰撞保留是此前用户明确允许的取舍 |
| 移星秘典外层移动范围 | `get_movement_axes()` 已返回不同的 X／Y 半轴，问题在内层落点圈及冲击环 |
| 移星原位星印 PNG | 已经画成扁的阶梯外环。生成点的主半轴为约 23／16，可见整体含底影和中心星，抽帧范围 102×78。不是正圆；若要进一步统一到 0.659，应调整外环，不能再把整张星印机械乘 0.659 |
| 坤舆秘仪书领域圈与地面符文 | 基准半轴 220／145；PNG 的环形与星芒也已有地面压缩，抽帧范围 351×217。与目标身上的命中符印是两层效果 |
| 铸铁榴弹炮：当前主动战斗范围、落点与爆炸 | 指示器使用共享椭圆半轴；正式主动爆炸绘制也压缩 Y，分裂继续继承 |
| 落雷前黄色粒子预警 | [electric_spark_warning_png.gdshader:15](D:/project/useless/resources/infinite-build-dome-survival/assets/shaders/electric_spark_warning_png.gdshader:15) 的轨道基准是 23／14，已经是椭圆。8×8 小粒子的局部形状不等于整体预警形状 |
| 冰霜领域、冰霜扩散前沿、脚下减速纹理 | 虽然调用图集时等比缩放，PNG 已烘焙了扁平图形；抽帧可见范围分别为 88×52、146×75、32×20 |
| 玩家脚底标记、冥狼脚底影 | 分别使用 `Vector2(1, 0.42)` 与 `Vector2(1, 0.3)` 的绘制变换 |
| 草根接触影、遗物落地影、电浆球落地影 | 当前草地脚底阴影以 22×7 四边形显示；遗物为 12／3 椭圆半轴，电浆落地层同样单独使用扁椭圆 |
| 黑洞地面影 | `hole_shadow.png` 已扁平，抽帧范围 32×12；与正圆悬浮核心是两层 |
| 裂地战锤的 R02 地面碎块 | 地面运动的 Y 已乘 0.65，不是未处理的整圆爆点 |

当前主战斗地表是 `MeadowBattleBackdrop`，旧湿地的 `wet_stone_floor.gdshader` 水纹不属于默认草地场景；旧着色器本身也用 `vec2(1, 1.85)` 压扁水纹，不能列为当前正圆问题。

## 6. 应保持体积或界面形状的项目

- 电浆球的圆形本体、黑洞的悬浮核心与空间吸入线：可以保留圆形。只有明确表示地面范围或投影的那一层需要椭圆化。
- 光剑本体、移星闪现晶片、火焰、蒸汽、命中爆点：属于竖直或立体效果，不整体压扁。风刃和蝙蝠声波随飞行方向表现体积，也不等同于地面圆圈。
- 秘仪书目标上的指纹状命中符印、钱币命中圈：当前是覆盖目标的短时命中图形，不是范围预警；若后续改成“地面法阵”，再单独改变投影。
- 头顶日光／暗眼状态图标、霸体描边与飘字、债务目标头顶标志、武器栏冷却、金币到期倒计时圈、摇杆与普通图标：遵循角色轮廓或屏幕空间，不因地面视角而压扁。
- 正式移动终点使用 `assets/ui/combat/move_destination.png` 的八帧绿色星形标记，已经不是双圆。精英冲锋和蝙蝠声波预警是路径条，也不属于圆形遗漏。
- 指示器中间的玩家避让孔虽由圆形距离裁剪，却是用于让玩家可见的遮罩，不是地面范围边界；不能仅为统一比例就缩小上下避让空间。
- `CircleShape2D`、拾取半径、索敌范围等不可见逻辑，不纳入美术形状遗漏清单。

## 7. 建议实施顺序与验收

1. **先处理成套表现不一致的地方**：移星落点／返回圈／落地冲击环；冥狼出生／跳扑预警／落地扩散。保持指示与结果在同一地面平面。
2. **再处理明确的地面特效**：水波、落雷触地环、光剑落点、火炮后撤点。参考 0.659，保留像素网格、环带厚薄和抬起的碎片／水花。
3. **单独审阅方向性扇形**：短刀、摆锤、炉灯、火炮散射、冥狼吐息。联合检查水平、竖直和斜向瞄准，不直接对整个武器／怪物节点缩放。
4. **最后检查柔光和教程一致性**，不把无伤害语义的微小圆点当作优先问题。

危险预警必须和真实可命中区域协调。冥狼当前的扑击伤害依然按圆形距离结算；如果预警纵半轴改成 `0.659r` 而伤害不变，中心正上／正下约 `0.659r` 至 `r` 的区域就会出现视觉圈外仍可能受伤的问题，角色碰撞体还会进一步影响边界。玩家技能也需要明确选择：保持既有玩法并接受装饰性投影，或同时调整范围查询；不要把此前仅针对短刃的取舍自动推广到怪物危险预警。

美术检查时把地面轨迹、向上高度与图标尺寸分开：压扁的是地面上的圆形轨迹，不是所有像素块。最终显示坐标仍对齐像素网格，避免非整数整体缩放让轮廓粗细跳变。已烘焙椭圆的素材只能投影一次。

本轮依据静态代码、父级变换和现有资源抽帧判断，未进行新的整场实机录像。未来修改需验证实际层级、遮挡、各朝向、范围加成和预警／伤害边界。

## 8. 附件

- [16 项正式素材抽帧核对图](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/ground_projection_audit_20261010/asset_contact_sheet.png)：不是实机截图；按有关显示纵横比例展示，图块未统一为游戏大小，秘仪领域符文仅在检查图中提高了透明度。
- [抽帧来源与可见范围](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/ground_projection_audit_20261010/asset_samples.json)。可见范围只作辅助证据，不能代替地面主体轮廓判断。
- [12 张水波图集的 372 帧范围统计](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/ground_projection_audit_20261010/water_frame_bounds.json)。
