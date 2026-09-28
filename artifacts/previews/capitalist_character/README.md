# 资本家：形象审阅

状态：已正式接入游戏。本目录保留素材预览；[游戏内截图与行走实录](../../reviews/characters/capitalist/README.md) 使用正式角色配置与场景采集。

当前形象已修正五官透视：单片镜对应近侧眼睛、镜内可以看清瞳孔，鼻梁与鼻尖独立排列；腰腹收窄，外套在腰部合拢，红色马甲仅露出胸前窄开口。以下静态图、头像与所有行走帧均为同步修订后的版本。

| 文件 | 用途 |
|---|---|
| [capitalist_review.png](capitalist_review.png) | 1600×1060 审阅板：全身、细节及战斗尺寸对照 |
| [角色展示图](../../../assets/sprites/player/capitalist_idle_right.png) | 256×256 透明角色展示图 |
| [角色头像](../../../assets/ui/icons/characters/icon_capitalist.png) | 128×128 透明头像 |
| [战斗待机图](../../../assets/sprites/player/combat/capitalist_idle_right.png) | 单独绘制的 54×54 战斗纹理 |
| [实机行走](../../reviews/characters/capitalist/walk.gif) | 正式场景中的角色行走实录 |
| [capitalist_walk_frames.png](capitalist_walk_frames.png) | 四个动作姿态总览 |
| [capitalist_walk_right.png](capitalist_walk_right.png) | 1024×256 透明源图帧表，四帧横排，每帧 256×256 |
| [战斗行走帧表](../../../assets/sprites/player/combat/capitalist_walk_right_spritesheet.png) | 216×54 透明战斗帧表，四帧横排，每帧 54×54 |

直接手工构造像素形状与色块，Pillow 输出 PNG；未调用外部图像 API。

高帽、单片镜和拐杖为主要识别点，克苏鲁细节仅在幽绿镜片与杖头雕纹。行走动画已接入。

动作顺序：落杖迈步 → 承重跟进 → 抬杖换步 → 前送手杖 → 循环。双腿分别摆动，抬脚与承重脚分离；鞋尖向前，拐杖有落地和抬起，上身与高帽轻微起伏，衣摆随步态摆动。

正式动画速度 6 FPS，完整步态约 0.67 秒。初心者保留原速度 3.5 FPS。

每帧原点固定。源图脚底基准为 y=242（像素下边界），战斗帧为 y=51；不按每帧可见范围重新裁剪。左向使用整帧水平镜像。

已核对四个独立姿态、透明通道、边界留白和脚底基准。清理时移除了与正式资源重复的 PNG 和素材播放 GIF，保留源图、帧总览、审阅板及实机录像。

完整设计与数值：[角色设计与实现](../../../docs/main/21-capitalist_character_design_review.md)。本版完整触发四方案合计 500 本金，额外角色代价为伤害加成 -30%、战斗金币获取最终 -50%、负载上限 80。

可编辑源图定义：[capitalist_character.py](../../../scripts/tools/source_art/capitalist_character.py)。仓库根目录运行：

```powershell
python scripts/tools/source_art/capitalist_character.py
```

脚本可重建完整预览包（七张 PNG 和一张 GIF）；审阅后只需保留本页列出的必要文件。运行 `python scripts/tools/source_art/capitalist_character.py --install` 同步安装展示图、头像、战斗待机及四帧行走纹理；配置与代码独立维护。
