# 武器提示文本

当前 14 把武器的静态介绍维护于 [weapons.json](../../data_config/weapons.json)。完整详情按武器等级、角色属性、附魔、释放方式和当前状态动态构建，不维护另一份固定数值导出稿。

| 显示内容 | 实现入口 |
| --- | --- |
| 完整属性与机制 | `scripts/weapons/weapon_instance.gd` 的 `build_full_stats_text()` |
| Esc 武器栏 | `scripts/ui/weapon_strip.gd` 的 `_show_weapon_tooltip()` |
| 理财已装备武器 | `scripts/ui/enchantment_workbench.gd` |
| 选人初始武器 | `scripts/ui/character_select_view.gd` |
| 商店卡片与升级提示 | `scripts/ui/preparation_offer_card.gd`、`scripts/ui/shop_offer_generator.gd` |
| 理财页签与详情弹窗 | `scripts/ui/finance_popup.gd` |

`description` 与 `shop_description` 是静态介绍入口；商店升级提示展示该候选的增量，完整武器详情展示当前实例，二者数值口径不同。冷却、伤害、范围与多段攻击说明应使用同一套运行公式。

修改文案时同步本地化目录，并检查选人、商店、理财已装备和 Esc 的实际入口。位移技能的返回状态、自动／手动设置与特殊伤害时序分别参照[位移规则](mobility_weapons_implementation.md)、[自动释放](per_skill_auto_cast.md)和[命中判定](weapon_contact_rules_2026-10-19.md)。
