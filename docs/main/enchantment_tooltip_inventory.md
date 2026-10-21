# 附魔提示与配置

当前 19 种附魔的名称、介绍、稀有度和效果参数维护于 [augmentations.json](../../data_config/augmentations.json)，本地化文案维护于 [localization](../../localization/README.md)。显示数值应来自当前配置和实例，不保留另一个日期版本的文本快照。

理财背包放大镜、已装备附魔槽和 Esc 背包共用 `ItemInventoryCard._build_tooltip()`。保留名称标题，正文显示类型、稀有度和效果描述，不追加实例浮动参数、粒子或辉光参数。显示类型为增益、法术、元素；装填分类仍是附魔卷轴。

附魔作用于装填武器，装填顺序、兼容性、多段触发和元素反应由运行代码处理。编辑显示文案不应改变这些行为。核对效果时同时检查配置、实际伤害结算和[武器命中规则](weapon_contact_rules_2026-10-19.md)。

正式图标位于 `assets/ui/icons/augmentations/`，当前尺寸与显示倍率见[素材规则](../asset/asset_rules_summary.md)。
