# HUD 风格剩余范围核对

2026-10-19，按当前正式脚本、场景、贴图引用和实际入口核对。目标风格为灰铁常态、烟褐＋古铜悬停／选中。后续已完成 ESC 背包、下一波挑战、新手引导，并修复图鉴在理财等阶段的入口限制；详细实机验证见 `secondary_hud_20261019.md`。

## 已接入

天赋、主菜单／战斗设置、升级／Boss 奖励、结算，以及理财（存取款、商店、附魔／专精、出售武器、交易、贷款、到账和日志）的主框体与操作控件。

后续完成：ESC 背包／查看页（含武器、物品格与说明框）、下一波挑战、新手引导。图鉴入口已修复，图鉴自身仍保留旧样式。

本轮新增：战斗状态条外框、波次区、主动武器栏与伤害统计已接入分级装饰的灰铁／古铜设计；共享与系统悬浮提示已统一为极简单线像素框。详细范围与验证见 `combat_hud_20261019.md`。

理财四列布局已获用户确认：1920×1080 下银行宽 340px、商店／附魔宽 1103px、商品卡宽 262px。`scripts/ui/finance_popup.gd` 直接调用正式的 `FinanceSceneLayout` 和 `VirtualShopGrid`，两份脚本哈希与上一轮通过 285 项检查的版本一致。无需将截图或审阅脚本复制到正式目录。

## 仍需统一的常规 HUD

| 区域 | 仍使用的样式／范围 | 核对依据 |
| --- | --- | --- |
| 图鉴 | 外框仍为深绿底、旧金边，搜索、分类和列表控件未统一。战斗设置走独立的已更新组件，不受这条影响。 | `scripts/ui/battle_utility_overlay.gd:47`、`:149` |
| 移动端虚拟摇杆 | 深绿外圈、黄绿色描边与金色摇杆，未接入灰铁／古铜皮肤。 | `scripts/ui/mobile_joystick.gd:6` |

剩余常规 HUD：图鉴、移动摇杆。经验条保留已确认的无外框细条设计。

## 沿用独立美术的界面

- 主菜单按钮与语言选择：使用主菜单独立贴图；语言下拉仍为深绿金边。依据：`assets/ui/main_menu/menu_button_theme.tres`、`scripts/ui/main_menu_ui_controller.gd:486`。
- 选人页的角色卡、难度与导航按钮：继续使用 `assets/ui/character_select/` 中配套贴图。依据：`scripts/ui/character_select_view.gd:595`。
- 战斗属性卷轴：保留 `assets/ui/stats_drawer/stats_parchment_panel.png`，作为已约定保留的卷轴美术；其悬浮说明现已统一为极简像素框。
- 哥布林对话气泡：用户明确要求恢复原样，保留深橄榄底／旧金边，不算漏改。
- 加载界面：黑底浅灰文字，没有框体或交互按钮，不需要为统一风格额外加框。

主菜单、选人页和属性卷轴属于整体画风参考，不应仅因未引用灰铁贴图就直接重绘整页。可在后续需要时单独统一交互控件。

## 遗留资源

`InterestSettlementPopup` 独立利息结算窗仍为旧深绿／亮金样式。场景节点仍被实例化，但当前正式 `FinanceUIController` 不再配置或打开它，普通流程通过理财页到账演出显示；旧窗仅见调试审计直接调用。因此它属于待清理或迁移的遗留资源，不是当前理财到账界面漏改。

核对依据：`scripts/ui/interest_settlement_popup.gd:4`、`scenes/ui/finance/finance_ui_controller.tscn:15`、`scripts/ui/finance_ui_controller.gd:44`、`scripts/debug/ui_visual_audit.gd:236`。
