# 美术素材分辨率与场景缩放清单

核查日期：2026-10-20；武器图标、附魔图标及角色／怪物主体正式接入更新：2026-10-21。依据当前工作区的实际文件、配置与正式运行路径，包含未提交修改；不是旧设计文档的规格汇总。

本次更新：**101 件遗物、15 张武器/状态图标、19 张附魔图标均已正式接入**，分别使用 36px、36px、32px 源图。2026-10-21 用户确认附魔背包两侧对齐、六列等权重的新布局，该布局已用于正式工作台。遗物的旧正式资源备份、“正式资源 → 36px”版本及该轮中间产物已清理；武器、附魔制作与审阅记录仍按第 5 节保留。角色／怪物本轮96／192px制作与接入见11.6；场景及特效按第11节各自状态处理，第10节未采纳的规格仍为提案。

**附魔范围统一已实施（2026-10-21）**：水流、光辉剑、火池、落雷、结霜的实际判定与终态地面覆盖共用尺寸；黑洞采用球体半径的 3 倍判定；风刃使用随伤害范围变化的独立圆；震荡终态圆与瞬时击退圆对齐。具体数值、玩法影响和验证记录见 7.6。本轮未重制特效 PNG，也未完成第 10 节提出的全项目像素网格统一。

规格速览：遗物已采用 **36×36 → 72×72（2 倍）**，商店/选人页为 **36×36（1 倍）**。武器15张正式PNG使用36×36，常规展示72×72、紧凑/工作台等36×36；附魔19张使用32×32，Esc为64×64、其余入口32×32。角色与怪物新规格已正式接入：**初心者战斗96→96、选人96→288；幼体/蝙蝠96→96；骑士/冥狼192→192**，制作与验证见11.6。第10节旧角色提案已由此方案取代；各特效按第11节分别保持现状、待定或移除，不再统一列为强制缩半/改网格的待办。

## 1. 结论与统计口径

项目已统一为 **1920×1080 设计画布**，但没有统一所有素材的像素密度，也不是所有素材都以原尺寸显示。角色、怪物、背景、图标、攻击特效中同时存在原尺寸、整数缩放、非整数缩放、非等比缩放和程序生成像素网格。

本清单覆盖：上一轮核查的角色、怪物、拾取物与主要战斗场景素材；当前配置的全部 101 件遗物图标、14 种武器主图标及 1 张返程状态图标、19 张附魔图标；14 种武器的攻击表现；全部附魔类别及相关元素反应。历史素材单独标注，不把目录中留存的旧图当成当前画面。

- **源文件分辨率**：PNG 实际宽高，直接读取文件；图集另列单帧分辨率与有效帧数。
- **绘制尺寸**：包含透明留白的矩形尺寸，通常大于可见主体；不是碰撞体或伤害范围。
- **S 原图**：绘制尺寸 ÷ 原始单帧尺寸。用于比较素材源规格与设计画布中的占用。
- **S 选用图**：绘制尺寸 ÷ 实际选中的小尺寸变体。图标存在预制变体时，该值才是运行时重采样倍率。
- **网格**：程序/Shader 的采样或绘制步长。例如 3 px 网格不意味着源图只有 3×3，也不意味着没有缩放。
- 表中倍率均以 **1920×1080、摄像机 zoom=1、普通体型、一级武器、无范围加成、无入场/悬停缩放动画**为基准。小数是栅格化/像素对齐前的尺寸，不表示屏幕存在半个物理像素。
- `R` 表示当前攻击距离，`H` 表示当前命中半径，`V` 表示 `get_projectile_visual_scale()`，默认 `V=1`；`G=145/220≈0.659091` 为常用地面纵向投影比例。标注投影的行应先按本地尺寸缩放，再按方向旋转和地面投影计算，不能把斜向结果简单当成固定轴对齐矩形。

源码基准：`project.godot`、`scripts/core/game_root.gd`、`scripts/weapons/weapon_instance.gd`、`scripts/data/stat_definitions.gd`、`scripts/battle/attack_footprint.gd`。

## 2. 画布与窗口的整体缩放

| 项目 | 当前值 | 含义 |
|---|---|---|
| 根画布 | 1920×1080，`canvas_items`，保持宽高比 | UI 的设计坐标基准 |
| 世界 SubViewport | 1920×1080 | 战斗画面先绘制到该尺寸 |
| 世界容器 / `stretch_shrink` / Camera2D | 1 倍 / 1 / zoom=(1,1) | 基准尺寸下无额外整体缩小 |
| 世界采样 | 最近邻；变换位置对齐像素 | 不会自动把素材的小数倍率改成整数 |
| 窗口输出 1280×720 | 2/3 倍 | 世界画面缩小，可能丢失细线 |
| 窗口输出 1920×1080 | 1 倍 | 本文表格使用的基准 |
| 窗口输出 2560×1440 | 4/3 倍 | 在表中素材倍率之外再整体放大 |
| 本机保存的显示偏好 | 2560×1440、非全屏 | 仅是核查时本机设置，不是仓库的固定规格 |

对普通世界贴图：最终输出尺寸 = 单帧尺寸 × 素材/父节点变换 × 摄像机倍率 × 窗口倍率。世界里的 2 px / 3 px 网格在 1440p 输出下分别对应约 2.667 / 4 个输出像素；武器与遗物 UI 图标均固定使用正式 36×36 源图，附魔图标固定使用正式 32×32 源图。当前未启用严格整数窗口缩放。

## 3. 角色、怪物、拾取物与场景

本节各素材的推荐源帧与倍率见 **10.3、10.4**，角色／怪物正式接入记录见 **11.6**；下表数值均为现状。

### 3.1 实体与选人页

| 对象 / 使用位置 | 源单帧 | 基准倍率 | 基准绘制画布 | 说明 / 依据 |
|---|---|---|---|---|
| 初心者战斗动作 | 96×96 | 1 | 96×96 | `data_config/characters.json` 中 `action_scale_percent=100`；VisualAnchor 绝对倍率为 1 |
| 初心者选人页 | 同一套 96×96 idle/move | 3 | 288×288 | 完整画布固定3倍、整数位置；取消初心者呼吸拉伸 |
| 天外幼体 | 96×96 | 1 | 96×96 | 原图重新像素化，留白保持约70×35的可见体型 |
| 蝙蝠主体 | 96×96 | 1 | 96×96 | 原图重新像素化，共同锚点；技能图不等同主体比例 |
| 钢甲骑士 | 192×192 | 1 | 192×192 | 原图重新像素化，显示大小接近原版；`elite_rusher.tscn` |
| 幽焰冥狼 | 192×192 | 1 | 192×192 | 逐帧补偿已合并到共同源图坐标；基础1倍，再乘挑战体型倍率 |
| 经验球 | 16×16 | 0.5 | 8×8 | Sprite2D 缩放，父节点重置为 1 不会清除该缩放 |
| 附魔掉落图标 | 32×32 | 1 | 32×32 | `augmentation_pickup.gd` 固定最长边 32，直接使用新正式源图 |
| 地面遗物选择拾取物 | 程序绘制，无遗物 PNG | 不适用 | 小方块/立方体与 44×44 光晕 | `relic_pickup.gd`；不能把它误记成某张遗物图标的缩小版 |
| 选人页背景 | 2752×1536 | 0.697674419 | 1920×1071.6279 | `character_select_view.gd` 的 `ART_SIZE`；不是原生 1080p 图片 |

怪物挑战体型会继续乘 `body_scale_multiplier`；死亡动画再缩小到当时尺寸的 0.82 倍。角色地面标记、光晕和碰撞形状有各自比例，不能据此推断人物贴图倍率。

当前主体图集索引（初心者 7 个文件、47 个独立帧；前后跳复用同一个文件）：

| 对象 / 动作 | 文件 | 整张尺寸 | 单帧尺寸 | 帧数 | 显示倍率 |
|---|---|---|---|---|---|
| 初心者 idle | [idle.png](assets/sprites/player/actions/novice_96/idle.png) | 96×96 | 96×96 | 1 | 战斗 1；选人 3（idle/move） |
| 初心者 move | [move.png](assets/sprites/player/actions/novice_96/move.png) | 768×96 | 96×96 | 8 | 战斗 1；选人 3（idle/move） |
| 初心者 attack | [attack.png](assets/sprites/player/actions/novice_96/attack.png) | 672×96 | 96×96 | 7 | 战斗 1 |
| 初心者 sustain | [sustain.png](assets/sprites/player/actions/novice_96/sustain.png) | 768×96 | 96×96 | 8 | 战斗 1 |
| 初心者 move_sustain | [move_sustain.png](assets/sprites/player/actions/novice_96/move_sustain.png) | 768×96 | 96×96 | 8 | 战斗 1 |
| 初心者 jump_forward / jump_backward | [jump.png](assets/sprites/player/actions/novice_96/jump.png) | 576×96 | 96×96 | 6 | 战斗 1 |
| 初心者 move_attack | [move_attack.png](assets/sprites/player/actions/novice_96/move_attack.png) | 864×96 | 96×96 | 9 | 战斗 1 |
| 天外幼体 | [enemy_gloom_mite_idle.png](assets/sprites/enemies/combat/enemy_gloom_mite_idle.png) | 96×96 | 96×96 | 1 | 1 |
| 天外幼体 | [enemy_gloom_mite_move.png](assets/sprites/enemies/combat/enemy_gloom_mite_move.png) | 672×96 | 96×96 | 7 | 1 |
| 蝙蝠 | [idle.png](assets/sprites/enemies/echo_bat/idle.png) | 96×96 | 96×96 | 1 | 1 |
| 蝙蝠 | [move.png](assets/sprites/enemies/echo_bat/move.png) | 576×96 | 96×96 | 6 | 1 |
| 蝙蝠 | [attack.png](assets/sprites/enemies/echo_bat/attack.png) | 864×96 | 96×96 | 9 | 1 |
| 钢甲骑士 | [knight_idle.png](assets/sprites/enemies/iron_knight/knight_idle.png) | 192×192 | 192×192 | 1 | 1 |
| 钢甲骑士 | [knight_move.png](assets/sprites/enemies/iron_knight/knight_move.png) | 1344×192 | 192×192 | 7 | 1 |
| 钢甲骑士 | [knight_windup.png](assets/sprites/enemies/iron_knight/knight_windup.png) | 1344×192 | 192×192 | 7 | 1 |
| 钢甲骑士 | [knight_dash.png](assets/sprites/enemies/iron_knight/knight_dash.png) | 384×192 | 192×192 | 2 | 1 |
| 钢甲骑士 | [knight_recover.png](assets/sprites/enemies/iron_knight/knight_recover.png) | 192×192 | 192×192 | 1 | 1 |
| 冥狼 | [move.png](assets/sprites/enemies/underworld_wolf/atlases/move.png) | 1344×192 | 192×192 | 7 | 1 |
| 冥狼 | [attack.png](assets/sprites/enemies/underworld_wolf/atlases/attack.png) | 768×192 | 192×192 | 4 | 1 |
| 冥狼 | [jump.png](assets/sprites/enemies/underworld_wolf/atlases/jump.png) | 1920×192 | 192×192 | 10 | 1 |
| 资本家（当前锁定） idle | [capitalist_idle.png](assets/sprites/display_clarity/player/capitalist_idle.png) | 80×80 | 80×80 | 1 | 1；选人展示另行按可见包围盒适配 |
| 资本家（当前锁定） walk | [capitalist_walk.png](assets/sprites/display_clarity/player/capitalist_walk.png) | 560×80 | 80×80 | 7 | 1；选人展示另行按可见包围盒适配 |

### 3.2 当前草地战场

正式继承链为 `CavernSunlightBackdrop → CavernGrasslandBackdrop → CavernPopulationBackdrop → CavernMeadowBackdrop → CavernBattleBackdrop`。以下按实际覆写后的逻辑计算，而不是只看基类的旧 `ART_SCALE` 常量。

| 素材 | 源文件 | 整张尺寸 | 倍率 | 说明 |
|---|---|---|---|---|
| 地面 | [pit-ground.png](assets/sprites/background/meadow/pit-ground.png) | 2176×1600 | (1,0.659091)，按世界坐标循环采样 | 纵向投影压缩；Shader 承载面不是源图尺寸 |
| 地面环境数据 | [pit-ground-context.png](assets/sprites/background/meadow/pit-ground-context.png) | 272×200 | 不直接显示 | 用于布草/地表判断，不是可见贴图 |
| G09_grass_short-32 | [G09_grass_short-32.png](assets/sprites/background/green_ground/G09_grass_short-32.png) | 32×32 | 主层 0.95～1.25；底层 0.48～0.78；伴生草按目标高度适配 | 32×32 主层约30.4～40；底层约15.36～24.96 |
| G10_grass_dense-32 | [G10_grass_dense-32.png](assets/sprites/background/green_ground/G10_grass_dense-32.png) | 32×32 | 主层 0.95～1.25；底层 0.48～0.78；伴生草按目标高度适配 | 32×32 主层约30.4～40；底层约15.36～24.96 |
| G11_grass_long-32 | [G11_grass_long-32.png](assets/sprites/background/green_ground/G11_grass_long-32.png) | 32×32 | 主层 0.95～1.25；底层 0.48～0.78；伴生草按目标高度适配 | 32×32 主层约30.4～40；底层约15.36～24.96 |
| G12_grass_dry_mix-32 | [G12_grass_dry_mix-32.png](assets/sprites/background/green_ground/G12_grass_dry_mix-32.png) | 32×32 | 主层 0.95～1.25；伴生草按目标高度适配 | 主层约30.4～40；底层仅选前三种绿草 |
| rock | [prop_rock.png](assets/sprites/background/cavern/prop_rock.png) | 75×65 | 2 | 正式 landmark()；镜像不改变绝对倍率 |
| log | [prop_log.png](assets/sprites/background/cavern/prop_log.png) | 69×31 | 2 | 正式 landmark()；镜像不改变绝对倍率 |
| loose_stone_0 | [rubble_0.png](assets/sprites/background/cavern/rubble_0.png) | 100×60 | 1.45 / texture_density(4) = 0.3625 | 先用放置倍率，再除贴图密度 |
| loose_stone_1 | [rubble_1.png](assets/sprites/background/cavern/rubble_1.png) | 64×44 | 1.45 / texture_density(4) = 0.3625 | 先用放置倍率，再除贴图密度 |
| decal_single_brick | [decal_single_brick.png](assets/sprites/background/wetland/decal_single_brick.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| decal_stacked_bricks | [decal_stacked_bricks.png](assets/sprites/background/wetland/decal_stacked_bricks.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| decal_brick_fragments | [decal_brick_fragments.png](assets/sprites/background/wetland/decal_brick_fragments.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| decal_scattered_stones | [decal_scattered_stones.png](assets/sprites/background/wetland/decal_scattered_stones.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| decal_high_rubble | [decal_high_rubble.png](assets/sprites/background/wetland/decal_high_rubble.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| decal_low_rubble | [decal_low_rubble.png](assets/sprites/background/wetland/decal_low_rubble.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| decal_flat_stones | [decal_flat_stones.png](assets/sprites/background/wetland/decal_flat_stones.png) | 64×64 | 0.85～1.16 | 随机实例倍率 |
| 远景全景 | [panorama_aligned.png](assets/sprites/background/cavern/panorama_aligned.png) | 3098×206 | (1,1.000000) | 1920基准单段绘制 3098×206；循环平移/遮罩 |
| 远景 arch | [ruin_arch.png](assets/sprites/background/cavern/ruin_arch.png) | 248×216 | 0.5×洞口适配系数 f | 请求124×108；空间不足时等比缩小 |
| 远景 pillar | [ruin_pillar.png](assets/sprites/background/cavern/ruin_pillar.png) | 104×184 | 0.5×洞口适配系数 f | 请求52×92；空间不足时等比缩小 |
| 远景 obelisk | [ruin_obelisk.png](assets/sprites/background/cavern/ruin_obelisk.png) | 88×148 | 0.5×洞口适配系数 f | 请求44×74；空间不足时等比缩小 |
| 远景 lamp | [ruin_lamp.png](assets/sprites/background/cavern/ruin_lamp.png) | 100×156 | 0.5×洞口适配系数 f | 请求50×78；空间不足时等比缩小 |
| 前景角图 0 | [foreground_0.png](assets/sprites/background/cavern/foreground_0.png) | 128×128 | (1.676471,1.673729) | 继承 foreground 适配：214.588×214.237；可见性另受布局/遮罩控制 |
| 前景角图 1 | [foreground_1.png](assets/sprites/background/cavern/foreground_1.png) | 128×128 | (1.800554,1.800847) | 继承 foreground 适配：230.471×230.508；可见性另受布局/遮罩控制 |
| 前景角图 2 | [foreground_2.png](assets/sprites/background/cavern/foreground_2.png) | 128×128 | (2.596154,2.585404) | 继承 foreground 适配：332.308×330.932；可见性另受布局/遮罩控制 |
| 前景角图 3 | [foreground_3.png](assets/sprites/background/cavern/foreground_3.png) | 128×128 | (2.911275,2.906699) | 继承 foreground 适配：372.643×372.057；可见性另受布局/遮罩控制 |
| 接触阴影 | [pit-contact-shadow.png](assets/sprites/background/meadow/pit-contact-shadow.png) | 96×48 | 目标宽/96、目标高/48 | 例如94×25；另有90×13、18×7等实例 |

远景还会按 `display_size / 源尺寸 × art_scale` 适配；1920×1080 下 `art_scale=2.5`，当前洞穴远层再乘 0.8。洞口适配系数 `f=min(1,可用宽/请求宽,可用高/请求高)`，由 `_cave_side_rect()` 计算。接触影子 96×48 贴图按目标宽高分别缩放，例如 94×25 对应 (0.979167,0.520833)。投射影子还包含剪切与纵向压缩，不能用一个等比倍率表示。对应 `cavern_battle_horizon.gd`、`cavern_pit_horizon.gd`、`cavern_grassland_backdrop.gd`。

## 4. 遗物图标：36×36 已正式接入

2026-10-20，按用户纠正后的要求，当前配置的 **101 件遗物全部从原始来源重新处理为 36×36 透明 PNG**。同名 `.pxg` / `.pal` 同步替换，每图最多 14 色、alpha 仅为 0/255。保留原图的配色、主体轮廓与必要识别细节，并对挂链、指针、棱线、裂纹和图案做局部像素修整；不使用抖色或生图 API。

本次输入是 **90 件高清图集原始裁切 + 11 件脚本最初绘制的 64×64 画布**，没有将正式 128px 或前一轮 36px 图片作为转换输入。存钱罐也已重新制作。5 张完整图集从 Git 历史 `f304137` 恢复并核对哈希：前三张 2048×2048、第四张 1536×2752、第八批白底图集 2364×1773。每件先按原始像素裁切，再直接制作 36px 稿；完整图集和裁切尺寸列于下表。

最终选稿为四列对比中的 **B：“原始图 → 36px”**，101 件全部采用；与选稿逐张核对 SHA-256 一致。正式目录为 `assets/ui/icons/relics/`，保留 101 张 PNG、101 份可编辑 PXG、101 份 PAL 及对应导入设置。保留这版原有构图和主体占比，没有再次缩放、裁切或统一到 32px 主体。

原始来源保存在以下位置；逐件原图哈希、裁切坐标、正式资源哈希、可见包围盒与色数维护于 [icon_manifest.json](docs/asset/icon_manifest.json)，覆盖全部 101 件。

| 原始来源 | 分辨率 | 遗物数量 |
|---|---|---|
| [yiwu_icon1.png](artifacts/sources/relics/yiwu_icon1.png) | 2048×2048 | 12 |
| [yiwu_icon2.png](artifacts/sources/relics/yiwu_icon2.png) | 2048×2048 | 24 |
| [yiwu_icon3.png](artifacts/sources/relics/yiwu_icon3.png) | 2048×2048 | 24 |
| [yiwu_icon4.png](artifacts/sources/relics/yiwu_icon4.png) | 1536×2752 | 24 |
| [relics_sheet_08_source.png](artifacts/sources/relics/a9acdbf404-relics_sheet_08_source.png) | 2364×1773 | 6 |
| [attribute_relics.py](scripts/tools/source_art/attribute_relics.py) 原始绘图函数 | 64×64 画布 | 5 |
| [combat_attribute_relics.py](scripts/tools/source_art/combat_attribute_relics.py) 原始绘图函数 | 64×64 画布 | 6 |

两份原始绘图脚本保留用于追溯；其中历史安装函数会输出旧尺寸，不是当前正式稿的安装入口。正式稿以已确认的 PNG/PXG/PAL 为准。

清理范围包括本轮 r01/r02 任务目录、存钱罐试稿、旧尺寸展示、四列对比网页与压缩包、旧 128/64px 备份、旧 36px 备份、裁切/遮罩/候选图、临时脚本、日志和过程报告。共享 `clarity` 图集中的 90 件旧遗物登记及其像素也已移除，保留 15 张武器/状态图标的 18 档变体，共 270 个区域，像素与清理前一致。本轮接入报告合并到本文，原始源图和正式可编辑稿保留。

### 4.1 不同界面的显示规则

| 使用场合 | 当前源图 / 推荐源图 | 场景显示尺寸 | 显示倍率 | 实际接入规则 |
|---|---|---|---|---|
| 常规奖励、Esc 遗物栏 | 36×36 | 72×72 | 2 倍 | 直接绘制正式源图，最近邻；取消遗物入场/悬停/领取中的非整数尺寸动画 |
| 游戏百科遗物详情 | 36×36 | 72×72 | 2 倍 | 与奖励共用同一源图和展示档位 |
| 小尺寸奖励卡备用布局 | 36×36 | 72×72 | 2 倍 | 同一档位，不额外保留旧 64×64 分支 |
| 备战商店遗物卡 | 36×36 | 36×36 | 1 倍 | 居中显示；卡框大小不代表图片大小 |
| 选人页初始遗物 | 36×36 | 36×36 | 1 倍 | 完整保留透明留白，不再裁可见包围盒后拉满 |

`FinanceUIStyle.RELIC_DISPLAY_SIZE=72`，列表倍率为 `0.5`，奖励和 Esc 相对基础倍率均为 `1.0`。`ItemIconArt` 对遗物绕过历史清晰度图集，窗口变化也不会切回旧 40/64/80 版本；武器也已于 2026-10-21 改为正式 36px 源图，退出旧变体机制。

“小尺寸奖励卡”是 `RewardOption` 在空间不足时使用的备用布局，没有独立功能入口。标准 1920×1080 奖励弹窗仍使用常规卡，二者现在都显示 72×72 遗物。

这里的“像素保留”指**已完成的 36×36 结果图**以 1 倍或 2 倍最近邻绘制：每个源像素对应 1×1 或 2×2 像素。高清原图／原始 64px 绘图画布转为 36 时已主动简化细节，不能称为原始高分辨率图无损压缩。规格以 1920×1080 设计画布为基准；全局窗口在 720p、1440p 等尺寸输出时仍有额外缩放，不承诺任意窗口下都保持整数物理像素。

### 4.2 101 件遗物逐项清单

全部条目推荐继续使用当前 36×36 源规格；商店/选人页 36×36（1 倍），奖励/Esc/百科 72×72（2 倍）。下表“主体占用”是非透明像素包围盒，其余显示尺寸包含透明留白。当前主体最长边为 30～34px：30px 4 件、31px 1 件、32px 60 件、33px 8 件、34px 28 件；这些差异随本次选稿保留。例如存钱罐主体为 34×32，2 倍显示时实际可见包围盒为 68×64。

| 遗物 | ID | 正式源文件 | 当前 / 推荐源图 | 主体占用 | 商店 / 选人页 | 奖励 / Esc / 百科 | 色数 | 原始图集 / 画布 | 原始裁切 |
|---|---|---|---|---|---|---|---|---|---|
| 猪猪存钱罐 | `relic_piggy_bank` | [relic_piggy_bank.png](assets/ui/icons/relics/relic_piggy_bank.png) | 36×36 | 34×32 | 36×36 / 1 | 72×72 / 2 | 9 | 2048×2048 | 477×468 |
| 理财经理 | `relic_finance_manager` | [relic_finance_manager.png](assets/ui/icons/relics/relic_finance_manager.png) | 36×36 | 32×28 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 498×550 |
| 分红支票 | `relic_dividend_check` | [relic_dividend_check.png](assets/ui/icons/relics/relic_dividend_check.png) | 36×36 | 32×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 498×550 |
| 定期存单 | `relic_fixed_deposit_certificate` | [relic_fixed_deposit_certificate.png](assets/ui/icons/relics/relic_fixed_deposit_certificate.png) | 36×36 | 30×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 498×550 |
| 传单广告 | `relic_flyer_ad` | [relic_flyer_ad.png](assets/ui/icons/relics/relic_flyer_ad.png) | 36×36 | 26×34 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 498×590 |
| 钢铁保险柜 | `relic_steel_vault` | [relic_steel_vault.png](assets/ui/icons/relics/relic_steel_vault.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 498×590 |
| 量化操盘 | `relic_quant_trading` | [relic_quant_trading.png](assets/ui/icons/relics/relic_quant_trading.png) | 36×36 | 32×34 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 498×590 |
| 恶意收购 | `relic_hostile_takeover` | [relic_hostile_takeover.png](assets/ui/icons/relics/relic_hostile_takeover.png) | 36×36 | 31×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 498×590 |
| 吸金罗盘 | `relic_gold_compass` | [relic_gold_compass.png](assets/ui/icons/relics/relic_gold_compass.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 498×560 |
| 小费托盘 | `relic_tip_tray` | [relic_tip_tray.png](assets/ui/icons/relics/relic_tip_tray.png) | 36×36 | 34×18 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 498×560 |
| 复利宝典 | `relic_compound_interest_tome` | [relic_compound_interest_tome.png](assets/ui/icons/relics/relic_compound_interest_tome.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 498×560 |
| 高利契约 | `relic_high_yield_contract` | [relic_high_yield_contract.png](assets/ui/icons/relics/relic_high_yield_contract.png) | 36×36 | 28×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 498×560 |
| 并购重组 | `relic_merger_reorg` | [relic_merger_reorg.png](assets/ui/icons/relics/relic_merger_reorg.png) | 36×36 | 34×34 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×396 |
| 周期分红钟 | `relic_periodic_dividend_clock` | [relic_periodic_dividend_clock.png](assets/ui/icons/relics/relic_periodic_dividend_clock.png) | 36×36 | 26×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 328×396 |
| 医疗削减方案 | `relic_medical_cutback` | [relic_medical_cutback.png](assets/ui/icons/relics/relic_medical_cutback.png) | 36×36 | 20×32 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×396 |
| 福利削减方案 | `relic_welfare_cutback` | [relic_welfare_cutback.png](assets/ui/icons/relics/relic_welfare_cutback.png) | 36×36 | 32×22 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×396 |
| 年假削减方案 | `relic_annual_leave_cutback` | [relic_annual_leave_cutback.png](assets/ui/icons/relics/relic_annual_leave_cutback.png) | 36×36 | 34×30 | 36×36 / 1 | 72×72 / 2 | 9 | 2048×2048 | 328×396 |
| 薪酬调整方案 | `relic_salary_adjustment` | [relic_salary_adjustment.png](assets/ui/icons/relics/relic_salary_adjustment.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×396 |
| 神性融合 | `relic_divine_fusion` | [relic_divine_fusion.png](assets/ui/icons/relics/relic_divine_fusion.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 327×420 |
| 哥布林金币铸造机 | `relic_goblin_central_bank_printer` | [relic_goblin_central_bank_printer.png](assets/ui/icons/relics/relic_goblin_central_bank_printer.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 328×420 |
| 永续年金卷轴 | `relic_perpetual_annuity_scroll` | [relic_perpetual_annuity_scroll.png](assets/ui/icons/relics/relic_perpetual_annuity_scroll.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 10 | 2048×2048 | 327×420 |
| 破产重组 | `relic_bankruptcy_reorg` | [relic_bankruptcy_reorg.png](assets/ui/icons/relics/relic_bankruptcy_reorg.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 9 | 2048×2048 | 327×420 |
| 磨损的止血布条 | `relic_worn_hemostatic_cloth` | [relic_worn_hemostatic_cloth.png](assets/ui/icons/relics/relic_worn_hemostatic_cloth.png) | 36×36 | 26×32 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 328×420 |
| 负重铁皮护腕 | `relic_load_iron_bracer` | [relic_load_iron_bracer.png](assets/ui/icons/relics/relic_load_iron_bracer.png) | 36×36 | 26×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×420 |
| 刺鼻香包 | `relic_pungent_sachet` | [relic_pungent_sachet.png](assets/ui/icons/relics/relic_pungent_sachet.png) | 36×36 | 24×32 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×438 |
| 残破晶石 | `relic_broken_crystal` | [relic_broken_crystal.png](assets/ui/icons/relics/relic_broken_crystal.png) | 36×36 | 20×32 | 36×36 / 1 | 72×72 / 2 | 10 | 2048×2048 | 328×438 |
| 生命力药瓶 | `relic_vitality_potion` | [relic_vitality_potion.png](assets/ui/icons/relics/relic_vitality_potion.png) | 36×36 | 22×32 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×438 |
| 死寂护盾徽章 | `relic_dead_shield_badge` | [relic_dead_shield_badge.png](assets/ui/icons/relics/relic_dead_shield_badge.png) | 36×36 | 26×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×438 |
| 龟壳吊坠 | `relic_turtle_shell_pendant` | [relic_turtle_shell_pendant.png](assets/ui/icons/relics/relic_turtle_shell_pendant.png) | 36×36 | 25×32 | 36×36 / 1 | 72×72 / 2 | 10 | 2048×2048 | 328×438 |
| 监狱铜制脚环 | `relic_prison_copper_anklet` | [relic_prison_copper_anklet.png](assets/ui/icons/relics/relic_prison_copper_anklet.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×438 |
| 黄铜怀表 | `relic_brass_pocket_watch` | [relic_brass_pocket_watch.png](assets/ui/icons/relics/relic_brass_pocket_watch.png) | 36×36 | 28×33 | 36×36 / 1 | 72×72 / 2 | 10 | 2048×2048 | 327×475 |
| 血肉肩甲 | `relic_flesh_pauldron` | [relic_flesh_pauldron.png](assets/ui/icons/relics/relic_flesh_pauldron.png) | 36×36 | 28×33 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 328×475 |
| 梦魇治愈圣壶 | `relic_nightmare_healing_urn` | [relic_nightmare_healing_urn.png](assets/ui/icons/relics/relic_nightmare_healing_urn.png) | 36×36 | 22×33 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×475 |
| 屏障结晶 | `relic_barrier_crystal` | [relic_barrier_crystal.png](assets/ui/icons/relics/relic_barrier_crystal.png) | 36×36 | 19×32 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×475 |
| 密教圣盾 | `relic_cultic_holy_shield` | [relic_cultic_holy_shield.png](assets/ui/icons/relics/relic_cultic_holy_shield.png) | 36×36 | 23×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 328×475 |
| 迷途者胫环 | `relic_lost_wayfarer_greave` | [relic_lost_wayfarer_greave.png](assets/ui/icons/relics/relic_lost_wayfarer_greave.png) | 36×36 | 30×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×475 |
| 守魂人面石雕 | `relic_soul_keeper_face_stone` | [relic_soul_keeper_face_stone.png](assets/ui/icons/relics/relic_soul_keeper_face_stone.png) | 36×36 | 26×34 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 327×377 |
| 苦痛祭皿 | `relic_pain_vessel` | [relic_pain_vessel.png](assets/ui/icons/relics/relic_pain_vessel.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 328×377 |
| 真银护甲 | `relic_true_silver_armor` | [relic_true_silver_armor.png](assets/ui/icons/relics/relic_true_silver_armor.png) | 36×36 | 26×32 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×377 |
| 圣质银杯 | `relic_holy_silver_cup` | [relic_holy_silver_cup.png](assets/ui/icons/relics/relic_holy_silver_cup.png) | 36×36 | 20×32 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 327×377 |
| 受难甲壳 | `relic_suffering_carapace` | [relic_suffering_carapace.png](assets/ui/icons/relics/relic_suffering_carapace.png) | 36×36 | 32×34 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 328×377 |
| 代价生命之种 | `relic_costly_seed_of_life` | [relic_costly_seed_of_life.png](assets/ui/icons/relics/relic_costly_seed_of_life.png) | 36×36 | 22×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×377 |
| 无影遁形胫甲 | `relic_shadowless_greave` | [relic_shadowless_greave.png](assets/ui/icons/relics/relic_shadowless_greave.png) | 36×36 | 20×34 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×372 |
| 苦难前行之枷锁 | `relic_chain_of_hardship` | [relic_chain_of_hardship.png](assets/ui/icons/relics/relic_chain_of_hardship.png) | 36×36 | 28×33 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 328×372 |
| 虚空触手 | `relic_void_tentacle` | [relic_void_tentacle.png](assets/ui/icons/relics/relic_void_tentacle.png) | 36×36 | 24×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×372 |
| 磨损格斗拳套 | `relic_worn_fighting_gloves` | [relic_worn_fighting_gloves.png](assets/ui/icons/relics/relic_worn_fighting_gloves.png) | 36×36 | 32×28 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×372 |
| 裂痕石子弹 | `relic_cracked_stone_bullet` | [relic_cracked_stone_bullet.png](assets/ui/icons/relics/relic_cracked_stone_bullet.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 328×372 |
| 急促弹簧扳机 | `relic_hasty_spring_trigger` | [relic_hasty_spring_trigger.png](assets/ui/icons/relics/relic_hasty_spring_trigger.png) | 36×36 | 32×30 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×372 |
| 粗糙研磨透镜 | `relic_rough_grinding_lens` | [relic_rough_grinding_lens.png](assets/ui/icons/relics/relic_rough_grinding_lens.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 14 | 2048×2048 | 327×365 |
| 阻滞配重石 | `relic_blocking_counterweight` | [relic_blocking_counterweight.png](assets/ui/icons/relics/relic_blocking_counterweight.png) | 36×36 | 22×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 328×365 |
| 嗜血皮带 | `relic_bloodstained_belt` | [relic_bloodstained_belt.png](assets/ui/icons/relics/relic_bloodstained_belt.png) | 36×36 | 34×28 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×365 |
| 毒雾投囊 | `relic_poison_mist_pouch` | [relic_poison_mist_pouch.png](assets/ui/icons/relics/relic_poison_mist_pouch.png) | 36×36 | 26×34 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×365 |
| 震颤握柄 | `relic_tremor_grip` | [relic_tremor_grip.png](assets/ui/icons/relics/relic_tremor_grip.png) | 36×36 | 28×33 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 328×365 |
| 黑斑鹰眼水晶 | `relic_black_spot_eagle_eye` | [relic_black_spot_eagle_eye.png](assets/ui/icons/relics/relic_black_spot_eagle_eye.png) | 36×36 | 32×31 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 327×365 |
| 狂战士铜质徽章 | `relic_berserker_copper_badge` | [relic_berserker_copper_badge.png](assets/ui/icons/relics/relic_berserker_copper_badge.png) | 36×36 | 32×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×324 |
| 蚀腐吹管 | `relic_corroded_blowpipe` | [relic_corroded_blowpipe.png](assets/ui/icons/relics/relic_corroded_blowpipe.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 13 | 2048×2048 | 328×324 |
| 疾风轮盘 | `relic_gale_roulette` | [relic_gale_roulette.png](assets/ui/icons/relics/relic_gale_roulette.png) | 36×36 | 32×30 | 36×36 / 1 | 72×72 / 2 | 10 | 2048×2048 | 327×324 |
| 屠戮者臂铠 | `relic_executioner_bracer` | [relic_executioner_bracer.png](assets/ui/icons/relics/relic_executioner_bracer.png) | 36×36 | 30×34 | 36×36 / 1 | 72×72 / 2 | 11 | 2048×2048 | 327×324 |
| 裁决之眼吊坠 | `relic_judgment_eye_pendant` | [relic_judgment_eye_pendant.png](assets/ui/icons/relics/relic_judgment_eye_pendant.png) | 36×36 | 20×32 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 328×324 |
| 分裂晶石弹头 | `relic_split_crystal_warhead` | [relic_split_crystal_warhead.png](assets/ui/icons/relics/relic_split_crystal_warhead.png) | 36×36 | 28×33 | 36×36 / 1 | 72×72 / 2 | 12 | 2048×2048 | 327×324 |
| 淘金者的手套 | `relic_gold_digger_gloves` | [relic_gold_digger_gloves.png](assets/ui/icons/relics/relic_gold_digger_gloves.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 13 | 1536×2752 | 370×386 |
| 残缺的占卜骰子 | `relic_incomplete_divination_dice` | [relic_incomplete_divination_dice.png](assets/ui/icons/relics/relic_incomplete_divination_dice.png) | 36×36 | 34×30 | 36×36 / 1 | 72×72 / 2 | 11 | 1536×2752 | 370×386 |
| 商旅账本 | `relic_travelers_ledger` | [relic_travelers_ledger.png](assets/ui/icons/relics/relic_travelers_ledger.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 10 | 1536×2752 | 370×386 |
| 被亵渎的祈福铜钱 | `relic_defiled_blessing_coin` | [relic_defiled_blessing_coin.png](assets/ui/icons/relics/relic_defiled_blessing_coin.png) | 36×36 | 32×34 | 36×36 / 1 | 72×72 / 2 | 13 | 1536×2752 | 370×386 |
| 扩容背包束带 | `relic_expanded_backpack_strap` | [relic_expanded_backpack_strap.png](assets/ui/icons/relics/relic_expanded_backpack_strap.png) | 36×36 | 26×32 | 36×36 / 1 | 72×72 / 2 | 14 | 1536×2752 | 370×378 |
| 观星者的镜片 | `relic_stargazers_lens` | [relic_stargazers_lens.png](assets/ui/icons/relics/relic_stargazers_lens.png) | 36×36 | 30×30 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 丰收的牺牲祭器 | `relic_harvest_sacrificial_vessel` | [relic_harvest_sacrificial_vessel.png](assets/ui/icons/relics/relic_harvest_sacrificial_vessel.png) | 36×36 | 34×28 | 36×36 / 1 | 72×72 / 2 | 14 | 1536×2752 | 370×378 |
| 人性护符 | `relic_amulet_of_humanity` | [relic_amulet_of_humanity.png](assets/ui/icons/relics/relic_amulet_of_humanity.png) | 36×36 | 22×34 | 36×36 / 1 | 72×72 / 2 | 14 | 1536×2752 | 370×378 |
| 馈赠印记 | `relic_gift_mark` | [relic_gift_mark.png](assets/ui/icons/relics/relic_gift_mark.png) | 36×36 | 28×30 | 36×36 / 1 | 72×72 / 2 | 9 | 1536×2752 | 370×378 |
| 虚空收纳匣 | `relic_void_storage_casket` | [relic_void_storage_casket.png](assets/ui/icons/relics/relic_void_storage_casket.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 轮回业火之烛 | `relic_reincarnation_hellfire_candle` | [relic_reincarnation_hellfire_candle.png](assets/ui/icons/relics/relic_reincarnation_hellfire_candle.png) | 36×36 | 20×31 | 36×36 / 1 | 72×72 / 2 | 11 | 1536×2752 | 370×378 |
| 守心铜鉴 | `relic_guarding_heart_copper_mirror` | [relic_guarding_heart_copper_mirror.png](assets/ui/icons/relics/relic_guarding_heart_copper_mirror.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 14 | 1536×2752 | 370×378 |
| 无眠账簿 | `relic_sleepless_ledger` | [relic_sleepless_ledger.png](assets/ui/icons/relics/relic_sleepless_ledger.png) | 36×36 | 32×23 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 狂热分红 | `relic_frenzied_dividend` | [relic_frenzied_dividend.png](assets/ui/icons/relics/relic_frenzied_dividend.png) | 36×36 | 32×28 | 36×36 / 1 | 72×72 / 2 | 13 | 1536×2752 | 370×378 |
| 镀金扳机 | `relic_gilded_trigger` | [relic_gilded_trigger.png](assets/ui/icons/relics/relic_gilded_trigger.png) | 36×36 | 32×26 | 36×36 / 1 | 72×72 / 2 | 11 | 1536×2752 | 370×378 |
| 失控增幅器 | `relic_runaway_amplifier` | [relic_runaway_amplifier.png](assets/ui/icons/relics/relic_runaway_amplifier.png) | 36×36 | 30×30 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 清醒誓言 | `relic_lucid_vow` | [relic_lucid_vow.png](assets/ui/icons/relics/relic_lucid_vow.png) | 36×36 | 30×33 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 金币心脏 | `relic_coin_heart` | [relic_coin_heart.png](assets/ui/icons/relics/relic_coin_heart.png) | 36×36 | 30×28 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 囤积者戒指 | `relic_hoarders_ring` | [relic_hoarders_ring.png](assets/ui/icons/relics/relic_hoarders_ring.png) | 36×36 | 30×34 | 36×36 / 1 | 72×72 / 2 | 14 | 1536×2752 | 370×378 |
| 黄金棺椁 | `relic_golden_sarcophagus` | [relic_golden_sarcophagus.png](assets/ui/icons/relics/relic_golden_sarcophagus.png) | 36×36 | 22×32 | 36×36 / 1 | 72×72 / 2 | 12 | 1536×2752 | 370×378 |
| 旧铜望远镜 | `relic_old_brass_telescope` | [relic_old_brass_telescope.png](assets/ui/icons/relics/relic_old_brass_telescope.png) | 36×36 | 32×22 | 36×36 / 1 | 72×72 / 2 | 13 | 1536×2752 | 370×378 |
| 裂纹铜铃 | `relic_cracked_bronze_bell` | [relic_cracked_bronze_bell.png](assets/ui/icons/relics/relic_cracked_bronze_bell.png) | 36×36 | 30×34 | 36×36 / 1 | 72×72 / 2 | 14 | 1536×2752 | 370×378 |
| 长焦目镜 | `relic_long_focus_eyepiece` | [relic_long_focus_eyepiece.png](assets/ui/icons/relics/relic_long_focus_eyepiece.png) | 36×36 | 34×28 | 36×36 / 1 | 72×72 / 2 | 13 | 1536×2752 | 370×376 |
| 扩散喷口 | `relic_diffusion_nozzle` | [relic_diffusion_nozzle.png](assets/ui/icons/relics/relic_diffusion_nozzle.png) | 36×36 | 34×28 | 36×36 / 1 | 72×72 / 2 | 11 | 1536×2752 | 370×376 |
| 定距脚架 | `relic_range_tripod` | [relic_range_tripod.png](assets/ui/icons/relics/relic_range_tripod.png) | 36×36 | 26×34 | 36×36 / 1 | 72×72 / 2 | 12 | 2364×1773 | 591×591 |
| 余震沙漏 | `relic_aftershock_hourglass` | [relic_aftershock_hourglass.png](assets/ui/icons/relics/relic_aftershock_hourglass.png) | 36×36 | 20×33 | 36×36 / 1 | 72×72 / 2 | 14 | 2364×1773 | 591×591 |
| 黄金测距仪 | `relic_golden_rangefinder` | [relic_golden_rangefinder.png](assets/ui/icons/relics/relic_golden_rangefinder.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 9 | 2364×1773 | 591×591 |
| 深海回声螺 | `relic_abyssal_echo_shell` | [relic_abyssal_echo_shell.png](assets/ui/icons/relics/relic_abyssal_echo_shell.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 14 | 2364×1773 | 591×591 |
| 折叠星图 | `relic_folded_star_chart` | [relic_folded_star_chart.png](assets/ui/icons/relics/relic_folded_star_chart.png) | 36×36 | 32×26 | 36×36 / 1 | 72×72 / 2 | 13 | 2364×1773 | 591×591 |
| 地平线星仪 | `relic_horizon_orrery` | [relic_horizon_orrery.png](assets/ui/icons/relics/relic_horizon_orrery.png) | 36×36 | 25×32 | 36×36 / 1 | 72×72 / 2 | 8 | 2364×1773 | 591×591 |
| 绯红凝血瓶 | `relic_crimson_coagulation_vial` | [relic_crimson_coagulation_vial.png](assets/ui/icons/relics/relic_crimson_coagulation_vial.png) | 36×36 | 27×32 | 36×36 / 1 | 72×72 / 2 | 9 | 64×64 原始绘图 | 64×64 |
| 哥布林特许状 | `relic_goblin_trade_charter` | [relic_goblin_trade_charter.png](assets/ui/icons/relics/relic_goblin_trade_charter.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 13 | 64×64 原始绘图 | 64×64 |
| 虚市通行钥匙 | `relic_void_market_key` | [relic_void_market_key.png](assets/ui/icons/relics/relic_void_market_key.png) | 36×36 | 32×32 | 36×36 / 1 | 72×72 / 2 | 7 | 64×64 原始绘图 | 64×64 |
| 猎群骨哨 | `relic_hunting_bone_whistle` | [relic_hunting_bone_whistle.png](assets/ui/icons/relics/relic_hunting_bone_whistle.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 7 | 64×64 原始绘图 | 64×64 |
| 锈蚀祭铃 | `relic_hungry_tide_bell` | [relic_hungry_tide_bell.png](assets/ui/icons/relics/relic_hungry_tide_bell.png) | 36×36 | 29×32 | 36×36 / 1 | 72×72 / 2 | 8 | 64×64 原始绘图 | 64×64 |
| 猎隼瞄针 | `relic_falcon_sighting_pin` | [relic_falcon_sighting_pin.png](assets/ui/icons/relics/relic_falcon_sighting_pin.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 10 | 64×64 原始绘图 | 64×64 |
| 刽子手磨石 | `relic_executioner_whetstone` | [relic_executioner_whetstone.png](assets/ui/icons/relics/relic_executioner_whetstone.png) | 36×36 | 32×28 | 36×36 / 1 | 72×72 / 2 | 11 | 64×64 原始绘图 | 64×64 |
| 猩红断头印 | `relic_crimson_execution_seal` | [relic_crimson_execution_seal.png](assets/ui/icons/relics/relic_crimson_execution_seal.png) | 36×36 | 30×32 | 36×36 / 1 | 72×72 / 2 | 9 | 64×64 原始绘图 | 64×64 |
| 褪色护身符 | `relic_faded_ward_talisman` | [relic_faded_ward_talisman.png](assets/ui/icons/relics/relic_faded_ward_talisman.png) | 36×36 | 22×32 | 36×36 / 1 | 72×72 / 2 | 8 | 64×64 原始绘图 | 64×64 |
| 双腔弹匣 | `relic_twin_chamber_magazine` | [relic_twin_chamber_magazine.png](assets/ui/icons/relics/relic_twin_chamber_magazine.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 7 | 64×64 原始绘图 | 64×64 |
| 凝时琥珀 | `relic_stilltime_amber` | [relic_stilltime_amber.png](assets/ui/icons/relics/relic_stilltime_amber.png) | 36×36 | 28×32 | 36×36 / 1 | 72×72 / 2 | 6 | 64×64 原始绘图 | 64×64 |

## 5. 武器图标与附魔图标

### 5.1 武器 icon：36×36 已正式接入

2026-10-21，按用户确认的电浆炮样稿完成 **14 种武器主图标 + 1 张移星秘典返程图标，共 15 张**。正式 PNG、同名 PXG/PAL 全部采用 **36×36**；alpha 为 0/255，每张不超过 16 色。输入为原始武器大图的 11 个裁切，以及原始绘图脚本的 4 张 64×64 画布；没有把正式 128px 资源作为转换输入。

11 个高清来源取自 Git `f304137` 的 `wuqi_icon.png`（1536×2752），SHA-256 为 `2f244d0a6346a82313ff6dedfef4bd8672fab1e6719db3490fbcd5a4a921976e`。4 个独立像素来源取自 Git `02b3ef4` 的 `build_mobility_weapon_art.py`，仅跳过原脚本导出时的 2 倍放大，恢复 64px 原始绘制画布；其 2 倍最近邻结果逐像素等于旧正式图，验证了来源。电浆炮复用用户确认的文件，SHA-256 保持 `baf90ca42ba1809452a7547e33500fe07403f3e000b1d2de0fd8587b287211b2`。

使用项目 Picxel 原图像素化流程，加上局部像素修整：补齐炉灯提手、整理连续链条与枪口，合并细碎划痕，简化触手吸盘和秘典边框。移星秘典与返程状态共用同样大小的书体，返程态叠加箭头。没有调用生图 API。原始输入、确认样稿及逐项哈希保留在[本轮接入清单](artifacts/previews/weapons_36/20261021-r01/manifest.json)。

| 场合 | 正式源图 | 实际绘制尺寸 | 倍率 | 布局规则 |
|---|---|---|---|---|
| 战斗武器栏，常规档 | 36×36 | 72×72 | 2 | 108×108 卡框，间距 10px |
| 战斗武器栏，紧凑档 | 36×36 | 36×36 | 1 | 72×72 卡框，间距 8px；超宽换行 |
| Esc 武器栏 | 36×36 | 72×72 | 2 | 图像完整居中；卡框 88px |
| 商店武器卡、奖励页上方武器栏 | 36×36 | 72×72 | 2 | 不按源图包围盒裁切 |
| 常规/紧凑/小型武器奖励 | 36×36 | 72×72 | 2 | 图框预留空间；取消图像浮动、入场/悬停缩放 |
| 游戏百科 | 36×36 | 72×72 | 2 | 完整画布居中 |
| 附魔工作台：当前武器、切换按钮、出售确认 | 36×36 | 36×36 | 1 | 同一档位；按钮文字与图像分别留白 |
| 鼠标旁武器图、拖拽预览 | 36×36 | 36×36 | 1 | 鼠标外框 44px，四边各 4px |
| 伤害统计 | 36×36 | 36×36 | 1 | 40px 行高；图像位置取整 |
| 选人页初始武器 | 36×36 | 36×36 | 1 | 保留完整画布，不裁透明边后拉满 |

**战斗栏切档**：可用宽度为 `floor(min(画布宽×0.8, 画布宽−32))`。常规档需要 `N×108+(N−1)×10`；超宽时整栏切为 36px，仍放不下则换行，行间距 20px。1920×1080 下 1～13 件使用 72px，14 件起使用 36px；紧凑档一行最多 19 件。图标始终保留完整方形画布，位置取整。秘仪书反馈保留亮度和边框闪烁，不再缩放图片。

`ItemIconArt.texture_for()` 与武器专用绘制器均直接取正式 36px 源图，窗口变化不会切回旧图集。旧 `clarity` 武器变体仍留作历史资源，但已退出武器运行采样路径；它们不是正式显示版本。上述 1/2 倍保证以 **1920×1080 逻辑画布、1080p 输出**为基准；720p/1440p 的整体窗口缩放仍会改变物理像素对应关系，本轮没有更改全项目窗口缩放策略。

| 武器 | 配置 ID | 正式资源 | 正式/推荐源尺寸 | 可见主体 | 色数 | 原始裁切/绘制画布 | 常规 / 紧凑显示 |
|---|---|---|---|---|---|---|---|
| 营地短刀 | `weapon_camp_dagger` | [weapon_camp_dagger.png](assets/ui/icons/weapons/weapon_camp_dagger.png) | 36×36 | 26×32 | 9 | 492×544 | 72×72 / 2；36×36 / 1 |
| 赤铜炉灯 | `weapon_copper_lamp` | [weapon_copper_lamp.png](assets/ui/icons/weapons/weapon_copper_lamp.png) | 36×36 | 18×32 | 13 | 503×544 | 72×72 / 2；36×36 / 1 |
| 裂地战锤 | `weapon_earth_hammer` | [weapon_earth_hammer.png](assets/ui/icons/weapons/weapon_earth_hammer.png) | 36×36 | 28×32 | 8 | 489×544 | 72×72 / 2；36×36 / 1 |
| 铸铁榴弹炮 | `weapon_iron_grenade_cannon` | [weapon_iron_grenade_cannon.png](assets/ui/icons/weapons/weapon_iron_grenade_cannon.png) | 36×36 | 32×32 | 9 | 489×524 | 72×72 / 2；36×36 / 1 |
| 坤舆秘仪书 | `weapon_kunyu_ritual_tome` | [weapon_kunyu_ritual_tome.png](assets/ui/icons/weapons/weapon_kunyu_ritual_tome.png) | 36×36 | 32×32 | 11 | 492×516 | 72×72 / 2；36×36 / 1 |
| 流星摆锤 | `weapon_meteor_flail` | [weapon_meteor_flail.png](assets/ui/icons/weapons/weapon_meteor_flail.png) | 36×36 | 30×32 | 8 | 503×516 | 72×72 / 2；36×36 / 1 |
| 异化触手 | `weapon_mutant_tentacle` | [weapon_mutant_tentacle.png](assets/ui/icons/weapons/weapon_mutant_tentacle.png) | 36×36 | 26×32 | 11 | 489×516 | 72×72 / 2；36×36 / 1 |
| 守夜长枪 | `weapon_nightwatch_spear` | [weapon_nightwatch_spear.png](assets/ui/icons/weapons/weapon_nightwatch_spear.png) | 36×36 | 32×32 | 10 | 492×507 | 72×72 / 2；36×36 / 1 |
| 电浆炮 | `weapon_plasma_cannon` | [weapon_plasma_cannon_v2.png](assets/ui/icons/weapons/weapon_plasma_cannon_v2.png) | 36×36 | 32×30 | 12 | 503×507 | 72×72 / 2；36×36 / 1 |
| 食利者钱袋 | `weapon_rentier_purse` | [weapon_rentier_purse.png](assets/ui/icons/weapons/weapon_rentier_purse.png) | 36×36 | 28×32 | 6 | 489×507 | 72×72 / 2；36×36 / 1 |
| 木质弓箭 | `weapon_void_blade` | [weapon_wood_arrow.png](assets/ui/icons/weapons/weapon_wood_arrow.png) | 36×36 | 30×32 | 10 | 492×572 | 72×72 / 2；36×36 / 1 |
| 突进短刃 | `weapon_dash_blade` | [weapon_dash_blade.png](assets/ui/icons/weapons/weapon_dash_blade.png) | 36×36 | 22×31 | 11 | 64×64 | 72×72 / 2；36×36 / 1 |
| 巨型手持火炮 | `weapon_hand_cannon` | [weapon_recoil_gun.png](assets/ui/icons/weapons/weapon_recoil_gun.png) | 36×36 | 32×30 | 10 | 64×64 | 72×72 / 2；36×36 / 1 |
| 移星秘典 | `weapon_star_tome` | [weapon_star_tome.png](assets/ui/icons/weapons/weapon_star_tome.png) | 36×36 | 31×31 | 10 | 64×64 | 72×72 / 2；36×36 / 1 |
| 移星秘典（返程状态） | `weapon_star_tome` | [weapon_star_tome_return.png](assets/ui/icons/weapons/weapon_star_tome_return.png) | 36×36 | 31×31 | 10 | 64×64 | 72×72 / 2；36×36 / 1 |

实机审阅：以正式 GameRoot/BattleRoot 和正式 UI 组件运行，使用临时审阅库存覆盖不同武器；不写入玩家进度。完整截图为 1920×1080，另提供未缩放的界面局部拼图。

- [全部新图标](artifacts/previews/weapons_36/20261021-r01/review/icons-clean.png)
- [实机 UI 局部汇总](artifacts/previews/weapons_36/20261021-r01/screenshots/ui-details.png)
- [战斗栏 72px](artifacts/previews/weapons_36/20261021-r01/screenshots/02_battle_72.png)、[14 武器切换 36px](artifacts/previews/weapons_36/20261021-r01/screenshots/03_battle_many_36.png)
- [Esc 72px](artifacts/previews/weapons_36/20261021-r01/screenshots/04_esc_72.png)、[商店 72px](artifacts/previews/weapons_36/20261021-r01/screenshots/06_shop_72.png)、[工作台 36px](artifacts/previews/weapons_36/20261021-r01/screenshots/07_workbench_36.png)
- [选人页 36px](artifacts/previews/weapons_36/20261021-r01/screenshots/01_character_select_36.png)、[百科 72px](artifacts/previews/weapons_36/20261021-r01/screenshots/05_encyclopedia_72.png)

验证结果见[本轮检查汇总](artifacts/validation/weapons_36_installed_20261021/summary.json)。Godot headless 导入、图标复用、战斗栏切档/输入、原生 HUD、选人页、奖励布局、冷却/亮度反馈检查均通过；GPU 实机 175 项检查通过，7 张完整截图中的 41 个武器图标与正式源 PNG 的全部不透明像素对应（允许每通道 1/255 输出误差），没有丢失源像素。后台私有桌面已核对且 `foreground_samples=0`。旧移动武器集成测试在上一轮确认的 16 个射程/伤害基线失败不属于本次图标接入，本轮没有修改这些玩法参数。

### 5.2 附魔 icon：32×32 已正式接入

附魔背包布局：列表左边框与武器列表、已装备附魔槽的左边框对齐，右边框与“出售武器”按钮右侧对齐。六列等权重（各 1）铺满可用宽度，卡片最小尺寸为 136×48，1920×1080 实机下宽度约 139–140px（整数像素分配），高度 48px；框内四边各留 8px。列表区域左右 padding 为 0、上下为 12px，列间距 16px、行间距 8px。图标仍为 32×32、1 倍；最新实机截图已更新，小窗口通过滚动访问完整列表。

2026-10-21：全部 **19 张正式 PNG/PXG/PAL 已替换为用户确认的原图 → 32px 版本**。正式 PNG 哈希与确认稿逐张一致；源图为从 Git `f304137:artifacts/sources/spells/fashu_icon.png` 恢复的原始 **1536×2752** 图集，未用旧正式 64px PNG 作为转换输入。原图、裁片、处理与局部修整记录保留在[本轮制作目录](artifacts/previews/spell_icons_32/20261021-r01/README.md)。

采用项目 Picxel 本地像素化与网格修整；箭杆、星形边框、晶体切面、雪花分支已根据目标尺寸接续或简化。每图不超过 16 色、透明度为 0/255，正式 PNG 与可编辑网格一致。显示时保留完整 32px 画布，不裁可见包围盒再适配，不选旧尺寸变体。

| 使用位置 | 正式源图 | 当前显示 | 倍率 | 实现说明 |
|---|---|---|---|---|
| 背包基础卡、工作台库存 | 32×32 | 32×32 | 1 | 固定原尺寸；容器不足时滚动，不压缩图标 |
| 工作台已装备槽位 | 32×32 | 32×32 | 1 | 独立固定绘制区域，文字另行布局 |
| 地面掉落 | 32×32 | 32×32 | 1 | Sprite2D 缩放为 (1,1)，光晕不改变图标尺寸 |
| Esc 物品栏 | 32×32 | 64×64 | 2 | 不再随 `_display_scale` 连续改变图标；扩大必要卡框 |
| 选人页初始附魔 | 32×32 | 32×32 | 1 | 取消约 25.116px 图框与透明包围盒裁切 |
| 拖拽预览 | 32×32 | 32×32 | 1 | 修复旧 48px 最小尺寸缓存导致的放大 |
| 武器说明中的附魔图像 | 32×32 | 32×32 | 1 | BBCode 从 24px 改为 32px；Esc/工作台等说明复用 |
| 武器出售确认中的返还附魔 | 32×32 | 32×32 | 1 | 由 30px 改为 32px |
| 共用出售弹窗的附魔主图 | 32×32 | 32×32 | 1 | 与武器 36px 分支分别处理，反复切换不串档 |

工作台「出售附魔」目前直接执行出售，共用出售弹窗的附魔分支作为额外复用检查；本轮未增加确认步骤。百科目前仅有遗物/武器分类，商店未直接陈列附魔商品。战斗法术特效仍按第 7 节独立规格处理。

**验证范围：1920×1080 设计画布与同尺寸输出。** 9 张真实 GPU 截图、468 项运行检查通过；94 次图标绘制的全部不透明像素与正式 PNG 对应（每通道允许 1/255 输出误差），差异像素 0。后台私有桌面一致且 `foreground_samples=0`。其他窗口的整体拉伸仍可能产生非整数倍率，不能把本结论扩展为所有素材、所有输出分辨率都已统一。

7 项 headless 场景合计 1455 条断言通过，包含图标接入、旧工作台审阅、掉落、属性附魔、选人页、图标复用、附魔说明。旧审阅断言已同步当前六列加滚动/省略显示规则。部分 headless 运行仍报告 Dummy 渲染器的纹理初始化或退出 RID 清理诊断（涉及既有结算面板 GradientTexture）；没有 GDScript 编译/运行错误，GPU 审阅未出现这些诊断。原始日志保留，未将其混记为断言失败。

实机审阅：[完整 9 张截图](artifacts/previews/spell_icons_32/20261021-r01/screenshots/README.md)、[未缩放局部总览](artifacts/previews/spell_icons_32/20261021-r01/screenshots/ui-details.png)、[逐像素对应检查](artifacts/previews/spell_icons_32/20261021-r01/screenshots/pixel-correspondence.json)。

| 附魔 | ID | 正式资源 | 分辨率 | 色数 | 场景显示 / 倍率 |
|---|---|---|---|---|---|
| 巨力 | `scroll_might` | [scroll_might.png](assets/ui/icons/augmentations/scroll_might.png) | 32×32 | 4 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 智慧 | `scroll_wisdom` | [scroll_wisdom.png](assets/ui/icons/augmentations/scroll_wisdom.png) | 32×32 | 5 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 多投 | `scroll_multishot` | [scroll_multishot.png](assets/ui/icons/augmentations/scroll_multishot.png) | 32×32 | 4 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 领域 | `scroll_domain` | [scroll_domain.png](assets/ui/icons/augmentations/scroll_domain.png) | 32×32 | 5 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 会心 | `scroll_precision` | [scroll_precision.png](assets/ui/icons/augmentations/scroll_precision.png) | 32×32 | 5 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 致命 | `scroll_lethality` | [scroll_lethality.png](assets/ui/icons/augmentations/scroll_lethality.png) | 32×32 | 4 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 迅捷 | `scroll_haste` | [scroll_haste.png](assets/ui/icons/augmentations/scroll_haste.png) | 32×32 | 6 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 弹跳 | `scroll_bounce` | [scroll_bounce.png](assets/ui/icons/augmentations/scroll_bounce.png) | 32×32 | 5 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 水流 | `scroll_water` | [scroll_water.png](assets/ui/icons/augmentations/scroll_water.png) | 32×32 | 6 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 光辉剑 | `scroll_light_sword` | [scroll_light_sword.png](assets/ui/icons/augmentations/scroll_light_sword.png) | 32×32 | 8 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 黑洞 | `scroll_black_hole` | [scroll_black_hole.png](assets/ui/icons/augmentations/scroll_black_hole.png) | 32×32 | 6 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 火焰 | `scroll_fire` | [scroll_fire.png](assets/ui/icons/augmentations/scroll_fire.png) | 32×32 | 5 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 震荡 | `scroll_explosion` | [scroll_explosion.png](assets/ui/icons/augmentations/scroll_explosion.png) | 32×32 | 4 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 电火花 | `scroll_lightning` | [scroll_lightning.png](assets/ui/icons/augmentations/scroll_lightning.png) | 32×32 | 5 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 落雷 | `scroll_electric_spark` | [scroll_electric_spark.png](assets/ui/icons/augmentations/scroll_electric_spark.png) | 32×32 | 6 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 分裂 | `scroll_split` | [scroll_split.png](assets/ui/icons/augmentations/scroll_split.png) | 32×32 | 6 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 穿透 | `scroll_pierce` | [scroll_pierce.png](assets/ui/icons/augmentations/scroll_pierce.png) | 32×32 | 6 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 结霜 | `scroll_ice` | [scroll_ice.png](assets/ui/icons/augmentations/scroll_ice.png) | 32×32 | 4 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |
| 风刃 | `scroll_wind` | [scroll_wind.png](assets/ui/icons/augmentations/scroll_wind.png) | 32×32 | 4 | Esc 64×64 / 2；其余图标入口 32×32 / 1 |

## 6. 武器攻击素材与特效

本节全部武器的推荐源帧、倍率及动态缩放规则见 **10.5**。攻击贴图与同名 UI 图标使用不同规格。

以下与 UI icon 分开统计。动态尺寸取决于范围属性、动作进度、分裂代数和方向；“默认尺寸”不是最大可能范围。

### 6.1 各武器的绘制规则

| 武器 | 当前攻击素材 / 实现 | 单帧或基础尺寸 | 基准倍率 / 公式 | 基准显示与像素网格 |
|---|---|---|---|---|
| 木质弓箭 | `projectile_wood_arrow.png` | 24×24 | `1×V`，默认 1 | 24×24；飞行方向旋转；拖尾另由粒子系统绘制 |
| 电浆炮 | 运行时生成核心 ImageTexture，16 帧 | 24×24 | `2H/24`；H=20 时 1.666667 | 核心 40×40；AlignedAtlas 网格 1；周边电弧含 1 px 线及 2 px 装饰 |
| 铸铁榴弹炮：弹体 | 程序矩形拼接 | 包围盒约 12×13 | `V`；分裂弹再乘 0.65 | 默认约 12×13，无源 PNG |
| 铸铁榴弹炮：爆炸 | `block_vfx/grenade.png` | 128×128，12 帧 | `(2B/128,2B×G/128)`；B 为爆炸半径，默认 107 | 默认 214×141.045；网格 3；非地面椭圆路径为 214×214 |
| 坤舆秘仪书：法阵 | `kunyu_domain_rune.png` | 384×240 | 父层 `(R/220,minor/145)`，默认约 (1.668182,1.668966) | 约 640.582×400.552；网格 2；外围粒子另按最终像素取整 |
| 坤舆秘仪书：命中 | `block_vfx/tome.png` | 96×128，10 帧 | 1 | 96×128；网格 3；旧 `_draw_tome_impact` 的 0.5 倍并非当前 `_draw` 路径 |
| 食利者钱袋：金币 | `rentier_coin_spin.png` | 16×16，8 帧 | `V`；分裂为 `0.75×V` | 默认 16×16 / 分裂 12×12；网格 1 |
| 食利者钱袋：命中 | `pixel_baked/coin_hit.png` | 80×80，25 帧 | 1 | 80×80；普通最近邻图集绘制 |
| 赤铜炉灯 | Shader 火焰 + 128×128 程序噪声 | 无固定美术帧 | 正式路径改变`reach`，扇角固定60°；不按噪声尺寸算倍率 | 默认reach=360，绘制承载框720×720；分裂reach再乘0.65；主体为地面投影扇形，网格2 |
| 异化触手：主体 | `mutant_tentacle.png` | 128×128，19 帧 | `(R/140,H/20)`，默认 (1.664286,1.65) | 约 213.029×211.2；分裂再乘 0.65；主体按方向旋转 |
| 异化触手：攻击覆盖 | `block_vfx/tentacle.png` | 160×128，8 帧 | 同主体倍率 | 约 266.286×211.2；网格 3；分裂再乘 0.65 |
| 裂地战锤：主体 | `earth_hammer.png` | 64×64，9 帧 | `2.2×V` | 默认 140.8×140.8；方向旋转 |
| 裂地战锤：挥击 | `block_vfx/hammer.png` | 128×128，8 帧 | `2.2×V` | 默认 281.6×281.6；网格 3 |
| 裂地战锤：地裂 | `block_vfx/hammer_crack.png` | 96×96，6 帧 | 主段 `(spacing/96,1.30)×V`；子段 `(length/96,0.90)×V` | 默认主段约 107×124.8；按障碍裁剪，网格 3；飞屑由代码另绘 |
| 营地短刀：刀身 | `camp_dagger.png` | 32×32 | `(R_base经距离加成/40,H/4)`，默认 (4.175,3.25) | 默认 133.6×104；按挥刀方向旋转；注释中的“固定尺寸”不能解释为 scale=1 |
| 营地短刀：刀光 | `camp_dagger_slash.png` | 64×64 | `R/29` 后地面投影；默认约 5.758621 | 未投影完整画布约 368.552×368.552；逐帧只显示其中一段，网格 3 |
| 守夜长枪：枪身 | `weapon_nightwatch_spear.png` | 文件 248×28，使用区域 238×28 | `(R×144/220/238,2H/28)` | 默认约 240.218×46，即 (1.009320,1.642857)；旋转显示 |
| 守夜长枪：枪芒 | `block_vfx/spear.png` | 192×64，7 帧 | `(tip(t)×1.12/192,140.8×max(0.75,H/12)/64)` | 宽度随刺出进度变化；默认 H=23 时高度约 269.867；网格 3 |
| 守夜长枪：分裂枪片 | 复用枪身的 238×28 区域 | 238×28 | (54/238,12/28)≈(0.226891,0.428571) | 54×12；另随方向旋转 |
| 流星摆锤：锤头 | `meteor_flail_head.png` | 40×40 | `2H/40`；子摆再乘 0.8 | 默认 54×54，1.35 倍；子摆 43.2×43.2，1.08 倍 |
| 流星摆锤：链节 / 握柄 | `meteor_flail_chain_link.png` / `meteor_flail_grip.png` | 9×7 / 12×32 | 1 / 0.5 | 9×7 / 6×16；旋转排列 |
| 流星摆锤：轨迹 | `block_vfx/flail.png` | 320×320，18 帧 | `未投影锤头距离/144`，再地面投影与镜像 | 默认外伸距离 240 时倍率约 1.666667；实际随摆动变化；网格 3 |
| 突进短刃：拖尾 | `mobility/dash_trail.png` | 128×64，8 帧 | 1 | 128×64，方向旋转；网格 2 |
| 突进短刃：落点斩圈 | `mobility/dash_circle.png` | 160×160，10 帧 | `(H/96×1.1)×(1,G)` | H=160 时约 (1.833333,1.208333)，293.333×193.333；网格 2 |
| 巨型手持火炮：喷流 | Shader + 共用程序噪声 | 无固定美术帧 | reach=`1.25R`，默认 312.5 | 绘制承载框 625×625，实际喷流远小于整个框；网格 3 |
| 巨型手持火炮：弹丸 | `mobility/pellet.png` | 48×16，4 帧 | `V`；分裂再乘 0.65 | 默认 48×16 / 分裂 31.2×10.4；方向旋转 |
| 巨型手持火炮：命中 / 后坐尘 | `block_vfx/pellet_hit.png` / `mobility/recoil_dust.png` | 64×64，6 帧 / 128×64，8 帧 | 1 | 64×64 / 128×64；网格 2 |
| 移星秘典：离开 / 到达 / 返回 | `star_depart` / `star_arrive` / `star_return` | 各 96×128，8 帧 | 1 | 各 96×128；网格 2 |
| 移星秘典：锚点 | `star_anchor.png` | 128×128，12 帧 | 1 | 128×128；网格 2 |
| 移星秘典：冲击波 | `star_shockwave.png` | 160×160，10 帧 | `(H/64)×(1,G)` | H=107 时约 (1.671875,1.101918)，267.5×176.307；网格 2 |

上述无范围加成的 `R/H/V` 已按正式角色与武器配置做无窗口读取。通用公式仍以运行时 getter 为准，不能用表中默认值覆盖升级后的武器。

绘制依据：`scripts/weapons/` 下的对应武器脚本，以及 `scripts/effects/weapon_block_vfx.gd`、`mobility_atlas_effect.gd`、`aligned_atlas.gd`、`plasma_ball_visual.gd`、`copper_lamp_flame.gd`、`cannon_jet_flame.gd`。

### 6.2 武器 PNG 文件尺寸索引

下表列出完整文件尺寸，显示倍率对应上一节；“保留”行不会作为当前主攻击的证据。

| 源文件 | 整张尺寸 | 单帧 / 使用区域 | 有效帧数 | 当前用途与倍率 |
|---|---|---|---|---|
| [camp_dagger.png](assets/sprites/weapons/camp_dagger.png) | 32×32 | 32×32 | 1 | 刀身；默认(4.175,3.25) |
| [camp_dagger_slash.png](assets/sprites/weapons/effects/camp_dagger_slash.png) | 64×64 | 64×64 | 1 | 刀光；R/29，再投影 |
| [earth_hammer.png](assets/sprites/weapons/earth_hammer/earth_hammer.png) | 576×64 | 64×64 | 9 | 锤体；2.2V |
| [flail.png](assets/sprites/weapons/effects/block_vfx/flail.png) | 5760×320 | 320×320 | 18 | 正式摆锤轨迹；锤头距离/144，再投影 |
| [grenade.png](assets/sprites/weapons/effects/block_vfx/grenade.png) | 1536×128 | 128×128 | 12 | 正式榴弹爆炸；2B/128，再投影 |
| [hammer.png](assets/sprites/weapons/effects/block_vfx/hammer.png) | 1024×128 | 128×128 | 8 | 锤击；2.2V |
| [hammer_crack.png](assets/sprites/weapons/effects/block_vfx/hammer_crack.png) | 576×96 | 96×96 | 6 | 正式地裂；长度/96、纵向1.3或0.9，再乘V |
| [muzzle.png](assets/sprites/weapons/effects/block_vfx/muzzle.png) | 768×96 | 128×96 | 6 | 保留；当前炮口主路径为CannonJetFlame Shader |
| [pellet_hit.png](assets/sprites/weapons/effects/block_vfx/pellet_hit.png) | 384×64 | 64×64 | 6 | 正式手炮命中；1 |
| [spear.png](assets/sprites/weapons/effects/block_vfx/spear.png) | 1344×64 | 192×64 | 7 | 枪芒；宽随tip(t)，高随H |
| [tentacle.png](assets/sprites/weapons/effects/block_vfx/tentacle.png) | 1280×128 | 160×128 | 8 | 触手覆盖；(R/140,H/20)，子分支再×0.65 |
| [tome.png](assets/sprites/weapons/effects/block_vfx/tome.png) | 960×128 | 96×128 | 10 | 正式秘仪书命中；1 |
| [ground_cracks.png](assets/sprites/weapons/ground_cracks/ground_cracks.png) | 256×64 | 64×64 | 4 | 保留；当前默认地裂使用block_vfx/hammer_crack |
| [kunyu_domain_rune.png](assets/sprites/weapons/kunyu_domain_rune.png) | 384×240 | 384×240 | 1 | 法阵；(R/220,minor/145) |
| [meteor_flail_chain_link.png](assets/sprites/weapons/meteor_flail/meteor_flail_chain_link.png) | 9×7 | 9×7 | 1 | 链节；1 |
| [meteor_flail_grip.png](assets/sprites/weapons/meteor_flail/meteor_flail_grip.png) | 12×32 | 12×32 | 1 | 握柄；0.5 |
| [meteor_flail_head.png](assets/sprites/weapons/meteor_flail/meteor_flail_head.png) | 40×40 | 40×40 | 1 | 锤头；2H/40，子摆×0.8 |
| [meteor_flail_trail.png](assets/sprites/weapons/meteor_flail/meteor_flail_trail.png) | 5760×320 | 320×320 | 18 | 保留；当前轨迹使用block_vfx/flail |
| [dash_circle.png](assets/sprites/weapons/mobility/dash_circle.png) | 1600×160 | 160×160 | 10 | 突进斩圈；H/96×1.1，再投影 |
| [dash_trail.png](assets/sprites/weapons/mobility/dash_trail.png) | 1024×64 | 128×64 | 8 | 突进拖尾；1 |
| [muzzle.png](assets/sprites/weapons/mobility/muzzle.png) | 576×64 | 96×64 | 6 | 保留；当前炮口主路径为Shader |
| [pellet.png](assets/sprites/weapons/mobility/pellet.png) | 192×16 | 48×16 | 4 | 手炮弹丸；V，子弹×0.65 |
| [pellet_hit.png](assets/sprites/weapons/mobility/pellet_hit.png) | 384×64 | 64×64 | 6 | 保留；实际CLIPS引用block_vfx/pellet_hit |
| [recoil_dust.png](assets/sprites/weapons/mobility/recoil_dust.png) | 1024×64 | 128×64 | 8 | 后坐尘；1 |
| [star_anchor.png](assets/sprites/weapons/mobility/star_anchor.png) | 1536×128 | 128×128 | 12 | 移星锚点；1 |
| [star_arrive.png](assets/sprites/weapons/mobility/star_arrive.png) | 768×128 | 96×128 | 8 | 移星到达；1 |
| [star_depart.png](assets/sprites/weapons/mobility/star_depart.png) | 768×128 | 96×128 | 8 | 移星离开；1 |
| [star_return.png](assets/sprites/weapons/mobility/star_return.png) | 768×128 | 96×128 | 8 | 移星返回；1 |
| [star_shockwave.png](assets/sprites/weapons/mobility/star_shockwave.png) | 1600×160 | 160×160 | 10 | 移星冲击波；H/64，再投影 |
| [mutant_tentacle.png](assets/sprites/weapons/mutant_tentacle/mutant_tentacle.png) | 2432×128 | 128×128 | 19 | 触手主体；(R/140,H/20)，子分支×0.65 |
| [projectile_wood_arrow.png](assets/sprites/weapons/projectiles/projectile_wood_arrow.png) | 24×24 | 24×24 | 1 | 箭；V，默认1 |
| [rentier_coin_spin.png](assets/sprites/weapons/rentier_coin_spin.png) | 128×16 | 16×16 | 8 | 金币；V，分裂×0.75 |
| [weapon_nightwatch_spear.png](assets/sprites/weapons/weapon_nightwatch_spear.png) | 248×28 | 238×28 | 1 | 248×28文件裁取238×28；显示尺寸见枪身/枪片 |

## 7. 附魔法术特效与像素尺寸

本节各附魔、反应、状态的推荐规格见 **10.6**；程序噪声分辨率不作为法术美术分辨率。

配置中文名以 `data_config/augmentations.json` 为准：**`scroll_lightning` 是“电火花”，`scroll_electric_spark` 是“落雷”**，不要仅按脚本英文名交换两者。

### 7.1 当前正式效果

| 附魔 | 当前实现 | 源帧 / 程序画布 | 缩放与实际绘制规则 | 网格 / 备注 |
|---|---|---|---|---|
| 巨力、智慧、多投、领域、会心、致命、迅捷 | 武器属性修改 | 无专属攻击 PNG | 修改伤害、数量、范围等；若改变范围，会通过对应武器/效果公式影响尺寸 | 图标源图已为 32×32；不能把“无独立特效”写成缺素材 |
| 弹跳 | 复用武器攻击 | 按第 6 节 | 命中处追加攻击，显示比例随对应武器路径 | 无独立通用动画图集 |
| 分裂 | 复用武器或弹体 | 按第 6 节 | 箭、金币、触手、榴弹、摆锤等各自处理；例如金币 0.75、手炮弹/触手 0.65、摆锤头 0.8 | 没有全武器统一分裂缩放值 |
| 穿透 | 改变命中次数 | 无专属帧 | 沿用当前弹体显示尺寸 | 不是新增 PNG 特效 |
| 水流 | `enchantment_blocks.gdshader` kind=1 | 程序噪声 128×128，仅驱动形态 | 配置 96，经 0.7×0.68×1.65 得终态横半轴 r=75.3984；纵半轴 0.66r=49.762944；承载框约 188.496×196.036 | 网格 3；视觉与判定共用终态椭圆，动画前 55% 完成扩散，之后不再扩大 |
| 黑洞 | Shader 核心 + 前后层程序气流 | 无固定美术帧；共用 128×128 噪声 | 视觉 reach=90，承载框 180×180；完全展开球体半径 31.5，伤害/初次吸附选取半径 94.5；两者共用范围倍率 | Shader 网格 3；气流含 1 px 线；不绘制伤害边界，球体张合不改变终态判定 |
| 光辉剑 | 烘焙剑体图集 | 等待/下落 80×272；落地消散 80×144 | 主体固定 1 倍；默认伤害半径 78 的变化不直接缩放剑体 | 普通最近邻帧；等待 1、下落 15、落地 46 帧；3 档细节 |
| 光辉剑：地面标记 / 裂痕 / 作用区 | 烘焙贴图 + 程序地面覆盖 | 32×32 / 72×16；覆盖无固定 PNG | 原标记 (1,G)→32×21.091、裂痕 72×16 保留；另按实际范围绘制 156×102.818 的终态椭圆，随范围同比变化 | 原标记网格 1；新增必要地面覆盖网格 2，最低细节档保留 |
| 火焰：飞行火种 | 程序 Shader | 14×22 火舌；噪声 128×128 | 火舌按 2 px 网格生成，默认不整张缩放 | 网格 2 |
| 火焰：地面火场 | 程序 Shader，3 根火舌 + 地面覆盖 | 火舌基础 31×48、34×52、57×60；覆盖无固定 PNG | 火舌仍乘 `clamp(r/30,0.85,1.3)`；另绘制与点燃判定一致的 2r×2Gr 椭圆，默认 60×39.545；合并/风扩张同步 | 火舌网格 3；必要地面覆盖网格 2，火舌高度不算作用区 |
| 火焰：附着燃烧 | 程序 Shader | 宽 `clamp(身体半径×1.4,14,24)`，高 28 | 向上对齐 2 px；跟随敌人 | 网格 2 |
| 震荡 | `enchantment_blocks` kind=0 | 无固定美术帧 | 纯击退控制，r=55.2，不乘范围倍率；承载框 132.48×110.4；终态环为直径 110.4 的圆，与瞬时击退圆一致 | 网格 3；前 55% 完成扩散，不再使用 0.72 纵向压缩 |
| 电火花：闪电主体 | `LightningPixelBolt` 动态光栅网格 | 无固定 PNG 宽高 | 根据起点/终点和分叉生成路径；增加跨度不是拉长一张固定图 | 网格 2；链条与回闪使用独立路径 |
| 电火花：命中火花 | 4 张 core/glow 图集 | 每帧 48×48；24 时间帧×32 变体 | 承载 Quad 为 48×48，再乘解析后的 `size_multiplier`；发光 UV 另乘 glow_scale | 默认尺寸因触发参数而变；可见粒子主体明显小于 48 帧画布 |
| 落雷：地面电弧（已移除） | 专用PNG与脚本已删除 | 历史单帧160×112 | 当前不生成、不加载 | 按用户要求完全移除；落雷预警、雷柱、命中粒子和落地冲击圈保留，见11.5 |
| 落雷：预警粒子 / 作用区 | `warning_masks.png` + 程序地面覆盖 | 8×8；16×16 布局，共 256 方向 | 每粒 1 倍→8×8；预警与判定共用 r=30 的地面椭圆，默认 60×39.545；范围只移动粒子中心 | 最多 24 粒；整张图 128×128；粒子全隐藏时仍保留 2px 网格地面覆盖 |
| 落雷：雷柱 / 落地冲击圈 | 复用动态闪电及程序地面圈 | 无固定 PNG | 雷柱高度默认 182；终态圈和伤害共用横半轴 30、纵半轴 19.773 的椭圆，范围倍率同步 | 雷线 2px；冲击圈前 60% 扩散至终态后消退，伤害仍在落地时结算 |
| 结霜：冰场 | `ice_d0/d1/d2.png` + 程序地面覆盖 | 128×80；37 帧 | 图集仍按 `r/51.2` 缩放；新增终态覆盖默认 102.4×56.32，与判定共用 (r,0.55r)，风扩张同步 | 原图集采样网格 1；必要地面覆盖网格 2，前 0.6 秒扩散至终态 |
| 风刃 | `enchantment_blocks` kind=5 | 无固定美术帧 | 承载框 `248×248×M`；圆形判定半径 `72×M`，不再依赖来源武器命中半径/攻击距离 | 网格 3；月牙外观与判定圆共用伤害范围倍率；128 噪声不等于248源帧 |

默认无加成时范围倍率为 1。当前 `StatDefinitions.RANGE_BONUS_EFFICIENCY=0.5`，通常范围倍率为 `1+经钳制的对应属性×0.5/100`，所以“伤害范围 +30”一般对应 1.15，不应直接写成 1.30。最终以 `EffectParameterResolver` / `EffectContext` 解析结果为准。

### 7.2 元素反应与状态

`ReactionBlockVisual.enabled=true` 为正式默认：蒸汽、导电、光反射等优先使用当前程序表现，不能因为 `baked_pixel_frames.gd` 预加载了图集，就认定屏幕正在播放该图集。

| 效果 | 当前来源与尺寸 / 公式 | 像素规则 |
|---|---|---|
| 蒸汽 | Shader 承载框 130×125 | 3 px；旧 96×96 蒸汽图集为回退 |
| 导电提示 | Shader 承载框 64×44 | 3 px；旧 48×32 图集为回退 |
| 湿润传播 | 起终点包围盒外扩 28 | 3 px；范围动态 |
| 解冻 | Shader 承载框 130×90 | 1 px |
| 光反射 | 当前 Shader 承载框 `2(r+35)` 的方形，默认 r=220 时 510×510；扇扫角变化 | 3 px；另有不同细节层与批量绘制逻辑 |
| 雷火反应爆发 | 当前 Shader 承载框 2.8r×2.7r | 3 px；负载档可把视觉半径变成 0.75r 或 min(18,0.22r) |
| 冰壳 | 72×72，11 张尺寸形态帧中选一张；绘制倍率 1 | 最终采样网格 1；改变的是选帧，不是整张缩放 |
| 减速雪花 | 64×40，倍率 `max(1,身体半径×0.88/16)` | 最终采样网格 1 |
| 冻结瞬间碎片 | `freeze_d0/d1.png`，每帧112×112，图集各39帧；绘制倍率1 | 普通最近邻；不随伤害范围或身体半径缩放，区别于持续显示的冰壳 |
| 风扩张冰场前沿 | 160×96，44 帧；倍率 `当前插值半径 / lerp(51.2,69.12,growth)` | 最终采样网格 1 |

头顶湿润/光/暗标记、眩晕粒子以及圣焰/暗焰的体型适配规则补充见11.4；它们由程序绘制，没有独立PNG源尺寸。

### 7.3 附魔及反应 PNG 图集文件清单

`d0/d1/d2` 是不同细节档；表中有效帧数不等于图集所有格子的总数，末尾空格不能计作动画帧。“回退/保留”不计为当前默认的主画面素材。

| 源文件 | 整张尺寸 | 单帧 / 使用区域 | 有效帧 / 方向数 | 正式状态与倍率 |
|---|---|---|---|---|
| [ice_d0.png](assets/effects/pixel_baked/ice_d0.png) | 1024×400 | 128×80 | 37 | 正式冰场；r/51.2，默认1；最终网格1 |
| [hole_d0.png](assets/effects/pixel_baked/hole_d0.png) | 1664×1456 | 208×208 | 52 | 保留/旧路径；当前黑洞核心为Shader和气流 |
| [sword_wait_d0.png](assets/effects/pixel_baked/sword_wait_d0.png) | 640×272 | 80×272 | 1 | 正式光辉剑主体；1 |
| [sword_fall_d0.png](assets/effects/pixel_baked/sword_fall_d0.png) | 640×544 | 80×272 | 15 | 正式光辉剑主体；1 |
| [sword_land_d0.png](assets/effects/pixel_baked/sword_land_d0.png) | 640×864 | 80×144 | 46 | 正式光辉剑主体；1 |
| [ice_d1.png](assets/effects/pixel_baked/ice_d1.png) | 1024×400 | 128×80 | 37 | 正式冰场；r/51.2，默认1；最终网格1 |
| [hole_d1.png](assets/effects/pixel_baked/hole_d1.png) | 1664×1456 | 208×208 | 52 | 保留/旧路径；当前黑洞核心为Shader和气流 |
| [sword_wait_d1.png](assets/effects/pixel_baked/sword_wait_d1.png) | 640×272 | 80×272 | 1 | 正式光辉剑主体；1 |
| [sword_fall_d1.png](assets/effects/pixel_baked/sword_fall_d1.png) | 640×544 | 80×272 | 15 | 正式光辉剑主体；1 |
| [sword_land_d1.png](assets/effects/pixel_baked/sword_land_d1.png) | 640×864 | 80×144 | 46 | 正式光辉剑主体；1 |
| [ice_d2.png](assets/effects/pixel_baked/ice_d2.png) | 1024×400 | 128×80 | 37 | 正式冰场；r/51.2，默认1；最终网格1 |
| [hole_d2.png](assets/effects/pixel_baked/hole_d2.png) | 1664×1456 | 208×208 | 52 | 保留/旧路径；当前黑洞核心为Shader和气流 |
| [sword_wait_d2.png](assets/effects/pixel_baked/sword_wait_d2.png) | 640×272 | 80×272 | 1 | 正式光辉剑主体；1 |
| [sword_fall_d2.png](assets/effects/pixel_baked/sword_fall_d2.png) | 640×544 | 80×272 | 15 | 正式光辉剑主体；1 |
| [sword_land_d2.png](assets/effects/pixel_baked/sword_land_d2.png) | 640×864 | 80×144 | 46 | 正式光辉剑主体；1 |
| [hole_shadow.png](assets/effects/pixel_baked/hole_shadow.png) | 384×140 | 48×20 | 52 | 保留/旧路径；当前黑洞核心为Shader和气流 |
| [sword_mark.png](assets/effects/pixel_baked/sword_mark.png) | 256×32 | 32×32 | 1 | 正式剑标记；(1,G)，最终网格1 |
| [sword_cracks.png](assets/effects/pixel_baked/sword_cracks.png) | 576×16 | 72×16 | 1 | 正式剑裂痕；1 |
| [steam_d0.png](assets/effects/pixel_baked/steam_d0.png) | 768×864 | 96×96 | 67 | 回退；ReactionBlockVisual.enabled=false时按1倍绘制 |
| [frost_front_d0.png](assets/effects/pixel_baked/frost_front_d0.png) | 1280×576 | 160×96 | 44 | 保留细节版本；当前扩张路径指定d1 |
| [steam_d1.png](assets/effects/pixel_baked/steam_d1.png) | 768×864 | 96×96 | 67 | 回退；ReactionBlockVisual.enabled=false时按1倍绘制 |
| [frost_front_d1.png](assets/effects/pixel_baked/frost_front_d1.png) | 1280×576 | 160×96 | 44 | 正式冰场扩张；当前插值半径/基准插值半径 |
| [conduct.png](assets/effects/pixel_baked/conduct.png) | 384×64 | 48×32 | 14 | 回退；ReactionBlockVisual.enabled=false时按1倍绘制 |
| [grenade.png](assets/effects/pixel_baked/grenade.png) | 1152×576 | 144×144 | 31 | 保留/旧路径；当前对应命中使用block_vfx |
| [tome.png](assets/effects/pixel_baked/tome.png) | 768×480 | 96×96 | 37 | 保留/旧路径；当前对应命中使用block_vfx |
| [coin_hit.png](assets/effects/pixel_baked/coin_hit.png) | 640×320 | 80×80 | 25 | 正式金币命中；1 |
| [ice_shell.png](assets/effects/pixel_baked/ice_shell.png) | 576×144 | 72×72 | 11 | 正式冰壳；1，按身体半径选帧 |
| [slowed.png](assets/effects/pixel_baked/slowed.png) | 512×40 | 64×40 | 1 | 正式雪花；max(1,身体半径×0.88/16) |
| [freeze_d0.png](assets/sprites/effects/ice_shards/freeze_d0.png) | 896×560 | 112×112 | 图集39帧 | 正式冻结瞬间碎片，低细节档；1倍 |
| [freeze_d1.png](assets/sprites/effects/ice_shards/freeze_d1.png) | 896×560 | 112×112 | 图集39帧 | 正式冻结瞬间碎片，中/高细节档共用；1倍 |
| [thaw_d0.png](assets/sprites/effects/ice_shards/thaw_d0.png) | 896×672 | 112×112 | 图集45帧 | 保留；当前解冻先进入Shader路径并返回，不播放此图集 |
| [thaw_d1.png](assets/sprites/effects/ice_shards/thaw_d1.png) | 896×672 | 112×112 | 图集45帧 | 保留；当前解冻先进入Shader路径并返回，不播放此图集 |
| [shard.png](assets/effects/pixel_baked/shard.png) | 512×32 | 64×32 | 1 | 反射回退碎片；(length/38,width/11) |
| [star.png](assets/effects/pixel_baked/star.png) | 192×28 | 24×28 | 1 | 反射回退星点；radius/11 |
| [reflection_beam.png](assets/effects/pixel_baked/reflection_beam.png) | 1888×20 | 236×20 | 1 | 回退；反射当前优先Shader；回退倍率(r/220,1) |
| [reflection_sides.png](assets/effects/pixel_baked/reflection_sides.png) | 1760×20 | 220×20 | 1 | 回退；反射当前优先Shader；回退倍率(r/220,1) |
| [warning_masks.png](assets/effects/electric_spark_warning/warning_masks.png) | 128×128 | 8×8 | 256 | 正式落雷预警；单粒1倍，半径只改变粒子中心 |
| `assets/effects/lightning_ground_arcs/ground_arcs.png`（已删除） | 历史1280×224 | 历史160×112 | 历史16 | 用户要求移除落雷地面电弧；不再属于正式资源 |
| [particle_square.png](assets/effects/pixel_baked/particle_square.png) | 4×4 | 4×4 | 1 | 通用粒子遮罩；目标粒子尺寸/4，按profile与时序变化 |
| [particle_circle.png](assets/effects/pixel_baked/particle_circle.png) | 128×128 | 128×128 | 1 | 通用圆形粒子遮罩；目标粒子尺寸/128，非128px可见粒子 |
| [flash_core.png](assets/effects/lightning_hit_png/flash_core.png) | 1152×1536 | 48×48 | 24×32=768 | 正式命中粒子；size_multiplier；glow另有UV缩放 |
| [flash_glow.png](assets/effects/lightning_hit_png/flash_glow.png) | 1152×1536 | 48×48 | 24×32=768 | 正式命中粒子；size_multiplier；glow另有UV缩放 |
| [impact_core.png](assets/effects/lightning_hit_png/impact_core.png) | 1152×1536 | 48×48 | 24×32=768 | 正式命中粒子；size_multiplier；glow另有UV缩放 |
| [impact_glow.png](assets/effects/lightning_hit_png/impact_glow.png) | 1152×1536 | 48×48 | 24×32=768 | 正式命中粒子；size_multiplier；glow另有UV缩放 |

### 7.4 全部 19 种附魔对范围属性的响应（2026-10-21 源码复核）

这里比较只增加「伤害范围」属性后的新一次施法，其他条件相同。「攻击距离」对应 `area_size`，「伤害范围」对应 `damage_area_size`，是两个独立属性。正常正向加成下，伤害范围倍率 `M = 1 + damage_area_size × 0.5 / 100`；例如领域提供 +30，对应半径/宽度约 1.15 倍，不是 1.30 倍。以下公式使用当前基础参数，省略负向属性的安全下限和额外效果修正。

| 附魔 | 作用范围是否随伤害范围属性扩大 | 当前视觉响应 |
|---|---|---|
| 水流 | 是，终态横半轴 max(96×M,32)×0.7×0.68×1.65；正向加成时为 75.3984×M，纵半轴为其 0.66 倍 | 水浪成熟轮廓与判定共用椭圆；生效时直接使用终态区域 |
| 黑洞 | 是，伤害及初次吸附选取半径 94.5×M | 球体半径 31.5×M；伤害半径始终是终态球体半径 3 倍，不画伤害圈 |
| 结霜 | 是，初始冰场半轴 (51.2,28.16)×M | 新增地面覆盖与冰场判定同步；风还能另行扩张，最大为本次初始横半轴的 2 倍 |
| 风刃 | 是，独立圆形命中半径 72×M | 月牙与圆共用 M；不再受来源武器命中半径或攻击距离影响；速度、寿命、风扩场倍率和湿润传播半径不因此增大 |
| 火焰 | 部分：地面火场横半轴 r=min(30×M,58)，纵半轴 Gr；附着燃烧仍对单个目标生效 | 必要地面覆盖与点燃区域同步；火舌保留原尺寸规则。合并与风扩张更新两者，风扩张上限为 96；飞行火种和附着燃烧不增加范围 |
| 落雷 | 是，预警、终态圈、实际判定共用半轴 (30,19.772727)×M | 单粒预警仍为 8×8，雷柱高度仍默认 182；粒子可减密度，必要地面覆盖保留 |
| 光辉剑 | 是，地面判定半轴 (78,51.409091)×M | 新增预警和终态地面覆盖同步扩大；竖直剑体、原小标记与裂痕保持原尺寸 |
| 震荡 | 否；当前仅击退，默认作用半径 55.2 | 压力波仍有随时间扩散的动画，但最大规格不随攻击距离或伤害范围属性扩大 |
| 电火花 | 否；连锁搜索半径受攻击距离影响，基准为 170×攻击距离倍率 | 雷路径连接实际目标，可能随目标间距变长；伤害范围属性不放大它。命中粒子散布另使用攻击距离倍率 |
| 巨力、智慧、多投、会心、致命、迅捷（6 种） | 无独立法术半径；分别修改伤害、元素伤害、数量、暴击率、暴击伤害、攻速 | 无独立法术主体；数量或频率变化不等于单个素材放大 |
| 领域（1 种） | 本身提供伤害范围 +30；扩大适用武器/法术 | 无独立范围特效；实际改变上面各效果使用的 M，不改变攻击距离 |
| 弹跳、分裂、穿透（3 种） | 无统一独立法术半径；复用对应武器的攻击、子攻击或命中规则 | 受所用武器本身的范围规则影响，不能统一标成“尺寸固定”；分裂另有各武器的缩小系数 |

统计：7 种独立法术的部分或全部作用范围受伤害范围加成，其中光辉剑的主体画面固定；震荡和电火花不受该属性扩大；另外 10 种为属性或攻击规则附魔。此处“不变”仅指不随伤害范围属性变化，不表示没有动画、不同体型适配或其他参数修正。

源码依据：`stat_definitions.gd`、`effect_parameter_resolver.gd`、`spell_footprint.gd`；以及各法术生成与绘制路径。`shockwave_enchantment_test.gd` 和 `attribute_enchantment_test.gd` 继续验证领域不扩大纯控制震荡；新增 `spell_terminal_range_test.gd` 验证本节已实施规则。7.5 保留修改前分析，不能代替本节现状。

元素反应另计：雷火反应使用伤害爆炸路径，会乘伤害范围倍率；它与震荡附魔的纯控制路径不同。多数场效果在生成时读取范围属性，以上分类不表示已经存在的场会实时跟随玩家后续属性变化。

### 7.5 视觉作用区域与实际判定一致性：修改范围分析

本节保留上一轮按“逐时刻完全一致”进行的源码分析，未实施玩法修改。**用户随后确认的最终实施口径见 7.6，并优先于本节建议**：扩散类按完成后的视觉区域判定；黑洞、风刃、震荡有明确例外。下表关于逐帧推进伤害、给黑洞增加范围标记、将风刃改为月牙碰撞的建议，不再作为实施要求。

| 附魔 | 当前不一致及依据 | 按新规则需要处理的内容 |
|---|---|---|
| 水流：明确需要修改 | `water_wave_effect.gd` 生成时按完整圆形区域立即伤害并打湿；当前默认半径 45.696。画面却以 1.65r 为 reach，在 Shader 内纵向乘 0.66，并随进度及噪声扩散 | 统一圆/椭圆形状、边界与命中时刻；将 1.65 倍装饰扩张从作用边界中移除。若保留渐进水浪，应明确伤害是跟波前推进还是瞬时覆盖，并同步显示 |
| 光辉剑：明确需要修改 | 判定为半径 78×M 的圆；固定 32×32 地面标记经投影绘制，固定裂痕与剑体不表达完整判定。范围加成只扩大查询范围 | 从实际判定生成完整的落点预警及落地作用边界；使用一致的形状与投影。单纯放大竖直剑图无法表示圆形落点区域 |
| 黑洞：明确需要修改 | 实际一次选取半径 r 的圆内敌人并伤害/吸附；核心仅约 0.35r，中心上移 0.22r，外围气流另有 0.85 纵向压缩、张合和不规则轨迹。后续吸附沿用最初目标列表 | 增加与真实选取区域相同的吸附边界；明确持续有效或一次选取的时序。持续作用时应检查新进入/离开边界的目标，避免画面持续但判定已经结束或目标已离开仍被吸附 |
| 火焰：地面火场明确需要修改 | 火场用圆形 Area2D 重叠施加燃烧，画面是三根立体火舌；两侧位置随 r 变化，火舌尺寸在 1.3 倍封顶，不能表示完整圆形覆盖。合并和风扩张继续增大判定 | 为火场提供与施加燃烧区域共用的地面形状，扩张与合并同步更新。飞行火种和敌人身上的燃烧是投送/状态表现，不应误标为它们周围都有范围伤害 |
| 风刃：明确需要修改 | Shader 画的是月牙形；命中则按以节点为中心的圆形距离查询。判定还使用武器基础命中半径和攻击距离，画面只使用伤害范围倍率。不同武器、攻击距离下都可能偏离 | 统一月牙轮廓与命中几何，并处理运动扫过区域；所有决定形状的参数共用。还需同步瞬时初始命中与移动风刃的反馈，避免在画面未接触时发生额外命中 |
| 落雷：明确需要修改 | 预警半径参数默认 20，实际伤害半径是其 1.5 倍、默认 30；预警粒子轨道另用 23×14 椭圆及摆动。伤害判定为圆，落地圈为投影椭圆且从半径 7 扩散；落地时已经对完整区域造成伤害 | 预警、落地圈、判定共用最终半径和形状；统一落地命中时刻与覆盖范围，修正预警/伤害的 1.5 倍分离。雷柱及粒子自身大小可以独立，但不能充当错误的伤害边界 |
| 结霜：明确需要修改，几何基础较接近 | 代码已使用 (r,0.55r) 的椭圆查询，图集缩放也跟随 r。但生成时立即启用完整范围；图集首帧仅约 4×4，第 12 帧仍未覆盖完整范围。风扩张时判定立即变大，扩张前沿动画另外插值。成熟雪晶轮廓也不是完整椭圆边界 | 从生效首帧显示准确覆盖，或让判定随真实生长范围推进；风扩张与消退时同步。保留同一椭圆只能解决包络问题，仍需明确连续作用边界，不能把雪晶枝条的空隙当作安全区 |
| 震荡：明确需要修改控制范围显示 | 当前没有伤害，按圆形半径 55.2 瞬时击退；画面是纵向 0.72 的椭圆压力环，前沿随进度从约 0.16r 扩至 1.06r，并带噪声 | 统一视觉与击退作用区域和时机；保持纯控制语义，不能为匹配画面而新增伤害 |
| 电火花：需要先明确连锁线的作用语义 | 只对选中的连锁目标结算伤害，搜索距离由攻击距离控制；可见折线及回闪本身没有路径碰撞，穿过其他敌人不会命中 | 按目标连锁语义，准确呈现选中目标及命中时刻，不把搜索半径画成伤害圈。若新规则要求可见雷线经过之处也都是伤害区域，则必须增加路径判定，属于额外玩法变更，不能作为纯美术修正悄然实施 |

其余 10 种均无独立伤害范围：巨力、智慧、多投、会心、致命、迅捷修改属性；领域改变适用效果的范围倍率；弹跳、分裂、穿透复用对应武器/后续法术。它们自身无需新增范围图，但复用的武器、子攻击应服从同一判定与绘制规则，不能据此认定这些攻击已对齐。

关联的元素反应也存在问题：雷火爆炸在降低视觉负载时将画面半径缩为 0.75r，甚至 min(18,0.22r)，而伤害半径不变；光反射判定当前累计扫过的扇区，但画面只表示当前光束，进入已扫过区域的敌人也可能受伤。若规则覆盖所有附魔联动，这两项必须纳入修改。蒸汽、导电、湿润传播等单体/目标间反馈应明确为命中或状态提示，不能把装饰云雾、连接线的覆盖当成区域伤害。

统一实现约束：每种攻击提供一个权威的作用形状和有效时间，视觉与碰撞共用；投影、范围加成、像素取整及风扩张由同一份参数驱动。敌人进入区域的标准也应统一，目前混用碰撞体重叠、中心点距离和两者并集。性能降级可以减少装饰，不能缩小或隐藏仍有效的必要范围边界。上述要求包含时序和边界修正，不能仅用 Picxel 换图完成。

本次验证为正式代码路径核对及冰场图集抽帧检查；不是修改后实机验收。水流原清单遗漏的 0.7×0.68 系数及当前 Shader 的 0.66 纵向比例已同步修正。

### 7.6 用户确认的范围统一方案（2026-10-21；已实施）

已修改正式战斗代码。“最终视觉范围”指扩散完成、尚未消散时的有效地面覆盖轮廓；透明贴图画布、竖直剑身/雷柱/火舌高度以及飘散装饰不作为地面伤害面积。逐渐扩散的效果在原有生效时刻使用终态范围，保留原有的瞬时、延迟落地或周期施加状态节奏，不要求伤害半径追随每一帧扩散。

| 对象 | 用户确认的规则 | 实施口径 |
|---|---|---|
| 水流 | 实际伤害范围与扩散完成后的视觉范围一致 | 从同一终态地面形状生成视觉与判定；保留椭圆视觉时使用对应椭圆判定，移除导致两者分离的独立换算。即时伤害/打湿可继续按终态范围结算 |
| 黑洞 | 不显示伤害范围；实际伤害范围为视觉球体的三倍，伤害范围属性同时影响二者 | “三倍”按半径/直径的线性倍率理解：伤害半径=完全展开后的球体半径×3，面积为9倍。两者共用伤害范围倍率；开场张合、消散动画不改终态基准。保持地面作用中心与立体球体偏移的区别，不把上浮偏移直接移入地面判定 |
| 光辉剑 | 按准确落点预警与落地作用范围的方案执行，扩散按终态范围 | 地面预警、落地作用区与实际伤害使用同一形状和尺寸；剑身仍是立体表现，保留落地触发伤害的节奏 |
| 火焰、火池 | 按统一地面作用区的方案执行，扩张按终态范围 | 地面火池的点燃区域与终态地面覆盖一致，属性、合并、风扩张同步；飞行火种和附着燃烧仍分别作为投送及单体状态表现，不因其火舌高度新增范围伤害 |
| 落雷 | 按统一预警、落地作用区和判定的方案执行，扩散按终态范围 | 修正目前预警参数和伤害半径的1.5倍分离；预警与终态冲击圈共用实际范围，保持落地时结算伤害，雷柱高度不当作地面伤害范围 |
| 结霜 | 实际作用区域与扩散完成后的冰场一致 | 保持完整终态范围生效；成熟冰场与判定使用同一地面轮廓。风扩张后的终态区域同步更新，雪晶生长和消退继续作为动画 |
| 风刃 | 保留圆形判定，圆形大小受伤害范围加成影响 | 保留月牙外观，使用明确的基准判定圆；判定半径和风刃视觉共用伤害范围倍率。无需为贴合月牙新增像素轮廓碰撞 |
| 震荡 | 保留瞬时完整圆形作用，与扩散结束的视觉范围大致一致即可 | 以终态压力波校准基准控制圆，允许地面投影带来的视觉近似；仍为纯击退，继续保留不受伤害范围属性放大的现行规则 |

实际数值变化：黑洞球体基准半径保留 `0.35×90=31.5`，伤害半径从90改为94.5（增加5%）。水流由半径45.696的圆改为半轴75.3984×49.762944的椭圆，横向明显增大；风刃由依赖来源武器的圆改为基准72的独立圆，按可见月牙包络校准；光辉剑、火池、落雷由圆改为纵轴压缩 G 的地面椭圆，横轴保留，纵向覆盖减少。结霜保留原有0.55椭圆；震荡保留55.2的控制圆、将终态视觉改为圆。这些属于真实判定调整，不只是换图。

`spell_footprint.gd` 统一作用区尺寸，`spell_ground_area.gd` 为光辉剑、火池、落雷和结霜绘制必要地面覆盖。物理椭圆采用项目现有96边凸多边形；像素 Shader 使用同一半轴。逻辑范围一致，栅格边缘仍有一个采样格以内的阶梯误差，不代表逐像素碰撞。风刃继续按敌人中心距判断，其他地面区域按敌人碰撞体重叠；黑洞保留原有一次选取/吸附时序。上述命中语义不额外统一。

验证与画面：新增边界集成测试在伤害范围0和+100（M=1与1.5）下放置边界内外目标，**173项通过、0失败**；覆盖原触发时机、黑洞3倍、风刃独立基准、火池合并/风扩张、结霜风扩张和落雷最低特效档。9组相关回归共**1236项通过、0失败**。另跑旧精英测试为13通过、2失败：其断言仍假定骑士旧0.56倍率、54像素脚锚，而正式场景已为0.75倍率、新脚锚；两项与本轮法术范围修改无关，未改动骑士资源或放宽断言。

实机图采用正式 GameRoot/BattleRoot 与法术组件，在1920×1080下固定展示阶段，以便比较终态： [基础范围](artifacts/reports/spell_terminal_ranges/base.png)、[伤害范围+100](artifacts/reports/spell_terminal_ranges/area_plus100.png)。这些是固定阶段的 GPU 画面，不是完整施法录像；不能据此承诺所有动画帧和高负载性能均已验收。私有桌面与实际引擎桌面核对一致，`foreground_samples=0`。日志和复现入口见 [验证记录](artifacts/reports/spell_terminal_ranges/README.md)。

另已核对 [落雷落地阶段](artifacts/reports/spell_terminal_ranges/area_plus100_strike.png)。最终无窗口编辑器导入、正式主场景30fps运行360帧均退出0且无错误/警告。额外截图场景曾在完成流程后以0xC0000374异常退出，headless及一次GPU复跑均出现过，原因未定位；其他GPU运行正常。该异常及早期headless资源解码、快速退出时的DummyTexture异常保留在验证记录中，不计为通过。

电火花连锁以及雷火爆炸、光反射等关联反应不在本次8项确认列表内，保留现行语义；上一节分析继续作为后续参考。范围与显示规则的最终验收采用本节标准，避免将允许的扩散时差和明确例外再次判为缺陷。

### 7.7 现有法术在不同窗口下的实机表现（2026-10-21）

**用户审阅结论：保持现状。** 用户已接受本节多窗口对照中的附魔特效表现。光辉剑、结霜及风扩张前沿、水流、黑洞、火焰/火池、风刃、震荡和落雷预警沿用当前正式资源与显示规则，保留7.6已实施的范围修正；不再将这些素材列为必须缩半或统一2px网格的下一批任务。此结论不扩展为尚未展示的元素反应、其他状态贴图或武器攻击动画均已通过审阅。

本次只检查现有素材和输出，不开始下一批重制。光辉剑剑体/旧标记/裂痕、结霜冰场和风扩张前沿使用PNG图集；水流、黑洞、风刃、震荡、火焰主体由Shader/程序生成。新增地面覆盖也由程序绘制；落雷为PNG粒子与程序雷柱/地面圈混合。程序噪声纹理不等于可直接用Picxel缩小的完整特效原图。

通过正式GameRoot/BattleRoot生成9种效果/阶段，固定同一世界帧后切换实际窗口，读取各窗口GPU输出。三档世界SubViewport始终为1920×1080；实际窗口、PNG输出尺寸、世界显示倍率均已核对：

| 实际窗口及截图 | 战斗画面输出倍率 | 1px内部细节 | 2px内部色块 | 3px内部色块 |
|---|---|---|---|---|
| 1280×720 | 2/3 | 部分像素被跳过，细线可能缺失 | 1或2px宽 | 2px宽 |
| 1920×1080 | 1 | 1px宽 | 2px宽 | 3px宽 |
| 2560×1440 | 4/3 | 1或2px宽 | 2或3px宽 | 4px宽 |

相对屏幕的构图和逻辑作用范围不变；720p损失细节，1440p增加显示像素但不增加美术细节。最近邻避免插值模糊，但不能保证任意窗口下所有细线连续、像素等宽。当前3px大色块恰好适配本次两档缩放，混在其中的1px/2px部分仍会不均匀。

水流、冰场、风刃三个局部在720p及1440p的实机像素，与同帧1080p最近邻映射逐像素比较，6处差异均为0。该检查验证输出缩放关系，不代表完整动画、多种范围加成或所有窗口均已验收。截图页可逐项切换9种效果，并用整数倍率放大实际截图像素： [对比页](artifacts/reports/spell_window_resolution/index.html)、[局部对比图](artifacts/reports/spell_window_resolution/pixel_details.png)。三张原始实机图及记录见 [验证说明](artifacts/reports/spell_window_resolution/README.md)。本次GPU退出0、无脚本/Shader错误，私有桌面核对一致，`foreground_samples=0`。

## 8. 怎样理解“严格像素统一”

不同 PNG 可以有不同宽高；真正需要统一的是它们在共同画布上的像素对应比例。当前项目同时存在以下情况：

1. **原生主体**：初心者战斗帧为 96→96。
2. **缩放主体**：小怪 128→76.8，骑士 256→192，短刀 32→133.6×104。
3. **图标**：101 件遗物和 15 张武器/状态图标均统一使用正式 36px 源图，只按 36→36 / 36→72 显示；两类均绕过旧尺寸变体。
4. **缩放后再像素化**：多数武器块状特效在变换之后用 AlignedAtlas 的 2/3 px 网格重新采样；它们不是源像素逐个保留。
5. **程序像素**：电浆、火焰、水流、闪电等并没有共同的源画布，使用不同网格和动态范围。
6. **额外整体输出缩放**：1440p、720p 等输出仍会改变最终屏幕像素对应关系。

因此，仅把工程设为 1920×1080、全部打开最近邻，或把 PNG 全部改成 128×128，都不能解决统一像素密度问题。若后续要收敛，应先选定角色/世界/UI/特效各自允许的像素网格，再决定哪些素材按最终尺寸重制、哪些保留多尺寸版本、哪些允许动态缩放。

## 9. 核查范围与验证记录

- 文件尺寸直接读取 PNG 头部；图集单帧、有效帧数与裁剪区域来自当前动画定义和实际绘制脚本。
- 图标逐项来自三个当前 JSON 配置，并逐项核对 `clarity/catalog.gd` 的变体登记，包含返程状态图标。
- 无窗口运行读取了正式入口的画布、摄像机、角色、怪物、经验球、实际武器栏控件和选用贴图尺寸；另读取了 14 种武器的基准范围/半径。遗物现按 36/72 新契约验证，旧 40/64/80 检查已更新。
- Shader 采样步长、动态特效公式与默认/回退路径为源码核查；战斗特效尚未在本轮进行逐帧 GPU 验收，不能据此保证每个动画时刻均无像素抖动或裁切。图标的 GPU 验证另见第 4、5 节。
- 遗物、武器和附魔图标及相应 UI 尺寸已按用户选稿确认实施；初心者展示和四类怪物主体新规格也已按11.6正式接入。场景和战斗特效依第11节保持现状或待定，不自动执行旧推荐。表中基准参数随后续配置、皮肤、UI 布局和范围属性变更而变化。本轮遗物的独立过程报告已清理，结论合并如下。

遗物最终验收（2026-10-20）：

| 项目 | 结果 |
|---|---|
| 正式 PNG 与“原始图 → 36px”选稿哈希一致 | 101/101 |
| 正式 PNG 与同名 PXG 像素一致 | 101/101 |
| 36×36、二值透明、四角透明、每图最多 14 色 | 101/101 |
| 原始来源保留、素材索引及本文逐项清单 | 全部 101 件可追溯；完整图集 5 张、原始绘图脚本 2 份 |
| 旧遗物图集清理 | 90 件旧登记及对应像素移除；270 个武器变体像素一致 |
| Godot 无窗口导入与脚本检查 | 通过，无解析/编译错误 |
| 图标接入、奖励布局、选人页回归 | 128 + 362 + 218 = 708 项，0 失败 |
| 此前对同一批正式稿的 1080p GPU 验证 | 6 个入口/布局，11 个图标全部不透明像素对应，允许每通道 1/255 输出误差 |
| 此前后台截图行为 | 私有桌面核对通过，`foreground_samples=0` |

上述 GPU 验证对应此次保留且哈希未变的 B 版；清理阶段复核文件和运行回归，不重复生成截图。旧验证图片、日志与本轮临时核验文件随中间产物一并删除。

本轮首次选人页 headless 运行在设置标签文字时出现一次 dummy 渲染器 `texture_2d_initialize: Parameter "t" is null`，当次 218 项断言仍通过；同一场景复跑后 218 项通过且无错误日志。没有修改字体或选人页逻辑。

## 10. 推荐分辨率与统一规则（遗物、武器、附魔图标已实施，其余为提案）

### 10.1 采用 1/2 创作分辨率，优先统一像素密度

**建议以 960×540 的美术像素密度，对应 1920×1080 的设计画布：固定素材默认最近邻放大 2 倍。** 这是创作和显示规范，不表示本次已把世界 SubViewport 改成 960×540，也不要求每张图片都是 960×540。

例如，画面中占 96×96 的人物应按 48×48 创作；占 80×80 的图标按 40×40 创作。直接把现有 96×96 人物设成 scale=2 会变成 192×192，不能保持当前人物大小。需要在低分辨率上重新整理轮廓、细节及动画，再以整数倍率显示。

| 方案 | 等效全屏创作画布 | 1080p 下每个美术像素 | 保持 96×96 人物所需源帧 | 适用判断 |
|---|---|---|---|---|
| 原生 1 倍 | 1920×1080 | 1×1 | 96×96 | 细节最多；现有初心者属于这一档 |
| **推荐 2 倍** | **960×540** | **2×2** | **48×48** | 保留较多角色细节，也能精确对应现有 32/40/64/80 图标尺寸 |
| 备选 3 倍 | 640×360 | 3×3 | 32×32 | 像素更粗；多数 UI 尺寸需改为 3 的倍数，小物品识别成本更高 |

“同类统一”落实为以下规则：

1. **同一类物品在同一用途/档位中，共用源画布和倍率。** 不能让部分遗物是 64 源图、部分是 128 源图，再分别任意缩放到同一尺寸。
2. **同一角色、同一怪物、同一攻击动画的各帧，共用帧尺寸、基准倍率和锚点。** 体型确实不同的普通怪与大型精英可分档；箭矢与长枪也不必塞入同样的正方形。
3. **同一物品允许有少量明确的展示规格。** 遗物共用一张 36×36 稿，以 1 倍或 2 倍显示；其他图标可按空间制作专用稿。同场合的所有物品必须一起切档，不能由源文件大小或最近变体决定。
4. **固定贴图统一 2 倍；动态攻击与投影统一最终 2 px 网格。** 动态效果可以连续扩大伤害范围，但缩放、旋转、地面投影完成后，画面中的像素块仍为 2×2。其纹理倍率可能是小数，不能把“最终网格 2 px”写成“源图始终 scale=2”。

表中的推荐源尺寸是**单帧创作画布**，不是整张图集尺寸。透明留白算入画布；填充留白不会扩大可见主体。图集按帧数排布，原帧数、时长、动作方向与接入状态继续以第 3、6、7 节为准。

### 10.2 遗物、武器、附魔 icon：统一档位与倍率

遗物已按用户最终选择统一为 **36×36**，常规展示为 **72×72、2 倍**，商店/选人页为 **36×36、1 倍**，不制作另一套小稿。武器也已确定 **36×36 源图，36/72 两档展示**；新美术与各入口均已接入。附魔也已正式接入统一 **32×32** 源图，以下显示策略均已实施。

| 档位 | 推荐源图 | 推荐显示 | 显示倍率 | 用途 |
|---|---|---|---|---|
| 常规 | 32×32 | 32×32 | 1 | 附魔背包/掉落/工作台 |
| 选人 | 32×32 | 32×32 | 1 | 选人页初始附魔，容器已调整 |
| 放大 | 32×32 | 64×64 | 2 | Esc 附魔，复用同一张源图 |

附魔正式资源已全部为 32px；武器和遗物复用各自同一张 36px 源图。具体清单对应如下：

| 清单类别 / 场合 | 当前显示 | 推荐源图 → 显示 | 接入建议 |
|---|---|---|---|
| 全部 101 件遗物：商店/选人页 | 36 | 36×36 → 36×36，1 倍 | 已实施；不裁可见包围盒 |
| 全部遗物：百科/小型奖励 | 72 | 36×36 → 72×72，2 倍 | 已实施；共用一张源图 |
| 全部遗物：常规奖励/Esc | 72 | 36×36 → 72×72，2 倍 | 已实施；取消非整数尺寸动画 |
| 14 张武器主图 + 1 张返程图：战斗栏 | 72；超宽切 36 | 36×36 → 72/36，2/1 倍 | 已实施；直接使用新正式源图 |
| 武器：Esc / 商店 | 72 | 36×36 → 72×72，2 倍 | 已实施 |
| 武器奖励 / 百科 | 72 | 36×36 → 72×72，2 倍 | 已实施；取消任意框尺寸连续适配 |
| 工作台当前武器 / 鼠标 / 伤害统计 | 36 | 36×36 → 36×36，1 倍 | 已实施；调整图框与留白 |
| 工作台武器切换按钮 | 36 | 36×36 → 36×36，1 倍 | 已实施；保持完整画布 |
| 全部 19 张附魔：背包/工作台/掉落 | 32 | 32×32 → 32×32，1 倍 | 已实施；三处复用同一稿 |
| 全部附魔：Esc | 最大 64 | 32×32 → 64×64，2 倍 | 已实施；复用同一张 32px 稿 |
| 选人页：初始武器 | 36 | 36×36 → 36×36，1 倍 | 已实施；保留完整源画布 |
| 选人页：初始附魔 | 32 | 32×32 → 32×32，1 倍 | 已实施；取消包围盒裁切 |

武器数增加时，整个战斗栏只从 72 切到 36；后者仍放不下时换行，绝不缩到第三种尺寸。切档按包含卡框、间距的实际宽度决定，现行实现见 5.1。

武器可见主体建议占 36px 画布最长边约 **32px**；当前电浆炮样稿为 32×30。细长武器按最长边控制，不能非等比拉成方块。主体锚点、透明留白、轮廓线宽应共用规范，稀有度由边框和颜色表达。过细的装饰应在制作阶段简化。本批次已按此主体规范完成替换，实际主体范围逐项见 5.1。

上述图标已同时完成资源替换和 UI 档位调整，正式入口直接使用对应的 36px 或 32px 源图。各场合可以有不同显示尺寸，但**同场合、同类图标的源分辨率与倍率必须相同**；窗口整体缩放仍按第 2 节处理。

### 10.3 角色、怪物与拾取物

本节的角色行已按用户新方案更新为正式规格，制作记录见11.6；拾取物及其他未讨论项仍仅为提案。

| 类别 | 推荐源单帧 | 推荐基准倍率 | 推荐绘制画布 | 相对现状的处理 |
|---|---|---|---|---|
| 初心者战斗动作，已实施 | 96×96 | 1 | 96×96 | 保留现有47个独立帧及动作锚点 |
| 小型怪：幼体、蝙蝠，已实施 | 96×96 | 1 | 96×96 | 原图像素化，统一源图比例与留白，保留现有碰撞参数 |
| 大型精英：骑士、冥狼，已实施 | 192×192 | 1 | 192×192 | 原图像素化；冥狼逐帧补偿已合并进构图 |
| 资本家等后续玩家 | 48×48 | 2 | 96×96 | 和初心者共用玩家档；当前 80 画布可先以透明留白补齐，主体大小另按角色设定 |
| 初心者选人展示，已实施 | 96×96 | 3 | 288×288 | 复用正式idle/move；可见身体高228，不做呼吸拉伸 |
| 经验球 | 4×4 | 2 | 8×8 | 保持当前占用；16 源图不再在运行时缩到 8 |
| 附魔掉落 | 32×32 | 1 | 32×32 | 已实施；复用统一正式图标 |
| 遗物拾取方块与光晕 | 程序生成；光晕逻辑画布 22×22 | 逻辑像素按 2 倍输出 | 光晕 44×44 | 方块也对齐 2 px 网格，无需新增遗物 PNG |

**已确认的初心者 96×96、47 帧是现行正式稿。** 用户已选择战斗1倍、选人3倍，先前48px／2倍提案不再作为初心者的待办。锁定资本家及拾取物仍按各自状态处理。

冥狼当前 157.286/196.608 的不同帧框来自注册补偿。重整时要比较可见身体与落脚点，不能直接给所有旧帧改成相同 scale。若跳跃动作完整轮廓放不进 96 源帧，应把该体型档的共用源画布一起提高，例如统一为 112×112、仍显示 2 倍；整套动作同步处理，不能只对个别帧缩小。

选人页使用独立展示稿可以维持 2 px 密度。若复用 48×48 战斗稿并放大到 288×288，则需要 6 倍、像素块也变成 6×6，应列为明确的展示例外；不能写成与战斗相同的像素密度。呼吸感宜通过动画帧或位移实现，连续纵向拉伸会破坏严格方形像素。

### 10.4 背景、植被、道具与阴影

| 类别 | 推荐源尺寸 / 单元 | 推荐倍率与显示 | 统一方式 |
|---|---|---|---|
| 选人页全屏背景 | 960×540 | 2 → 1920×1080 | 按目标构图重制/裁切，取代 2752×1536 的小数适配 |
| 地面可循环单元 | 128×128，按最终投影外观创作 | 2 → 256×256 | 用可拼接单元覆盖任意地图；现有 2176×1600 不是新规格的固定要求 |
| 主层草，全部四种 | 16×16 | 2 → 32×32 | 同画布、同脚底锚点，取消 0.95～1.25 连续随机缩放 |
| 底层/伴生草 | 小档 8×8；中档 12×12 | 2 → 16×16 / 24×24 | 按用途选档；同档共用规格，丰富度来自不同轮廓和摆放 |
| 石头、倒木等中型地标 | 80×72 共用帧框 | 2 → 160×144 | 当前 75×65 石头、69×31 倒木已是 2 倍，可补透明留白到共用框，保留可见形状 |
| 小碎石 | 20×12 | 2 → 40×24 | 对应当前约 36.25×21.75、23.2×15.95 的绘制框；以主体占用区分碎石形状 |
| 七种砖石地表装饰 | 32×32 | 2 → 64×64 | 同档不再 0.85～1.16 随机变形，需要大小变化时制作另一档 |
| 远景全景长条 | 1549×104 | 2 → 3098×208 | 宽度保留，当前 206 高调整为 208 高；保持循环边缘衔接 |
| 远景遗迹四种 | 共用 64×56 帧框 | 2 → 128×112 | 拱门/柱/尖碑/灯可见主体约 124×108、52×92、44×74、50×78，其余为留白 |
| 四张前景角图 | 共用 192×192 帧框 | 2 → 384×384 | 按原布局分别安排约 216、232、332、372 的主体占用，避免把四张全部撑满 |
| 接触阴影、投射阴影 | 程序轮廓或共用遮罩；无唯一美术帧 | 跟随对象尺寸，最后对齐 2 px | 不把阴影拉伸倍率当成实体贴图倍率 |
| 地面环境数据图 | 保持数据需求，例如现有 272×200 | 不显示，无显示倍率 | 数据精度独立于美术规范，不需要改成“半屏分辨率” |

地面当前的纵向投影 G≈0.659 会把方形源像素压扁。严格方案是先确定投影后的地面外观再按 2 px 网格创作，或在投影完成后统一像素化；不要对已按最终外观绘制的地面再重复压缩。远景空间不足时应改变摆放、选较小档或减少物件，避免继续通过任意小数倍率塞入洞口。

### 10.5 武器攻击：固定动画用 2 倍，动态范围用共同网格

固定动画按下面的源帧制作，基准显示 2 倍。新增留白的帧必须同步更新锚点和有效区域，不能按整帧包围盒重新推导攻击距离。普通瞬时命中统一 **48×48 源帧 → 96×96 画布**，金币火花、手炮命中、闪电命中可在其中保留各自较小的主体。

范围类素材建议采用两个共用形状画布：**圆形/环形/弧形 128×128，长条/枪芒 128×64**。它们是可变范围的形状母版，不保证源像素逐个保留；在实际绘制宽高 `Dₓ、Dᵧ` 下，纹理倍率分别为 `(Dₓ/128,Dᵧ/128)` 或 `(Dₓ/128,Dᵧ/64)`，最终输出仍统一为 **2 px 网格**。`D` 应含实际方向与地面投影，不得把投影后的图再次乘 G。

| 武器 | 推荐源帧 / 形状母版 | 推荐基准显示与倍率 | 动态处理 |
|---|---|---|---|
| 木质弓箭 | 小弹体共用 16×16；箭主体放在约 12×12 区域 | 2 → 32×32 画布，箭主体约 24×24 | 旋转/V 变化后统一 2 px 网格，透明框不改变命中尺寸 |
| 电浆炮 | 程序核心参考逻辑画布 20×20 | 默认 2 → 40×40 | 核心半径改变时重建/重采样；电弧与主体都用 2 px，去除同层 1 px 细线混用 |
| 铸铁榴弹炮 | 弹体程序逻辑框 8×8；爆炸母版 128×128 | 弹体 2 → 16×16 框，主体约 12×14；爆炸按 D/128 | 默认爆炸仍约 214×141.045，经最终网格覆盖约 214×142；不改变 B=107 的逻辑半径 |
| 坤舆秘仪书 | 法阵参考稿 320×200；命中 48×64 | 法阵基准 2 → 640×400；命中 2 → 96×128 | 法阵以当前默认范围为参考，范围变化后重新映射到 2 px 网格 |
| 食利者钱袋 | 金币共用弹体帧 16×16，主体 8×8；命中 48×48，主体范围约 40×40 | 2 → 32×32 弹体框/16×16 金币；命中框 96×96/主体约 80×80 | 分裂金币保持约 12×12 可见尺寸，可用 6×6 主体稿；所有旋转最终对齐 2 px |
| 赤铜炉灯 | 程序火焰；按现有reach=360对应参考逻辑承载框360×360 | 默认2 → 720×720承载框 | reach与投影控制形状，正式扇角60°，最终网格2px；本行仅修正旧提案的基准数值 |
| 异化触手 | 主体 112×112；攻击覆盖 144×112 | 2 → 224×224 / 288×224 帧框；主体占用约 212×212 / 266×212 | 默认形状先整理进统一帧；R/H 与分支变化后再像素化，不能整帧拉伸后直接输出 |
| 裂地战锤 | 锤体 72×72；挥击母版 128×128；地裂参考帧 64×64 | 锤体 2 → 144×144，主体约 140；地裂 2 → 128×128，内容约 108×124；挥击按 D/128 | 保留当前挥击约 281.6 的范围关系；裂缝按长度分段/裁剪，最后统一 2 px |
| 营地短刀 | 刀体 72×56；刀光母版 128×128 | 刀体 2 → 144×112，内容约 134×104；刀光按实际 D/128 | 刀体默认宽高比例烘焙进稿；范围、挥角与投影之后统一 2 px |
| 守夜长枪 | 枪体 128×32；分裂枪片 32×8；枪芒母版 128×64 | 2 → 256×64 / 64×16，内容约 240×46 / 54×12；枪芒按 D 映射 | 枪芒仍随刺出进度/范围改变长度；不为了像素整数缩小伤害范围 |
| 流星摆锤 | 锤头 32×32，主体 27×27；链节 5×4；握柄 3×8；轨迹母版 128×128 | 2 → 64×64 帧框/54×54 锤头；链节 10×8；握柄 6×16 | 轨迹按真实摆动与投影映射；子摆尺寸重新栅格化到 2 px |
| 突进短刃 | 拖尾 64×32；斩圈母版 128×128 | 拖尾 2 → 128×64；斩圈按 D/128 | 默认斩圈约 293.333×193.333，最后按 2 px 覆盖；保留真实落点与范围 |
| 巨型手持火炮 | 弹丸 24×8；命中 48×48，内容约 32×32；后坐尘 64×32；喷流程序生成 | 2 → 48×16 / 96×96 命中框（主体约 64×64）/128×64 | 喷流由 3 px 收敛为 2 px；分裂弹和范围变化后保持相同最终网格 |
| 移星秘典 | 离开/到达/返回均 48×64；锚点 64×64；冲击波母版 128×128 | 2 → 96×128 / 128×128；冲击波按 D/128 | 默认冲击波约 267.5×176.307，范围变化后固定最终 2 px |

这张表覆盖第 6 节的 14 种武器。保留/旧路径 PNG 不作为重制优先项；若未来重新启用，也应按其“弹体、普通命中、竖向命中、范围形状”等用途归入相同规格。更换形状母版尺寸时需要同步调整采样区域及基准参数，不能只替换 PNG。

### 10.6 附魔、元素反应与状态

程序效果无需为了统一而伪造一张固定尺寸 PNG。下面的“逻辑承载框”只是按目标外框除以 2 得到的参考采样尺寸；**当前噪声纹理 128×128 可继续保留**，它控制形态复杂度，不代表画面像素密度。动态承载框尺寸向上覆盖到偶数，逻辑伤害范围仍使用原值。

| 效果 | 推荐源帧 / 逻辑参考尺寸 | 推荐显示与倍率 / 网格 |
|---|---|---|
| 巨力、智慧、多投、领域、会心、致命、迅捷 | 无独立特效帧；icon 按 10.2 | 修改属性后，实际武器效果继续遵循 10.5 |
| 弹跳、分裂、穿透 | 复用所属武器稿；不新增通用 PNG | 分裂可保留各武器当前比例，但最终都按 2 px 网格重新采样 |
| 水流 | 程序；按当前承载框推荐逻辑框 95×99 | 2 → 190×198，覆盖当前188.496×196.036；范围变化时重算承载框，最终网格 2 px 尚待实施 |
| 黑洞 | 程序；默认逻辑承载框 90×90 | 2 → 180×180；核心与气流统一 2 px，原 1 px 气流需要重新调整稀疏度与亮度 |
| 光辉剑等待/下落/消散 | 整套统一 40×136；消散内容放在其中约 40×72 区域 | 2 → 80×272 帧框；消散主体仍约 80×144；共用落点锚点 |
| 光辉剑地面标记 / 裂痕 | 16×16 / 36×8 | 基础 2 → 32×32 / 72×16；标记投影后约 32×22，最终 2 px |
| 飞行火种 | 程序逻辑火舌 7×11 | 2 → 14×22；继续统一 2 px |
| 地面火场三种火舌 | 共用逻辑帧框 32×32；内容分别约 16×24、17×26、29×30 | 2 → 64×64 框，火舌约 32×48、34×52、58×60；尺寸变化后仍 2 px |
| 附着燃烧 | 程序；逻辑宽 7～12、高 14 | 2 → 宽 14～24、高 28；跟随体型，保持 2 px |
| 震荡 | 程序；默认逻辑承载框约 67×56 | 2 → 134×112 覆盖当前 132.48×110.4；控制半径55.2，最终 2 px 尚待实施 |
| 电火花 / 落雷雷柱 | 动态路径，无固定帧宽；默认落雷参考高度 91 逻辑像素 | 高约 182；路径栅格、主线和分叉统一 2 px，延长路径不拉伸像素 |
| 闪电命中 core/glow 四图集 | 共用普通命中 48×48 源帧；当前约 48×48 显示内容放在 24×24 区域 | 2 → 96×96 帧框/约 48×48 内容；四张帧布局及锚点一致，glow 也在最终网格内变化 |
| 地面电弧（已移除） | 不再推荐制作源图 | 用户已要求删除此效果，旧80×56提案作废 |
| 落雷预警粒子 | 4×4；各方向统一 | 2 → 8×8；范围只移动粒子中心；若低分辨率下多个方向相同，可合并图案而保留方向逻辑 |
| 结霜冰场 | 64×40；全部 37 帧及细节档统一 | 默认 2 → 128×80；扩大后最终网格仍 2 px |
| 风扩张冰场前沿 | 80×48；全部 44 帧统一 | 基准 2 → 160×96；扩张后最终 2 px |
| 风刃 | 程序；默认逻辑承载框 124×124 | 2 → 248×248；随范围重算，最终 2 px |
| 蒸汽 | 程序；默认逻辑承载框 65×63 | 2 → 130×126，覆盖当前 130×125；最终 2 px |
| 导电提示 | 程序；逻辑承载框 32×22 | 2 → 64×44；最终 2 px |
| 湿润传播 | 动态包围盒，无固定源帧 | 跟随真实起终点，承载框向外对齐 2 px；传播范围不变 |
| 解冻 | 程序；逻辑承载框 65×45 | 2 → 130×90；由 1 px 收敛为 2 px |
| 光反射 | 程序；默认逻辑承载框 255×255 | 2 → 510×510；扇角/半径仍动态，最终 2 px |
| 雷火反应爆发 | 程序；逻辑参考框约 1.4r×1.35r，向上取整 | 输出覆盖 2.8r×2.7r；性能档可减密度/数量，像素网格保持 2 px |
| 冰壳 | 共用 40×40 源帧，当前形状内容约 36×36 | 2 → 80×80 帧框/约 72×72 内容；各身体形态选帧，统一 2 px |
| 减速雪花 | 32×20 | 默认 2 → 64×40；随体型变化后最终 2 px |
| 通用方形 / 圆形粒子 | 方形用程序单元或 1×1 遮罩；圆形共用 16×16 形状遮罩 | 以 2、4、6…设计像素为粒子尺寸；遮罩按目标尺寸映射，最终 2 px |

第 7.3 节中的旧黑洞、蒸汽/反射回退图等不需要因为这份清单立刻重做。若启用回退或低性能档，优先减少粒子、帧数及装饰层，不要在同一种法术中突然切换 1/2/3 px 密度。原有半透明光晕可以保留，但其轮廓与采样网格也应遵循所属效果的规则。

### 10.7 窗口分辨率、旋转与最终验收

统一源尺寸只是第一步。若希望运行画面严格统一，推荐固定贴图与动态效果共享同一个世界像素网格：可采用 **960×540 世界渲染后最近邻 2 倍合成**，UI 仍使用 1920×1080 布局；也可以在 1080p 世界中逐类实现等价网格。采用低分辨率世界时，需要配套调整坐标/相机映射以保持当前视野，不能只改 SubViewport 宽高。前者更容易让旋转、投影和效果边缘共同落在同一网格上，但需要检查现有 Shader 的 `FRAGCOORD` 语义，避免原有 2 px 再乘 2 变成 4 px。两种方式都属于后续渲染改造，本次没有实施。

| 满屏输出 | 960×540 世界方案的最终倍率 | 640×360 世界方案的最终倍率 |
|---|---|---|
| 1280×720 | 4/3，非整数 | 2，整数 |
| 1920×1080 | 2，整数 | 3，整数 |
| 2560×1440 | 8/3，非整数 | 4，整数 |

因此，本提案的“严格 2 px”首先指 **1920×1080 设计画布**。若要在其他窗口也保持物理像素等宽，2 倍方案需要整数放大并留边，例如 1440p 窗口内使用 1920×1080 内容区；若优先要求 720p/1080p/1440p 都满屏且世界像素整数对应，应整体选用 640×360、1080p 下 3 倍的方案，并重新按三分之一尺寸制定素材。不能同时承诺任意窗口满屏与严格整数像素。UI 文字、线框的清晰度策略应单独处理，不能据此声称整个 UI 也已统一像素。

后续实施建议顺序：

1. **先统一图标。** 101 件遗物及 15 张武器图标已完成正式接入；19 张附魔也已接入 32px 正式源图，全部图标入口使用 32/64 两档并完成实机验证。
2. **再整理世界实体和场景。** 小怪、道具、植被先去掉无目的的小数缩放；角色低分辨率重绘需核对原已确认动作的识别度。相机移动、镜像和脚底锚点也必须落在同一网格。
3. **最后统一动态特效。** 保留攻击半径、碰撞与时间参数，检查范围加成、分裂、旋转和地面投影后的 2 px 输出。瞬时命中、气流细线和冰场是目前密度差异较明显的部分。

本节早期推荐不代表当前待办。图标已正式接入并完成UI实机检查；附魔范围修正与多窗口审阅见7.6、7.7；角色与怪物主体已制作、接入并经用户确认，见11.6。其余项目分别按第11节“保持现状”“待定”或“当前查看”的决定处理，未验收部分不能沿用其他批次的GPU结论。

## 11. 下一批像素优化素材：当前状态（2026-10-21）

最新决策：第11.6节角色与怪物主体已按96／192px、战斗1倍及初心者选人3倍正式接入，用户已确认接受。第11.7节蝙蝠声波／蓄力／命中已按用户确认的32／20／32px原生1倍重制并接入；本批程序效果和原1倍路径预警确认保持现状。第11.5节落雷地面电弧已完全移除，其余7类效果确认保持现状；此前第7.7节已审附魔特效与第11.1节9张固定武器攻击动画也保持现状。第11.2节武器本体与PNG弹体、第11.3节9张武器动态范围攻击PNG、第11.4节状态与元素反应继续“待定，暂不修改”。下表保留尺寸问题索引；已移除或确认保留项目的旧优化建议不再作为待办，第10.5、10.6节相应推荐也不自动实施。

本次复核：19 张正式附魔 PNG 均为 32×32，哈希与确认稿一致；正式 `FinancePopup` 使用已调整的 `EnchantmentWorkbench`。最新布局实机检查 468 项、小窗口检查 358 项均通过；9 张图标截图中 94 次绘制的像素对应检查差异为 0。另复核第 6、7 节文件索引中的 73 张 PNG，实际文件尺寸与表格一致。以下是当前主素材与处理顺序建议，未开始下一批转换；完整文件及动态公式仍见第 6、7 节。

| 后续批次 | 当前素材 | 当前单帧 / 绘制规则 | 当前决定 / 后续审阅点 |
|---|---|---|---|
| 已确认保留：固定武器攻击动画 | 秘仪书命中、金币命中、手炮命中、突进拖尾、后坐尘、移星离开/到达/返回/锚点 | 依次为 96×128、80×80、64×64、128×64、128×64、96×128（3 套）、128×128；基准均为 1 倍 | 不受伤害范围加成放大，保留当前PNG与普通最近邻/2px/3px绘制规则，见11.1 |
| 已确认保留：光辉剑等已审附魔特效 | 光辉剑等待/下落/消散、地面标记/裂痕；其他已审附魔见7.7 | 剑体80×272 / 80×144，1倍；原标记32×32经地面投影，裂痕72×16；新增作用区随范围变化 | 沿用7.7审阅决定及7.6范围修正 |
| 待定，暂不修改：状态与元素反应 | 冻结碎片、冰壳、减速雪花、头顶状态提示、圣焰/暗焰、蒸汽、导电、湿润传播、解冻、光反射、雷火爆发 | 冻结112×112、冰壳72×72为1倍；雪花64×40随体型放大；其余主要为程序绘制，详见11.4 | 按用户最新决定待定，保留资源与显示规则 |
| 待定，暂不修改：武器本体与弹体 | 弓箭、金币、手炮弹丸、短刀、战锤、触手、长枪、摆锤 | 弓箭 24×24、金币 16×16、弹丸 48×16，基准 1 倍；分裂倍率各异。短刀 32×32 非等比放大；战锤 64×64 以 2.2 倍放大；触手 128×128 按范围/宽度分别缩放；长枪使用区 238×28；摆锤头 40×40，默认 1.35 倍 | 用户认为当前没有明显问题，先待定；保留资源及绘制参数，详见11.2 |
| 待定，暂不修改：武器动态范围攻击PNG | 榴弹爆炸、触手覆盖、锤击/地裂、短刀刀光、枪芒、摆锤轨迹、突进斩圈、移星冲击波 | 分别为 128×128、160×128、128×128 / 96×96、64×64、192×64、320×320、160×160、160×160，共9张 | 按用户最新决定待定，保留资源及显示规则，详见11.3 |
| 已确认保留：闪电粒子与连锁路径 | 命中core/glow、连锁闪电 | 命中每帧48×48，默认1倍；连锁路径程序绘制 | 保持现状；地面电弧另按用户要求移除，详见11.5 |
| 已确认保留：武器程序特效与法阵 | 电浆球、炉灯火焰、手炮喷流、榴弹弹体、秘仪书法阵 | 电浆核心24→40；炉灯承载框720×720；手炮承载框625×625；榴弹程序形状12×13；法阵384×240→约640.58×400.55 | 保留当前资源、程序生成及动态缩放规则，详见11.5 |
| 已实施并确认：角色与怪物主体 | 初心者、幼体、蝙蝠、骑士、冥狼；锁定角色另注 | 初心者战斗96px／1倍、选人3倍；幼体／蝙蝠96px／1倍；骑士／冥狼192px／1倍 | 四类怪物60张原图经Picxel转换，替换13张主体图集，用户接受当前结果，详见11.6 |
| 已实施并确认：蝙蝠3项特效；其余保持现状 | 蝙蝠声波／蓄力／命中／路径预警，骑士冲锋预警，冥狼喷焰／扑跃／出场 | 蝙蝠前三项32／20／32px原生1倍，移除额外2px重采样；路径仍默认1倍，保留原2px采样；其他为程序或Shader绘制 | 用户接受实机结果，3张正式PNG与审阅稿哈希一致，其余保持现状，详见11.7 |
| 当前查看：地面摆件、植被与拾取物 | 4种草、2种大摆件、2种碎石、7种地面贴花、经验球、治疗包 | 草32×32随机缩放；碎石0.3625倍；贴花64×64、0.85～1.16倍；经验球16×16→8×8；治疗包16×16、1倍 | 本批17张PNG仅核查现状；大石块与木头已有2倍，附魔掉落复用已完成32px图标，详见11.8 |
| 后续查看：环境大图、远景与阴影 | 地面、远景全景、洞口遗迹、前景角图、接触／投射阴影、光照输入 | 包含地面投影、洞口适配、遮罩和窗口适配；尺寸及公式见3.2 | 留待下一批；不能将噪声／遮罩当作直接显示的完整美术源图 |

固定武器攻击动画、光辉剑和其余已审附魔特效均保持现状。当前部分图集来自程序离线烘焙，来源与图标的高清原图不同；旧黑洞、旧炮口、旧蒸汽等保留/回退图集不列为当前主路径的优先转换对象。

### 11.1 已确认保持现状：固定武器攻击动画（9张正式PNG图集）

重新核对正式绘制入口和PNG文件尺寸，以下为单帧完整画布，含透明留白；1920×1080设计画布下基准显示均为1倍，部分另按方向旋转。这9张固定动画的尺寸不乘伤害范围加成，用户据此确认保持现状；不转换、不替换、不调整当前显示参数。

| 武器 / 效果 | 当前源帧 → 基准显示 | 有效帧数 | 当前绘制 |
|---|---|---|---|
| 坤舆秘仪书：命中 | 96×128 → 96×128 | 10 | PNG，最终3px网格 |
| 食利者钱袋：金币命中 | 80×80 → 80×80 | 25 | PNG，普通最近邻 |
| 巨型手持火炮：命中 | 64×64 → 64×64 | 6 | PNG，最终2px网格 |
| 突进短刃：拖尾 | 128×64 → 128×64 | 8 | PNG，旋转后2px网格 |
| 巨型手持火炮：后坐尘 | 128×64 → 128×64 | 8 | PNG，旋转后2px网格 |
| 移星秘典：离开 / 到达 / 返回 | 各96×128 → 96×128 | 各8，3张图集 | PNG，最终2px网格 |
| 移星秘典：锚点 | 128×128 → 128×128 | 12 | PNG，最终2px网格 |

核查依据：`ritual_coin_hit.gd`的命中绘制固定为96×128或80×80；`mobility_weapon_runtime.gd`和`cannon_pellet.gd`生成本节其他动画时均采用默认`Vector2.ONE`尺寸（移星锚点显式传入`Vector2.ONE`）。拖尾和后坐尘可旋转，命中位置/数量可随攻击结果变化，窗口仍有整体输出缩放；这些不改变本节所指的固定画布尺寸。确认基于代码规格，不冒充已完成本批多窗口动画实机审阅。动态范围攻击（榴弹爆炸、刀光、枪芒、突进斩圈、移星冲击波等）不属于本次保持现状的9张动画，仍另列后续。

### 11.2 待定，暂不修改：武器本体与PNG弹体

用户最新决定：这批当前没有明显问题，先待定，继续查看下一批。本节记录现状，暂不重制资源或调整缩放；“待定”不等同于最终确认保持现状。

以下沿用1920×1080设计画布、无额外范围加成、一级基础数据，尺寸包含源帧透明留白，且为旋转前画布。依据正式`ActiveCombatController`启用的`use_active_range_rules=true`路径，不能使用旧测试关闭该开关时的范围公式替代当前行为。

| 对象 | 源帧 / 使用区 | 当前基础显示 | 基础倍率 | 伤害范围加成对主体尺寸的影响 |
|---|---|---|---|---|
| 营地短刀刀身 | 32×32 | 133.6×104 | 横4.175、纵3.25 | 不改变刀身；攻击距离改变刀身长度。刀光与攻击覆盖另有范围规则 |
| 守夜长枪枪身 | 文件248×28，使用238×28 | 约240.22×46 | 横约1.0093、纵约1.6429 | 不改变枪身；攻击距离改变枪身长度。分裂枪片另绘制为54×12 |
| 流星摆锤锤头 | 40×40 | 主锤54×54；子锤43.2×43.2 | 主1.35、子1.08 | 不改变锤头；范围加成会改变摆动覆盖/链条伸展，不能把整个武器作用范围也标为固定 |
| 裂地战锤锤体 | 64×64 | 140.8×140.8 | 2.2 | 随伤害范围倍率M同比扩大；该武器当前带投射物标签 |
| 异化触手主体 | 128×128 | 约213.03×211.2 | 横约1.6643、纵1.65 | 伤害范围改变纵向厚度；攻击距离改变横向长度；分支再乘0.65 |
| 木质弓箭弹体 | 24×24 | 24×24 | 1 | 随M同比扩大 |
| 金币弹体 | 16×16 | 主弹16×16；分裂12×12 | 主1、分裂0.75 | 两者均随M同比扩大 |
| 手炮弹丸 | 48×16 | 主弹48×16；分裂31.2×10.4 | 主1、分裂0.65 | 两者均随M同比扩大 |

`M=1+damage_area_size×0.5/100`。例如仅伤害范围+100时，战锤为211.2×211.2、触手约213.03×316.8、弓箭36×36、金币主弹24×24、手炮主弹72×24；短刀刀身、长枪枪身、摆锤锤头维持表中尺寸。这些为源码公式推算，尚未作为本批实机验收结果。

后续若重新审阅本批，可重点对照短刀刀身、长枪枪身、摆锤锤头的非整数/非等比基础显示，以及战锤、触手、弹体在范围加成和分裂下的表现。当前先按用户决定待定。电浆核心和榴弹弹体属于程序生成，另按第6.1节处理，不混入本节PNG清单。本轮只更新现状，未改变正式资源、绘制或玩法代码。

### 11.3 待定，暂不修改：武器动态范围攻击（9张正式PNG）

用户最新决定：本批9张动态攻击特效也先待定，暂不修改，继续查看下一批。以下规格作为现状记录保留，不据此自动重制或调整显示倍率。

以下为正式主动战斗路径、一级基础数据、无额外属性加成时的规格。源帧与显示框均包含透明留白，不能直接当作可见轮廓或伤害判定范围。显示尺寸以1920×1080设计画布为基准；旋转前的数值用于比较缩放，不代表动画每帧的屏幕包围盒。标注地面投影的效果另按投影公式处理。

| 效果 | 正式单帧 / 帧数 | 基础显示框 | 源帧 → 显示倍率 / 动态规则 | 影响显示尺寸的属性 | 最终采样网格 |
|---|---|---|---|---|---|
| 榴弹爆炸 | 128×128 / 12帧 | 约214×141.05，已地面投影 | 横`2B/128`、纵`2B×G/128`；默认约1.672、1.102倍；分裂随自身爆炸半径缩小 | 伤害范围；攻击距离只改变投掷距离 | 3px |
| 触手攻击覆盖 | 160×128 / 8帧 | 约266.29×211.2 | 横`R/140`、纵`H/20`；默认约1.664、1.65倍；分支再乘0.65 | 攻击距离改变长度；伤害范围改变厚度 | 3px |
| 战锤挥击 | 128×128 / 8帧 | 281.6×281.6 | `2.2×V`；随挥击方向旋转 | 伤害范围，当前战锤带投射物标签 | 3px |
| 战锤地裂 | 96×96 / 6帧 | 主段未裁切107×124.8；子段按长度变化 | 主段横`spacing/96`、纵1.30；子段横`length/96`、纵0.90；两者再乘`V` | 攻击距离改变节点间距/延伸；伤害范围放大贴图；另有起点及障碍裁切 | 3px |
| 短刀刀光 | 64×64 / 单张 | 未投影完整框约368.55×368.55；实际仅显示随挥刀揭开的部分 | `R/29`，默认约5.759倍，再地面投影；逐帧裁切显露 | 攻击距离、伤害范围都会改变正式路径的`R` | 3px |
| 长枪枪芒 | 192×64 / 7帧 | 宽随动作变化、最大411.04；高约269.87 | 横`tip(t)×1.12/192`、纵`140.8×max(0.75,H/12)/64`；最大横约2.141、纵约4.217倍 | 攻击距离和出枪进度改变长度；正式路径中伤害范围不改变枪芒尺寸 | 3px |
| 摆锤轨迹 | 320×320 / 18帧 | 随当前锤头距离变化，无固定显示框 | `未投影锤头距离/144`，再随摆动旋转、镜像和地面投影 | 攻击距离、伤害范围改变摆动覆盖；动作进度也改变绘制变换 | 3px |
| 突进落点斩圈 | 160×160 / 10帧 | 约293.33×193.33，已地面投影 | 横`H/96×1.1`、纵再乘`G`；默认约1.833、1.208倍 | 伤害范围；攻击距离改变位移距离 | 2px |
| 移星冲击波 | 160×160 / 10帧 | 约267.5×176.31，已地面投影 | 横`H/64`、纵再乘`G`；默认约1.672、1.102倍 | 伤害范围；攻击距离改变传送距离 | 2px |

公式说明：`R=get_attack_range()`，`H=get_hit_radius()`，`B=get_grenade_blast_radius()`，`V=get_projectile_visual_scale()`，`G=145/220≈0.659091`。无额外加成时，榴弹`B=107`、触手`R=233/H=33`、短刀`R=167`、长枪`R=367/H=23`、突进`H=160`、移星`H=107`、战锤`V=1`。正式路径中，短刀和摆锤同时带“扇形”“范围”标签，`R`同时计入攻击距离与伤害范围加成；长枪只带“近战”标签，伤害范围不改变其`R/H`。常规非负属性下伤害范围倍率为`M=1+damage_area_size×0.5/100`，例如+100对应1.5倍；不能把属性+100直接当成显示2倍。

本批均有正式PNG，但不是固定1倍展示。前7项通过`AlignedAtlas`以3px网格采样，突进/移星以2px网格采样；该处理在战斗画布上对缩放、旋转、投影后的采样位置取整，使最终像素格规整，并不保证每个源像素都会保留。其他窗口的整体输出倍率仍另计。

后续若重新审阅本批，可观察基础范围与范围加成下的轮廓连续性、动画稳定性，以及可见作用区和实际判定的对应关系；不要仅因为存在小数倍率就要求重制或改成固定整数档。当前按用户决定待定。本批已核对代码、基础配置与PNG规格，尚未进行新的实机动画验收，也未确认这9项的视觉边界全部等于伤害边界。附魔特效与9张固定武器动画仍按之前决定保持现状。

代码依据：`scripts/weapons/grenade_projectile.gd`、`mutant_tentacle.gd`、`earth_hammer.gd`、`camp_dagger.gd`、`nightwatch_spear.gd`、`meteor_flail.gd`、`mobility_weapon_runtime.gd`及`weapon_instance.gd`；图集登记与采样见`scripts/effects/weapon_block_vfx.gd`、`mobility_atlas_effect.gd`和`aligned_atlas.gd`。PNG路径索引沿用第6.2节。

### 11.4 待定，暂不修改：状态与元素反应表现

用户最新决定：本批保留待定，暂不修改，继续查看下一批。以下为现状记录，不自动实施源图重制或绘制规则调整。

本批查看尚未审阅的状态/反应效果，已确认保留的结霜冰场、风扩张前沿等不重复纳入。以下尺寸基于1920×1080设计画布，PNG为含透明边的完整帧；程序效果列出绘制框或几何尺寸，不能将它们当成PNG分辨率或实际伤害面积。

| 效果 / 使用场合 | 当前源图或实现 | 当前显示 / 缩放规则 | 是否随伤害范围属性扩大 | 像素规则 |
|---|---|---|---|---|
| 冻结瞬间的冰晶碎片 | `freeze_d0/d1.png`，各112×112源帧、39帧图集 | 112×112，1倍；冻结瞬间播放约0.62秒，细节档只换图集 | 否 | 普通最近邻 |
| 持续冻结的冰壳 | `ice_shell.png`，72×72源帧，11种形态 | 72×72，1倍；按身体半径选择形态，不整张缩放 | 否 | 1px采样网格 |
| 减速时脚下雪花 | `slowed.png`，64×40源帧 | `64×40×max(1,b×0.88/16)`；身体半径b不超过约18.18时为1倍，b=24时为1.32倍，即84.48×52.8 | 否；随敌人体型 | 1px采样网格 |
| 头顶湿润 / 光 / 暗状态标记 | 程序多边形、方块、线段及圆形，无PNG | 各使用3～5的几何半径参数；按身体半径分别乘0.18/0.19/0.20后钳制；标记水平间隔15px。半径参数不等于最终包围盒半径 | 否；随敌人体型，小范围钳制 | 多边形顶点取整；方块/线段经2px辅助网格绘制，非整套统一网格 |
| 眩晕时头顶电粒子 | 程序绘制，无PNG | 8个2×2粒子；轨道半径q=`clamp(b×0.48,7,12)`，横半轴1.35q、纵半轴0.62q；部分粒子带短尾 | 否；随敌人体型改变轨道，粒子仍2×2 | 2px辅助网格 |
| 圣焰 / 暗焰附着状态 | 共用`PixelFireVisual`程序火舌，用不同调色板 | 宽`clamp(b×1.4,14,24)`、高28，宽度向上对齐2px；随身体中心定位 | 否；随敌人体型 | 2px；普通附着燃烧共用同一尺寸规则 |
| 蒸汽：水火反应提示 | `reaction_blocks.gdshader` kind=0，无当前主路径PNG | 绘制框130×125；云团在框内变化，框尺寸固定 | 否；是命中位置提示，不是扩大伤害的范围圈 | 3px |
| 导电：湿润与雷接触提示 | 同Shader kind=5 | 绘制框64×44，跟随目标，尺寸固定 | 否 | 3px |
| 湿润传播：风传播湿润 | 同Shader kind=2 | 连接实际起终点；绘制框为起终点包围盒四周外扩28，即宽`abs(dx)+56`、高`abs(dy)+56` | 不直接乘范围倍率；随实际目标间距变化 | 3px |
| 解冻碎片 | 同Shader kind=7 | 绘制框130×90，尺寸固定；旧112×112解冻图集当前不播放 | 否 | 1px |
| 光反射 | 同Shader kind=6，动态扇扫 | 绘制框边长`2(r+35)`；默认r=220，对应510×510；扇扫在框内变化 | 是；入口传入`220×damage_event.damage_area_scale`，半径下限48 | 3px；高负载可隐藏视觉，判定继续 |
| 雷火反应爆发 | 同Shader kind=1 | 完整档绘制框`2.8r×2.7r`；默认r=72时为201.6×194.4 | 是；r使用解析后的伤害范围倍率。负载降档另缩小或隐藏视觉，不缩小判定 | 3px |

本批实际主路径PNG共4张：冻结碎片2张、冰壳1张、雪花1张。冻结两图整张均为896×560；冰壳整张576×144；雪花整张512×40。文件尺寸已读取PNG头核对。其余主要由程序绘制；蒸汽96×96、导电48×32及反射光束等旧PNG是回退资源，解冻旧图集当前被提前返回的Shader路径绕过，不能把预加载等同于当前显示。

雷火完整档使用实际伤害半径r；减量档视觉半径为0.75r，极简档为`min(18,0.22r)`，还可完全隐藏。以上是当前负载策略，不代表视觉终态与伤害边界在全部档位完全相等。光反射绘制框含35px边缘留白，也不是方形伤害区域。

后续若重新审阅本批，可观察体型变化下的状态识别度及反应提示清晰度；如需处理PNG，可单独讨论冻结碎片、冰壳与雪花的源帧规格，程序效果则需调整绘制规则。当前按用户决定待定。该批仅更新清单与批次状态，未修改美术资源、缩放、伤害或负载策略，也未新增本批实机截图。

源码依据：`scripts/effects/element_reaction_visual.gd`、`enemy_frost_visual.gd`、`enemy_status_visual.gd`、`lightning_status_visual.gd`、`pixel_fire_visual.gd`、`reaction_block_visual.gd`、`element_reaction_resolver.gd`、`light_reflection_effect.gd`、`explosion_effect.gd`及`shaders/effects/reaction_blocks.gdshader`。完整PNG路径补充至7.3。

### 11.5 已确认：移除落雷地面电弧，其余保持现状

用户最新决定已实施：完全移除落雷地面电弧，其余7类效果保持现状。已从`LightningParticleEffect`移除地面电弧预加载、创建、脉冲状态、透明度同步和销毁逻辑；删除专用`lightning_ground_arc_burst.gd`、其UID、`ground_arcs.png`及导入描述，并移除两份闪电审阅脚本对旧电弧的依赖。落雷预警、雷柱、命中粒子、落地冲击圈和伤害逻辑继续使用现有实现。第11.2～11.4节的待定决定不变。

以下记录本批处理后的状态，为正式主动战斗路径、无额外属性加成、1920×1080设计画布下的基础规格。PNG列完整单帧；程序效果列生成纹理或绘制框，后者包含未着色区域，不代表可见主体或伤害边界。

| 效果 | 当前来源 | 基础显示与倍率 | 尺寸变化规则 | 像素规则 |
|---|---|---|---|---|
| 闪电命中粒子（电火花/落雷共用） | 4张PNG：flash/impact各有core与glow；单帧48×48，各24时间帧×32变体 | 单粒绘制框48×48，默认1倍；通用尺寸为`48×48×S`，S是解析后的`size_multiplier` | 不直接乘伤害范围倍率；攻击距离改变生成数量及散布距离。发光层UV另缩放，不能等同于整张图片倍率 | 最近邻；移动位移取整，无统一2/3px重采样 |
| 落雷地面电弧：已移除 | 历史PNG与专用脚本已删除 | 不再显示 | 无运行时创建或预加载 | 不适用 |
| 电火花连锁闪电 | 动态路径，无固定PNG | 连接实际起终点，没有固定长宽和源图倍率 | 攻击距离扩大连锁搜索距离，默认170；实际路径随目标位置变化；伤害范围不直接扩大线条 | 路径按2px网格光栅化 |
| 电浆球及放电 | 运行时生成24×24核心纹理，共16帧；光晕/电弧由程序绘制 | 核心默认40×40，约1.667倍；纹理不是磁盘正式PNG | 核心直径`2H`，H默认20并随伤害范围变化；光晕与放电范围跟随H | 核心1px采样；细电弧1px，其他方块/光晕含2px |
| 赤铜炉灯火焰 | Shader，共用128×128程序噪声，无完整火焰源图 | 基础reach=360，承载框720×720；实际为地面投影扇形，扇角60° | 正式“扇形+范围”标签使攻击距离和伤害范围都增加reach；分裂reach再乘0.65，默认234、承载框468×468；角度不随范围扩大 | 2px |
| 巨型手持火炮喷流 | Shader，复用程序噪声 | reach=`1.25R`；R默认250，reach=312.5、承载框625×625；动画0.28秒 | 随攻击距离改变；伤害范围不直接改变喷流尺寸，弹丸的尺寸响应另见11.2 | 3px |
| 榴弹飞行弹体 | 程序矩形拼接，无PNG | 默认形状包围盒12×13；分裂为7.8×8.45 | 乘`V`，正式路径中V随伤害范围变化；分裂另乘0.65 | 原始1px几何直接缩放；无统一最终像素网格 |
| 坤舆秘仪书法阵 | PNG，384×240；外围另有程序粒子 | 默认约640.58×400.55；横367/220≈1.6682倍、纵242/145≈1.6690倍 | 当前两个半轴随攻击距离变化；伤害范围属性不进入`get_domain_axes()`，不会直接放大法阵 | 法阵2px采样；外围方块按世界坐标取整 |

闪电命中粒子的S默认1，独立效果参数/修饰器仍可覆盖；不能将攻击距离导致的散布扩大写成单粒PNG扩大。默认完整视觉档、无额外发光修饰时，连锁闪电的glow UV缩放为0.25，落雷为0.5；这仅改变48×48绘制框内的光晕覆盖。高负载档减粒子数量、减光晕或隐藏整批，未因此改变单粒S。落雷8×8预警及雷柱/地面作用区已按7.7保持现状，本批不重新提出修改。

本批现保留5张磁盘PNG：4张命中图集各1152×1536，法阵384×240；尺寸已读取PNG头核对。原1280×224地面电弧图集已删除。电浆24×24是程序生成纹理，炉灯/手炮128×128是噪声输入，均不能当作可直接用Picxel缩小的完整特效原图。

本轮纠正了6.1与10.5中炉灯旧的“reach=200、承载框400×400”基准：当前`data_config/weapons.json`配置为360，`CopperLamp._build_beams()`直接使用`get_attack_range()`传给视觉，故基础承载框为720×720。只修正文档，没有修改射程或画面。

验证：Godot headless编辑器导入及主场景120帧启动通过；调整后的落雷回归278项、闪电路径/时序109项、命中PNG149项，共536项检查通过，无脚本/编译错误。覆盖落雷与回闪不产生地面电弧、暂停/生命周期、满粒子池下正常落地、伤害生效、重复落地不重复伤害、回闪不追加伤害，以及保留的主闪电/命中粒子行为。日志为`artifacts/reports/ground_arc_removed_editor.log`、`ground_arc_removed_main.log`及`ground_arc_removed_lightning_*_test.log`。编辑器另有Android build-tools路径提示，与本次桌面修改无关。本次未新增GPU截图。

源码依据：`scripts/effects/lightning_hit_sprite_burst.gd`、`lightning_particle_effect.gd`、`lightning_pixel_bolt.gd`、`plasma_ball_visual.gd`、`copper_lamp_flame.gd`、`cannon_jet_flame.gd`，`scripts/weapons/copper_lamp.gd`、`grenade_projectile.gd`、`ritual_domain.gd`及`weapon_instance.gd`，以及相应Shader和`data_config/weapons.json`。

### 11.6 已实施并经用户确认：角色与怪物主体（2026-10-21）

本批已按用户指定尺寸制作并正式接入。全部使用PNG，以下数值包含完整源帧的透明留白；基准为1920×1080设计画布、普通体型、非死亡阶段。四类怪物使用720×720原始文件进行Picxel像素化，不从旧正式小图放大生成。

| 对象 / 场合 | 当前源帧 | 当前基础显示 | 当前倍率 | 动态变化与说明 |
|---|---|---|---|---|
| 初心者：战斗动作 | 96×96 | 96×96 | 1倍 | 7张图集、47个独立帧；前后跳共用6帧。动作贴图缩放100%，VisualAnchor绝对倍率1；`body_scale_percent=150`不是动作贴图再放大1.5倍 |
| 初心者：选人页大图 | 同一套96×96 idle/move | 288×288 | 3倍 | 完整画布固定尺寸、整数位置、无呼吸拉伸；保留悬停走路动画 |
| 天外幼体 | 96×96 | 96×96 | 1倍 | 移动7个独立帧；idle复用move-01；Sprite位置(0,2) |
| 蝙蝠主体 | 96×96 | 96×96 | 1倍 | 移动6、攻击9个独立帧；idle复用move-01；Sprite位置(0,-10)，嘴部像素(60,46)；声波技能PNG在后续11.7单独重制 |
| 钢甲骑士 | 192×192 | 192×192 | 1倍 | 移动7、攻击10个独立帧；分为idle/move/windup/dash/recover；Sprite位置(0,-70) |
| 幽焰冥狼 | 192×192 | 192×192 | 1倍 | 移动7、攻击4、跳跃10帧；所有帧共用偏移(0,-91)与1倍倍率；另保留实际跳跃高度 |
| 资本家（当前锁定） | 80×80 | 战斗回退显示80×80；选人页按可见身体适配 | 战斗回退1倍；选人页非固定倍率 | 已配置待机1帧、行走7帧，`release_locked=true`；不计作当前可选角色已完成的一套战斗动作 |

怪物仍会乘挑战的`body_scale_multiplier`，死亡消退会把当时贴图尺寸逐渐缩到0.82倍；这些变化与玩家“伤害范围”属性无关。冥狼原先0.8192/1.024的逐帧补偿及1.5倍显示已合并进画布，运行时不再重复乘；`BASE_BODY_SCALE=1.5`继续服务现有技能／判定参数。

本批共13张主体图集、63个图集帧格，对应**60张独立原图（幼体7、蝙蝠15、骑士17、冥狼21）**；idle复用不重复计作独立原图。冥狼场景所用的独立idle别名文件也同步替换。原始帧、上一版正式资源、Picxel网格与修整记录保留在`artifacts/previews/enemies_native_96_192/20261021-r01/`。

核查依据：第3.1节PNG索引、角色/敌人正式场景、`character_select_view.gd`、`underworld_wolf.gd`、两套SpriteFrames和各类`native_pixel_provenance.json`。后续候选为怪物技能表现及环境/拾取物。

#### 11.6.1 原图来源、制作与接入记录

| 对象 / 场合 | 正式源单帧 | 基础显示框 | 基础倍率 | 已完成处理 |
|---|---|---|---|---|
| 初心者：战斗 | 96×96 | 96×96 | 1倍 | 保留现有正式动作图 |
| 初心者：选人页 | 96×96 | 288×288 | 3倍 | 复用现有idle/move，改为完整画布固定3倍，取消可见包围盒适配和纵向呼吸拉伸，位置按设计像素取整 |
| 天外幼体 | 96×96 | 96×96 | 1倍 | 7张原图→2张图集，保留触须与嘴部轮廓，共同源比例0.1 |
| 蝙蝠 | 96×96 | 96×96 | 1倍 | 15张原图→3张图集；共同源比例0.12；补齐黑底抠图后的断边和内部孔洞，更新出嘴锚点 |
| 钢甲骑士 | 192×192 | 192×192 | 1倍 | 17张原图→5张图集；共同源比例0.25；简化盾面碎裂刻纹、保留盾边和锤柄，更新SpriteFrames裁切 |
| 幽焰冥狼 | 192×192 | 192×192 | 1倍 | 21张原图→3张图集；共同源比例0.3072；原图脚底(360,650)映射到新帧(96,187)，保留尾部与跳跃姿态 |

原图从Git提交`02b3ef4`的`artifacts/sources/enemies/`按原字节恢复，共60张720×720。蝙蝠／骑士／冥狼53张均与现有来源清单中的SHA-256一致；幼体7张来自原始移动图目录。输入与来源校验记录为任务目录的`source_manifest.json`。素材制作使用项目Picxel本地限色、网格投票和局部修整，未调用图片生成模型。

四类怪物分别使用统一色板（每帧最多16色）、二值透明度0/255与公共源图坐标，不逐帧拉满画布。留白使主体体型尽量接近原版；碰撞、移动和技能数值未因换图修改。选人页框从约331.40改为288，初心者idle可见身体高228。骑士attack-03原图锤头左端已被裁切，保留此来源限制，没有虚构缺失结构。

Picxel项目运行库增加96/192尺寸和`--preserve-canvas`，按7／15／17／11／10帧分批完成build→逐图检查／修整→select→finish。正式打包工具`scripts/tools/build_enemy_native_pixels.py`先验证全部选用网格与原图哈希，再安装；原有三套正式素材验证工具已同步新尺寸。

本表约定的是普通体型、1920×1080设计画布下的基础倍率。挑战体型倍率、死亡缩到0.82倍以及其他窗口的整体输出缩放仍属于现有动态规则，不能据此承诺所有时刻、所有窗口都是整数倍率。锁定资本家保留原展示规则。本次原图缩小会主动取舍细节；1倍／3倍约束保证的是制成素材在基础展示时不再因额外小数缩放丢像素。

正式资源及显示代码已完成替换。代表帧可见体型对比（不含透明留白，单位为基础世界像素）：

| 对象 | 替换前 | 替换后 |
|---|---|---|
| 天外幼体move-01 | 70.2×35.4 | 70×35 |
| 蝙蝠move-01 | 71.4×40.8 | 73×43 |
| 骑士move-01 | 100.5×141 | 100×144 |
| 冥狼attack-01／idle | 152.37×137.63 | 152×137 |

#### 11.6.2 验证与实机审阅

- Picxel流程回归 **11项通过**，包含96／192画布的共同锚点不因另一部件出现而改变、无效画布拒绝处理，以及原图哈希／选稿验证。
- 正式PNG／图集校验通过：幼体与骑士尺寸、蝙蝠15帧与4张保留技能图、冥狼21帧与9段动画元数据，均符合新规格、每帧最多16色、alpha为0/255。
- Godot编辑器headless导入完成，无Parse／Compile／SCRIPT ERROR。专项回归 **400项通过**：骑士／幼体73、蝙蝠35、冥狼73、选人页219；覆盖动作帧、脚底、出嘴位置、技能时序与伤害、挑战生成和UI交互。
- 旧回归同步现状：蝙蝠追近检查包含加速过程，接触伤害使用实际碰撞中心；冥狼独立射程按现配置240检查，不再假设等于炉灯射程两倍；源尺寸与显示倍率断言按新规范更新。未为通过测试修改对应玩法数值。
- 主场景headless运行120帧完成，无脚本错误；`--quit-after`强制结束时仍报告4个ObjectDB实例及2个资源未释放。本次没有将该退出提示计作通过的资源释放检查。独立实机审阅场景正常退出，退出码0。
- GPU截图在私有Windows桌面执行，`verified_desktop`与`private_desktop`一致、**foreground_samples=0**。1920×1080、相机1倍；展示正式选人页、四类正式怪物的待机、移动、攻击和冥狼跳跃姿态。为了看清主体，仅审阅场景临时隐藏遮挡草丛／大石块，正常游戏环境保持原状。移动GIF是实际GPU画面裁切，无几何缩放；GIF存在256色编码限制，PNG为核对依据。

审阅文件：

- [原图、旧正式展示与新图对照](artifacts/previews/enemies_native_96_192/20261021-r01/comparison.png)
- [实机主体同屏裁切](artifacts/previews/enemies_native_96_192/20261021-r01/runtime_lineup.png)
- [实机移动动画裁切](artifacts/previews/enemies_native_96_192/20261021-r01/runtime_moves.gif)
- [选人页固定3倍](artifacts/previews/enemies_native_96_192/20261021-r01/runtime/01_character_select_3x.png)
- [完整战斗截图](artifacts/previews/enemies_native_96_192/20261021-r01/runtime/02_battle_idle_1x.png)

验证日志：`artifacts/reports/enemy_native_editor.log`、`enemy_native_main.log`、`enemy_native_iron_knight_test.log`、`enemy_native_echo_bat_review.log`、`enemy_native_underworld_wolf_review.log`、`enemy_native_character_select_view_test.log`、`enemy_native_gpu.log`及`enemy_native_gpu.json`。原始帧、分批Picxel检查和正式安装哈希保存在本轮任务目录，正式运行不依赖该预览目录。

### 11.7 已实施并经用户确认：蝙蝠3项原生特效；其他技能与预警保持现状（2026-10-21）

用户确认：程序绘制内容不用改，原本1倍的PNG不用改；蝙蝠声波、嘴部蓄力、命中特效分别重绘为32×32、20×20、32×32并以1倍显示。三套正式资源及采样规则现已替换。以下尺寸以1920×1080设计画布、相机1倍、默认敌人配置为基准。PNG尺寸包含透明留白，旋转前画布不等于可见轮廓或碰撞边界。

| 对象 / 效果 | 正式源规格 | 基础显示 / 作用区 | 倍率与绘制规则 |
|---|---|---|---|
| 蝙蝠：飞行声波 | `sonic_wave.png`，256×32，8帧，每帧32×32 | 32×32，横向螺旋、上下留白 | 1倍、最近邻，随方向旋转；移除额外2px网格重采样 |
| 蝙蝠：嘴部蓄力 | `sonic_charge.png`，120×20，6帧，每帧20×20 | 20×20 | 1倍、最近邻；移除额外2px网格重采样 |
| 蝙蝠：声波命中 | `sonic_hit.png`，192×32，6帧，每帧32×32 | 32×32 | 1倍、最近邻，命中时取消旋转；移除额外2px网格重采样 |
| 蝙蝠：路径预警 | `sonic_warning.png`，320×20，单张 | 320×20 | 默认1倍；横向`attack_range/320`、纵向`path_width/20`，随方向旋转并按2px采样 |
| 钢甲骑士：冲锋预警 | 程序矩形、边线和方粒，无PNG | 311.68×71.68，旋转前 | 长为240+2×35.84，宽为2×35.84；边线1px、方粒3×2，无源图倍率 |
| 幽焰冥狼：喷焰 | Shader；128×128程序噪声仅为输入 | 半径240、扇角60°；承载框480×480 | 本地2px网格；噪声不是完整火焰图，不能用480/128当源图展示倍率 |
| 幽焰冥狼：喷焰预警 | 程序扇形，无PNG | 半径240、扇角60°；进度弧半径243 | 轮廓线宽1.5、进度线宽2；按喷焰方向旋转，本路径未乘地面椭圆投影 |
| 幽焰冥狼：扑跃落点预警 | 程序地面椭圆、进度环与十字，无PNG | 主区域156×约102.82；外进度环164×约108.09 | 半径78，地面纵向比例145/220；进度环半径82，线宽1.5／2 |
| 幽焰冥狼：落地扩散波 | 程序地面环与12个方粒，无PNG | 主环由109.2×约71.97扩至156×约102.82 | 半径从78×0.7扩至78；线宽3，方粒4×4；方粒中心半径从46.8扩至85.8，另作装饰 |
| 幽焰冥狼：出场环 | 程序地面椭圆，无PNG | 默认108×约71.18 | 半径36×1.5=54，再乘挑战体型倍率；线宽2 |

本批效果均不受玩家“伤害范围”属性影响。敌人的`apply_body_scale()`只缩放主体Sprite、碰撞形状及其偏移，不直接缩放本批技能范围：蝙蝠声波尺寸、骑士冲锋区域、冥狼喷焰半径和扑跃半径保持各自配置。嘴部位置会随身体变化；冥狼出场环显式乘体型倍率，是本表例外。天外幼体为接触攻击，没有另外一套独立技能PNG；主体攻击动作已包含在11.6，不重复计数。

蝙蝠4张PNG由`scripts/tools/build_echo_bat_art.py`离线绘制，来源不同于上一批720×720角色原图。本次从原绘制结构在目标网格重画20帧，不压缩旧小图、不调用图片生成模型，也不将本地重画称作高清原图Picxel转换。沿用Picxel像素质量准则：声波双螺旋连续、删去游离端点、保持横向比例；蓄力为连续收拢环和中心亮点；命中将细碎弧段合并为连续扩散环。特效保留原有半透明及逐帧消退，不套用角色PNG必须二值alpha的规则。

历史规格：声波48×32→30×20（0.625倍）、蓄力40×40→20.8×20.8（0.52倍）、命中48×48→36×36（0.75倍），且三者原有2px网格重采样。现三者均`scale=Vector2.ONE`，不再绑定`AlignedAtlas`材质；原路径预警PNG的字节与320×20显示、2px采样规则不变。原生1倍避免了额外尺寸缩放和粗网格采样造成的丢点；声波任意角度旋转及窗口整体缩放仍可能重新采样，不能据此承诺任意角度、窗口均逐像素保留。

程序预警与Shader火焰按用户要求保持现状。本次仅改变上述3项美术与采样，不宣称本批每帧视觉和伤害轮廓完全一致：例如喷焰有动态火舌留空、落地波有额外装饰粒子，蝙蝠实际弹体碰撞仍为半径10的圆形扫掠；速度300、射程320、伤害7、蓄力0.2秒、预警0.5秒和24fps动画时序均未改变。

核查依据：4张PNG头尺寸；`data_config/enemies.json`；`scripts/enemies/echo_bat.gd`、`echo_bat_sonic.gd`、`elite_rusher.gd`、`underworld_wolf.gd`、`underworld_wolf_flame.gd`、`enemy_controller.gd`；`scripts/effects/aligned_atlas.gd`与对应Shader；`ghost_flame.gdshader`、`ground_projection_r05.gd`及`attack_footprint.gd`。

制作记录：`artifacts/previews/bat_sonic_native/20261021-r01/`保留原PNG与原绘制脚本、成品、逐帧总览和哈希清单。`build_echo_bat_art.py --rebuild-sonic`只重建三张新特效；普通执行仍为只读校验。无其他怪物美术、程序技能或玩法配置改动。

用户已接受实机结果并确认作为正式资源。本轮再次核对3张正式PNG与任务`manifest.json`的SHA-256全部一致，正式脚本仍为原生1倍、无额外2px材质；路径预警与本轮前的备份逐字节一致。资源此前已安装，因此本次无需重复覆盖或重绘，继续查看11.8。

#### 11.7.1 验证与实机结果

- 正式资源检查通过：三张图集为256×32、120×20、192×32，分别8／6／6帧；蝙蝠主体与原路径预警保持原字节。20帧均已查看原尺寸及放大图；声波与命中环每帧各为一个连续的8邻接像素区域，蓄力保留有意分开的环与中心亮点。
- Godot headless编辑器导入和主场景120帧启动退出0，无脚本错误；编辑器仍有原有Android build-tools路径提示，与本次桌面显示无关。蝙蝠行为回归 **39项通过、0失败**，包括新增尺寸／材质检查，以及原预警、速度、半径10碰撞、伤害7、闪避、暂停和清理行为。
- GPU使用正式GameRoot/BattleRoot、蝙蝠与弹体组件，1920×1080、相机1倍，记录36帧，审阅流程41项检查通过、退出0。实际伤害仅发生一次；运行记录中三项尺寸为32／20／32、全局倍率1、无粗网格材质。导出Godot实际载入纹理，与新PNG逐像素比较，alpha及非透明像素RGBA差异均为0（透明区域的导入边缘颜色填充不计）。
- 私有Windows桌面核对一致，`foreground_samples=0`。只在审阅场景隐藏遮挡草丛／石块，正常游戏未改；截图上方为原尺寸裁切，下方为4倍最近邻局部放大。GIF将实机截帧按每帧50ms回放，有256色限制，不代表实时性能录像。未对所有角度或其他窗口作额外验收。

审阅素材：[实机三阶段对照](artifacts/previews/bat_sonic_native/20261021-r01/runtime_review.png)、[实机流程GIF](artifacts/previews/bat_sonic_native/20261021-r01/runtime.gif)、[20帧总览](artifacts/previews/bat_sonic_native/20261021-r01/frames.png)、[原生素材动画预览](artifacts/previews/bat_sonic_native/20261021-r01/native_preview.gif)。

验证日志：`artifacts/reports/bat_sonic_native_editor.log`、`bat_sonic_native_main.log`、`bat_sonic_native_behavior.log`、`bat_sonic_native_gpu.log`、`bat_sonic_native_gpu.json`。截图入口为`scenes/tests/bat_sonic_native_review.tscn`；采样尺寸与实际载入纹理的核查记录为任务目录中的`runtime/capture.json`和`runtime_validation.json`。一次独立`--script --check-only`尝试因未初始化项目autoload而报告`WindowSettings`未找到；随后正式场景GPU运行成功，此命令限制未被当成运行时脚本问题或通过证据。

### 11.8 当前查看：地面摆件、植被与拾取物（2026-10-21）

本批仅核查当前正式PNG、场景和代码，尚未重制或调整参数。尺寸按1920×1080设计画布、相机1倍计算，包含透明留白；镜像不改变绝对倍率。环境大图、远景及阴影另列后续，避免与小摆件混为同一规格。

| 对象 | 当前源图 | 当前基础显示框 | 当前倍率 / 变化 | 后续建议（未实施） |
|---|---|---|---|---|
| 主层草：短草／密草／长草／枯草，4张 | 各32×32 | 各30.4～40×30.4～40 | 每个实例随机0.95～1.25倍 | 保留32×32源图，若统一倍率则使用1倍；可用不同原生稿区分高低，不靠随机缩放 |
| 底层草：复用前三种绿草 | 同一套32×32 | 各15.36～24.96×15.36～24.96 | 每个实例随机0.48～0.78倍 | 如需单独小草档，可制作16×16、1倍；不可将主层同步改小 |
| 石块／木头旁的伴生草 | 复用短草／密草／枯草32×32 | 按宿主可见高度适配，无统一画布显示尺寸 | `clamp(宿主可见高度×0.42,10,22)/草可见高度×随机0.9～1.1` | 与主层／底层一起规定档位；不能遗漏这一条动态缩放路径 |
| 大石块 | 75×65 | 150×130 | 2倍 | 已是整数倍率，保留现状 |
| 倒木 | 69×31 | 138×62 | 2倍 | 已是整数倍率，保留现状 |
| 松散碎石0 | 100×60 | 36.25×21.75 | 1.45÷贴图密度4=0.3625倍 | 可考虑两种碎石统一32×32、1倍，以留白保留各自可见体型；先审阅样稿 |
| 松散碎石1 | 64×44 | 23.2×15.95 | 同为0.3625倍 | 同上；当前可见主体约15.59×13.41，不应拉满32px |
| 地面砖石贴花，7张 | 各64×64 | 各54.4～74.24×54.4～74.24 | 每个实例随机0.85～1.16倍 | 优先保留64×64源图、统一1倍；若另行追求更粗像素，再评估32×32源图／2倍，不直接缩图替换 |
| 经验球 | 16×16 | 8×8 | Sprite固定0.5倍；波末收集另有旋转 | 若保持当前占用，推荐原生8×8／1倍；旧10.3的4×4／2倍是更粗像素方案，不是当前已确认待办 |
| 治疗包 | 16×16 | 16×16 | 1倍；吸附仅改变位置 | 已符合当前规则，保留现状 |
| 附魔掉落图标 | 已完成的19张32×32源图 | 32×32 | 1倍；光晕单独程序绘制 | 沿用已确认资源，不重复制作 |
| 遗物选择拾取方块 | 程序绘制，无遗物PNG | 方块名义24px，另有44×44光晕 | 程序几何及悬浮位置变化 | 按程序内容不改的既定方向保留，无需新增或缩小遗物PNG |

主层、底层与伴生草共用4张PNG，不能把三行计作三套独立源图。本批新增核查的PNG共17张：草4、大摆件2、碎石2、贴花7、拾取物2。附魔19张属于前面已完成资源，遗物拾取方块也不是36px遗物图标的缩小版。

草还使用正式`shaders/battle/meadow/sunlight/grass.gdshader`进行顶端水平风摆，局部位移振幅最高1.25，再受实例变换影响；不是整株按时间缩放。故单纯把PNG或基础scale改为整数，不能宣称风摆过程也完全不重采样。当前尚未修改随机尺寸或风摆。经验球的拾取半径属性只影响吸附距离，不放大PNG；本表内容均不因玩家伤害范围加成而扩大。

可优先审阅经验球、两种碎石和7张贴花：前三项涉及固定缩小，贴花涉及随机大小。草丛需要一起考虑主层／底层／伴生草的尺寸层次与风摆观感。两种碎石当前非透明可见范围分别约28.64×19.94和15.59×13.41，所以统一画布仍可通过不同留白保持体型。

正式文件：草为`assets/sprites/background/green_ground/G09_grass_short-32.png`至`G12_grass_dry_mix-32.png`；摆件为`assets/sprites/background/cavern/prop_rock.png`、`prop_log.png`，碎石为同目录`rubble_0.png`、`rubble_1.png`；7张贴花为`assets/sprites/background/wetland/decal_{single_brick,stacked_bricks,brick_fragments,scattered_stones,high_rubble,low_rubble,flat_stones}.png`；拾取物为`assets/sprites/pickups/pickup_exp_orb.png`、`pickup_health_pack.png`。本批全部已读取PNG尺寸。

运行依据：正式`CavernSunlightBackdrop`继承链、`data_config/cavern_meadow_battlefield.json`、`cavern_population_backdrop.gd`的主层／伴生草和摆件放置、`cavern_grassland_backdrop.gd`的底层草、4类拾取脚本与场景、`drop_reward_system.gd`生成入口。以上为源码和配置核查结果，本轮无新的运行时代码改动或GPU截图。
