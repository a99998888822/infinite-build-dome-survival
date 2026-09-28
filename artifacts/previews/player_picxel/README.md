# 初心者与资本家 · Picxel 审阅包

状态：2026-09-28 经用户授权，已替换正式游戏资源。输入来自 `assets/sprites/player/tobe_handled/`，初心者 6 张、资本家 7 张；13 张原图内容均未改变。

2026-09-29 更新：本包当前仅资本家仍用于正式游戏；初心者已由[新版八帧素材](../combat_picxel_3838180/README.md)替换。下文初心者规格与安装结果为上一版记录，保留作已确认的可编辑来源；安装器始终选择新版初心者。

当前审阅：[资本家实机成品](../../reviews/characters/capitalist/README.md) · [新版初心者与怪物](../combat_picxel_3838180/integration/README.md) · [文件、尺寸与哈希清单](manifest.json)。旧版混合预览和重复实机截图已清理。

## 尺寸与格式

| 用途 | 导出格式 | 说明 |
| --- | --- | --- |
| 战斗待机 | 54×54 RGBA PNG | 从 64×64 像素稿仅裁去四周透明留白；像素未缩放 |
| 现有四帧行走 | 216×54 RGBA PNG | 横排 4 帧，每帧 54×54，直接符合当前 `hframes=4` 的布局 |
| 完整动作序列 | 初心者 324×54；资本家 378×54 | 保留全部 6／7 帧；使用时需要对应调整配置的 `walk_frames` |
| 角色展示 | 256×256 RGBA PNG | 从独立按高清输入计算的 128×128 像素稿，最近邻放大 2 倍 |
| 角色头像 | 128×128 RGBA PNG | 从高清原图的头肩区域独立转换，保留发型／礼帽、视线和眼镜 |
| 可编辑单帧 | 64×64 与 128×128 `.pxg`、PNG | 两种网格分别从高清输入计算，128 稿并非放大 64 稿 |

每个角色共用一套 16 色色板；透明度只有 0／255，无抖色。审阅图中的绿色底不在透明素材内。单帧完整保留原图的双手、鞋子、剑／手杖；展示图中的持物仍属于角色图像。

所有战斗帧统一源图尺度和头部横向锚点，导出时将脚底基准固定在 y=52（不含该行）。校验透明裁切和平移前后不丢失任何可见像素。左向沿用当前控制器的整帧水平镜像。

四帧兼容版选用初心者原图 2→4→5→6，资本家原图 1→3→5→7，分别保留当前 3.5／6 FPS。待机使用初心者第 3 张和资本家第 7 张相对平稳的现有姿态。完整序列按文件编号排列；若保持现有循环时长，6／7 帧版本分别使用 5.25／10.5 FPS。原图自身的姿势与衣褶差异仍保留，未生成过渡帧。

## 文件对应

`delivery/beginner/` 与 `delivery/capitalist/` 分别包含：

- `combat/`：待机、四帧兼容图集、完整序列图集。
- `ui/`：256 展示图与 128 头像，名称对应当前角色资源。
- `frames_64/`、`frames_128/`：所有动作的独立透明 PNG。

初心者前缀为 `void_hunter`，资本家前缀为 `capitalist`。两人的待机、四帧行走、展示图和头像共 8 张 PNG 已覆盖同名正式资源，沿用原路径、导入 UID 和动画配置。正式目标与哈希见 `manifest.json` 的 `installed_assets`；删除记录与仓库外备份位置见 [installation.json](installation.json)。完整 6／7 帧图集保留作后续编辑使用。

安装／校验工具：[install_player_picxel_assets.py](../../../scripts/tools/install_player_picxel_assets.py)。运行 `python scripts/tools/install_player_picxel_assets.py --check` 核对已安装贴图；修改像素稿并导出新审阅包后，去掉 `--check` 可安装新版本。旧角色生成脚本及旧版素材已清理。

## 处理与修改

使用项目 Picxel 外部图片流程：浅色背景与脚下灰影清理 → 统一画布 → 锁定材质色板 → Picxel 网格投票 → 恢复原图细线和一像素外轮廓 → 单独检查并局部修整眼睛／眼镜。没有调用图片生成模型。

默认 Picxel 会按单图可见范围重新适配，本任务通过独立包装脚本保持 1152×1152 的统一高清画布，不修改技能本体。剑面的白色高光使用逐帧检查过的局部遮罩保护，避免误当背景。眼部修整之后没有再进行全图平滑或描边。

`work/*-64-detail-face.pxg`、`work/*-128-detail-face.pxg` 为初心者选定稿；资本家使用对应的 `*-accessory-face.pxg`。头像选定稿在 `portraits/work/*-128.pxg`。最终网格及对应原尺寸 PNG、色板、局部修整参数均保留。

2026-09-29 已清理未选用底稿、抠图副本、重复成品和放大过程图。历史批次报告保持原样，所列部分过程路径已归档；如需重跑完整批次或 `finish`，先按[清理记录](../../reports/intermediate_cleanup.json)恢复输入。正式贴图校验和安装不依赖这些中间文件。

准备与处理脚本：[prepare_player_picxel_review.py](../../../scripts/tools/prepare_player_picxel_review.py)。格式导出与审阅脚本：[export_player_picxel_review.py](../../../scripts/tools/export_player_picxel_review.py)。来源、画布和平移记录见 [source-map.json](source-map.json)。

已校验 36 张交付 PNG 的尺寸、色数、透明度和源图哈希；四帧图集逐帧可还原为对应 54×54 图片。Picxel 的完成状态表示处理和检查结束，最终风格仍以用户审阅为准。
