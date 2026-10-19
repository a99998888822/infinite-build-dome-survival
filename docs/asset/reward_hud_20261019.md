# 战斗奖励界面灰铁方案

最终确认：用户否决轻紫试稿，正式版采用本页记录的灰铁常态、烟褐＋古铜悬停与彩色功能图标。轻紫稿未接入正式资源；完整处理范围见 `hud_finalization_20261019.md`。

2026-10-19：升级奖励与小 Boss 遗物奖励已接入与天赋、设置一致的正式 HUD 样式。

最新释放模式：升级奖励和小 Boss 奖励页均显示每把武器的手动／自动释放按钮；手指代表手动，循环箭头代表自动，点击可切换并同步战斗 HUD。按钮在各武器正下方的外框底线上居中，避开小框底角的左右换位按钮。状态图标恢复原有颜色：手指暖金 `#ddbe79`、循环箭头浅绿 `#91dcb8`，悬停时也保留状态色；边框继续使用灰铁常态、烟褐＋古铜悬停。沿用已有状态图标，无需新增图片。交互检查保存于 `artifacts/reviews/reward_weapon_cast_modes_20261019/`，最新彩色实景截图位于 `artifacts/reviews/reward_weapon_cast_colors_20261019/`。

最新留白与换位：奖励武器栏高度改为 90px，内框上下各留 12px（外框内容边距 2px＋容器边距 10px）。奖励页接入原有左右换位与拖动排序：第一把只显示右移、最后一把只显示左移、中间武器显示双向按钮。箭头位于各小框的下角，恢复原有淡黄色 `#dec48a`，悬停时也保留黄色；边框继续使用灰铁常态、烟褐＋古铜悬停。三武器实景、按钮交互及上下间距测量保存于 `artifacts/reviews/reward_weapon_padding_reorder_20261019/`，最新黄色箭头截图位于 `artifacts/reviews/reward_weapon_yellow_arrows_20261019/`。

最新武器小框：依用户提供的 `hud_background.png` 改用一像素细边、切角及内侧明暗线。直接裁去原图透明留白并逐色替换，保留原图透明轮廓和边线像素；常态为灰铁，悬停为烟褐＋古铜。两张 46×31 贴图分别位于 `assets/ui/hud/neutral_iron/weapon_slot_thin.png`、`assets/ui/hud/smoke_bronze/weapon_slot_thin.png`，通过 3px 九宫格边缘适配 64×64 武器槽，图标和控件内边距保持原值。来源、颜色映射、哈希与实际场景截图位于 `artifacts/reviews/reward_weapon_thin_frames_20261019/`。

同日补充：奖励面板上方每个武器图标增加独立灰铁像素边框，悬停使用烟褐＋古铜；通过武器栏的可选 `icon_slot_theme` 配置，武器列表重建后仍保留边框。截图位于 `artifacts/reviews/reward_weapon_frames_20261019/`。

- 面板、卡片、武器栏、跳过和刷新按钮采用炭黑／灰铁底、像素金属细边与骨白文字。
- 悬停奖励卡片或聚焦其选择按钮时，使用原烟褐＋古铜底图、边框与暖色文字；焦点移开后恢复灰铁色。
- 稀有度以图标区域底部的细色条和右上角文字显示，保留普通、优秀、稀有、史诗、神话、传说的区别；卡片大边框不再使用品级色。
- 移除旧奖励面板的扫描线和图标彩色光晕。保留四列两行、图标尺寸、说明、属性预览及原领取／刷新／跳过流程。

正式样式入口为 `scripts/ui/reward_hud_style.gd`，复用 `hud_palette.gd` 与 `assets/ui/hud/neutral_iron/`、`assets/ui/hud/smoke_bronze/`。两类奖励共用 `ShopPopup`／`RewardOption`；该组件的付费模式也使用相同外观。理财页独立的商店卡片和战斗属性卷轴未在本轮改绘。

实际场景截图与日志位于 `artifacts/reviews/reward_neutral_iron_20261019/`：

- `level_1920_highlight.png`：升级奖励，第一张卡片高亮。
- `miniboss_1920_highlight.png`：小 Boss 遗物奖励，第一张卡片高亮。
- `*_changed.png`：切换到第二张卡片。
- `*_keyboard_focus.png`：选择按钮键盘聚焦。
- `eight_choices_en.png`：八张奖励的英文布局。

截图使用临时会话与私有 Windows 桌面，未切换输入桌面。验证记录见同目录 `verification.json`。本轮无界面奖励布局检查覆盖 1184×666、1280×720、1920×1080、2560×1440，以及八选项布局、刷新、跳过和真实遗物领取；另运行 Boss 奖励队列、重复领取拒绝及胜利结算顺序检查。

最终结果：奖励布局 272 项、Boss 奖励流程 25 项检查通过；实际 GPU 场景含 9 张截图共 281 项检查通过，`foreground_samples=0`。无解析或脚本错误；独立 Boss 流程测试退出时控制台提示 115 个 ObjectDB 实例未释放，正式场景的布局测试及 GPU 运行未出现该提示。编辑器的 Android build-tools 提示与本轮 Windows UI 无关。
