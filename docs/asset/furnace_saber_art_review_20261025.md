# 刚焰炉与斩马刀美术候选 · 2026-10-25

本文记录两把新武器的攻击特效与独立美术审阅场景。后续正式接入已完成，属性、商店、受击触发、伤害和附魔规则见 `docs/furnace_saber_integration.md`。本页所述美术审阅视频仍由场景编排，用于观察演出节奏；正式运行证据另存于预览目录的 `production/`。

## 素材与来源

采用本地 Godot 着色器绘制并通过透明 SubViewport 导出 PNG；没有调用图片生成模型。可调整尺寸、投影与时序的源文件和独立 PNG 图集同时保留。

| 素材 | 单帧尺寸 | 布局 | 帧数 | 时长 |
| --- | --- | --- | --- | --- |
| `assets/sprites/weapons/candidates/furnace_saber_v1/furnace_ring.png` | 448 × 320 | 4 列 × 3 行 | 12 | 0.72 秒 |
| `assets/sprites/weapons/candidates/furnace_saber_v1/furnace_split.png` | 512 × 352 | 4 列 × 3 行 | 12 | 0.62 秒 |
| `assets/sprites/weapons/candidates/furnace_saber_v1/saber_cut.png` | 384 × 96 | 4 列 × 3 行 | 12 | 0.30 秒 |

三个图集均为 RGBA，四档实体颜色加透明背景，无抗锯齿透明边。图集已包含地面投影，直接播放 PNG 时不应再次压扁。主火圈与分裂图集的锚点为帧中心；第二版刀光从帧内 `(42, 48)` 延伸至 `(342, 48)`，几何中心和旋转锚点均为 `(192, 48)`。PNG 播放采用最近邻采样。图集播放帧率分别为约 16.67、19.35、40 fps；源着色器的视觉更新节奏为火焰 18 Hz、刀光 48 Hz。

逐帧透明边界、独立帧数量和尺寸校验记录在同目录 `manifest.json`。分裂开头为空白帧，随后独立火簇长出；所有可见帧都留有透明边距。

## 风格与演出

- 刚焰炉沿用 `copper_lamp_flame.gdshader` 的四档火色与像素节奏。第二版已加宽到 40→22 个世界像素半宽，外沿采用宽缓曲线。第三版移除内部细噪声、零碎火星及随机破洞消散，由低频曲线分隔连贯的大块暗红、橙、金黄、浅黄；结束时整条火焰带收细。外沿 18 个分裂火簇同样采用大块分色。这 18 个是本轮视觉排列数量，正式接入时应由分裂规则决定。
- 火焰运行时采用前后两层：主体位于角色后，稀疏前缘位于角色前。透明图集把完整图形合并在一张帧中；需要相同角色遮挡时使用着色器源效果。
- 第四版保留第三版的大色块与宽缓轮廓，将火焰采样从固定的 2 屏幕像素改为与赤铜炉灯一致的 2 世界像素网格。像素在地面投影前对齐，镜头放大时颗粒同步放大，轮廓与色块交界恢复清晰阶梯；主圈与外沿火簇共用此规则。
- 第二版斩马刀移除所有额外虚线、单侧弧度、闪星和碎裂余光。单道刀光上下左右对称，两端尖、中间稍宽，消失时整体收细。五刀每隔 4/60 秒出现，围绕共同几何中心依次旋转 0°、+3°、−3°、+6°、−6°，不再横向平移。
- 第三版把现有六帧 `jump_forward` 动画按 3+3 拆分：在起点完整播放第 1–3 帧，按原动画时长累计约 0.36 秒后闪现，在落点接着播放第 4–6 帧。60 fps 录制在第 50 帧闪现（第 28 帧开始起跳）；刀光、命中闪光及残影随闪现同步。审阅场景单独推进正式动画播放器，并断言起点只出现前三帧、落点只出现后三帧；记录包含每帧首次出现的时刻和所在位置。一轮演出只编排一次玩家闪现。
- 所有演出使用真实战场、玩家和敌人素材；预览镜头作了近景放大。录制没有音效设计。

## 运行与审阅

源效果：`scripts/effects/candidate_weapon_art.gd`、`shaders/effects/candidate_furnace_ring.gdshader`、`shaders/effects/candidate_saber_cut.gdshader`。

审阅场景：`scenes/debug/new_weapon_art_review.tscn`。脚本要求临时存档会话与后台录制参数，GPU 运行必须通过项目私有桌面工具。不会切换输入桌面或修改正常游戏窗口设置。

```text
python scripts/tools/review_new_weapon_art.py headless
python scripts/tools/review_new_weapon_art.py bake
python scripts/tools/review_new_weapon_art.py record
python scripts/tools/review_new_weapon_art.py package
```

审阅页、视频、总览和日志位于 `artifacts/previews/new_weapon_art_20261025/`。审阅页模板为 `scripts/tools/new_weapon_art_gallery.html`，提供六个片段与 1×、0.5×、0.25× 播放速度。

## 验证

- Godot 无界面编辑器校验；六段演出的无界面运行通过。
- 三个图集通过 RGBA、尺寸、帧差异、透明边距检查；第二版刀光追加逐帧上下和左右镜像一致性检查。
- GPU 预览与透明图集导出退出码为 0；私有桌面名称验证一致，`foreground_samples=0`。
- 实际查看了主火圈、多圈分裂、五刀与透明刀光图集，检查像素轮廓、角色可读性和形状区分。
- 这些检查验证美术和预览运行，不代表新武器伤害、冷却与词条机制已经实现。
