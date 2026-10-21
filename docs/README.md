# 项目文档

这里只维护当前实现、使用说明和约定。规则变化时更新对应文档；试验过程、阶段分析、截图与测试日志放入临时输出目录，完成后清理，不再积累历史报告。

| 内容 | 入口 |
| --- | --- |
| 工程与启动 | [目录、入口与验证](main/project_structure.md) |
| 游戏流程 | [波次、理财、结算与存档](main/run_flow.md) |
| 战斗操作 | [施放规则](main/active_combat_implementation.md)、[首次指引](main/combat_guide.md)、[逐技能自动释放](main/per_skill_auto_cast.md) |
| 武器 | [位移武器](main/mobility_weapons_implementation.md)、[命中判定](main/weapon_contact_rules_2026-10-19.md)、[提示文本](main/weapon_tooltip_inventory.md) |
| 附魔 | [提示与配置](main/enchantment_tooltip_inventory.md) |
| 交易与挑战 | [完整交易清单](../goblin_trades_list.md)、[新增交易规则](main/goblin_trade_expansion.md)、[合同](main/goblin_contracts.md)、[挑战](main/challenge_expansion.md) |
| 界面 | [布局坐标](main/hud_native_1920.md)、[正式样式](asset/hud_style.md) |
| 素材 | [规则](asset/asset_rules_summary.md)、[资源入口](asset/asset_checklist_summary.md)、[精灵与碰撞](asset/combat_sprite_clarity.md)、[环境](asset/battle_environment.md)、[特效](asset/combat_effects.md) |
| 性能 | [当前实现与维护边界](performance/README.md) |
| 数据与语言 | [配置目录](../data_config/README.md)、[本地化维护](../localization/README.md)、[术语表](localization/glossary.md) |
| 录制 | [战斗录制台](marketing/recording_studio.md) |

具体数值以运行配置及消费代码为准。素材原图与可编辑源放在 `artifacts/sources/`、`artifacts/reference/`、`artifacts/editable/` 和正式素材旁；[图标索引](asset/icon_manifest.json)保留当前文件、哈希和来源裁切信息，[配置参考资料](asset/config_reference_metadata.json)供素材审阅工具使用。
