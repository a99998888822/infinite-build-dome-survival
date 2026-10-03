# 天外幼体 32px 原色12色动画正式接入

2026-10-03，按用户确认的 B 方案，将天外幼体完整 7 帧替换到正式资源。新稿采用 32×32 画布和共享原色 12 色板，单帧实际使用 11–12 色；移动第 03 帧与选定样例逐像素一致。

## 正式规格

| 项目 | 当前值 |
| --- | --- |
| 静止图 | `assets/sprites/enemies/combat/enemy_gloom_mite_idle.png`，32×32，复用移动第 01 帧 |
| 移动图集 | `assets/sprites/enemies/combat/enemy_gloom_mite_move.png`，224×32，横排 7 帧 |
| 移动播放 | 7 FPS，按 01–07 顺序循环，停止时恢复静止图 |
| 可编辑源 | `frames/grub_move_01-32-final.pxg` 至 `grub_move_07-32-final.pxg`，对应 PAL 同步更新 |
| 场景缩放 | `scenes/enemy/mutated_grub.tscn` 的 Sprite 缩放由 0.8 改为 1.6 |
| 显示画布 | 32×1.6＝51.2，与旧 64×0.8 相同 |
| 位置与碰撞 | Sprite / 碰撞偏移 `(0,-6.4)`、碰撞半径 17.6 保持原值 |

采用固定 2:1 画布缩小，保留原色调和主要明暗，合并内部碎斑，并逐帧修复缩小丢失或模糊的眼点。没有单独居中各帧。正式 PNG 与可编辑网格完全匹配，原有导入配置保留，最近邻显示。

旧 64px 网格已随原图集、色板及场景备份到 `artifacts/previews/grub_source12_animation/r03_32_animation/installation/previous/`，正式目录只保留当前 32px 网格。制作输入和已确认样例保留。

## 验证

- Godot 4.7.2 无窗口导入通过，确认两张正式贴图重新导入。
- 现有 `iron_knight_test` 的小怪尺寸检查同步到 32px，新增显示大小检查；70 项检查全部通过。覆盖 7 帧循环、无空帧、停止恢复 idle、脚底参考位置和战斗显示大小。
- 安装器校验同步为 idle 32×32、move 224×32，通过尺寸、色数和二值透明检查。
- 通过正式 GameRoot / 战斗场景 / WaveManager 和小怪动画控制器，在私有桌面记录 144 张 GPU 视口帧，核对动画与镜像显示。未切换用户桌面，`foreground_samples=0`。
- 其余敌人资源与原有导入文件共 47 项哈希保持一致。

详细记录位于 `artifacts/previews/grub_source12_animation/r03_32_animation/installation/installed.json` 和 `validation.json`。实机截图为 `installation/live/battle.png`，动图为 `installation/live/battle-detail.gif`；动图是实机视口裁切与最近邻放大，场景及角色素材没有重绘。
