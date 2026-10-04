# 钢甲骑士 256px 正式接入

用户确认 256×256 清理版的移动与攻击实机动图后，于 2026-10-04 授权替换正式资源。本轮安装已确认的像素稿，不重新转换图片。

正式目录为 `assets/sprites/enemies/iron_knight/`，沿用原有五张图集名称与 SpriteFrames 资源 UID。移动 7 帧、10 FPS；待机取移动第 1 帧；攻击 10 帧按蓄力 1–7、冲刺 8–9、收招 10 拆分。所有帧为 256×256、同一 16 色板、0/255 透明通道。17 张唯一帧与用户确认稿逐像素相同；新的 PXG/PAL 与来源映射已同步安装。

| 图集 | 尺寸 | 动作 |
| --- | --- | --- |
| `knight_idle.png` | 256×256 | 移动第 1 帧 |
| `knight_move.png` | 1792×256 | 移动 1–7，10 FPS |
| `knight_windup.png` | 1792×256 | 攻击 1–7，400 ms |
| `knight_dash.png` | 512×256 | 攻击 8–9，160 ms |
| `knight_recover.png` | 256×256 | 攻击 10，500 ms |

`elite_rusher.tscn` 的 Sprite2D 缩放从 1.12 调整到 0.56，补偿画布分辨率翻倍；偏移改为 `(0,-52.08)`，将 `(128,221)` 鞋底基线置于身体原点，保持审阅画面。碰撞半径 33.6、移动速度、攻击距离、伤害和技能逻辑不变。攻击第 3 帧源图锤头左侧已有裁切，保留已确认的处理结果。

2026-10-04 清理后，原始17帧统一保存在 `artifacts/sources/enemies/iron_knight/`，压缩包成员与哈希见 `artifacts/sources/index.json`。历史审阅稿 `20261004-animation256-r4`、安装包 `20261004-installed256-r5`、旧资源备份和一次性验证脚本已按用户要求删除。当前 `art_source_manifest.json` 与 `artifacts/editable/index.json` 指向正式目录中的256版编辑源。

验证：Boss 安装器的五张图集规格检查通过；Godot 无窗口导入通过；`iron_knight_test.tscn` 的 73 项检查通过，包含完整攻击时序、移动帧、碰撞扫掠、阻挡、暂停与死亡。安装版实机场景直接实例化正式 `elite_rusher.tscn`，检查正式导入贴图与审阅帧的可见像素一致，并实际播放全部 17 帧、双向追击及完整攻击。

安装时 GPU 私有桌面验证通过，前台窗口采样为0，全部17帧实际播放。中间日志与截图不作为制作源保留；后续可运行 `scripts/tools/install_iron_knight_assets.py --check` 和 `scenes/tests/iron_knight_test.tscn` 检查当前正式资源。
