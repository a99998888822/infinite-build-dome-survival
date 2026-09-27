# 审阅成品与必要报告

正式资源位于 `assets/`，运行代码位于 `scripts/`、`scenes/`，规则与实施记录位于 `docs/`。本目录仅保存最新且仍有用途的审阅材料；根目录 `.gdignore` 阻止 Godot 导入这些文件。

| 目录 | 保留内容 |
| --- | --- |
| [previews/main_menu](previews/main_menu/README.md) | 待接入的主菜单像素背景、透明菜单层、合成预览和绘图源文件。 |
| [previews/iron_knight](previews/iron_knight/README.md) | 安装工具依赖的六组已确认透明图集及参数清单；美术模拟与联系表可重建，不保留重复成品。 |
| [previews/nightwatch_spear](previews/nightwatch_spear/README.md) | 未接入正式武器池的长枪动作、判定和附魔原型。 |
| [previews/range_relics](previews/range_relics/README.md) | 已接入的10件距离与范围遗物图标总览与属性说明；独立图标统一存放在正式资源目录。实机审阅见 [reviews/ui/range_relics](reviews/ui/range_relics/)。 |
| [reviews/effects](reviews/effects/) | 当前钢甲骑士、遗物掉落、单圈水流实录，以及[远景入水、电浆贴地、结霜对比](reviews/effects/grounding/)。旧四足怪录像、水流草稿与旧版组合动图已清理。 |
| [reviews/weapons](reviews/weapons/) | 榴弹炮、流星锤、电浆炮、秘仪书和钱袋的代表性正式实录。 |
| [reviews/ui](reviews/ui/) | 经济日志、设置、天赋、难度、遗物与属性范围的必要验证图；交易和结息仅保留最新代表成品。 |
| [reports/android](reports/android/README.md) | Android 适配评估、控件测量和现行界面的桌面模拟截图。 |
| [reports/balance_verification.md](reports/balance_verification.md) | 附魔掉率、稀有度槽数、三档难度与无天赋开局实测；含最新选择界面和战斗截图。 |
| [reports/audio_release.json](reports/audio_release.json) | 已确认的 34 项音效资源、增益及哈希；32 项保留、2 项停播。验证结果见 [audio_validation.json](reports/audio_validation.json)。 |

常用入口：[正式单圈水流](reviews/effects/water.gif) · [钢甲骑士](reviews/effects/iron_knight/game.gif) · [属性栏](reviews/ui/bank_hud_review/06_all_other_attributes.png) · [属性提示](reviews/ui/stat_tooltips.png)。

交易审阅仅保留：[五笔交易总览](reviews/ui/goblin_trade/five_trades_overview.png)、[小窗口完整条款](reviews/ui/goblin_trade/small_terms.png)、[强力刷新按钮](reviews/ui/goblin_trade/strong_refresh_button.gif)。总览由最后一版文本间距截图合成，历史布局与录制帧已清理。

结息审阅仅保留：[最新演出](reviews/ui/interest_arrival/settlement.gif)、[完整界面截图](reviews/ui/interest_arrival/receipt.png)、[小窗口截图](reviews/ui/interest_arrival/small_receipt.png)。对应已精简文案、居中显示及利率成长显示具体小数的版本。

最新武器提示：[六把武器的完整信息](reviews/ui/weapon_details/weapon_strip.png) · [理财页富文本提示](reviews/ui/weapon_details/bank_tooltips.png)。

属性数值与范围实测：[七项属性去掉百分号](reviews/ui/stat_ranges/stats.png) · [攻击距离对比](reviews/ui/stat_ranges/attack_range.png) · [伤害范围对比](reviews/ui/stat_ranges/damage_area.png)。使用一级铸铁榴弹炮，在相同目标位置对比属性 0 与 50；辅助线和 HP 标签为依据运行数据添加的审阅标注。

附魔掉落：[16×16图标与淡辉光](reviews/ui/enchantment_drops/ground_icons.png) · [ESC 四档稀有度](reviews/ui/enchantment_drops/inventory_rarities.png)。分裂紫、电火花蓝、爆裂橙，其余绿色；移除连锁主宰，掉落成功后按绿70／蓝20／紫8／橙2抽取。

遗物奖励掉落：[24像素斜上方视角符文小箱与四类掉落物实机对比](reviews/effects/relic_pickup/README.md)，带淡辉光和少量上浮方形粒子。

武器实录中，`grenade.gif`、`grenade_fire.gif`、`grenade_split.gif` 分别展示基础爆炸、逐目标火焰与正式分裂；流星锤保留机制和附魔两组动图。`plasma.mp4`、`tome.mp4`、`purse.mp4` 保留完整视口录像，同次录制的重复 GIF 和截图不另存。

绘图与构建依赖归入 `scripts/tools/`：遗物绘制函数见 `source_art/`，音频母版与处理输入见 `audio_sources/`，标题生成器为 `render_main_menu_title.py`。需要检查当前音效时运行 `scripts/tools/build_all_sfx_review.py`，试听页生成到系统临时目录。

新增录制的原始帧、日志、源码副本、临时测试脚本和打包中间文件应写入系统临时目录。审阅通过后只保留有独立用途的最新成品；同一内容优先保留一份，避免再按日期和轮次堆积历史目录。
