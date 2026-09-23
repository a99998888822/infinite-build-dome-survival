# 冲刺精英资源制作规格

日期：2026-09-23。

用户已确认：精英体型大、sprite 完全重绘、具备小冲刺、提前显示 30% 不透明度红色矩形路径，无箭头、无圆角。追加要求：不用 API，直接绘制透明 PNG，克苏鲁风格约 10%。已接入精英场景、生成、冲刺和遗物掉落物；幸运乘区及属性 UI 另行接入。

## 制作状态

- 已直接绘制原创像素角色，六组动作共 23 帧，输出透明 RGBA PNG；未调用图像模型或 API。
- 制作源为 `scripts/tools/build_elite_rusher_assets.py`，使用 Pillow 按手写像素图形、色块和动作姿态绘制。普通怪与玩家图片仅用于预览中的尺寸对比，不采样进新角色。
- 已制作独立冲刺路径 SVG 与 PNG，PNG 所有像素 alpha 为 77（8 位通道对 30% 的近似），四角完整，无箭头或镂空。
- 已生成 Godot `SpriteFrames` 资源，包含全部动画、帧区域、循环和帧时长；已由 `EliteRusher` 驱动实际角色动作。
- 预览图、逐帧联系表、动作 GIF 和结构校验报告位于 `artifacts/elite_rusher_assets_20260923/`。
- 新增攻击专项演示：`elite_rusher_attack.gif` 为正常速度，`elite_rusher_attack_slow.gif` 为半速，`elite_rusher_attack_keyframes.png` 为完整分镜，`elite_rusher_attack_review.html` 可暂停、拖动时间轴、慢放和左右翻转。演示组合既有帧表与固定红色预警路径，冲刺 240 像素；尚不是游戏碰撞/伤害实现。

## 造型

暂定名“裂甲奔袭者”，资源前缀 `enemy_rift_rusher`。

- 沿用干净、轮廓清晰、轻微可爱的像素风，克苏鲁元素约占 10%，通过小型口部触须与低饱和细节表达；避免写实腐烂、血腥和细碎噪点。
- 新设计为低重心、厚甲壳、强壮前肢的四足怪；背部隆起，前部有短而结实的撞角或甲盾，清晰的单眼用于辨认面向。
- 配色参考现有普通怪与猎人：深青黑轮廓、灰绿甲壳、浅骨色高光，少量暖色眼部。不依靠整身红色识别精英，保留红色给技能危险提示。
- 采用右向偏侧俯视视角，向左由水平翻转完成。不要直接放大、描摹或换色普通怪；参考图仅约束画风、材质和世界观。
- 普通怪战斗贴图可见范围为 44×39 像素；新精英待机可见范围为 87×80（含角和触须），约 2 倍，主体甲壳与四肢略小于此包围盒。尺寸以非透明范围衡量，透明画布为 128×128。

参考图：`assets/sprites/enemies/enemy_gloom_mite_idle.png` 与 `assets/sprites/player/void_hunter_idle_right.png`，均只作为画风参考。

## 帧表与锚点

直接在 128×128 战斗画布上绘制，使用 1 倍最近邻显示；同时以最近邻 2 倍导出每帧 256×256 的源图展示版。高分辨率展示版不额外创造细节，避免将其误用为更高精度的原始绘图。

待机战斗帧脚底末行 y=101，游戏锚点为 (64,84)；256 版对应锚点 (128,168)。实际接入时，128 帧中心与锚点差值对应 Sprite2D 偏移 (0,-20)。所有帧共用相同锚点；肢体可抬起、收招可压低，冲刺整体位移由代码控制。

全部动画共享 23 色，硬透明背景，不烘焙红色路径、精英标记、血条或大面积投影进角色图片。各动画单独一行等宽帧表：

| 动画 | 帧数 | 源图尺寸 | 战斗图尺寸 | 动作要求 |
|---|---:|---|---|---|
| 待机 idle | 4 | 1024×256 | 512×128 | 轻微呼吸，前肢撑地，主体不漂移 |
| 移动 move | 6 | 1536×256 | 768×128 | 前后肢交替，体现体重，循环首尾自然 |
| 蓄力 windup | 3 | 768×256 | 384×128 | 降低重心、后肢压缩、甲盾朝前；末帧保持到预警结束 |
| 冲刺 dash | 2 | 512×256 | 256×128 | 身体向前伸展、后肢后收；同一锚点，无整图拖影 |
| 收招 recover | 3 | 768×256 | 384×128 | 前肢刹停、身体回弹、恢复正常姿态 |
| 死亡 death | 5 | 1280×256 | 640×128 | 伏地、甲壳下沉、眼光熄灭；保持无血腥，淡出由代码处理 |

基准造型为 `enemy_rift_rusher_reference.png`。实际输出尺寸和每帧 alpha 已通过构建脚本检查；Godot 资源为 `elite_rusher_sprite_frames.tres`，元信息为 `asset_manifest.json`。

256 展示版、基准图与资源描述位于 `assets/sprites/enemies/elite_rusher/`；战斗帧表位于 `assets/sprites/enemies/combat/elite_rusher/`。已接入 `scenes/enemy/elite_rusher.tscn` 和 `data_config/enemies.json`；遗物选择掉落物由 `scenes/pickups/relic_pickup.tscn` 显示三块符牌与金色底座，拾取后复用升级奖励弹窗。游戏内路径按相同的矩形参数直接绘制。

## 冲刺路径资源

- 文件：`assets/sprites/effects/telegraphs/elite_rusher_dash_path.svg` 与同名 `.png`。
- 参考画布 304×64：角色中心从 (32,32) 向 (272,32) 冲刺 240 像素，路径扫掠半宽 32。
- 填充红色 `#FF3B30`，不透明度 0.3。整条路径为直角矩形，只填充一次，无箭头、无圆角、无镂空，不叠加半透明描边。
- SVG 保持向右；技能使用时旋转至锁定方向。实际距离或半宽改变时由统一几何参数重新生成路径，不能只缩放图片却保持不同的伤害范围。
- 图示宽度是技能扫掠区域；实际实现应明确玩家碰撞形状与扫掠区域的交叠判定。较大的 sprite 和碰撞体需一起校准。
- 预警期显示 0.8 秒，结束后执行 0.4 秒短冲刺；素材不自带时间，时序由技能控制。
- UI/场景的额外 alpha 必须为 1，避免把 30% 再乘成 9%。不同精英路径重叠导致的视觉加深属于两个独立危险区，单条路径自身不得重复绘制。

## 美术说明与提示词归档

最终制作方式为用户指定的直接绘制，未向模型发送提示词。以下保留为美术约束归档；权威可重复制作源为 Python 绘制脚本，实际素材采用约 10% 克苏鲁元素及 23 色像素表现。

### 基准造型

```text
Use case: stylized-concept
Asset type: production 2D pixel-art enemy sprite, one right-facing reference pose
Primary request: draw an entirely new large armored short-dash elite monster for a clean, lightly cute cosmic-fantasy survival game.
Input images: the existing small enemy and hooded hunter are STYLE REFERENCES ONLY. Do not enlarge, recolor, trace, or reproduce either character.
Subject: a low, heavy quadruped with a raised gray-green armored shell, powerful front limbs, short sturdy forward-facing ram plates, and one readable eye. The pose clearly faces right in a slightly elevated side view. Strong readable silhouette and compact proportions.
Style/medium: deliberate pixel clusters, crisp dark teal-black outline, restrained gray-green and bone-highlight palette, tiny warm eye accent, approximately 24 to 32 colors. Clean and mildly fantastical, not gruesome.
Composition: one complete isolated character, generous transparent margins, no cropped limbs. Keep all body parts inside one square frame; grounded feet, no large cast shadow. The character should remain readable as a roughly 76 by 68 pixel silhouette after production cleanup.
Background: actual transparency, not a checkerboard painted into the image.
Constraints: no words, labels, UI, red warning path, motion trail, scenery, watermark, gradients, blur, gore, photoreal textures, or tiny noisy ornament. This is a new design, not a larger version of the reference enemy.
```

### 动画共用约束

每个动画分别生成，使用已验收基准造型作为角色一致性参考，复用以下约束，再追加该动作段落：

```text
Use case: stylized-concept
Asset type: horizontal production sprite animation sheet
Primary request: animate the approved armored elite monster in the requested action. Preserve its identity, anatomy, shell layout, eye position, palette, right-facing direction, and pixel-art style in every frame.
Composition: exactly the requested number of equal square cells in one row, one complete character per cell, no labels and no gutters inside the cells. Identical character scale, fixed ground baseline and anchor in every cell. Movement must come from changing limbs and posture, not translating the whole character through the cells.
Background: actual transparency. No red warning path, background, UI, blur, cast shadow, motion smear, or watermark. Keep enough transparent margin for all action poses.
```

动作段落：

```text
Idle: exactly 4 frames; restrained breathing loop, planted forelimbs, small shell rise and fall, return smoothly to the first pose.
Move: exactly 6 frames; a heavy but readable alternating quadruped gait, forelimb weight transfer and rear-leg follow-through, seamless loop.
Windup: exactly 3 frames; lower the head and ram plates, compress the rear legs, brace into a tense launch pose; the third frame is a held anticipation pose.
Dash: exactly 2 frames; forward-reaching compact charge, ram plates leading, rear legs extended then tucked; keep the body anchored, no positional travel baked into the sprite.
Recover: exactly 3 frames; front legs absorb the stop, shell settles, character returns to its idle stance.
Death: exactly 5 frames; legs fold, body settles to the ground, eye light fades; non-gory and readable, no dismemberment. Do not fade the entire character alpha because runtime handles the fade.
```

## 素材验收

- [x] 基准造型为新绘制，能与普通怪清楚区分，而非仅靠尺寸/颜色变化。
- [x] 已制作同尺寸对比图，精英完整可见包围盒约为普通怪 2 倍。
- [x] 六组动画 23 帧、尺寸、透明边界、无重复帧通过脚本检查；脚底和锚点经过联系表检查。
- [x] 透明度数据真实存在；角色素材使用硬透明，不含棋盘格和杂边。
- [x] 已检查完整联系表，动作保持相同解剖结构；另附动作 GIF 供查看。
- [x] 红色路径 PNG 所有像素 alpha 为 77，SVG 为 0.3；直角矩形、无箭头，贴图仅有一层填充。
- [x] 所有正式 PNG 已存入工程。
- [x] Godot 4.7.2 隔离项目导入通过，`SpriteFrames` 六组动画、23 帧纹理和路径 PNG 加载通过；日志位于同一预览目录。
- [x] 已接入敌人场景，验证移动距离、方向锁定、撞墙和矩形扫掠伤害；游戏内渲染预览见 `artifacts/elite_pickups_20260923/engine_preview.png`。

重新制作：`python scripts/tools/build_elite_rusher_assets.py`。

重新制作攻击专项预览：`python scripts/tools/build_elite_attack_preview.py`。时间线为准备 0.6 秒、蓄力 0.8 秒、冲刺 0.4 秒、收招 0.5 秒、待机 0.7 秒；完整循环 3 秒，其中攻击流程共 1.7 秒。红色路径仅在蓄力期显示，蓄力结束后按锁定方向完成冲刺。
