# 15-召唤物与友方实体模块素材清单

> 当前模块代码允许缺少美术素材时继续运行；正式素材生成后放入下列路径，再在 Godot 中绑定到 `scenes/summons/summon_unit.tscn` 的 `Sprite2D`。

## 1. 必需素材

| 状态 | 素材 | 文件名 | 放置路径 | 格式与尺寸 | 提示词 |
|---|---|---|---|---|---|
| 未存在 | 默认眷族幼体单帧 | `summon_kinling_base.png` | `assets/sprites/summons/summon_kinling_base.png` | PNG，透明背景，128x128 或 256x256，1:1 | 生成一张清新干净的中高精度像素风召唤物单帧图，主题是“友方眷族幼体”，体型小巧可爱，像一只浅绿色或淡蓝色的圆润小生物，带轻微克苏鲁感但不恐怖，可以有小触须、小耳朵或柔和发光眼睛，整体适合森林、篝火、黄昏氛围，不要肮脏环境，不要噪点，不要血腥，不要文字，透明背景，正面略偏右朝向，轮廓清晰，适合游戏内跟随玩家显示。 |

## 2. 可选素材

| 状态 | 素材 | 文件名 | 放置路径 | 格式与尺寸 | 提示词 |
|---|---|---|---|---|---|
| 未存在 | 默认眷族幼体右向行走帧表 | `summon_kinling_walk_right_spritesheet.png` | `assets/sprites/summons/summon_kinling_walk_right_spritesheet.png` | PNG，透明背景，512x128，4 帧横向帧表，每帧 128x128 | 基于“友方眷族幼体”的单帧形象，生成一张清新干净的中高精度像素风右向行走帧表，4 帧横向排列，每帧尺寸一致，小生物轻快跳步或摆动触须前进，动作简单可爱，轮廓清晰，不要文字，不要噪点，不要血腥，透明背景，整体保持浅绿色或淡蓝色、柔和发光眼睛、轻微克苏鲁但不恐怖的风格。 |
| 未存在 | 默认眷族幼体攻击特效 | `effect_summon_kinling_hit.png` | `assets/sprites/summons/effects/effect_summon_kinling_hit.png` | PNG，透明背景，128x128 或 256x256，1:1 | 生成一张清新干净的中高精度像素风召唤物命中特效，主题是“柔和的绿色灵光冲击”，适合小型友方眷族近距离攻击命中敌人，一瞬间的弧形光波或小型星点扩散，颜色浅绿、青蓝或淡黄，画面干净，不要肮脏环境，不要血腥，不要文字，不要噪点，透明背景。 |
| 未存在 | 默认眷族幼体 UI 图标 | `icon_summon_kinling.png` | `assets/ui/icons/summons/icon_summon_kinling.png` | PNG，透明背景，128x128，1:1 | 生成一张清新干净的中高精度像素风 UI 图标，主题是“友方眷族幼体头像”，圆润可爱的小型召唤生物头像，浅绿色或淡蓝色，柔和发光眼睛，轻微克苏鲁元素但不恐怖，图标轮廓清晰，小尺寸可读，不要文字，不要噪点，不要血腥，透明背景。 |

## 3. 当前处理方式

1. `summon_unit.tscn` 当前可以没有贴图，逻辑验证不受影响。
2. 必需素材完成后，优先把 `summon_kinling_base.png` 绑定到 `Sprite2D.texture`。
3. 行走帧表和攻击特效为后续表现增强，不阻塞 MVP 结项。
4. 若后续新增多个召唤物类型，按 `summon_<id>_base.png`、`summon_<id>_walk_right_spritesheet.png`、`icon_summon_<id>.png` 命名。
