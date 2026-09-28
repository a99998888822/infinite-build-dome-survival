# 审阅成品与必要报告

正式资源位于 `assets/`，运行代码位于 `scripts/`、`scenes/`，规则与实施记录位于 `docs/`。本目录仅保存最新且仍有用途的审阅材料；根目录 `.gdignore` 阻止 Godot 导入这些文件。

最近一次[素材清理记录](reports/asset_cleanup.json)包含删除清单、保留规则、资源哈希核对和运行验证结果。

2026-09-29 [中间文件清理](reports/intermediate_cleanup.json)：清除两轮 Picxel 的未选用底稿、抠图副本、重复 PNG、放大过程图和过期角色预览；保留安装用交付包、最终可编辑网格、原图与最新实机成品。删除项的恢复备份位于项目外，路径见记录。

| 目录 | 保留内容 |
| --- | --- |
| [previews/combat_picxel_3838180](previews/combat_picxel_3838180/README.md) | 已接入新版初心者 8 帧、Boss 移动与攻击各 11 帧、小怪移动 7 帧；像素稿、游戏格式图集、动画预览和实机验证。 |
| [previews/player_picxel](previews/player_picxel/README.md) | 当前资本家四帧行走、展示图与头像；保留两角色上一版已确认像素稿和来源记录，初心者正式素材已由新版替换。 |
| [previews/bank_desk_picxel](previews/bank_desk_picxel/highres_r2/README.md) | 已确认并接入理财界面的 128×64、16 色透明柜台；原图像素化与局部修整记录。旧柜台的白底参考图已清理。 |
| [references/battle_environment](references/battle_environment/README.md) | 主战斗场景实际使用的 14 项小型环境素材：4096×3072 透明大图、中文编号对照图，以及供豆包高清重绘的逐项描述。 |
| [previews/goblin_reprint](previews/goblin_reprint/picxel_expressions_128/README.md) | 已接入的五表情原图、透明成品、可编辑像素网格与修整记录；旧造型、重复抠图和放大副本已清理。 |
| [previews/main_menu](previews/main_menu/README.md) | 待接入的主菜单像素背景、透明菜单层和合成预览；绘图源文件归入 `scripts/tools/source_art/`。 |
| [reviews/characters/capitalist](reviews/characters/capitalist/README.md) | 当前 Picxel 资本家的角色选择、结息截图与实机行走。旧绘图源和旧形象预览已清理。 |
| [reviews/ui/run_settlement](reviews/ui/run_settlement/README.md) | 已接入的死亡 / 通关营地币结算、四种哥布林反应与小窗口截图；过期离线原型和正式资源副本已清理。 |
| [previews/nightwatch_spear](previews/nightwatch_spear/README.md) | 未接入正式武器池的长枪动作、判定和附魔原型。 |
| [reviews/effects](reviews/effects/) | 当前钢甲骑士、遗物掉落、单圈水流实录，以及[远景入水和结霜对比](reviews/effects/grounding/)。 |
| [reviews/weapons](reviews/weapons/) | 榴弹炮、流星锤、电浆炮、秘仪书和钱袋的代表性正式实录。 |
| [reviews/ui](reviews/ui/) | 当前难度、结息、遗物、属性、武器提示、设置与天赋审阅图，另保留经济日志死亡结算样例。 |
| [reviews/ui/bank_desk_integration](reviews/ui/bank_desk_integration/README.md) | 当前柜台、完整哥布林图层、五种表情和小窗口实机截图；早期银行截图已清理。 |
| [reviews/environment/picxel_128_larger_ruins](reviews/environment/picxel_128_larger_ruins/README.md) | 当前放大遗迹的实机效果与尺寸对照；旧尺寸截图和重复返回视图已清理。 |
| [reports/android](reports/android/README.md) | Android 适配评估和当时的控件测量；过期桌面模拟截图已清理。 |
| [reports/audio_release.json](reports/audio_release.json) | 已确认的 34 项音效资源、增益及哈希；32 项保留、2 项停播。验证结果见 [audio_validation.json](reports/audio_validation.json)。 |

常用入口：[正式单圈水流](reviews/effects/water.gif) · [钢甲骑士](reviews/effects/iron_knight/game.gif) · [属性栏](reviews/ui/stat_ranges/stats.png) · [属性提示](reviews/ui/stat_tooltips.png)。

交易审阅仅保留：[五笔交易总览](reviews/ui/goblin_trade/five_trades_overview.png)、[小窗口完整条款](reviews/ui/goblin_trade/small_terms.png)、[强力刷新按钮](reviews/ui/goblin_trade/strong_refresh_button.gif)。总览由最后一版文本间距截图合成，历史布局与录制帧已清理。

新增[下一波挑战实机审阅](reviews/ui/wave_challenges/README.md)：三种挑战和 640×360 小窗口，仅保留四张成品截图。

新增[哥布林贷款实机与视觉审阅](reviews/ui/goblin_loan/README.md)：贷款已接入，包含三档弹窗、借款后银行底部状态栏及 640×360 实机截图；另保留已审阅的图标和贷款栏状态总览。

当前[难度与结算审阅](reviews/ui/wave_pressure/README.md)：数量翻倍后的三档怪群、利息等待9秒后Esc关闭、横向灰色“暂无附魔”，以及小窗口多项结息明细静帧。旧难度报告和自动消失版结息录像已清理。

最新武器提示：[六把武器的完整信息](reviews/ui/weapon_details/weapon_strip.png) · [理财页富文本提示](reviews/ui/weapon_details/bank_tooltips.png)。

属性数值与范围实测：[七项属性去掉百分号](reviews/ui/stat_ranges/stats.png) · [攻击距离对比](reviews/ui/stat_ranges/attack_range.png) · [伤害范围对比](reviews/ui/stat_ranges/damage_area.png)。使用一级铸铁榴弹炮，在相同目标位置对比属性 0 与 50；辅助线和 HP 标签为依据运行数据添加的审阅标注。

距离与范围遗物：[图标总览与实机验证](reviews/ui/range_relics/README.md)。已接入的图标审阅与商品、属性实测统一归在此处，独立素材仍在 `assets/ui/icons/relics/`。

附魔掉落：[16×16图标与淡辉光](reviews/ui/enchantment_drops/ground_icons.png) · [ESC 四档稀有度](reviews/ui/enchantment_drops/inventory_rarities.png)。分裂紫、电火花蓝、爆裂橙，其余绿色；移除连锁主宰，掉落成功后按绿70／蓝20／紫8／橙2抽取。

遗物奖励掉落：[24像素斜上方视角符文小箱与四类掉落物实机对比](reviews/effects/relic_pickup/README.md)，带淡辉光和少量上浮方形粒子。

武器实录中，`grenade.gif`、`grenade_fire.gif`、`grenade_split.gif` 分别展示基础爆炸、逐目标火焰与正式分裂；流星锤保留 [机制](reviews/weapons/meteor_flail.mp4) 和 [附魔](reviews/weapons/meteor_flail_enchantments.mp4) 两份录像。[plasma.mp4](reviews/weapons/plasma.mp4) 为最新接触减速实机对比：左侧原参数、右侧当前，上排持续接触、下排一击击杀；固定目标、无附魔，正常速度播放，文字为审阅标注。接触速度20，脱离后保持160毫秒，再用120毫秒恢复正常速度140；接触专项36项与武器回归70项通过。`tome.mp4`、`purse.mp4` 保留完整视口录像。

绘图与构建依赖归入 `scripts/tools/`：主菜单与遗物绘制源文件见 `source_art/`，音频母版见 `audio_sources/`。角色与怪物由 `install_combat_picxel_assets.py` 从已确认 Picxel 导出安装并核对哈希；钢甲骑士旧绘制代码已移除。需要检查当前音效时运行 `scripts/tools/build_all_sfx_review.py`。

原始帧、日志、临时测试脚本和打包中间文件写入系统临时目录。只保留有独立用途的最新成品；体积较大的录像使用MP4，核对尺寸、时长和画面后删除重复GIF，不按日期或轮次堆积目录。

Picxel 工作目录中的历史批次报告用于追溯，部分处理输入和过程预览已清理。继续改图使用报告 `selected` 指向的最终 `.pxg`；若要重跑旧批次的完整抠图、局部修整或 `finish` 流程，先从项目外备份恢复相应输入，不直接执行依赖已清理底稿的命令。
