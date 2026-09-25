# 审阅成品与必要报告

正式资源位于 `assets/`，运行代码位于 `scripts/`、`scenes/`，规则与实施记录位于 `docs/`。本目录仅保存最新且仍有用途的审阅材料；根目录 `.gdignore` 阻止 Godot 导入这些文件。

| 目录 | 保留内容 |
| --- | --- |
| [previews/water](previews/water/README.md) | 最新单圈扩散水流草稿、动图、绘制与录制入口、伤害最大半径检查；未替换正式资源。 |
| [previews/main_menu](previews/main_menu/README.md) | 待接入的主菜单像素背景、透明菜单层、合成预览和绘图源文件。 |
| [previews/nightwatch_spear](previews/nightwatch_spear/README.md) | 未接入正式武器池的长枪动作、判定和附魔原型。 |
| [reviews/effects](reviews/effects/) | 小 Boss 与掉落、结霜，以及已确认的两组水流组合动图。 |
| [reviews/weapons](reviews/weapons/) | 榴弹炮、流星锤、电浆炮、秘仪书和钱袋的代表性正式实录。 |
| [reviews/ui](reviews/ui/) | 属性栏、伤害统计、经济日志、设置和天赋的代表截图。 |
| [reports/android](reports/android/README.md) | Android 适配评估、控件测量和现行界面的桌面模拟截图。 |
| [reports/audio_release.json](reports/audio_release.json) | 已确认的 34 项音效资源、增益及哈希；32 项保留、2 项停播。验证结果见 [audio_validation.json](reports/audio_validation.json)。 |

常用入口：[水流草稿](previews/water/water_expansion.gif) · [汽化／冻结／导电／风吹扩散](reviews/effects/water_reactions.gif) · [落雷／光剑／黑洞／爆裂](reviews/effects/water_combinations.gif) · [小 Boss 与掉落](reviews/effects/elite.gif) · [属性栏](reviews/ui/stats.png)。

武器实录中，`grenade.gif`、`grenade_fire.gif`、`grenade_split.gif` 分别展示基础爆炸、逐目标火焰与正式分裂；流星锤保留机制和附魔两组动图。`plasma.mp4`、`tome.mp4`、`purse.mp4` 保留完整视口录像，同次录制的重复 GIF 和截图不另存。

绘图与构建依赖归入 `scripts/tools/`：遗物绘制函数见 `source_art/`，音频母版与处理输入见 `audio_sources/`，标题生成器为 `render_main_menu_title.py`。需要检查当前音效时运行 `scripts/tools/build_all_sfx_review.py`，试听页生成到系统临时目录。

新增录制的原始帧、日志、源码副本、临时测试脚本和打包中间文件应写入系统临时目录。审阅通过后只保留有独立用途的最新成品；同一内容优先保留一份，避免再按日期和轮次堆积历史目录。
